// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import './BaseV3Fixture.t.sol';

contract UniswapV3NoPermit2Test is BaseV3Fixture {
    function testExactInputERC20ToWETH() public {
        uint256 amountOutMin = 1e12;
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_IN)));
        bytes memory path = abi.encodePacked(address(OP), FEE, address(WETH));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, amountOutMin, path, true, true);

        router.execute(commands, inputs);
        assertEq(OP.balanceOf(FROM), BALANCE - AMOUNT);
        assertGt(WETH.balanceOf(FROM), BALANCE);
    }

    function testExactInputWETHToERC20() public {
        uint256 amountOutMin = 1e12;
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_IN)));
        bytes memory path = abi.encodePacked(address(WETH), FEE, address(OP));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, amountOutMin, path, true, true);

        router.execute(commands, inputs);
        assertEq(WETH.balanceOf(FROM), BALANCE - AMOUNT);
        assertGt(OP.balanceOf(FROM), BALANCE);
    }

    function testExactInputERC20ToETH() public {
        uint256 amountOutMin = 1e12;
        bytes memory commands =
            abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_IN)), bytes1(uint8(Commands.UNWRAP_WETH)));
        bytes memory path = abi.encodePacked(address(OP), FEE, address(WETH));
        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(address(router), AMOUNT, amountOutMin, path, true, true);
        inputs[1] = abi.encode(FROM, 0);
        uint256 ethBalanceBefore = FROM.balance;

        router.execute(commands, inputs);

        uint256 ethBalanceAfter = FROM.balance;
        assertEq(OP.balanceOf(FROM), BALANCE - AMOUNT);
        assertGt(ethBalanceAfter - ethBalanceBefore, amountOutMin);
    }

    function testExactInputERC20ToWETHToERC20() public {
        uint256 amountOutMin = 3e6;
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_IN)));
        bytes memory path = abi.encodePacked(address(OP), FEE, address(WETH), FEE, address(USDC));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, amountOutMin, path, true, true);

        router.execute(commands, inputs);
        assertEq(OP.balanceOf(FROM), BALANCE - AMOUNT);
        assertEq(WETH.balanceOf(FROM), BALANCE);
        assertGt(USDC.balanceOf(FROM), 0);
    }

    function testExactOutputERC20ToWETH() public {
        uint256 amountInMax = BALANCE;
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_OUT)));
        // see L46 of SwapRouter, exact output are executed in reverse order
        bytes memory path = abi.encodePacked(address(WETH), FEE, address(OP));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, amountInMax, path, true, true);

        router.execute(commands, inputs);
        assertLt(ERC20(address(OP)).balanceOf(FROM), BALANCE);
        assertEq(ERC20(address(WETH)).balanceOf(FROM), BALANCE + AMOUNT);
    }

    function testExactOutputWETHToERC20() public {
        uint256 amountInMax = BALANCE;
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_OUT)));
        bytes memory path = abi.encodePacked(address(OP), FEE, address(WETH));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, amountInMax, path, true, true);

        router.execute(commands, inputs);
        assertLt(ERC20(address(WETH)).balanceOf(FROM), BALANCE);
        assertEq(ERC20(address(OP)).balanceOf(FROM), BALANCE + AMOUNT);
    }

    function testExactOutputERC20ToETH() public {
        uint256 amountInMax = BALANCE;
        bytes memory commands =
            abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_OUT)), bytes1(uint8(Commands.UNWRAP_WETH)));
        bytes memory path = abi.encodePacked(address(WETH), FEE, address(OP));
        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(address(router), AMOUNT, amountInMax, path, true, true);
        inputs[1] = abi.encode(FROM, 0);
        uint256 ethBalanceBefore = FROM.balance;

        router.execute(commands, inputs);

        uint256 ethBalanceAfter = FROM.balance;
        assertLt(OP.balanceOf(FROM), BALANCE - AMOUNT);
        assertEq(ethBalanceAfter - ethBalanceBefore, AMOUNT);
    }
}
