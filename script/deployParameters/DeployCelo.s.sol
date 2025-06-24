// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {DeployUniversalRouter} from '../DeployUniversalRouter.s.sol';

contract DeployCelo is DeployUniversalRouter {
    function setUp() public override {
        params = DeploymentParameters({
            weth9: UNSUPPORTED_PROTOCOL,
            v2Factory: 0x79a530c8e2fA8748B7B40dd3629C0520c2cCf03f,
            v3Factory: 0xAfE208a311B21f13EF87E33A90049fC17A7acDEc,
            pairInitCodeHash: 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f,
            poolInitCodeHash: 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54,
            v4PoolManager: UNSUPPORTED_PROTOCOL,
            veloV2Factory: 0x31832f2a97Fd20664D76Cc421207669b55CE4BC0,
            veloCLFactory: 0x04625B046C69577EfC40e6c0Bb83CDBAfab5a55F,
            veloV2InitCodeHash: 0x558be7ee0c63546b31d0773eee1d90451bd76a0167bb89653722a2bd677c002d,
            veloCLInitCodeHash: 0x7b216153c50849f664871825fa6f22b3356cdce2436e4f48734ae2a926a4c7e5
        });

        outputFilename = 'celo.json';
    }
}
