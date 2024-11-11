// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import '../DeployUniversalRouter.s.sol';
import {RouterParameters} from 'contracts/base/RouterImmutables.sol';
import {ModeUniversalRouter} from 'contracts/extensions/ModeUniversalRouter.sol';

contract DeployMode is DeployUniversalRouter {
    using CreateXLibrary for bytes11;

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
            v2Factory: 0x31832f2a97Fd20664D76Cc421207669b55CE4BC0,
            v3Factory: 0x04625B046C69577EfC40e6c0Bb83CDBAfab5a55F,
            v2Implementation: 0x10499d88Bd32AF443Fc936F67DE32bE1c8Bb374C,
            clImplementation: 0x321f7Dfb9B2eA9131B8C17691CF6e01E5c149cA8
        });
        // tokenId needs to be set, to the token id for router
        modeParameters = ModeRouterParameters({sfs: 0x8680CEaBcb9b56913c519c069Add6Bc3494B7020, tokenId: 590});

        unsupported = 0x0D6953a74f9e50478e325B14053985eE8D548EdE;
        outputFilename = 'mode.json';
        require(modeParameters.tokenId != 0);
    }

    function deploy() internal override {
        router = ModeUniversalRouter(
            payable(
                cx.deployCreate3({
                    salt: UNIVERSAL_ROUTER_ENTROPY.calculateSalt({_deployer: deployer}),
                    initCode: abi.encodePacked(
                        type(ModeUniversalRouter).creationCode,
                        abi.encode(
                            params, // params
                            modeParameters.sfs, // sfs
                            modeParameters.tokenId // tokenId
                        )
                    )
                })
            )
        );

        checkAddress({_entropy: UNIVERSAL_ROUTER_ENTROPY, _output: address(router)});
    }
}
