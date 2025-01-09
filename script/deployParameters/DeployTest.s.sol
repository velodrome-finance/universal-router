// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {DeployUniversalRouter} from '../DeployUniversalRouter.s.sol';
import {RouterParameters} from 'contracts/base/RouterImmutables.sol';

import {TestConstants} from 'test/foundry-tests/utils/TestConstants.t.sol';

contract DeployTest is DeployUniversalRouter, TestConstants {
    /// @dev Using constructor since `setUp()` is not called automatically in tests
    constructor() {
        params = RouterParameters({
            permit2: address(PERMIT2),
            weth9: address(WETH),
            seaportV1_5: address(0),
            seaportV1_4: address(0),
            openseaConduit: address(0),
            nftxZap: address(0),
            x2y2: address(0),
            foundation: address(0),
            sudoswap: address(0),
            elementMarket: address(0),
            nft20Zap: address(0),
            cryptopunks: address(0),
            looksRareV2: address(0),
            routerRewardsDistributor: address(0),
            looksRareRewardsDistributor: address(0),
            looksRareToken: address(0),
            v2Factory: address(FACTORY),
            v3Factory: address(CL_FACTORY),
            v2Implementation: POOL_IMPLEMENTATION,
            clImplementation: CL_POOL_IMPLEMENTATION
        });

        unsupported = address(0);
        isTest = true;
    }

    function setUp() public override {}
}
