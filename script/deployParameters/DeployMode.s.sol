// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import '../DeployUniversalRouter.s.sol';
import {RouterParameters} from 'contracts/types/RouterParameters.sol';

contract DeployMode is DeployUniversalRouter {
    function setUp() public override {
        params = RouterParameters({
            permit2: 0xbF055A2D7450b55c194c32e285deDb956416CAF3,
            weth9: 0x4200000000000000000000000000000000000006,
            v2Factory: address(0),
            v3Factory: address(0),
            pairInitCodeHash: bytes32(0),
            poolInitCodeHash: bytes32(0),
            v4PoolManager: address(0),
            v3NFTPositionManager: address(0),
            v4PositionManager: address(0),
            veloV2Factory: 0x629157747eE3a635F9EA1ED37fD0DC7187d45478,
            veloV2Implementation: 0xDF49FF386344d3b687F56c02D0b1784b19013E25
        });

        unsupported = 0x0D6953a74f9e50478e325B14053985eE8D548EdE;
    }
}
