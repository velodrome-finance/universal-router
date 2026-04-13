// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from 'forge-std/Test.sol';
import {Quote, ITokenFee} from '@hyperlane/core/contracts/interfaces/ITokenBridge.sol';
import {TypeCasts} from '@hyperlane/core/contracts/libs/TypeCasts.sol';
import {BridgeRouter} from '../../../contracts/modules/bridge/BridgeRouter.sol';
import {PaymentsParameters, PaymentsImmutables} from '../../../contracts/modules/PaymentsImmutables.sol';

/// @dev Minimal harness that exposes BridgeRouter.quoteExactInputBridgeAmount for testing
contract BridgeRouterHarness is BridgeRouter {
    constructor() PaymentsImmutables(PaymentsParameters({permit2: address(0), weth9: address(0)})) {}

    function exposed_quoteExactInputBridgeAmount(
        address bridge,
        address token,
        address recipient,
        uint256 amount,
        uint32 domain
    ) external view returns (uint256) {
        return quoteExactInputBridgeAmount(bridge, token, recipient, amount, domain);
    }
}

/// @notice Unit tests for BridgeRouter.quoteExactInputBridgeAmount
/// Tests the formula: bridgeAmount = ((amount - igpTokenFee) * amount) / (quotes[1].amount + quotes[2].amount)
contract QuoteExactInputTest is Test {
    BridgeRouterHarness harness;

    address constant BRIDGE = address(0xB1);
    address constant TOKEN = address(0xC1);
    address constant RECIPIENT = address(0xA1);
    uint32 constant DOMAIN = 8453;

    function setUp() public {
        harness = new BridgeRouterHarness();
    }

    /// @dev Helper to mock quoteTransferRemote with the given quotes
    function _mockQuote(uint256 amount, Quote[3] memory quotes) internal {
        Quote[] memory quotesArr = new Quote[](3);
        quotesArr[0] = quotes[0];
        quotesArr[1] = quotes[1];
        quotesArr[2] = quotes[2];

        bytes32 recipientBytes32 = TypeCasts.addressToBytes32(RECIPIENT);
        vm.mockCall(
            BRIDGE,
            abi.encodeCall(ITokenFee.quoteTransferRemote, (DOMAIN, recipientBytes32, amount)),
            abi.encode(quotesArr)
        );
    }

    /// @notice No fees at all — bridgeAmount should equal amount
    function test_noFees() public {
        uint256 amount = 1000e6;
        _mockQuote(amount, [
            Quote({token: address(0), amount: 0}),       // no IGP
            Quote({token: TOKEN, amount: amount}),        // no internal fee
            Quote({token: TOKEN, amount: 0})              // no external fee
        ]);

        uint256 bridgeAmount = harness.exposed_quoteExactInputBridgeAmount(BRIDGE, TOKEN, RECIPIENT, amount, DOMAIN);
        assertEq(bridgeAmount, amount);
    }

    /// @notice Native IGP fee only — bridgeAmount should equal amount (IGP paid in ETH, not tokens)
    function test_nativeIgpOnly() public {
        uint256 amount = 1000e6;
        _mockQuote(amount, [
            Quote({token: address(0), amount: 69e9}),     // native IGP fee
            Quote({token: TOKEN, amount: amount}),         // no internal fee
            Quote({token: TOKEN, amount: 0})               // no external fee
        ]);

        uint256 bridgeAmount = harness.exposed_quoteExactInputBridgeAmount(BRIDGE, TOKEN, RECIPIENT, amount, DOMAIN);
        assertEq(bridgeAmount, amount);
    }

    /// @notice 5 bps internal fee (deployed USDC warp route style)
    /// For 1000 USDC: quotes[1] = 1000.5 USDC, quotes[2] = 0
    function test_internalFeeOnly() public {
        uint256 amount = 1000e6;
        uint256 internalFee = 500000; // 0.5 USDC = 5 bps of 1000 USDC
        _mockQuote(amount, [
            Quote({token: address(0), amount: 69e9}),               // native IGP
            Quote({token: TOKEN, amount: amount + internalFee}),    // 1000.5 USDC
            Quote({token: TOKEN, amount: 0})                        // no external fee
        ]);

        uint256 bridgeAmount = harness.exposed_quoteExactInputBridgeAmount(BRIDGE, TOKEN, RECIPIENT, amount, DOMAIN);

        // bridgeAmount + fee(bridgeAmount) should approximate amount
        // fee(bridgeAmount) = internalFee * bridgeAmount / amount
        uint256 feeOnBridgeAmount = (internalFee * bridgeAmount) / amount;
        assertApproxEqAbs(bridgeAmount + feeOnBridgeAmount, amount, 1, 'bridgeAmount + fee should equal amount');
        assertLt(bridgeAmount, amount, 'bridgeAmount should be less than amount');
    }

    /// @notice External fee only (e.g. CCTP ~1.3 bps)
    function test_externalFeeOnly() public {
        uint256 amount = 1000e6;
        uint256 externalFee = 130000; // 0.13 USDC = 1.3 bps of 1000 USDC
        _mockQuote(amount, [
            Quote({token: address(0), amount: 69e9}),     // native IGP
            Quote({token: TOKEN, amount: amount}),         // no internal fee
            Quote({token: TOKEN, amount: externalFee})     // 0.13 USDC external
        ]);

        uint256 bridgeAmount = harness.exposed_quoteExactInputBridgeAmount(BRIDGE, TOKEN, RECIPIENT, amount, DOMAIN);

        uint256 feeOnBridgeAmount = (externalFee * bridgeAmount) / amount;
        assertApproxEqAbs(bridgeAmount + feeOnBridgeAmount, amount, 1, 'bridgeAmount + fee should equal amount');
        assertLt(bridgeAmount, amount);
    }

    /// @notice Both internal and external fees
    function test_internalAndExternalFees() public {
        uint256 amount = 1000e6;
        uint256 internalFee = 500000;  // 5 bps
        uint256 externalFee = 130000;  // 1.3 bps
        _mockQuote(amount, [
            Quote({token: address(0), amount: 69e9}),
            Quote({token: TOKEN, amount: amount + internalFee}),
            Quote({token: TOKEN, amount: externalFee})
        ]);

        uint256 bridgeAmount = harness.exposed_quoteExactInputBridgeAmount(BRIDGE, TOKEN, RECIPIENT, amount, DOMAIN);

        uint256 totalFee = internalFee + externalFee;
        uint256 feeOnBridgeAmount = (totalFee * bridgeAmount) / amount;
        assertApproxEqAbs(bridgeAmount + feeOnBridgeAmount, amount, 1, 'bridgeAmount + fee should equal amount');
        assertLt(bridgeAmount, amount);
    }

    /// @notice Token-denominated IGP fee should be deducted from available amount
    function test_tokenDenominatedIgp() public {
        uint256 amount = 1000e6;
        uint256 igpFee = 1e6; // 1 USDC IGP fee in token
        uint256 internalFee = 500000; // 5 bps
        _mockQuote(amount, [
            Quote({token: TOKEN, amount: igpFee}),                  // IGP in same token
            Quote({token: TOKEN, amount: amount + internalFee}),    // internal fee
            Quote({token: TOKEN, amount: 0})                        // no external fee
        ]);

        uint256 bridgeAmount = harness.exposed_quoteExactInputBridgeAmount(BRIDGE, TOKEN, RECIPIENT, amount, DOMAIN);

        // bridgeAmount should be less than the no-IGP case
        uint256 availableForBridge = amount - igpFee;
        uint256 feeOnBridgeAmount = (internalFee * bridgeAmount) / amount;
        assertApproxEqAbs(bridgeAmount + feeOnBridgeAmount, availableForBridge, 1, 'bridgeAmount + fee should equal amount - igp');
        assertLt(bridgeAmount, availableForBridge);
    }

    /// @notice Large amount (18 decimal token) — verify no overflow
    function test_largeAmount18Decimals() public {
        uint256 amount = 1_000_000_000 * 1e18; // 1 billion tokens with 18 decimals
        uint256 internalFee = amount * 5 / 10000; // 5 bps
        _mockQuote(amount, [
            Quote({token: address(0), amount: 69e9}),
            Quote({token: TOKEN, amount: amount + internalFee}),
            Quote({token: TOKEN, amount: 0})
        ]);

        uint256 bridgeAmount = harness.exposed_quoteExactInputBridgeAmount(BRIDGE, TOKEN, RECIPIENT, amount, DOMAIN);

        uint256 feeOnBridgeAmount = (internalFee * bridgeAmount) / amount;
        assertApproxEqAbs(bridgeAmount + feeOnBridgeAmount, amount, 1e6, 'bridgeAmount + fee should equal amount');
        assertLt(bridgeAmount, amount);
    }
}
