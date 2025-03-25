// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {IPermit2} from 'permit2/src/interfaces/IPermit2.sol';
import {ERC20} from 'solmate/src/tokens/ERC20.sol';
import {ActionConstants} from '@uniswap/v4-periphery/src/libraries/ActionConstants.sol';

import {UniversalRouter} from '../../contracts/UniversalRouter.sol';
import {Payments} from '../../contracts/modules/Payments.sol';
import {Commands} from '../../contracts/libraries/Commands.sol';
import {RouterParameters} from '../../contracts/types/RouterParameters.sol';
import {IPoolFactory} from '../../contracts/interfaces/external/IPoolFactory.sol';
import {IPool} from '../../contracts/interfaces/external/IPool.sol';

import {BaseForkFixture} from './BaseForkFixture.t.sol';

abstract contract UniswapV2MultiHopTest is BaseForkFixture {
    address public firstPair;
    address public secondPair;

    function setUp() public virtual override {
        rootForkBlockNumber = 114000000;

        super.setUp();

        setUpTokens();

        // pair doesn't exist, make a mock one
        if (UNI_V2_FACTORY.getPair(token0(), address(bUSDC)) == address(0)) {
            firstPair = UNI_V2_FACTORY.createPair(token0(), address(bUSDC));
            deal(token0(), firstPair, 100 ether);
            deal(address(bUSDC), firstPair, 100 ether);
            IPool(firstPair).sync();
        }

        // pair doesn't exist, make a mock one
        if (UNI_V2_FACTORY.getPair(token1(), address(bUSDC)) == address(0)) {
            secondPair = UNI_V2_FACTORY.createPair(token1(), address(bUSDC));
            deal(token1(), secondPair, 100 ether);
            deal(address(bUSDC), secondPair, 100 ether);
            IPool(secondPair).sync();
        }

        vm.startPrank(FROM);
        deal(FROM, BALANCE);
        deal(token0(), FROM, BALANCE);
        deal(token1(), FROM, BALANCE);
        ERC20(token0()).approve(address(PERMIT2), type(uint256).max);
        ERC20(token1()).approve(address(PERMIT2), type(uint256).max);
        PERMIT2.approve(token0(), address(router), type(uint160).max, type(uint48).max);
        PERMIT2.approve(token1(), address(router), type(uint160).max, type(uint48).max);
    }

    function testMultiHopExactInput0For1() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_IN)));
        uint256 amount = 10 ** ERC20(token0()).decimals();
        address[] memory path = new address[](3);
        path[0] = token0();
        path[1] = address(bUSDC);
        path[2] = token1();
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, amount, 0, path, true);

        router.execute(commands, inputs);
        assertEq(ERC20(token0()).balanceOf(FROM), BALANCE - amount);
        assertGt(ERC20(token1()).balanceOf(FROM), BALANCE);
    }

    function testMultiHopExactInput1For0() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_IN)));
        uint256 amount = 10 ** ERC20(token1()).decimals();
        address[] memory path = new address[](3);
        path[0] = token1();
        path[1] = address(bUSDC);
        path[2] = token0();
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, amount, 0, path, true);

        router.execute(commands, inputs);
        assertEq(ERC20(token1()).balanceOf(FROM), BALANCE - amount);
        assertGt(ERC20(token0()).balanceOf(FROM), BALANCE);
    }

    function testMultiHopExactInput0For1FromRouter() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_IN)));
        uint256 amount = 10 ** ERC20(token0()).decimals();
        deal(token0(), address(router), amount);
        address[] memory path = new address[](3);
        path[0] = token0();
        path[1] = address(bUSDC);
        path[2] = token1();
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, amount, 0, path, false);

        router.execute(commands, inputs);
        assertGt(ERC20(token1()).balanceOf(FROM), BALANCE);
    }

    function testMultiHopExactInput1For0FromRouter() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_IN)));
        uint256 amount = 10 ** ERC20(token1()).decimals();
        deal(token1(), address(router), amount);
        address[] memory path = new address[](3);
        path[0] = token1();
        path[1] = address(bUSDC);
        path[2] = token0();
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, amount, 0, path, false);

        router.execute(commands, inputs);
        assertGt(ERC20(token0()).balanceOf(FROM), BALANCE);
    }

    function testMultiHopExactOutput0For1() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_OUT)));
        uint256 amount = 10 ** ERC20(token0()).decimals();
        address[] memory path = new address[](3);
        path[0] = token0();
        path[1] = address(bUSDC);
        path[2] = token1();
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, amount, type(uint256).max, path, true);

        router.execute(commands, inputs);
        assertLt(ERC20(token0()).balanceOf(FROM), BALANCE);
        assertGe(ERC20(token1()).balanceOf(FROM), BALANCE + amount);
    }

    function testMultiHopExactOutput1For0() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_OUT)));
        uint256 amount = 10 ** ERC20(token1()).decimals();
        address[] memory path = new address[](3);
        path[0] = token1();
        path[1] = address(bUSDC);
        path[2] = token0();
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, amount, type(uint256).max, path, true);

        router.execute(commands, inputs);
        assertLt(ERC20(token1()).balanceOf(FROM), BALANCE);
        assertGe(ERC20(token0()).balanceOf(FROM), BALANCE + amount);
    }

    function testMultiHopExactOutput0For1FromRouter() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_OUT)));
        uint256 amount = 10 ** ERC20(token0()).decimals();
        deal(token0(), address(router), BALANCE);
        address[] memory path = new address[](3);
        path[0] = token0();
        path[1] = address(bUSDC);
        path[2] = token1();
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, amount, type(uint256).max, path, false);

        router.execute(commands, inputs);
        assertGe(ERC20(token1()).balanceOf(FROM), BALANCE + amount);
    }

    function testMultiHopExactOutput1For0FromRouter() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_OUT)));
        uint256 amount = 10 ** ERC20(token1()).decimals();
        deal(token1(), address(router), BALANCE);
        address[] memory path = new address[](3);
        path[0] = token1();
        path[1] = address(bUSDC);
        path[2] = token0();
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, amount, type(uint256).max, path, false);

        router.execute(commands, inputs);
        assertGe(ERC20(token0()).balanceOf(FROM), BALANCE + amount);
    }

    function token0() internal virtual returns (address);
    function token1() internal virtual returns (address);

    function setUpTokens() internal virtual {}
}
