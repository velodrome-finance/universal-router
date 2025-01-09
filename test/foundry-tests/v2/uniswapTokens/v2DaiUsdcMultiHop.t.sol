// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import 'forge-std/Test.sol';
import {ERC20} from 'solmate/src/tokens/ERC20.sol';
import {UniswapV2MultiHopTest} from '../UniswapV2MultiHop.t.sol';

contract V2DaiUsdcMultiHop is UniswapV2MultiHopTest {
    function token0() internal pure override returns (address) {
        return address(DAI);
    }

    function token1() internal pure override returns (address) {
        return address(USDC);
    }

    function stable0() internal pure override returns (bool) {
        return true;
    }

    function stable1() internal pure override returns (bool) {
        return true;
    }

    function labelContracts() internal override {
        super.labelContracts();
        vm.label(address(DAI), 'DAI');
        vm.label(address(USDC), 'USDC');
    }
}
