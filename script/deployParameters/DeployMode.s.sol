// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {DeployUniversalRouter} from '../DeployUniversalRouter.s.sol';
import {RouterParameters} from 'contracts/base/RouterImmutables.sol';
import {ModeUniversalRouter} from 'contracts/extensions/ModeUniversalRouter.sol';

contract DeployMode is DeployUniversalRouter {
    struct ModeRouterParameters {
        address sfs;
        uint256 tokenId;
    }

    ModeRouterParameters internal modeParameters;

    function setUp() public override {
        params = RouterParameters({
            permit2: 0xbF055A2D7450b55c194c32e285deDb956416CAF3,
            weth9: 0x4200000000000000000000000000000000000006,
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
            v2Factory: 0x629157747eE3a635F9EA1ED37fD0DC7187d45478,
            v3Factory: address(0),
            v2Implementation: 0xDF49FF386344d3b687F56c02D0b1784b19013E25,
            clImplementation: address(0)
        });
        // tokenId needs to be set, to the token id for router
        modeParameters = ModeRouterParameters({sfs: 0x8680CEaBcb9b56913c519c069Add6Bc3494B7020, tokenId: 0});

        unsupported = 0x0D6953a74f9e50478e325B14053985eE8D548EdE;
        require(modeParameters.tokenId != 0);
    }

    function deploy() internal override {
        router = new ModeUniversalRouter({params: params, sfs: modeParameters.sfs, tokenId: modeParameters.tokenId});
    }
}
