// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {DeployUniversalRouter} from '../DeployUniversalRouter.s.sol';
import {RouterParameters} from 'contracts/types/RouterParameters.sol';

contract DeployInk is DeployUniversalRouter {
    function setUp() public override {
        params = RouterParameters({
            permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3,
            weth9: 0x4200000000000000000000000000000000000006,
            v2Factory: 0xfe57A6BA1951F69aE2Ed4abe23e0f095DF500C04,
            v3Factory: 0x640887A9ba3A9C53Ed27D0F7e8246A4F933f3424,
            pairInitCodeHash: 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f,
            poolInitCodeHash: 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54,
            v4PoolManager: 0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32,
            veloV2Factory: 0x31832f2a97Fd20664D76Cc421207669b55CE4BC0,
            veloCLFactory: 0x04625B046C69577EfC40e6c0Bb83CDBAfab5a55F,
            veloV2InitCodeHash: 0x558be7ee0c63546b31d0773eee1d90451bd76a0167bb89653722a2bd677c002d,
            veloCLInitCodeHash: 0x7b216153c50849f664871825fa6f22b3356cdce2436e4f48734ae2a926a4c7e5
        });
    }
}
