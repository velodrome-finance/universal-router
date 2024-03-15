// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {DeployUniversalRouter} from '../DeployUniversalRouter.s.sol';
import {RouterParameters} from 'contracts/base/RouterImmutables.sol';

contract DeployOptimism is DeployUniversalRouter {
    function setUp() public override {
        params = RouterParameters({
            permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3,
            weth9: 0x4200000000000000000000000000000000000006,
            seaportV1_5: 0x00000000000000ADc04C56Bf30aC9d3c0aAF14dC,
            seaportV1_4: 0x00000000000001ad428e4906aE43D8F9852d0dD6,
            openseaConduit: 0x1E0049783F008A0085193E00003D00cd54003c71,
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
            v2Factory: 0xF1046053aa5682b4F9a81b5481394DA16BE5FF5a,
            v3Factory: 0x548118C7E0B865C2CfA94D15EC86B666468ac758,
            v2Implementation: 0x95885Af5492195F0754bE71AD1545Fe81364E531,
            clImplementation: 0xE0A596c403E854FFb9C828aB4f07eEae04A05D37
        });

        unsupported = 0x40d51104Da22E3e77b683894E7e3E12e8FC61E65;
    }
}
