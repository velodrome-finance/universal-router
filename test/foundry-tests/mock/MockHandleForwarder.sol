// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import {MockInterchainAccountRouter} from './MockInterchainAccountRouter.sol';

/// @dev Helper contract to allow overriding non-virtual handle function in ICARouter
contract MockHandleForwarder {
    MockInterchainAccountRouter public immutable icaRouter;
    address public immutable mailbox;

    constructor(address _icaRouter, address _mailbox) {
        icaRouter = MockInterchainAccountRouter(_icaRouter);
        mailbox = _mailbox;
    }

    /**
     * @notice Only accept messages from a Hyperlane Mailbox contract
     */
    modifier onlyMailbox() {
        require(msg.sender == mailbox, 'MailboxClient: sender not mailbox');
        _;
    }

    /// @dev Forward `handle()` calls to `handleOverride()` in MockICARouter
    function handle(uint32 _origin, bytes32 _sender, bytes calldata _message) external payable onlyMailbox {
        icaRouter.handleOverride({_origin: _origin, _sender: _sender, _message: _message});
    }
}
