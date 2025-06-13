// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {ERC20} from 'solmate/src/tokens/ERC20.sol';
import {ActionConstants} from '@uniswap/v4-periphery/src/libraries/ActionConstants.sol';
import {IPermit2} from 'permit2/src/interfaces/IPermit2.sol';

import {UniversalRouter} from '../../contracts/UniversalRouter.sol';
import {Payments} from '../../contracts/modules/Payments.sol';
import {Commands} from '../../contracts/libraries/Commands.sol';
import {RouterDeployParameters} from '../../contracts/types/RouterDeployParameters.sol';
import {IPoolFactory} from '../../contracts/interfaces/external/IPoolFactory.sol';
import {IPool} from '../../contracts/interfaces/external/IPool.sol';

import {BaseForkFixture, Dispatcher} from './BaseForkFixture.t.sol';

abstract contract VelodromeV2Test is BaseForkFixture {
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
        ERC20(token0()).approve(address(rootPermit2), type(uint256).max);
        ERC20(token1()).approve(address(rootPermit2), type(uint256).max);
        rootPermit2.approve(token0(), address(router), type(uint160).max, type(uint48).max);
        rootPermit2.approve(token1(), address(router), type(uint160).max, type(uint48).max);

        labelContracts();
    }

    function testInitCodeHash() public pure {
        /// @dev Optimism initCodeHash
        address poolImplementation = 0x95885Af5492195F0754bE71AD1545Fe81364E531;
        bytes32 initCodeHash = _getInitCodeHash({_implementation: poolImplementation});
        assertEq(initCodeHash, 0xc0629f1c7daa09624e54d4f711ba99922a844907cce02997176399e4cc7e8fcf);

        /// @dev Superchain initCodeHash
        poolImplementation = 0x10499d88Bd32AF443Fc936F67DE32bE1c8Bb374C;
        initCodeHash = _getInitCodeHash({_implementation: poolImplementation});
        assertEq(initCodeHash, 0x558be7ee0c63546b31d0773eee1d90451bd76a0167bb89653722a2bd677c002d);

        /// @dev Base initCodeHash
        poolImplementation = 0xA4e46b4f701c62e14DF11B48dCe76A7d793CD6d7;
        initCodeHash = _getInitCodeHash({_implementation: poolImplementation});
        assertEq(initCodeHash, 0x6f178972b07752b522a4da1c5b71af6524e8b0bd6027ccb29e5312b0e5bcdc3c);
    }

    function testExactInput0For1() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_IN)));
        bytes memory routes = abi.encodePacked(token0(), stable(), token1());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, 0, routes, true, false);

        vm.expectEmit(address(router));
        emit Dispatcher.UniversalRouterSwap({sender: FROM, recipient: FROM});
        router.execute(commands, inputs);
        assertEq(ERC20(token0()).balanceOf(FROM), BALANCE - AMOUNT);
        assertGt(ERC20(token1()).balanceOf(FROM), BALANCE);
    }

    function testExactInput1For0() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_IN)));
        bytes memory routes = abi.encodePacked(token1(), stable(), token0());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, 0, routes, true, false);

        vm.expectEmit(address(router));
        emit Dispatcher.UniversalRouterSwap({sender: FROM, recipient: FROM});
        router.execute(commands, inputs);
        assertEq(ERC20(token1()).balanceOf(FROM), BALANCE - AMOUNT);
        assertGt(ERC20(token0()).balanceOf(FROM), BALANCE);
    }

    function testExactInput0For1FromRouter() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_IN)));
        deal(token0(), address(router), AMOUNT);
        bytes memory routes = abi.encodePacked(token0(), stable(), token1());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, 0, routes, false, false);

        vm.expectEmit(address(router));
        emit Dispatcher.UniversalRouterSwap({sender: FROM, recipient: FROM});
        router.execute(commands, inputs);
        assertGt(ERC20(token1()).balanceOf(FROM), BALANCE);
    }

    function testExactInput1For0FromRouter() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_IN)));
        deal(token1(), address(router), AMOUNT);
        bytes memory routes = abi.encodePacked(token1(), stable(), token0());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, 0, routes, false, false);

        vm.expectEmit(address(router));
        emit Dispatcher.UniversalRouterSwap({sender: FROM, recipient: FROM});
        router.execute(commands, inputs);
        assertGt(ERC20(token0()).balanceOf(FROM), BALANCE);
    }

    function testExactOutput0For1() public skipIfTrue {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_OUT)));
        bytes memory routes = abi.encodePacked(token0(), stable(), token1());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, type(uint256).max, routes, true, false);

        vm.expectEmit(address(router));
        emit Dispatcher.UniversalRouterSwap({sender: FROM, recipient: FROM});
        router.execute(commands, inputs);
        assertLt(ERC20(token0()).balanceOf(FROM), BALANCE);
        assertGe(ERC20(token1()).balanceOf(FROM), BALANCE + AMOUNT);
    }

    function testExactOutput1For0() public skipIfTrue {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_OUT)));
        bytes memory routes = abi.encodePacked(token1(), stable(), token0());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, type(uint256).max, routes, true, false);

        vm.expectEmit(address(router));
        emit Dispatcher.UniversalRouterSwap({sender: FROM, recipient: FROM});
        router.execute(commands, inputs);
        assertLt(ERC20(token1()).balanceOf(FROM), BALANCE);
        assertGe(ERC20(token0()).balanceOf(FROM), BALANCE + AMOUNT);
    }

    function testExactOutput0For1FromRouter() public skipIfTrue {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_OUT)));
        deal(token0(), address(router), BALANCE);

        bytes memory routes = abi.encodePacked(token0(), stable(), token1());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, type(uint256).max, routes, false, false);

        vm.expectEmit(address(router));
        emit Dispatcher.UniversalRouterSwap({sender: FROM, recipient: FROM});
        router.execute(commands, inputs);
        assertGe(ERC20(token1()).balanceOf(FROM), BALANCE + AMOUNT);
    }

    function testExactOutput1For0FromRouter() public skipIfTrue {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_OUT)));
        deal(token1(), address(router), BALANCE);
        bytes memory routes = abi.encodePacked(token1(), stable(), token0());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, type(uint256).max, routes, false, false);

        vm.expectEmit(address(router));
        emit Dispatcher.UniversalRouterSwap({sender: FROM, recipient: FROM});
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
        vm.label(address(VELO_V2_FACTORY), 'V2 Pool VELO_V2_FACTORY');
        vm.label(VELO_V2_POOL_IMPLEMENTATION, 'V2 Pool Implementation');
        vm.label(address(WETH), 'WETH');
        vm.label(FROM, 'from');
        vm.label(pair, string.concat(ERC20(token0()).symbol(), '-', string.concat(ERC20(token1()).symbol()), 'Pool'));
    }
}
