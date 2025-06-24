// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {DeployFraxtal} from '../../../script/deployParameters/DeployFraxtal.s.sol';

contract TestDeployFraxtalRouter is DeployFraxtal {
    constructor() {
        isTest = true;
    }
}
