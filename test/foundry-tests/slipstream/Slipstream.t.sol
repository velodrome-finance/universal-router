// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import './BaseSlipstreamFixture.t.sol';

contract SlipstreamTest is BaseSlipstreamFixture {
    function setUp() public override {
        super.setUp();
        OP.approve(address(PERMIT2), type(uint256).max);
        WETH.approve(address(PERMIT2), type(uint256).max);
        PERMIT2.approve(address(OP), address(router), type(uint160).max, type(uint48).max);
        PERMIT2.approve(address(WETH), address(router), type(uint160).max, type(uint48).max);
    }

    function testInitCodeHash() public pure {
        /// @dev Optimism initCodeHash
        address clPoolImplementation = 0xc28aD28853A547556780BEBF7847628501A3bCbb;
        bytes32 initCodeHash = _getInitCodeHash({_implementation: clPoolImplementation});
        assertEq(initCodeHash, 0x339492e30b7a68609e535da9b0773082bfe60230ca47639ee5566007d525f5a7);

        /// @dev Superchain initCodeHash
        clPoolImplementation = 0x321f7Dfb9B2eA9131B8C17691CF6e01E5c149cA8;
        initCodeHash = _getInitCodeHash({_implementation: clPoolImplementation});
        assertEq(initCodeHash, 0x7b216153c50849f664871825fa6f22b3356cdce2436e4f48734ae2a926a4c7e5);

        /// @dev Base initCodeHash
        clPoolImplementation = 0xeC8E5342B19977B4eF8892e02D8DAEcfa1315831;
        initCodeHash = _getInitCodeHash({_implementation: clPoolImplementation});
        assertEq(initCodeHash, 0xffb9af9ea6d9e39da47392ecc7055277b9915b8bfc9f83f105821b7791a6ae30);
    }

    function testExactInputERC20ToWETH() public {
        uint256 amountOutMin = 1e12;
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_IN)));
        bytes memory path = abi.encodePacked(address(OP), TICK_SPACING, address(WETH));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, amountOutMin, path, true, false);

        vm.expectEmit(address(router));
        emit Dispatcher.UniversalRouterSwap(FROM, ActionConstants.MSG_SENDER);
        router.execute(commands, inputs);
        assertEq(OP.balanceOf(FROM), BALANCE - AMOUNT);
        assertGt(WETH.balanceOf(FROM), BALANCE);
    }

    function testExactInputWETHToERC20() public {
        uint256 amountOutMin = 1e12;
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_IN)));
        bytes memory path = abi.encodePacked(address(WETH), TICK_SPACING, address(OP));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, amountOutMin, path, true, false);

        vm.expectEmit(address(router));
        emit Dispatcher.UniversalRouterSwap(FROM, ActionConstants.MSG_SENDER);
        router.execute(commands, inputs);
        assertEq(WETH.balanceOf(FROM), BALANCE - AMOUNT);
        assertGt(OP.balanceOf(FROM), BALANCE);
    }

    function testExactInputERC20ToETH() public {
        uint256 amountOutMin = 1e12;
        bytes memory commands =
            abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_IN)), bytes1(uint8(Commands.UNWRAP_WETH)));
        bytes memory path = abi.encodePacked(address(OP), TICK_SPACING, address(WETH));
        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(address(router), AMOUNT, amountOutMin, path, true, false);
        inputs[1] = abi.encode(FROM, 0);
        uint256 ethBalanceBefore = FROM.balance;

        vm.expectEmit(address(router));
        emit Dispatcher.UniversalRouterSwap(FROM, address(router));
        router.execute(commands, inputs);

        uint256 ethBalanceAfter = FROM.balance;
        assertEq(OP.balanceOf(FROM), BALANCE - AMOUNT);
        assertGt(ethBalanceAfter - ethBalanceBefore, amountOutMin);
    }

    function testExactInputERC20ToWETHToERC20() public {
        uint256 amountOutMin = 1e12;
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_IN)));
        bytes memory path = abi.encodePacked(address(OP), TICK_SPACING, address(WETH), TICK_SPACING, address(USDC));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, amountOutMin, path, true, false);

        vm.expectEmit(address(router));
        emit Dispatcher.UniversalRouterSwap(FROM, ActionConstants.MSG_SENDER);
        router.execute(commands, inputs);
        assertEq(OP.balanceOf(FROM), BALANCE - AMOUNT);
        assertEq(WETH.balanceOf(FROM), BALANCE);
        assertGt(USDC.balanceOf(FROM), 0);
    }

    function testExactOutputERC20ToWETH() public {
        uint256 amountInMax = BALANCE;
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_OUT)));
        // see L46 of SwapRouter, exact output are executed in reverse order
        bytes memory path = abi.encodePacked(address(WETH), TICK_SPACING, address(OP));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, amountInMax, path, true, false);

        vm.expectEmit(address(router));
        emit Dispatcher.UniversalRouterSwap(FROM, ActionConstants.MSG_SENDER);
        router.execute(commands, inputs);
        assertLt(ERC20(address(OP)).balanceOf(FROM), BALANCE);
        assertEq(ERC20(address(WETH)).balanceOf(FROM), BALANCE + AMOUNT);
    }

    function testExactOutputWETHToERC20() public {
        uint256 amountInMax = BALANCE;
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_OUT)));
        bytes memory path = abi.encodePacked(address(OP), TICK_SPACING, address(WETH));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, amountInMax, path, true, false);

        vm.expectEmit(address(router));
        emit Dispatcher.UniversalRouterSwap(FROM, ActionConstants.MSG_SENDER);
        router.execute(commands, inputs);
        assertLt(ERC20(address(WETH)).balanceOf(FROM), BALANCE);
        assertEq(ERC20(address(OP)).balanceOf(FROM), BALANCE + AMOUNT);
    }

    function testExactOutputERC20ToETH() public {
        uint256 amountInMax = BALANCE;
        bytes memory commands =
            abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_OUT)), bytes1(uint8(Commands.UNWRAP_WETH)));
        bytes memory path = abi.encodePacked(address(WETH), TICK_SPACING, address(OP));
        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(address(router), AMOUNT, amountInMax, path, true, false);
        inputs[1] = abi.encode(FROM, 0);
        uint256 ethBalanceBefore = FROM.balance;

        vm.expectEmit(address(router));
        emit Dispatcher.UniversalRouterSwap(FROM, address(router));
        router.execute(commands, inputs);

        uint256 ethBalanceAfter = FROM.balance;
        assertLt(OP.balanceOf(FROM), BALANCE - AMOUNT);
        assertEq(ethBalanceAfter - ethBalanceBefore, AMOUNT);
    }

    /// @dev Helper to get the InitCodeHash from the `_implementation` address
    function _getInitCodeHash(address _implementation) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                hex'3d602d80600a3d3981f3363d3d373d3d3d363d73', _implementation, hex'5af43d82803e903d91602b57fd5bf3'
            )
        );
    }
}
