// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import 'forge-std/Test.sol';
import {ERC20} from 'solmate/src/tokens/ERC20.sol';
import {UniswapV2Test} from '../UniswapV2.t.sol';

contract V2WethVelo is UniswapV2Test {
    ERC20 constant VELO = ERC20(0x3c8B650257cFb5f272f799F5e2b4e65093a11a05);

    function token0() internal pure override returns (address) {
        return address(VELO);
    }

    function token1() internal pure override returns (address) {
        return address(WETH9);
    }

    function stable() internal pure override returns (bool) {
        return false;
    }

    function labelContracts() internal override {
        super.labelContracts();
        vm.label(address(VELO), 'Velo');
    }
}
