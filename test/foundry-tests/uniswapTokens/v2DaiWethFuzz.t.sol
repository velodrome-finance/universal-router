// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import 'forge-std/Test.sol';
import {ERC20} from 'solmate/src/tokens/ERC20.sol';
import {UniswapV2FuzzTest} from '../UniswapV2Fuzz.t.sol';

contract V2DaiWethFuzz is UniswapV2FuzzTest {
    function token0() internal pure override returns (address) {
        return address(WETH);
    }

    function token1() internal pure override returns (address) {
        return address(DAI);
    }
}
