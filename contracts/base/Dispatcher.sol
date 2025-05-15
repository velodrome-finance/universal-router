// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {ERC20} from 'solmate/src/tokens/ERC20.sol';
import {TypeCasts} from '@hyperlane/core/contracts/libs/TypeCasts.sol';
import {IPostDispatchHook} from '@hyperlane/core/contracts/interfaces/hooks/IPostDispatchHook.sol';
import {IAllowanceTransfer} from 'permit2/src/interfaces/IAllowanceTransfer.sol';
import {ActionConstants} from '@uniswap/v4-periphery/src/libraries/ActionConstants.sol';
import {CalldataDecoder} from '@uniswap/v4-periphery/src/libraries/CalldataDecoder.sol';
import {PoolKey} from '@uniswap/v4-core/src/types/PoolKey.sol';
import {IPoolManager} from '@uniswap/v4-core/src/interfaces/IPoolManager.sol';

import {IInterchainAccountRouter} from '../interfaces/external/IInterchainAccountRouter.sol';
import {V2SwapRouter} from '../modules/uniswap/v2/V2SwapRouter.sol';
import {V3SwapRouter} from '../modules/uniswap/v3/V3SwapRouter.sol';
import {V4SwapRouter} from '../modules/uniswap/v4/V4SwapRouter.sol';
import {BytesLib} from '../modules/uniswap/v3/BytesLib.sol';
import {Payments} from '../modules/Payments.sol';
import {BridgeRouter} from '../modules/bridge/BridgeRouter.sol';
import {Commands} from '../libraries/Commands.sol';
import {Constants} from '../libraries/Constants.sol';
import {Lock} from './Lock.sol';

/// @title Decodes and Executes Commands
/// @notice Called by the UniversalRouter contract to efficiently decode and execute a singular command
abstract contract Dispatcher is Payments, V2SwapRouter, V3SwapRouter, V4SwapRouter, BridgeRouter, Lock {
    using BytesLib for bytes;
    using CalldataDecoder for bytes;

    error InvalidCommandType(uint256 commandType);
    error BalanceTooLow();

    event UniversalRouterSwap(address indexed sender, address indexed recipient);
    event UniversalRouterBridge(
        address indexed sender, address indexed recipient, address indexed token, uint256 amount, uint32 domain
    );

    /// @notice Executes encoded commands along with provided inputs.
    /// @param commands A set of concatenated commands, each 1 byte in length
    /// @param inputs An array of byte strings containing abi encoded inputs for each command
    function execute(bytes calldata commands, bytes[] calldata inputs) external payable virtual;

    /// @notice Public view function to be used instead of msg.sender, as the contract performs self-reentrancy and at
    /// times msg.sender == address(this). Instead msgSender() returns the initiator of the lock
    /// @dev overrides BaseActionsRouter.msgSender in V4Router
    function msgSender() public view override returns (address) {
        return _getLocker();
    }

    /// @notice Decodes and executes the given command with the given inputs
    /// @param commandType The command type to execute
    /// @param inputs The inputs to execute the command with
    /// @dev 2 masks are used to enable use of a nested-if statement in execution for efficiency reasons
    /// @return success True on success of the command, false on failure
    /// @return output The outputs or error messages, if any, from the command
    function dispatch(bytes1 commandType, bytes calldata inputs) internal returns (bool success, bytes memory output) {
        uint256 command = uint8(commandType & Commands.COMMAND_TYPE_MASK);

        success = true;

        // 0x00 <= command < 0x21
        if (command < Commands.EXECUTE_SUB_PLAN) {
            // 0x00 <= command < 0x10
            if (command < Commands.V4_SWAP) {
                // 0x00 <= command < 0x08
                if (command < Commands.V2_SWAP_EXACT_IN) {
                    if (command == Commands.V3_SWAP_EXACT_IN) {
                        // equivalent: abi.decode(inputs, (address, uint256, uint256, bytes, bool, bool))
                        address recipient;
                        uint256 amountIn;
                        uint256 amountOutMin;
                        bool payerIsUser;
                        bool isUni;
                        assembly {
                            recipient := calldataload(inputs.offset)
                            amountIn := calldataload(add(inputs.offset, 0x20))
                            amountOutMin := calldataload(add(inputs.offset, 0x40))
                            // 0x60 offset is the path, decoded below
                            payerIsUser := calldataload(add(inputs.offset, 0x80))
                            isUni := calldataload(add(inputs.offset, 0xA0))
                        }
                        bytes calldata path = inputs.toBytes(3);
                        address payer = payerIsUser ? msgSender() : address(this);
                        v3SwapExactInput({
                            recipient: map(recipient),
                            amountIn: amountIn,
                            amountOutMinimum: amountOutMin,
                            path: path,
                            payer: payer,
                            isUni: isUni
                        });
                        emit UniversalRouterSwap({sender: msgSender(), recipient: recipient});
                    } else if (command == Commands.V3_SWAP_EXACT_OUT) {
                        // equivalent: abi.decode(inputs, (address, uint256, uint256, bytes, bool, bool))
                        address recipient;
                        uint256 amountOut;
                        uint256 amountInMax;
                        bool payerIsUser;
                        bool isUni;
                        assembly {
                            recipient := calldataload(inputs.offset)
                            amountOut := calldataload(add(inputs.offset, 0x20))
                            amountInMax := calldataload(add(inputs.offset, 0x40))
                            // 0x60 offset is the path, decoded below
                            payerIsUser := calldataload(add(inputs.offset, 0x80))
                            isUni := calldataload(add(inputs.offset, 0xA0))
                        }
                        bytes calldata path = inputs.toBytes(3);
                        address payer = payerIsUser ? msgSender() : address(this);
                        v3SwapExactOutput({
                            recipient: map(recipient),
                            amountOut: amountOut,
                            amountInMaximum: amountInMax,
                            path: path,
                            payer: payer,
                            isUni: isUni
                        });
                        emit UniversalRouterSwap({sender: msgSender(), recipient: recipient});
                    } else if (command == Commands.PERMIT2_TRANSFER_FROM) {
                        // equivalent: abi.decode(inputs, (address, address, uint160))
                        address token;
                        address recipient;
                        uint160 amount;
                        assembly {
                            token := calldataload(inputs.offset)
                            recipient := calldataload(add(inputs.offset, 0x20))
                            amount := calldataload(add(inputs.offset, 0x40))
                        }
                        permit2TransferFrom(token, msgSender(), map(recipient), amount);
                    } else if (command == Commands.PERMIT2_PERMIT_BATCH) {
                        IAllowanceTransfer.PermitBatch calldata permitBatch;
                        assembly {
                            // this is a variable length struct, so calldataload(inputs.offset) contains the
                            // offset from inputs.offset at which the struct begins
                            permitBatch := add(inputs.offset, calldataload(inputs.offset))
                        }
                        bytes calldata data = inputs.toBytes(1);
                        (success, output) = address(PERMIT2).call(
                            abi.encodeWithSignature(
                                'permit(address,((address,uint160,uint48,uint48)[],address,uint256),bytes)',
                                msgSender(),
                                permitBatch,
                                data
                            )
                        );
                    } else if (command == Commands.SWEEP) {
                        // equivalent:  abi.decode(inputs, (address, address, uint256))
                        address token;
                        address recipient;
                        uint160 amountMin;
                        assembly {
                            token := calldataload(inputs.offset)
                            recipient := calldataload(add(inputs.offset, 0x20))
                            amountMin := calldataload(add(inputs.offset, 0x40))
                        }
                        Payments.sweep(token, map(recipient), amountMin);
                    } else if (command == Commands.TRANSFER) {
                        // equivalent:  abi.decode(inputs, (address, address, uint256))
                        address token;
                        address recipient;
                        uint256 value;
                        assembly {
                            token := calldataload(inputs.offset)
                            recipient := calldataload(add(inputs.offset, 0x20))
                            value := calldataload(add(inputs.offset, 0x40))
                        }
                        Payments.pay(token, map(recipient), value);
                    } else if (command == Commands.PAY_PORTION) {
                        // equivalent:  abi.decode(inputs, (address, address, uint256))
                        address token;
                        address recipient;
                        uint256 bips;
                        assembly {
                            token := calldataload(inputs.offset)
                            recipient := calldataload(add(inputs.offset, 0x20))
                            bips := calldataload(add(inputs.offset, 0x40))
                        }
                        Payments.payPortion(token, map(recipient), bips);
                    } else if (command == Commands.TRANSFER_FROM) {
                        // equivalent:  abi.decode(inputs, (address, address, uint256))
                        address token;
                        address recipient;
                        uint256 value;
                        assembly {
                            token := calldataload(inputs.offset)
                            recipient := calldataload(add(inputs.offset, 0x20))
                            value := calldataload(add(inputs.offset, 0x40))
                        }

                        address payer = msgSender();
                        if (value == Constants.TOTAL_BALANCE) value = ERC20(token).balanceOf(payer);
                        payOrPermit2Transfer({token: token, payer: payer, recipient: map(recipient), amount: value});
                    }
                } else {
                    // 0x08 <= command < 0x10
                    if (command == Commands.V2_SWAP_EXACT_IN) {
                        // equivalent: abi.decode(inputs, (address, uint256, uint256, bytes, bool, bool))
                        address recipient;
                        uint256 amountIn;
                        uint256 amountOutMin;
                        bool payerIsUser;
                        bool isUni;
                        assembly {
                            recipient := calldataload(inputs.offset)
                            amountIn := calldataload(add(inputs.offset, 0x20))
                            amountOutMin := calldataload(add(inputs.offset, 0x40))
                            // 0x60 offset is the path, decoded below
                            payerIsUser := calldataload(add(inputs.offset, 0x80))
                            isUni := calldataload(add(inputs.offset, 0xA0))
                        }
                        bytes calldata path = inputs.toBytes(3);
                        address payer = payerIsUser ? msgSender() : address(this);
                        v2SwapExactInput(map(recipient), amountIn, amountOutMin, path, payer, isUni);
                        emit UniversalRouterSwap({sender: msgSender(), recipient: recipient});
                    } else if (command == Commands.V2_SWAP_EXACT_OUT) {
                        // equivalent: abi.decode(inputs, (address, uint256, uint256, bytes, bool, bool))
                        address recipient;
                        uint256 amountOut;
                        uint256 amountInMax;
                        bool payerIsUser;
                        bool isUni;
                        assembly {
                            recipient := calldataload(inputs.offset)
                            amountOut := calldataload(add(inputs.offset, 0x20))
                            amountInMax := calldataload(add(inputs.offset, 0x40))
                            // 0x60 offset is the path, decoded below
                            payerIsUser := calldataload(add(inputs.offset, 0x80))
                            isUni := calldataload(add(inputs.offset, 0xA0))
                        }
                        bytes calldata path = inputs.toBytes(3);
                        address payer = payerIsUser ? msgSender() : address(this);
                        v2SwapExactOutput(map(recipient), amountOut, amountInMax, path, payer, isUni);
                        emit UniversalRouterSwap({sender: msgSender(), recipient: recipient});
                    } else if (command == Commands.PERMIT2_PERMIT) {
                        // equivalent: abi.decode(inputs, (IAllowanceTransfer.PermitSingle, bytes))
                        IAllowanceTransfer.PermitSingle calldata permitSingle;
                        assembly {
                            permitSingle := inputs.offset
                        }
                        bytes calldata data = inputs.toBytes(6); // PermitSingle takes first 6 slots (0..5)
                        (success, output) = address(PERMIT2).call(
                            abi.encodeWithSignature(
                                'permit(address,((address,uint160,uint48,uint48),address,uint256),bytes)',
                                msgSender(),
                                permitSingle,
                                data
                            )
                        );
                    } else if (command == Commands.WRAP_ETH) {
                        // equivalent: abi.decode(inputs, (address, uint256))
                        address recipient;
                        uint256 amount;
                        assembly {
                            recipient := calldataload(inputs.offset)
                            amount := calldataload(add(inputs.offset, 0x20))
                        }
                        Payments.wrapETH(map(recipient), amount);
                    } else if (command == Commands.UNWRAP_WETH) {
                        // equivalent: abi.decode(inputs, (address, uint256))
                        address recipient;
                        uint256 amountMin;
                        assembly {
                            recipient := calldataload(inputs.offset)
                            amountMin := calldataload(add(inputs.offset, 0x20))
                        }
                        Payments.unwrapWETH9(map(recipient), amountMin);
                    } else if (command == Commands.PERMIT2_TRANSFER_FROM_BATCH) {
                        IAllowanceTransfer.AllowanceTransferDetails[] calldata batchDetails;
                        (uint256 length, uint256 offset) = inputs.toLengthOffset(0);
                        assembly {
                            batchDetails.length := length
                            batchDetails.offset := offset
                        }
                        permit2TransferFrom(batchDetails, msgSender());
                    } else if (command == Commands.BALANCE_CHECK_ERC20) {
                        // equivalent: abi.decode(inputs, (address, address, uint256))
                        address owner;
                        address token;
                        uint256 minBalance;
                        assembly {
                            owner := calldataload(inputs.offset)
                            token := calldataload(add(inputs.offset, 0x20))
                            minBalance := calldataload(add(inputs.offset, 0x40))
                        }
                        success = (ERC20(token).balanceOf(owner) >= minBalance);
                        if (!success) output = abi.encodePacked(BalanceTooLow.selector);
                    } else {
                        // placeholder area for command 0x0f
                        revert InvalidCommandType(command);
                    }
                }
            } else {
                // 0x10 <= command < 0x21
                if (command == Commands.V4_SWAP) {
                    // pass the calldata provided to V4SwapRouter._executeActions (defined in BaseActionsRouter)
                    _executeActions(inputs);
                    // This contract MUST be approved to spend the token since its going to be doing the call on the position manager
                } else if (command == Commands.V4_INITIALIZE_POOL) {
                    PoolKey calldata poolKey;
                    uint160 sqrtPriceX96;
                    assembly {
                        poolKey := inputs.offset
                        sqrtPriceX96 := calldataload(add(inputs.offset, 0xa0))
                    }
                    (success, output) =
                        address(poolManager).call(abi.encodeCall(IPoolManager.initialize, (poolKey, sqrtPriceX96)));
                } else if (command == Commands.BRIDGE_TOKEN) {
                    // equivalent: abi.decode(inputs, (uint8, address, address, address, uint256, uint256, uint32, bool))
                    uint8 bridgeType;
                    address recipient;
                    address token;
                    address bridge;
                    uint256 amount;
                    uint256 msgFee;
                    uint32 domain;
                    bool payerIsUser;
                    assembly {
                        bridgeType := calldataload(inputs.offset)
                        recipient := calldataload(add(inputs.offset, 0x20))
                        token := calldataload(add(inputs.offset, 0x40))
                        bridge := calldataload(add(inputs.offset, 0x60))
                        amount := calldataload(add(inputs.offset, 0x80))
                        msgFee := calldataload(add(inputs.offset, 0xA0))
                        domain := calldataload(add(inputs.offset, 0xC0))
                        payerIsUser := calldataload(add(inputs.offset, 0xE0))
                    }
                    address sender = msgSender();
                    address payer = payerIsUser ? sender : address(this);
                    recipient = recipient == ActionConstants.MSG_SENDER ? sender : recipient;
                    bridgeToken({
                        bridgeType: bridgeType,
                        sender: sender,
                        recipient: recipient,
                        token: token,
                        bridge: bridge,
                        amount: amount,
                        msgFee: msgFee,
                        domain: domain,
                        payer: payer
                    });
                    emit UniversalRouterBridge({
                        sender: sender,
                        recipient: recipient,
                        token: token,
                        amount: amount,
                        domain: domain
                    });
                } else if (command == Commands.EXECUTE_CROSS_CHAIN) {
                    // equivalent: abi.decode(inputs, (uint32, address, bytes32, bytes32, bytes32, uint256, address, bytes))
                    uint32 domain;
                    address icaRouter;
                    bytes32 remoteRouter;
                    bytes32 ism;
                    bytes32 commitment;
                    uint256 msgFee;
                    address hook;
                    assembly {
                        domain := calldataload(inputs.offset)
                        icaRouter := calldataload(add(inputs.offset, 0x20))
                        remoteRouter := calldataload(add(inputs.offset, 0x40))
                        ism := calldataload(add(inputs.offset, 0x60))
                        commitment := calldataload(add(inputs.offset, 0x80))
                        msgFee := calldataload(add(inputs.offset, 0xA0))
                        hook := calldataload(add(inputs.offset, 0xC0))
                        // 0xE0 offset contains the hook metadata, decoded below
                    }
                    bytes calldata hookMetadata = inputs.toBytes(7);

                    IInterchainAccountRouter(icaRouter).callRemoteWithOverrides{value: msgFee}({
                        _destination: domain,
                        _router: remoteRouter,
                        _ism: ism,
                        _callsCommitment: commitment,
                        _hookMetadata: hookMetadata,
                        _salt: TypeCasts.addressToBytes32(msgSender()),
                        _hook: IPostDispatchHook(hook)
                    });
                } else {
                    // placeholder area for commands 0x14-0x20
                    revert InvalidCommandType(command);
                }
            }
        } else {
            // 0x21 <= command
            if (command == Commands.EXECUTE_SUB_PLAN) {
                (bytes calldata _commands, bytes[] calldata _inputs) = inputs.decodeCommandsAndInputs();
                (success, output) = (address(this)).call(abi.encodeCall(Dispatcher.execute, (_commands, _inputs)));
            } else {
                // placeholder area for commands 0x22-0x3f
                revert InvalidCommandType(command);
            }
        }
    }

    /// @notice Calculates the recipient address for a command
    /// @param recipient The recipient or recipient-flag for the command
    /// @return output The resultant recipient for the command
    function map(address recipient) internal view returns (address) {
        if (recipient == ActionConstants.MSG_SENDER) {
            return msgSender();
        } else if (recipient == ActionConstants.ADDRESS_THIS) {
            return address(this);
        } else {
            return recipient;
        }
    }
}
