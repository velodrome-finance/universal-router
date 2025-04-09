// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {IAllowanceTransfer} from 'permit2/src/interfaces/IAllowanceTransfer.sol';

import '../../BaseForkFixture.t.sol';

contract TransferFromTest is BaseForkFixture {
    function test_WhenSafeTransferFromSucceeds() external {
        // It should transfer tokens from the payer to the recipient via erc20 transfer
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.TRANSFER_FROM)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(weth), RECIPIENT, AMOUNT);

        uint256 oldBal = weth.balanceOf(RECIPIENT);

        deal(address(weth), address(this), AMOUNT);
        weth.approve(address(router), AMOUNT);
        router.execute(commands, inputs);

        assertEq(weth.balanceOf(RECIPIENT), oldBal + AMOUNT);
        assertEq(weth.balanceOf(address(this)), 0);
    }

    modifier whenSafeTransferFromFails() {
        _;
    }

    function test_RevertWhen_Permit2TransferFromFails() external whenSafeTransferFromFails {
        // It should revert
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.TRANSFER_FROM)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(weth), RECIPIENT, AMOUNT);

        vm.expectRevert(abi.encodeWithSelector(IAllowanceTransfer.AllowanceExpired.selector, 0));
        router.execute(commands, inputs);
    }

    function test_WhenPermit2TransferFromSucceeds() external whenSafeTransferFromFails {
        // It should transfer tokens from the payer to the recipient via permit2
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.TRANSFER_FROM)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(weth), RECIPIENT, AMOUNT);

        uint256 oldBal = weth.balanceOf(RECIPIENT);

        deal(address(weth), address(this), AMOUNT);
        WETH.approve(address(PERMIT2), type(uint256).max);
        PERMIT2.approve(address(WETH), address(router), type(uint160).max, type(uint48).max);
        router.execute(commands, inputs);

        assertEq(weth.balanceOf(RECIPIENT), oldBal + AMOUNT);
        assertEq(weth.balanceOf(address(this)), 0);
    }

    function test_transferFromAndUnwrapFlow() public {
        bytes memory commands =
            abi.encodePacked(bytes1(uint8(Commands.TRANSFER_FROM)), bytes1(uint8(Commands.UNWRAP_WETH)));
        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(address(weth), address(router), AMOUNT);
        inputs[1] = abi.encode(users.alice, AMOUNT);
        deal(address(weth), address(this), AMOUNT);

        uint256 oldBalETH = users.alice.balance;

        uint256 oldPayerBalETH = address(this).balance;
        uint256 oldRouterBalETH = address(router).balance;

        deal(address(weth), address(this), AMOUNT);
        weth.approve(address(router), AMOUNT);
        router.execute(commands, inputs);

        assertEq(users.alice.balance, oldBalETH + AMOUNT);
        assertEq(weth.balanceOf(users.alice), 0);

        /// @dev Router & Payer balances should remain unchanged
        assertEq(weth.balanceOf(address(this)), 0);
        assertEq(weth.balanceOf(address(router)), 0);
        assertEq(address(this).balance, oldPayerBalETH);
        assertEq(address(router).balance, oldRouterBalETH);
    }
}
