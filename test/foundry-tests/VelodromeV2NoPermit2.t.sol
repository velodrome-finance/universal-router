// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {ERC20} from 'solmate/src/tokens/ERC20.sol';
import {ActionConstants} from '@uniswap/v4-periphery/src/libraries/ActionConstants.sol';
import {IERC721Receiver} from '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import {IERC1155Receiver} from '@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol';
import {IPermit2} from 'permit2/src/interfaces/IPermit2.sol';

import {UniversalRouter} from '../../contracts/UniversalRouter.sol';
import {Payments} from '../../contracts/modules/Payments.sol';
import {Commands} from '../../contracts/libraries/Commands.sol';
import {RouterParameters} from '../../contracts/types/RouterParameters.sol';
import {Route} from '../../contracts/modules/uniswap/UniswapImmutables.sol';
import {IPoolFactory} from '../../contracts/interfaces/external/IPoolFactory.sol';
import {IPool} from '../../contracts/interfaces/external/IPool.sol';

import {BaseForkFixture} from './BaseForkFixture.t.sol';

abstract contract VelodromeV2NoPermit2Test is BaseForkFixture {
    address public pair;

    modifier skipIfTrue() {
        if (!stable()) _;
    }

    function setUp() public virtual override {
        super.setUp();

        setUpTokens();

        pair = createAndSeedPair(token0(), token1(), stable());

        vm.startPrank(FROM);
        deal(FROM, BALANCE);
        deal(token0(), FROM, BALANCE);
        deal(token1(), FROM, BALANCE);
        ERC20(address(token0())).approve(address(router), type(uint256).max);
        ERC20(address(token1())).approve(address(router), type(uint256).max);

        labelContracts();
    }

    function testExactInput0For1() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.POOL_SWAP_EXACT_IN)));
        Route[] memory routes = new Route[](1);
        routes[0] = Route(token0(), token1(), stable());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, 0, routes, true);

        router.execute(commands, inputs);
        assertEq(ERC20(token0()).balanceOf(FROM), BALANCE - AMOUNT);
        assertGt(ERC20(token1()).balanceOf(FROM), BALANCE);
    }

    function testExactInput1For0() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.POOL_SWAP_EXACT_IN)));
        Route[] memory routes = new Route[](1);
        routes[0] = Route(token1(), token0(), stable());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, 0, routes, true);

        router.execute(commands, inputs);
        assertEq(ERC20(token1()).balanceOf(FROM), BALANCE - AMOUNT);
        assertGt(ERC20(token0()).balanceOf(FROM), BALANCE);
    }

    function testExactInput0For1FromRouter() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.POOL_SWAP_EXACT_IN)));
        deal(token0(), address(router), AMOUNT);
        Route[] memory routes = new Route[](1);
        routes[0] = Route(token0(), token1(), stable());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, 0, routes, false);

        router.execute(commands, inputs);
        assertGt(ERC20(token1()).balanceOf(FROM), BALANCE);
    }

    function testExactInput1For0FromRouter() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.POOL_SWAP_EXACT_IN)));
        deal(token1(), address(router), AMOUNT);
        Route[] memory routes = new Route[](1);
        routes[0] = Route(token1(), token0(), stable());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, 0, routes, false);

        router.execute(commands, inputs);
        assertGt(ERC20(token0()).balanceOf(FROM), BALANCE);
    }

    function testExactOutput0For1() public skipIfTrue {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.POOL_SWAP_EXACT_OUT)));
        Route[] memory routes = new Route[](1);
        routes[0] = Route(token0(), token1(), stable());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, type(uint256).max, routes, true);

        router.execute(commands, inputs);
        assertLt(ERC20(token0()).balanceOf(FROM), BALANCE);
        assertGe(ERC20(token1()).balanceOf(FROM), BALANCE + AMOUNT);
    }

    function testExactOutput1For0() public skipIfTrue {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.POOL_SWAP_EXACT_OUT)));
        Route[] memory routes = new Route[](1);
        routes[0] = Route(token1(), token0(), stable());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, type(uint256).max, routes, true);

        router.execute(commands, inputs);
        assertLt(ERC20(token1()).balanceOf(FROM), BALANCE);
        assertGe(ERC20(token0()).balanceOf(FROM), BALANCE + AMOUNT);
    }

    function testExactOutput0For1FromRouter() public skipIfTrue {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.POOL_SWAP_EXACT_OUT)));
        deal(token0(), address(router), BALANCE);
        Route[] memory routes = new Route[](1);
        routes[0] = Route(token0(), token1(), stable());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, type(uint256).max, routes, false);

        router.execute(commands, inputs);
        assertGe(ERC20(token1()).balanceOf(FROM), BALANCE + AMOUNT);
    }

    function testExactOutput1For0FromRouter() public skipIfTrue {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.POOL_SWAP_EXACT_OUT)));
        deal(token1(), address(router), BALANCE);
        Route[] memory routes = new Route[](1);
        routes[0] = Route(token1(), token0(), stable());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, type(uint256).max, routes, false);

        router.execute(commands, inputs);
        assertGe(ERC20(token0()).balanceOf(FROM), BALANCE + AMOUNT);
    }

    function createAndSeedPair(address tokenA, address tokenB, bool _stable) internal returns (address newPair) {
        newPair = VELO_V2_FACTORY.getPair(tokenA, tokenB, _stable);
        if (newPair == address(0)) {
            newPair = VELO_V2_FACTORY.createPair(tokenA, tokenB, _stable);
        }

        deal(tokenA, address(this), 100 * 10 ** ERC20(tokenA).decimals());
        deal(tokenB, address(this), 100 * 10 ** ERC20(tokenB).decimals());
        ERC20(tokenA).transfer(address(newPair), 100 * 10 ** ERC20(tokenA).decimals());
        ERC20(tokenB).transfer(address(newPair), 100 * 10 ** ERC20(tokenB).decimals());
        IPool(newPair).mint(address(this));
    }

    function token0() internal virtual returns (address);
    function token1() internal virtual returns (address);
    // stability of token0 and token1 pair
    function stable() internal virtual returns (bool);

    function setUpTokens() internal virtual {}

    function labelContracts() internal virtual {
        vm.label(address(router), 'UniversalRouter');
        vm.label(RECIPIENT, 'recipient');
        vm.label(address(VELO_V2_FACTORY), 'V2 Pool Factory');
        vm.label(VELO_V2_POOL_IMPLEMENTATION, 'V2 Pool Implementation');
        vm.label(address(WETH), 'WETH');
        vm.label(FROM, 'from');
        vm.label(pair, string.concat(ERC20(token0()).symbol(), '-', string.concat(ERC20(token1()).symbol()), 'Pool'));
    }
}
