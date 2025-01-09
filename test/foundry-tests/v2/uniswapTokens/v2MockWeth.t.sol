// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import 'forge-std/Test.sol';
import {UniswapV2Test} from '../UniswapV2.t.sol';
import {MockERC20} from '../../mock/MockERC20.sol';

contract V2MockWeth is UniswapV2Test {
    MockERC20 mock;

    function setUpTokens() internal override {
        mock = new MockERC20('Mock', 'MOCK');
    }

    function token0() internal pure override returns (address) {
        return address(WETH);
    }

    function token1() internal view override returns (address) {
        return address(mock);
    }

    function stable() internal pure override returns (bool) {
        return false;
    }

    function labelContracts() internal override {
        super.labelContracts();
        vm.label(address(mock), 'Mock');
    }
}
