// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPostDispatchHook} from '@hyperlane/core/contracts/interfaces/hooks/IPostDispatchHook.sol';

interface IInterchainAccountRouter {
    /// @notice Dispatches a commitment and reveal message to the destination domain.
    ///  Useful for when we want to keep calldata secret (e.g. when executing a swap)
    /// @dev The commitment message is dispatched first, followed by the reveal message.
    /// The revealed calldata is executed by the `revealAndExecute` function, which will be called the OffChainLookupIsm in its `verify` function.
    /// @param _destination The remote domain of the chain to make calls on
    /// @param _router The remote router address
    /// @param _ism The remote ISM address
    /// @param _hookMetadata The hook metadata to override with for the hook set by the owner
    /// @param _salt Salt which allows control over account derivation.
    /// @param _hook The hook to use after sending our message to the mailbox
    /// @param _commitment The commitment to dispatch
    /// @return _commitmentMsgId The Hyperlane message ID of the commitment message
    /// @return _revealMsgId The Hyperlane message ID of the reveal message
    function callRemoteCommitReveal(
        uint32 _destination,
        bytes32 _router,
        bytes32 _ism,
        bytes memory _hookMetadata,
        IPostDispatchHook _hook,
        bytes32 _salt,
        bytes32 _commitment
    ) external payable returns (bytes32 _commitmentMsgId, bytes32 _revealMsgId);
}
