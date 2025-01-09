// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {DeployUniversalRouter} from '../DeployUniversalRouter.s.sol';
import {RouterParameters} from 'contracts/base/RouterImmutables.sol';

contract DeployBase is DeployUniversalRouter {
    function setUp() public override {
        params = RouterParameters({
            permit2: address(0),
            weth9: 0xFC00000000000000000000000000000000000006,
            seaportV1_5: UNSUPPORTED_PROTOCOL,
            seaportV1_4: UNSUPPORTED_PROTOCOL,
            openseaConduit: UNSUPPORTED_PROTOCOL,
            nftxZap: UNSUPPORTED_PROTOCOL,
            x2y2: UNSUPPORTED_PROTOCOL,
            foundation: UNSUPPORTED_PROTOCOL,
            sudoswap: UNSUPPORTED_PROTOCOL,
            elementMarket: UNSUPPORTED_PROTOCOL,
            nft20Zap: UNSUPPORTED_PROTOCOL,
            cryptopunks: UNSUPPORTED_PROTOCOL,
            looksRareV2: UNSUPPORTED_PROTOCOL,
            routerRewardsDistributor: UNSUPPORTED_PROTOCOL,
            looksRareRewardsDistributor: UNSUPPORTED_PROTOCOL,
            looksRareToken: UNSUPPORTED_PROTOCOL,
            v2Factory: 0x31832f2a97Fd20664D76Cc421207669b55CE4BC0,
            v3Factory: 0x04625B046C69577EfC40e6c0Bb83CDBAfab5a55F,
            v2Implementation: 0x10499d88Bd32AF443Fc936F67DE32bE1c8Bb374C,
            clImplementation: 0x321f7Dfb9B2eA9131B8C17691CF6e01E5c149cA8
        });

        unsupported = address(0);
        outputFilename = 'fraxtal.json';
    }
}
