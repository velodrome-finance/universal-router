// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import 'forge-std/Test.sol';
import {ERC20} from 'solmate/src/tokens/ERC20.sol';
import {UniswapV2Test} from '../UniswapV2.t.sol';

contract V2DaiUsdc is UniswapV2Test {
    ERC20 constant DAI = ERC20(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);
    ERC20 constant USDC = ERC20(0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85);

    function token0() internal pure override returns (address) {
        return address(DAI);
    }

    function token1() internal pure override returns (address) {
        return address(USDC);
    }

    function stable() internal pure override returns (bool) {
        return true;
    }

    function labelContracts() internal override {
        super.labelContracts();
        vm.label(address(DAI), 'DAI');
        vm.label(address(USDC), 'USDC');
    }
}
