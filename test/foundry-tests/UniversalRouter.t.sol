// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import 'forge-std/Test.sol';

import {Payments} from 'contracts/modules/Payments.sol';
import {Permit2Payments} from 'contracts/modules/Permit2Payments.sol';
import {RouterParameters} from 'contracts/types/RouterParameters.sol';
import {ExampleModule} from 'contracts/test/ExampleModule.sol';
import {UniversalRouter} from 'contracts/UniversalRouter.sol';
import {Constants} from 'contracts/libraries/Constants.sol';
import {Commands} from 'contracts/libraries/Commands.sol';

import {MockERC20} from './mock/MockERC20.sol';

contract UniversalRouterTest is Test {
    address constant RECIPIENT = address(1234);
    uint256 constant AMOUNT = 10 ** 18;

    UniversalRouter router;
    ExampleModule testModule;
    MockERC20 erc20;

    function setUp() public {
        RouterParameters memory params = RouterParameters({
            permit2: address(0),
            weth9: address(0),
            v2Factory: address(0),
            v3Factory: address(0),
            pairInitCodeHash: bytes32(0),
            poolInitCodeHash: bytes32(0),
            v4PoolManager: address(0),
            veloV2Factory: address(0),
            veloCLFactory: address(0),
            veloV2InitCodeHash: bytes32(0),
            veloCLInitCodeHash: bytes32(0),
            rootHLMessageModule: address(0)
        });
        router = new UniversalRouter(params);
        testModule = new ExampleModule();
        erc20 = new MockERC20();
    }

    event ExampleModuleEvent(string message);

    function testCallModule() public {
        uint256 bytecodeSize;
        address theRouter = address(router);
        assembly {
            bytecodeSize := extcodesize(theRouter)
        }
        emit log_uint(bytecodeSize);
    }

    function testSweepToken() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.SWEEP)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(erc20), RECIPIENT, AMOUNT);

        erc20.mint(address(router), AMOUNT);
        assertEq(erc20.balanceOf(RECIPIENT), 0);

        router.execute(commands, inputs);

        assertEq(erc20.balanceOf(RECIPIENT), AMOUNT);
    }

    function testSweepTokenInsufficientOutput() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.SWEEP)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(erc20), RECIPIENT, AMOUNT + 1);

        erc20.mint(address(router), AMOUNT);
        assertEq(erc20.balanceOf(RECIPIENT), 0);

        vm.expectRevert(Payments.InsufficientToken.selector);
        router.execute(commands, inputs);
    }

    function testSweepETH() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.SWEEP)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.ETH, RECIPIENT, AMOUNT);

        assertEq(RECIPIENT.balance, 0);

        router.execute{value: AMOUNT}(commands, inputs);

        assertEq(RECIPIENT.balance, AMOUNT);
    }

    function testSweepETHInsufficientOutput() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.SWEEP)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.ETH, RECIPIENT, AMOUNT + 1);

        erc20.mint(address(router), AMOUNT);

        vm.expectRevert(Payments.InsufficientETH.selector);
        router.execute(commands, inputs);
    }
}
