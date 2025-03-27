// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import 'forge-std/Test.sol';
import {ERC20} from 'solmate/src/tokens/ERC20.sol';
import {VelodromeV2NoPermit2Test} from '../VelodromeV2NoPermit2.t.sol';

contract V2DaiWethNoPermit2 is VelodromeV2NoPermit2Test {
    function token0() internal pure override returns (address) {
        return address(WETH);
    }

    function token1() internal pure override returns (address) {
        return address(DAI);
    }

    function stable() internal pure override returns (bool) {
        return false;
    }

    function labelContracts() internal override {
        super.labelContracts();
        vm.label(address(DAI), 'DAI');
    }
}
