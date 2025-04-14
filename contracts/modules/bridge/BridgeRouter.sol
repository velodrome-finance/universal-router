// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {ERC20} from 'solmate/src/tokens/ERC20.sol';
import {SafeTransferLib} from 'solmate/src/utils/SafeTransferLib.sol';
import {HypXERC20} from '@hyperlane/core/contracts/token/extensions/HypXERC20.sol';
import {StandardHookMetadata} from '@hyperlane/core/contracts/hooks/libs/StandardHookMetadata.sol';
import {TypeCasts} from '@hyperlane/core/contracts/libs/TypeCasts.sol';
import {IPostDispatchHook} from '@hyperlane/core/contracts/interfaces/hooks/IPostDispatchHook.sol';
import {Mailbox} from '@hyperlane/core/contracts/Mailbox.sol';

import {ITokenBridge} from '../../interfaces/external/ITokenBridge.sol';
import {IHookGasEstimator} from '../../interfaces/external/IHookGasEstimator.sol';
import {IRootHLMessageModule} from '../../interfaces/external/IRootHLMessageModule.sol';
import {BridgeTypes} from '../../libraries/BridgeTypes.sol';
import {Permit2Payments} from './../Permit2Payments.sol';

/// @title BridgeRouter
/// @notice Handles cross-chain bridging operations
abstract contract BridgeRouter is Permit2Payments {
    using SafeTransferLib for ERC20;

    error InvalidTokenAddress();
    error InvalidRecipient();
    error InvalidBridgeType(uint8 bridgeType);
    error InsufficientFunds();

    uint256 public constant OPTIMISM_CHAIN_ID = 10;
    IRootHLMessageModule internal immutable rootMessageModule;

    constructor(address _rootMessageModule) {
        rootMessageModule = IRootHLMessageModule(_rootMessageModule);
    }

    /// @notice Send tokens x-chain using the selected bridge
    /// @param bridgeType The type of bridge to use
    /// @param sender The address initiating the bridge
    /// @param recipient The recipient address on the destination chain
    /// @param token The token to be bridged
    /// @param bridge The bridge used for the token
    /// @param amount The amount to bridge
    /// @param domain The destination domain
    /// @param payer The address to pay for the transfer
    function bridgeToken(
        uint8 bridgeType,
        address sender,
        address recipient,
        address token,
        address bridge,
        uint256 amount,
        uint32 domain,
        address payer
    ) internal {
        if (recipient == address(0)) revert InvalidRecipient();

        if (bridgeType == BridgeTypes.HYP_XERC20) {
            if (address(HypXERC20(bridge).wrappedToken()) != token) revert InvalidTokenAddress();

            prepareTokensForBridge({_token: token, _bridge: bridge, _sender: sender, _amount: amount, _payer: payer});

            executeHypXERC20Bridge({
                bridge: bridge,
                sender: sender,
                recipient: recipient,
                amount: amount,
                domain: domain
            });
        } else if (bridgeType == BridgeTypes.XVELO) {
            address _bridgeToken = block.chainid == 10 ? ITokenBridge(bridge).erc20() : ITokenBridge(bridge).xerc20();
            if (_bridgeToken != token) revert InvalidTokenAddress();

            prepareTokensForBridge({_token: token, _bridge: bridge, _sender: sender, _amount: amount, _payer: payer});

            executeXVELOBridge({bridge: bridge, sender: sender, recipient: recipient, amount: amount, domain: domain});
        } else {
            revert InvalidBridgeType({bridgeType: bridgeType});
        }
    }

    /// @dev Executes bridge transfer via HypXERC20
    function executeHypXERC20Bridge(address bridge, address sender, address recipient, uint256 amount, uint32 domain)
        private
    {
        bytes memory metadata = StandardHookMetadata.formatMetadata({
            _msgValue: uint256(0),
            _gasLimit: HypXERC20(bridge).destinationGas(domain),
            _refundAddress: sender,
            _customMetadata: ''
        });

        HypXERC20(bridge).transferRemote{value: msg.value}({
            _destination: domain,
            _recipient: TypeCasts.addressToBytes32(recipient),
            _amountOrId: amount,
            _hookMetadata: metadata,
            _hook: address(HypXERC20(bridge).hook())
        });
    }

    /// @dev Executes bridge transfer via XVELO TokenBridge
    ///      Leftover ETH refunded to the sender
    ///      On leaf chains the chainId always defaults to 10
    function executeXVELOBridge(address bridge, address sender, address recipient, uint256 amount, uint32 domain)
        private
    {
        address hook = ITokenBridge(bridge).hook();
        uint256 gasLimit =
            hook != address(0) ? IHookGasEstimator(hook).estimateSendTokenGas() : ITokenBridge(bridge).GAS_LIMIT();
        bytes memory metadata = StandardHookMetadata.formatMetadata({
            _msgValue: uint256(0),
            _gasLimit: gasLimit,
            _refundAddress: sender,
            _customMetadata: ''
        });

        // workaround to avoid failed tx on refund
        uint256 fee = Mailbox(ITokenBridge(bridge).mailbox()).quoteDispatch({
            destinationDomain: domain,
            recipientAddress: TypeCasts.addressToBytes32(bridge),
            messageBody: abi.encodePacked(recipient, amount),
            metadata: metadata,
            hook: IPostDispatchHook(hook)
        });

        if (fee > msg.value) revert InsufficientFunds();
        uint256 leftover = msg.value - fee;

        uint256 chainId = block.chainid == OPTIMISM_CHAIN_ID ? rootMessageModule.chains(domain) : OPTIMISM_CHAIN_ID;

        ITokenBridge(bridge).sendToken{value: fee}({_recipient: recipient, _amount: amount, _chainid: chainId});

        // return any leftover ETH to the sender
        if (leftover > 0) payable(sender).transfer(leftover);
    }

    /// @dev Moves the tokens from sender to this contract then approves the bridge
    function prepareTokensForBridge(address _token, address _bridge, address _sender, uint256 _amount, address _payer)
        private
    {
        if (_payer != address(this)) {
            payOrPermit2Transfer({token: _token, payer: _sender, recipient: address(this), amount: _amount});
        }
        ERC20(_token).safeApprove({to: address(_bridge), amount: _amount});
    }
}
