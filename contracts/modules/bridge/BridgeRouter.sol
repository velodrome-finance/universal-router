// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {ERC20} from 'solmate/src/tokens/ERC20.sol';
import {SafeTransferLib} from 'solmate/src/utils/SafeTransferLib.sol';
import {TypeCasts} from '@hyperlane/core/contracts/libs/TypeCasts.sol';
import {ITokenBridge, Quote, ITokenFee} from '@hyperlane/core/contracts/interfaces/ITokenBridge.sol';

import {IXVeloTokenBridge} from '../../interfaces/external/IXVeloTokenBridge.sol';
import {BridgeTypes} from '../../libraries/BridgeTypes.sol';
import {Permit2Payments} from './../Permit2Payments.sol';

/// @title BridgeRouter
/// @notice Handles cross-chain bridging operations
abstract contract BridgeRouter is Permit2Payments {
    using SafeTransferLib for ERC20;

    error InvalidTokenAddress();
    error InvalidRecipient();
    error InvalidBridgeType(uint8 bridgeType);
    error TokenFeeExceedsMax(uint256 tokenFee, uint256 maxTokenFee);

    uint256 public constant OPTIMISM_CHAIN_ID = 10;

    /// @notice Send tokens x-chain using the selected bridge
    /// @param bridgeType The type of bridge to use
    /// @param sender The address initiating the bridge
    /// @param recipient The recipient address on the destination chain
    /// @param token The token to be bridged
    /// @param bridge The bridge used for the token
    /// @param amount The amount to bridge
    /// @param msgFee The fee to pay for message bridging
    /// @param maxTokenFee The maximum acceptable fee for token bridging
    /// @param domain The destination domain
    /// @param payer The address to pay for the transfer
    function bridgeToken(
        uint8 bridgeType,
        address sender,
        address recipient,
        address token,
        address bridge,
        uint256 amount,
        uint256 msgFee,
        uint256 maxTokenFee,
        uint32 domain,
        address payer
    ) internal {
        if (recipient == address(0)) revert InvalidRecipient();

        if (bridgeType == BridgeTypes.HYP_XERC20) {
            prepareTokensForBridge({_token: token, _bridge: bridge, _payer: payer, _amount: amount});

            executeHypBridge({bridge: bridge, recipient: recipient, amount: amount, msgFee: msgFee, domain: domain});
            ERC20(token).safeApprove({to: bridge, amount: 0});
        } else if (bridgeType == BridgeTypes.XVELO) {
            address _bridgeToken = block.chainid == OPTIMISM_CHAIN_ID
                ? IXVeloTokenBridge(bridge).erc20()
                : IXVeloTokenBridge(bridge).xerc20();
            if (_bridgeToken != token) revert InvalidTokenAddress();

            prepareTokensForBridge({_token: token, _bridge: bridge, _payer: payer, _amount: amount});

            executeXVELOBridge({
                bridge: bridge, sender: sender, recipient: recipient, amount: amount, msgFee: msgFee, domain: domain
            });
            ERC20(token).safeApprove({to: bridge, amount: 0});
        } else if (bridgeType == BridgeTypes.HYP_ERC20_COLLATERAL) {
            uint256 bridgeAmount = quoteExactInputBridgeAmount(bridge, token, recipient, amount, domain);
            uint256 tokenFee = amount - bridgeAmount;
            if (tokenFee > maxTokenFee) revert TokenFeeExceedsMax(tokenFee, maxTokenFee);

            prepareTokensForBridge({_token: token, _bridge: bridge, _payer: payer, _amount: amount});

            executeHypBridge({bridge: bridge, recipient: recipient, amount: bridgeAmount, msgFee: msgFee, domain: domain});
            ERC20(token).safeApprove({to: bridge, amount: 0});
        } else {
            revert InvalidBridgeType({bridgeType: bridgeType});
        }
    }

    /// @dev Executes bridge transfer via ITokenBridge (HypXERC20 or HypERC20Collateral)
    function executeHypBridge(address bridge, address recipient, uint256 amount, uint256 msgFee, uint32 domain)
        private
    {
        ITokenBridge(bridge).transferRemote{value: msgFee}({
            _destination: domain,
            _recipient: TypeCasts.addressToBytes32(recipient),
            _amount: amount
        });
    }

    /// @dev Executes bridge transfer via XVELO TokenBridge
    function executeXVELOBridge(
        address bridge,
        address sender,
        address recipient,
        uint256 amount,
        uint256 msgFee,
        uint32 domain
    ) private {
        IXVeloTokenBridge(bridge).sendToken{value: msgFee}({
            _recipient: recipient, _amount: amount, _domain: domain, _refundAddress: sender
        });
    }

    /// @dev Computes the amount to pass to transferRemote such that bridgeAmount + fee(bridgeAmount) = amount
    /// Assumes internal (quotes[1]) and external (quotes[2]) fees scale linearly with amount.
    /// The IGP fee (quotes[0]) is fixed and deducted from available amount if token-denominated.
    /// @param bridge The HypERC20Collateral bridge address
    /// @param token The collateral token address
    /// @param recipient The recipient address on the destination chain
    /// @param amount The total token amount the user provides
    /// @param domain The destination domain
    /// @return bridgeAmount The amount to pass to transferRemote
    function quoteExactInputBridgeAmount(
        address bridge,
        address token,
        address recipient,
        uint256 amount,
        uint32 domain
    ) internal view returns (uint256 bridgeAmount) {
        bytes32 recipientBytes32 = TypeCasts.addressToBytes32(recipient);
        Quote[] memory quotes = ITokenFee(bridge).quoteTransferRemote(domain, recipientBytes32, amount);
        uint256 igpTokenFee = (quotes[0].token == token) ? quotes[0].amount : 0;
        uint256 linearQuotedTokens = quotes[1].amount + quotes[2].amount;
        bridgeAmount = ((amount - igpTokenFee) * amount) / linearQuotedTokens;
    }

    /// @dev Moves the tokens from sender to this contract then approves the bridge
    function prepareTokensForBridge(address _token, address _bridge, address _payer, uint256 _amount) private {
        if (_payer != address(this)) {
            payOrPermit2Transfer({token: _token, payer: _payer, recipient: address(this), amount: _amount});
        }
        ERC20(_token).safeApprove({to: _bridge, amount: _amount});
    }
}
