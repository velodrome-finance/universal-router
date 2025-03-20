// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import 'forge-std/Test.sol';
import {ERC20} from 'solmate/src/tokens/ERC20.sol';
import {UniswapV2NoPermit2Test} from '../UniswapV2NoPermit2.t.sol';

contract V2DaiWethNoPermit2 is UniswapV2NoPermit2Test {
    ERC20 constant DAI = ERC20(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);

    function token0() internal pure override returns (address) {
        return address(WETH9);
    }

    function token1() internal pure override returns (address) {
        return address(DAI);
    }
}
