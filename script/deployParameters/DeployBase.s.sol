// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {DeployUniversalRouter} from '../DeployUniversalRouter.s.sol';

contract DeployBase is DeployUniversalRouter {
    function setUp() public override {
        params = DeploymentParameters({
            weth9: 0x4200000000000000000000000000000000000006,
            v2Factory: 0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6,
            v3Factory: 0x33128a8fC17869897dcE68Ed026d694621f6FDfD,
            pairInitCodeHash: 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f,
            poolInitCodeHash: 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54,
            v4PoolManager: 0x498581fF718922c3f8e6A244956aF099B2652b2b,
            veloV2Factory: 0x420DD381b31aEf6683db6B902084cB0FFECe40Da,
            veloCLFactory: 0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A,
            veloV2InitCodeHash: 0x6f178972b07752b522a4da1c5b71af6524e8b0bd6027ccb29e5312b0e5bcdc3c,
            veloCLInitCodeHash: 0xffb9af9ea6d9e39da47392ecc7055277b9915b8bfc9f83f105821b7791a6ae30
        });

        outputFilename = 'base.json';
    }
}
