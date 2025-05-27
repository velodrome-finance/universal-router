// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {DeployUniversalRouter} from '../DeployUniversalRouter.s.sol';

contract DeployOptimism is DeployUniversalRouter {
    function setUp() public override {
        params = DeploymentParameters({
            weth9: 0x4200000000000000000000000000000000000006,
            v2Factory: 0x0c3c1c532F1e39EdF36BE9Fe0bE1410313E074Bf,
            v3Factory: 0x1F98431c8aD98523631AE4a59f267346ea31F984,
            pairInitCodeHash: 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f,
            poolInitCodeHash: 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54,
            v4PoolManager: 0x9a13F98Cb987694C9F086b1F5eB990EeA8264Ec3,
            veloV2Factory: 0xF1046053aa5682b4F9a81b5481394DA16BE5FF5a,
            veloCLFactory: 0xCc0bDDB707055e04e497aB22a59c2aF4391cd12F,
            veloV2InitCodeHash: 0xc0629f1c7daa09624e54d4f711ba99922a844907cce02997176399e4cc7e8fcf,
            veloCLInitCodeHash: 0x339492e30b7a68609e535da9b0773082bfe60230ca47639ee5566007d525f5a7
        });
    }
}
