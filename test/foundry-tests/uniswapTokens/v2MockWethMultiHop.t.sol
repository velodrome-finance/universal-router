// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import 'forge-std/Test.sol';
import {MockERC20} from '../mock/MockERC20.sol';
import {UniswapV2MultiHopTest} from '../UniswapV2MultiHop.t.sol';

contract V2MockWeth is UniswapV2MultiHopTest {
    MockERC20 mock;

    function setUpTokens() internal override {
        mock = new MockERC20('Mock', 'MOCK');
    }

    function token0() internal pure override returns (address) {
        return address(WETH9);
    }

    function token1() internal view override returns (address) {
        return address(mock);
    }

    function stable0() internal pure override returns (bool) {
        return false;
    }

    function stable1() internal pure override returns (bool) {
        return false;
    }

    function labelContracts() internal override {
        super.labelContracts();
        vm.label(address(mock), 'Mock');
    }
}
