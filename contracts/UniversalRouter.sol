// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

// Command implementations
import {Dispatcher} from './base/Dispatcher.sol';
import {RouterDeployParameters} from './types/RouterDeployParameters.sol';
import {PaymentsImmutables, PaymentsParameters} from './modules/PaymentsImmutables.sol';
import {RouterImmutables, RouterParameters} from './modules/uniswap/RouterImmutables.sol';
import {V4SwapRouter} from './modules/uniswap/v4/V4SwapRouter.sol';
import {Commands} from './libraries/Commands.sol';
import {IUniversalRouter} from './interfaces/IUniversalRouter.sol';

contract UniversalRouter is IUniversalRouter, Dispatcher {
    constructor(RouterDeployParameters memory params)
        RouterImmutables(
            RouterParameters(
                params.v2Factory,
                params.v3Factory,
                params.pairInitCodeHash,
                params.poolInitCodeHash,
                params.veloV2Factory,
                params.veloCLFactory,
                params.veloV2InitCodeHash,
                params.veloCLInitCodeHash
            )
        )
        V4SwapRouter(params.v4PoolManager)
        PaymentsImmutables(PaymentsParameters(params.permit2, params.weth9))
    {}

    modifier checkDeadline(uint256 deadline) {
        if (block.timestamp > deadline) revert TransactionDeadlinePassed();
        _;
    }

    /// @notice To receive ETH from WETH
    receive() external payable {
        if (msg.sender != address(WETH9) && msg.sender != address(poolManager)) revert InvalidEthSender();
    }

    /// @inheritdoc IUniversalRouter
    function execute(bytes calldata commands, bytes[] calldata inputs, uint256 deadline)
        external
        payable
        checkDeadline(deadline)
    {
        execute(commands, inputs);
    }

    /// @inheritdoc Dispatcher
    function execute(bytes calldata commands, bytes[] calldata inputs) public payable override isNotLocked {
        bool success;
        bytes memory output;
        uint256 numCommands = commands.length;
        if (inputs.length != numCommands) revert LengthMismatch();

        // loop through all given commands, execute them and pass along outputs as defined
        for (uint256 commandIndex = 0; commandIndex < numCommands; commandIndex++) {
            bytes1 command = commands[commandIndex];

            bytes calldata input = inputs[commandIndex];

            (success, output) = dispatch(command, input);

            if (!success && successRequired(command)) {
                revert ExecutionFailed({commandIndex: commandIndex, message: output});
            }
        }
    }

    function successRequired(bytes1 command) internal pure returns (bool) {
        return command & Commands.FLAG_ALLOW_REVERT == 0;
    }
}
