// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import {IPostDispatchHook} from '@hyperlane-updated/contracts/interfaces/hooks/IPostDispatchHook.sol';
import {OwnableMulticall} from '@hyperlane-updated/contracts/middleware/libs/OwnableMulticall.sol';
import {CallLib} from '@hyperlane-updated/contracts/middleware/libs/Call.sol';
import {TypeCasts} from '@hyperlane-updated/contracts/libs/TypeCasts.sol';

import {InterchainAccountRouter} from '@hyperlane-updated/contracts/middleware/InterchainAccountRouter.sol';
import {InterchainAccountMessage} from './libs/InterchainAccountMessage.sol';

contract MockInterchainAccountRouter is InterchainAccountRouter {
    using TypeCasts for bytes32;

    error InvalidPayload();

    mapping(address => bytes32) public verifiedCommitments;

    constructor(address _mailbox) InterchainAccountRouter(_mailbox) {}

    /**
     * @notice Dispatches a sequence of remote calls to be made by an owner's
     * interchain account on the destination domain
     * @param _destination The remote domain of the chain to make calls on
     * @param _router The remote router address
     * @param _ism The remote ISM address
     * @param _callsCommitment The commitment to the sequence of calls to make
     * @param _hookMetadata The hook metadata to override with for the hook set by the owner
     * @param _salt Salt which allows control over account derivation.
     * @param _hook The hook to use after sending our message to the mailbox
     * @return The Hyperlane message ID
     */
    function callRemoteWithOverrides(
        uint32 _destination,
        bytes32 _router,
        bytes32 _ism,
        bytes32 _callsCommitment,
        bytes memory _hookMetadata,
        bytes32 _salt,
        IPostDispatchHook _hook
    ) public payable returns (bytes32) {
        bytes memory _body = InterchainAccountMessage.encodeCommitment(msg.sender, _ism, _callsCommitment, _salt);
        return _dispatchMessageWithHookOverride(_destination, _router, _ism, _body, _hookMetadata, _hook);
    }

    function executeWithCommitment(address _interchainAccount, CallLib.Call[] calldata _calls) public payable {
        bytes32 _commitment = hashCommitment(_calls);
        if (verifiedCommitments[_interchainAccount] != _commitment) revert InvalidPayload();

        delete verifiedCommitments[_interchainAccount];
        OwnableMulticall(payable(_interchainAccount)).multicall{value: msg.value}(_calls);
    }

    /**
     * @notice Handles dispatched messages by relaying calls to the interchain account
     * @dev Handle override with Commitment support
     * @dev `onlyMailbox` is checked during MockHandleForwarder.handle()
     * @param _origin The origin domain of the interchain account
     * @param _sender The sender of the interchain message
     * @param _message The InterchainAccountMessage containing the account
     * owner, ISM, and sequence of calls to be relayed
     * @dev Does not need to be onlyRemoteRouter, as this application is designed
     * to receive messages from untrusted remote contracts.
     */
    function handleOverride(uint32 _origin, bytes32 _sender, bytes calldata _message) external payable {
        (bytes32 _owner, bytes32 _ism, bytes32 _commitment, bytes32 _salt) =
            InterchainAccountMessage.decodeCommitment(_message);

        OwnableMulticall _interchainAccount =
            getDeployedInterchainAccount(_origin, _owner, _sender, _ism.bytes32ToAddress(), _salt);
        // Store commitment
        verifiedCommitments[address(_interchainAccount)] = _commitment;
    }

    /// @dev Helper function to generate commitment hashes
    function hashCommitment(CallLib.Call[] memory _calls) internal pure returns (bytes32 _salt) {
        bytes memory calls;
        uint256 length = _calls.length;
        for (uint256 i = 0; i < length; i++) {
            calls = abi.encode(calls, _calls[i].to, _calls[i].value, _calls[i].data);
        }

        return keccak256(calls);
    }

    /**
     * @notice Dispatches an InterchainAccountMessage to the remote router with hook metadata
     * @param _destination The remote domain
     * @param _router The address of the remote InterchainAccountRouter
     * @param _ism The address of the remote ISM
     * @param _body The InterchainAccountMessage body
     * @param _hookMetadata The hook metadata to override with for the hook set by the owner
     * @param _hook The hook to use after sending our message to the mailbox
     */
    function _dispatchMessageWithHookOverride(
        uint32 _destination,
        bytes32 _router,
        bytes32 _ism,
        bytes memory _body,
        bytes memory _hookMetadata,
        IPostDispatchHook _hook
    ) private returns (bytes32) {
        require(_router != InterchainAccountMessage.EMPTY_SALT, 'no router specified for destination');
        emit RemoteCallDispatched(_destination, msg.sender, _router, _ism);
        return mailbox.dispatch{value: msg.value}(_destination, _router, _body, _hookMetadata, _hook);
    }
}
