// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import 'forge-std/Test.sol';
import {ERC20} from 'solmate/src/tokens/ERC20.sol';
import {VelodromeV2MultiHopTest} from '../VelodromeV2MultiHop.t.sol';

contract V2DaiWethMultiHopTest is VelodromeV2MultiHopTest {
    ERC20 constant DAI = ERC20(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);

    function token0() internal pure override returns (address) {
        return address(WETH9);
    }

    function token1() internal pure override returns (address) {
        return address(DAI);
    }

    function stable0() internal pure override returns (bool) {
        return false;
    }

    function stable1() internal pure override returns (bool) {
        return true;
    }

    function labelContracts() internal override {
        super.labelContracts();
        vm.label(address(DAI), 'DAI');
    }
}
