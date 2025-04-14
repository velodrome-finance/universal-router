// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPostDispatchHook} from '@hyperlane/core/contracts/interfaces/hooks/IPostDispatchHook.sol';

interface IInterchainAccountRouter {
    /// @notice Dispatches a sequence of remote calls to be made by an owner's
    /// interchain account on the destination domain
    /// @param _destination The remote domain of the chain to make calls on
    /// @param _router The remote router address
    /// @param _ism The remote ISM address
    /// @param _callsCommitment The commitment to the sequence of calls to make
    /// @param _hookMetadata The hook metadata to override with for the hook set by the owner
    /// @param _salt Salt which allows control over account derivation.
    /// @param _hook The hook to use after sending our message to the mailbox
    /// @return The Hyperlane message ID
    function callRemoteWithOverrides(
        uint32 _destination,
        bytes32 _router,
        bytes32 _ism,
        bytes32 _callsCommitment,
        bytes memory _hookMetadata,
        bytes32 _salt,
        IPostDispatchHook _hook
    ) external payable returns (bytes32);
}
