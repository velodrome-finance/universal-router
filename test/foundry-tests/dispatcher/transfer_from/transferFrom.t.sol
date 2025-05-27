// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {ActionConstants} from '@uniswap/v4-periphery/src/libraries/ActionConstants.sol';
import {IAllowanceTransfer} from 'permit2/src/interfaces/IAllowanceTransfer.sol';

import '../../BaseForkFixture.t.sol';

contract TransferFromTest is BaseForkFixture {
    uint256 public amount;

    function setUp() public override {
        super.setUp();

        deal(address(weth), address(this), TOKEN_1 * 100);
    }

    modifier whenTheAmountToTransferIsEqualToContractBalanceConstant() {
        amount = ActionConstants.CONTRACT_BALANCE;
        _;
    }

    function test_WhenSafeTransferFromSucceeds() external whenTheAmountToTransferIsEqualToContractBalanceConstant {
        // It should transfer the whole balance from the payer to the recipient via erc20 transfer
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.TRANSFER_FROM)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(weth), RECIPIENT, amount);

        uint256 oldBal = weth.balanceOf(RECIPIENT);
        uint256 bridgeAmount = weth.balanceOf(address(this));

        weth.approve(address(router), amount);
        router.execute(commands, inputs);

        assertEq(weth.balanceOf(RECIPIENT), oldBal + bridgeAmount);
        assertEq(weth.balanceOf(address(this)), 0);
    }

    modifier whenSafeTransferFromFails() {
        _;
    }

    function test_RevertWhen_Permit2TransferFromFails()
        external
        whenTheAmountToTransferIsEqualToContractBalanceConstant
        whenSafeTransferFromFails
    {
        // It should revert
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.TRANSFER_FROM)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(weth), RECIPIENT, amount);

        vm.expectRevert();
        router.execute(commands, inputs);
    }

    function test_WhenPermit2TransferFromSucceeds()
        external
        whenTheAmountToTransferIsEqualToContractBalanceConstant
        whenSafeTransferFromFails
    {
        // It should transfer the whole balance from the payer to the recipient via permit2
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.TRANSFER_FROM)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(weth), RECIPIENT, amount);

        uint256 oldBal = weth.balanceOf(RECIPIENT);
        uint256 bridgeAmount = weth.balanceOf(address(this));

        WETH.approve(address(rootPermit2), type(uint256).max);
        rootPermit2.approve(address(WETH), address(router), type(uint160).max, type(uint48).max);
        router.execute(commands, inputs);

        assertEq(weth.balanceOf(RECIPIENT), oldBal + bridgeAmount);
        assertEq(weth.balanceOf(address(this)), 0);
    }

    modifier whenTheAmountToTransferIsNotEqualToContractBalanceConstant() {
        amount = AMOUNT;
        _;
    }

    function test_WhenSafeTransferFromSucceeds_() external whenTheAmountToTransferIsNotEqualToContractBalanceConstant {
        // It should transfer tokens from the payer to the recipient via erc20 transfer
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.TRANSFER_FROM)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(weth), RECIPIENT, amount);

        uint256 oldBal = weth.balanceOf(RECIPIENT);
        uint256 oldPayerBal = weth.balanceOf(address(this));

        weth.approve(address(router), amount);
        router.execute(commands, inputs);

        assertEq(weth.balanceOf(RECIPIENT), oldBal + amount);
        assertEq(weth.balanceOf(address(this)), oldPayerBal - amount);
    }

    modifier whenSafeTransferFromFails_() {
        _;
    }

    function test_RevertWhen_Permit2TransferFromFails_()
        external
        whenTheAmountToTransferIsNotEqualToContractBalanceConstant
        whenSafeTransferFromFails_
    {
        // It should revert
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.TRANSFER_FROM)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(weth), RECIPIENT, amount);

        vm.expectRevert();
        router.execute(commands, inputs);
    }

    function test_WhenPermit2TransferFromSucceeds_()
        external
        whenTheAmountToTransferIsNotEqualToContractBalanceConstant
        whenSafeTransferFromFails_
    {
        // It should transfer tokens from the payer to the recipient via permit2
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.TRANSFER_FROM)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(weth), RECIPIENT, amount);

        uint256 oldBal = weth.balanceOf(RECIPIENT);
        uint256 oldPayerBal = weth.balanceOf(address(this));

        WETH.approve(address(rootPermit2), type(uint256).max);
        rootPermit2.approve(address(WETH), address(router), type(uint160).max, type(uint48).max);
        router.execute(commands, inputs);

        assertEq(weth.balanceOf(RECIPIENT), oldBal + amount);
        assertEq(weth.balanceOf(address(this)), oldPayerBal - amount);
    }

    function test_transferFromAndUnwrapFlow() public {
        bytes memory commands =
            abi.encodePacked(bytes1(uint8(Commands.TRANSFER_FROM)), bytes1(uint8(Commands.UNWRAP_WETH)));
        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(address(weth), address(router), amount);
        inputs[1] = abi.encode(users.alice, amount);

        uint256 oldBalETH = users.alice.balance;
        uint256 oldPayerBal = weth.balanceOf(address(this));

        uint256 oldPayerBalETH = address(this).balance;
        uint256 oldRouterBalETH = address(router).balance;

        weth.approve(address(router), amount);
        router.execute(commands, inputs);

        assertEq(users.alice.balance, oldBalETH + amount);
        assertEq(weth.balanceOf(users.alice), 0);

        /// @dev Check Router & Payer balances
        assertEq(weth.balanceOf(address(router)), 0);
        assertEq(weth.balanceOf(address(this)), oldPayerBal - amount);
        assertEq(address(this).balance, oldPayerBalETH);
        assertEq(address(router).balance, oldRouterBalETH);
    }
}
