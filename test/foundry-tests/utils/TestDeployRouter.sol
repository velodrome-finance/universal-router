// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {DeployUniversalRouter} from 'script/DeployUniversalRouter.s.sol';

contract TestDeployRouter is DeployUniversalRouter {
    constructor(DeployUniversalRouter.DeploymentParameters memory _params, address _unsupported, address _permit2) {
        params = _params;
        unsupported = _unsupported;
        permit2 = _permit2;
        isTest = true;
    }

    function setUp() public override {}
}
