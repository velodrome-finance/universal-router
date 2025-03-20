// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import 'forge-std/Test.sol';
import {ERC20} from 'solmate/src/tokens/ERC20.sol';
import {UniswapV2MultiHopTest} from '../UniswapV2MultiHop.t.sol';

contract V2WethUsdc is UniswapV2MultiHopTest {
    ERC20 constant USDC = ERC20(0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85);

    function token0() internal pure override returns (address) {
        return address(USDC);
    }

    function token1() internal pure override returns (address) {
        return address(WETH9);
    }
}
