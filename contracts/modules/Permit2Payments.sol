// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {IAllowanceTransfer} from 'permit2/src/interfaces/IAllowanceTransfer.sol';
import {SafeCast160} from 'permit2/src/libraries/SafeCast160.sol';
import {ERC20} from 'solmate/src/tokens/ERC20.sol';
import {Payments} from './Payments.sol';

/// @title Payments through Permit2
/// @notice Performs interactions with Permit2 to transfer tokens
abstract contract Permit2Payments is Payments {
    using SafeCast160 for uint256;

    error FromAddressIsNotOwner();

    /// @notice Performs a transferFrom on Permit2
    /// @param token The token to transfer
    /// @param from The address to transfer from
    /// @param to The recipient of the transfer
    /// @param amount The amount to transfer
    function permit2TransferFrom(address token, address from, address to, uint160 amount) internal {
        PERMIT2.transferFrom(from, to, amount, token);
    }

    /// @notice Performs a batch transferFrom on Permit2
    /// @param batchDetails An array detailing each of the transfers that should occur
    /// @param owner The address that should be the owner of all transfers
    function permit2TransferFrom(IAllowanceTransfer.AllowanceTransferDetails[] calldata batchDetails, address owner)
        internal
    {
        uint256 batchLength = batchDetails.length;
        for (uint256 i = 0; i < batchLength; ++i) {
            if (batchDetails[i].from != owner) revert FromAddressIsNotOwner();
        }
        PERMIT2.transferFrom(batchDetails);
    }

    /// @notice Attempts a regular payment if payer is the router, otherwise attempts a transferFrom
    /// @notice A regular transferFrom is attempted prior to Permit2
    /// @param token The token to transfer
    /// @param payer The address to pay for the transfer
    /// @param recipient The recipient of the transfer
    /// @param amount The amount to transfer
    function payOrPermit2Transfer(address token, address payer, address recipient, uint256 amount) internal {
        if (payer == address(this)) {
            pay(token, recipient, amount);
        } else {
            // Try regular transferFrom before using Permit2
            (bool success, bytes memory data) =
                token.call(abi.encodeCall(ERC20.transferFrom, (payer, recipient, amount)));

            // Fall back to Permit2 if either:
            // 1. The call itself failed (reverted), or
            // 2. The call succeeded but returned a non-empty response of 'false'
            //    (Some ERC20 tokens return false instead of reverting on failure)
            if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
                permit2TransferFrom(token, payer, recipient, amount.toUint160());
            }
        }
    }
}
