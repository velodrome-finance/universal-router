// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {DeployPermit2AndUnsupported} from 'script/DeployPermit2AndUnsupported.s.sol';

contract TestDeployPermit2AndUnsupported is DeployPermit2AndUnsupported {
    constructor() {
        isTest = true;
    }
}
