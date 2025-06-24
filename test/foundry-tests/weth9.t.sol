// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import 'forge-std/Test.sol';

import './BaseForkFixture.t.sol';
import {TestDeployFraxtalRouter} from './utils/TestDeployFraxtalRouter.sol';

contract WETH9Test is BaseForkFixture {
    uint256 constant UNWRAP_AMOUNT = 1e18;

    TestDeployFraxtalRouter deployFraxtalRouter;
    UniversalRouter fraxtalRouter;
    IWETH9 fraxtalWeth9;

    function setUp() public override {
        createUsers();

        vm.createSelectFork({urlOrAlias: 'fraxtal', blockNumber: 21700000});

        deployFraxtalRouter = new TestDeployFraxtalRouter();
        deployFraxtalRouter.setUp();
        deployFraxtalRouter.run();

        fraxtalRouter = deployFraxtalRouter.router();
        fraxtalWeth9 = IWETH9(fraxtalRouter.WETH9());
    }

    function test_unwrapWETH9OnFraxtal() public {
        vm.startPrank(users.alice);

        vm.deal(users.alice, UNWRAP_AMOUNT);
        fraxtalWeth9.deposit{value: UNWRAP_AMOUNT}();
        assertEq(fraxtalWeth9.balanceOf(users.alice), UNWRAP_AMOUNT);

        fraxtalWeth9.transfer(address(fraxtalRouter), UNWRAP_AMOUNT);
        assertEq(fraxtalWeth9.balanceOf(address(fraxtalRouter)), UNWRAP_AMOUNT);

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.UNWRAP_WETH)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(users.alice, UNWRAP_AMOUNT);

        uint256 ethBalanceBefore = users.alice.balance;

        fraxtalRouter.execute(commands, inputs);

        assertEq(fraxtalWeth9.balanceOf(address(fraxtalRouter)), 0);
        assertEq(users.alice.balance, ethBalanceBefore + UNWRAP_AMOUNT);
    }
}
