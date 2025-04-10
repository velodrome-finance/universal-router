// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {DeployUniversalRouter, RouterParameters} from 'script/DeployUniversalRouter.s.sol';

contract TestDeployRouter is DeployUniversalRouter {
    constructor(RouterParameters memory _params_) {
        params = _params_;
        isTest = true;
    }

    function setUp() public override {}
}
