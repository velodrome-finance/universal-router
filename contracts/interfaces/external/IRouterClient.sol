// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRouterClient {
    /// @dev RMN depends on this struct, if changing, please notify the RMN maintainers.
    struct EVMTokenAmount {
        address token; // token address on the local chain.
        uint256 amount; // Amount of tokens.
    }

    // If extraArgs is empty bytes, the default is 200k gas limit.
    struct EVM2AnyMessage {
        bytes receiver; // abi.encode(receiver address) for dest EVM chains
        bytes data; // Data payload
        EVMTokenAmount[] tokenAmounts; // Token transfers
        address feeToken; // Address of feeToken. address(0) means you will send msg.value.
        bytes extraArgs; // Populate this with _argsToBytes(EVMExtraArgsV2)
    }

    /// @param destinationChainSelector The destination chainSelector
    /// @param message The cross-chain CCIP message including data and/or tokens
    /// @return fee returns execution fee for the message
    /// delivery to destination chain, denominated in the feeToken specified in the message.
    /// @dev Reverts with appropriate reason upon invalid message.
    function getFee(uint64 destinationChainSelector, EVM2AnyMessage memory message)
        external
        view
        returns (uint256 fee);
}
