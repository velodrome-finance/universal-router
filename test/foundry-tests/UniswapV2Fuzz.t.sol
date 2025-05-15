// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {IPermit2} from 'permit2/src/interfaces/IPermit2.sol';
import {ERC20} from 'solmate/src/tokens/ERC20.sol';
import {ActionConstants} from '@uniswap/v4-periphery/src/libraries/ActionConstants.sol';
import {IUniswapV2Factory} from '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';

import {UniversalRouter} from '../../contracts/UniversalRouter.sol';
import {Payments} from '../../contracts/modules/Payments.sol';
import {Commands} from '../../contracts/libraries/Commands.sol';
import {RouterParameters} from '../../contracts/types/RouterParameters.sol';
import {IPoolFactory} from '../../contracts/interfaces/external/IPoolFactory.sol';
import {IPool} from '../../contracts/interfaces/external/IPool.sol';

import {BaseForkFixture, Dispatcher} from './BaseForkFixture.t.sol';

abstract contract UniswapV2FuzzTest is BaseForkFixture {
    uint256 public constant BALANCE2 = MAX_RESERVES * 2;

    function setUp() public virtual override {
        rootForkBlockNumber = 114000000;

        super.setUp();

        setUpTokens();

        // make sure pair doesn't exist as we want the reserves to be fuzzed
        assertEq(UNI_V2_FACTORY.getPair(token0(), token1()), address(0));

        vm.startPrank(FROM);
        deal(FROM, BALANCE2);
        deal(token0(), FROM, BALANCE2);
        deal(token1(), FROM, BALANCE2);
        ERC20(token0()).approve(address(PERMIT2), type(uint256).max);
        ERC20(token1()).approve(address(PERMIT2), type(uint256).max);
        PERMIT2.approve(token0(), address(router), type(uint160).max, type(uint48).max);
        PERMIT2.approve(token1(), address(router), type(uint160).max, type(uint48).max);
    }

    function setPair(uint256 reserve0, uint256 reserve1) internal {
        address pair = UNI_V2_FACTORY.createPair(token0(), token1());
        deal(token0(), pair, reserve0);
        deal(token1(), pair, reserve1);
        IPool(pair).sync();
    }

    function testFuzzExactInput0For1(uint256 reserve0, uint256 reserve1) public {
        reserve0 = bound(reserve0, AMOUNT * 2, MAX_RESERVES);
        reserve1 = bound(reserve1, AMOUNT * 2, MAX_RESERVES);
        setPair(reserve0, reserve1);

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_IN)));
        bytes memory path = abi.encodePacked(token0(), token1());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, 0, path, true, true);

        vm.expectEmit(address(router));
        emit Dispatcher.UniversalRouterSwap({sender: FROM, recipient: FROM});
        router.execute(commands, inputs);
        assertEq(ERC20(token0()).balanceOf(FROM), BALANCE2 - AMOUNT);
        assertGt(ERC20(token1()).balanceOf(FROM), BALANCE2);
    }

    function testFuzzExactInput1For0(uint256 reserve0, uint256 reserve1) public {
        reserve0 = bound(reserve0, AMOUNT * 2, MAX_RESERVES);
        reserve1 = bound(reserve1, AMOUNT * 2, MAX_RESERVES);
        setPair(reserve0, reserve1);

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_IN)));
        bytes memory path = abi.encodePacked(token1(), token0());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, 0, path, true, true);

        vm.expectEmit(address(router));
        emit Dispatcher.UniversalRouterSwap({sender: FROM, recipient: FROM});
        router.execute(commands, inputs);
        assertEq(ERC20(token1()).balanceOf(FROM), BALANCE2 - AMOUNT);
        assertGt(ERC20(token0()).balanceOf(FROM), BALANCE2);
    }

    function testFuzzExactInput0For1FromRouter(uint256 reserve0, uint256 reserve1) public {
        reserve0 = bound(reserve0, AMOUNT * 2, MAX_RESERVES);
        reserve1 = bound(reserve1, AMOUNT * 2, MAX_RESERVES);
        setPair(reserve0, reserve1);

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_IN)));
        deal(token0(), address(router), AMOUNT);
        bytes memory path = abi.encodePacked(token0(), token1());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, 0, path, false, true);

        vm.expectEmit(address(router));
        emit Dispatcher.UniversalRouterSwap({sender: FROM, recipient: FROM});
        router.execute(commands, inputs);
        assertGt(ERC20(token1()).balanceOf(FROM), BALANCE2);
    }

    function testFuzzExactInput1For0FromRouter(uint256 reserve0, uint256 reserve1) public {
        reserve0 = bound(reserve0, AMOUNT * 2, MAX_RESERVES);
        reserve1 = bound(reserve1, AMOUNT * 2, MAX_RESERVES);
        setPair(reserve0, reserve1);

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_IN)));
        deal(token1(), address(router), AMOUNT);
        bytes memory path = abi.encodePacked(token1(), token0());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, 0, path, false, true);

        vm.expectEmit(address(router));
        emit Dispatcher.UniversalRouterSwap({sender: FROM, recipient: FROM});
        router.execute(commands, inputs);
        assertGt(ERC20(token0()).balanceOf(FROM), BALANCE2);
    }

    function testFuzzExactOutput0For1(uint256 reserve0, uint256 reserve1) public {
        reserve0 = bound(reserve0, AMOUNT * 2, MAX_RESERVES);
        reserve1 = bound(reserve1, AMOUNT * 2, MAX_RESERVES);
        setPair(reserve0, reserve1);

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_OUT)));
        bytes memory path = abi.encodePacked(token0(), token1());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, type(uint256).max, path, true, true);

        vm.expectEmit(address(router));
        emit Dispatcher.UniversalRouterSwap({sender: FROM, recipient: FROM});
        router.execute(commands, inputs);
        assertLt(ERC20(token0()).balanceOf(FROM), BALANCE2);
        assertGe(ERC20(token1()).balanceOf(FROM), BALANCE2 + AMOUNT);
    }

    function testFuzzExactOutput1For0(uint256 reserve0, uint256 reserve1) public {
        reserve0 = bound(reserve0, AMOUNT * 2, MAX_RESERVES);
        reserve1 = bound(reserve1, AMOUNT * 2, MAX_RESERVES);
        setPair(reserve0, reserve1);

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_OUT)));
        bytes memory path = abi.encodePacked(token1(), token0());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, type(uint256).max, path, true, true);

        vm.expectEmit(address(router));
        emit Dispatcher.UniversalRouterSwap({sender: FROM, recipient: FROM});
        router.execute(commands, inputs);
        assertLt(ERC20(token1()).balanceOf(FROM), BALANCE2);
        assertGe(ERC20(token0()).balanceOf(FROM), BALANCE2 + AMOUNT);
    }

    function testFuzzExactOutput0For1FromRouter(uint256 reserve0, uint256 reserve1) public {
        reserve0 = bound(reserve0, AMOUNT * 2, MAX_RESERVES);
        reserve1 = bound(reserve1, AMOUNT * 2, MAX_RESERVES);
        setPair(reserve0, reserve1);

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_OUT)));
        deal(token0(), address(router), BALANCE2);
        bytes memory path = abi.encodePacked(token0(), token1());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, type(uint256).max, path, false, true);

        vm.expectEmit(address(router));
        emit Dispatcher.UniversalRouterSwap({sender: FROM, recipient: FROM});
        router.execute(commands, inputs);
        assertGe(ERC20(token1()).balanceOf(FROM), BALANCE2 + AMOUNT);
    }

    function testFuzzExactOutput1For0FromRouter(uint256 reserve0, uint256 reserve1) public {
        reserve0 = bound(reserve0, AMOUNT * 2, MAX_RESERVES);
        reserve1 = bound(reserve1, AMOUNT * 2, MAX_RESERVES);
        setPair(reserve0, reserve1);

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_OUT)));
        deal(token1(), address(router), BALANCE2);
        bytes memory path = abi.encodePacked(token1(), token0());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, type(uint256).max, path, false, true);

        vm.expectEmit(address(router));
        emit Dispatcher.UniversalRouterSwap({sender: FROM, recipient: FROM});
        router.execute(commands, inputs);
        assertGe(ERC20(token0()).balanceOf(FROM), BALANCE2 + AMOUNT);
    }

    function token0() internal virtual returns (address);
    function token1() internal virtual returns (address);

    function setUpTokens() internal virtual {}
}
