// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import 'forge-std/Test.sol';
import {MockERC20} from '../mock/MockERC20.sol';
import {UniswapV2NoPermit2Test} from '../UniswapV2NoPermit2.t.sol';

contract V2MockMockNoPermit2 is UniswapV2NoPermit2Test {
    MockERC20 mockA;
    MockERC20 mockB;

    function setUpTokens() internal override {
        mockA = new MockERC20('Mock Token A', 'MOCKA');
        mockB = new MockERC20('Mock Token B', 'MOCKB');
    }

    function token0() internal view override returns (address) {
        return address(mockA);
    }

    function token1() internal view override returns (address) {
        return address(mockB);
    }

    function stable() internal pure override returns (bool) {
        return false;
    }

    function labelContracts() internal override {
        super.labelContracts();
        vm.label(address(mockA), 'Mock Token A');
        vm.label(address(mockB), 'Mock Token B');
    }
}
