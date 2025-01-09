// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import './BaseV2Fixture.t.sol';

abstract contract UniswapV2NoPermit2Test is BaseV2Fixture {
    modifier skipIfTrue() {
        if (!stable()) _;
    }

    function setUp() public virtual {
        vm.createSelectFork(vm.envString('RPC_URL'), 114000000);
        setUpTokens();

        DeployTest deploy = new DeployTest();
        deploy.run();

        router = deploy.router();
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
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_IN)));
        Route[] memory routes = new Route[](1);
        routes[0] = Route(token0(), token1(), stable());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.MSG_SENDER, AMOUNT, 0, routes, true);

        router.execute(commands, inputs);
        assertEq(ERC20(token0()).balanceOf(FROM), BALANCE - AMOUNT);
        assertGt(ERC20(token1()).balanceOf(FROM), BALANCE);
    }

    function testExactInput1For0() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_IN)));
        Route[] memory routes = new Route[](1);
        routes[0] = Route(token1(), token0(), stable());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.MSG_SENDER, AMOUNT, 0, routes, true);

        router.execute(commands, inputs);
        assertEq(ERC20(token1()).balanceOf(FROM), BALANCE - AMOUNT);
        assertGt(ERC20(token0()).balanceOf(FROM), BALANCE);
    }

    function testExactInput0For1FromRouter() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_IN)));
        deal(token0(), address(router), AMOUNT);
        Route[] memory routes = new Route[](1);
        routes[0] = Route(token0(), token1(), stable());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.MSG_SENDER, AMOUNT, 0, routes, false);

        router.execute(commands, inputs);
        assertGt(ERC20(token1()).balanceOf(FROM), BALANCE);
    }

    function testExactInput1For0FromRouter() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_IN)));
        deal(token1(), address(router), AMOUNT);
        Route[] memory routes = new Route[](1);
        routes[0] = Route(token1(), token0(), stable());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.MSG_SENDER, AMOUNT, 0, routes, false);

        router.execute(commands, inputs);
        assertGt(ERC20(token0()).balanceOf(FROM), BALANCE);
    }

    function testExactOutput0For1() public skipIfTrue {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_OUT)));
        Route[] memory routes = new Route[](1);
        routes[0] = Route(token0(), token1(), stable());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.MSG_SENDER, AMOUNT, type(uint256).max, routes, true);

        router.execute(commands, inputs);
        assertLt(ERC20(token0()).balanceOf(FROM), BALANCE);
        assertGe(ERC20(token1()).balanceOf(FROM), BALANCE + AMOUNT);
    }

    function testExactOutput1For0() public skipIfTrue {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_OUT)));
        Route[] memory routes = new Route[](1);
        routes[0] = Route(token1(), token0(), stable());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.MSG_SENDER, AMOUNT, type(uint256).max, routes, true);

        router.execute(commands, inputs);
        assertLt(ERC20(token1()).balanceOf(FROM), BALANCE);
        assertGe(ERC20(token0()).balanceOf(FROM), BALANCE + AMOUNT);
    }

    function testExactOutput0For1FromRouter() public skipIfTrue {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_OUT)));
        deal(token0(), address(router), BALANCE);
        Route[] memory routes = new Route[](1);
        routes[0] = Route(token0(), token1(), stable());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.MSG_SENDER, AMOUNT, type(uint256).max, routes, false);

        router.execute(commands, inputs);
        assertGe(ERC20(token1()).balanceOf(FROM), BALANCE + AMOUNT);
    }

    function testExactOutput1For0FromRouter() public skipIfTrue {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_OUT)));
        deal(token1(), address(router), BALANCE);
        Route[] memory routes = new Route[](1);
        routes[0] = Route(token1(), token0(), stable());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.MSG_SENDER, AMOUNT, type(uint256).max, routes, false);

        router.execute(commands, inputs);
        assertGe(ERC20(token0()).balanceOf(FROM), BALANCE + AMOUNT);
    }

    // stability of token0 and token1 pair
    function stable() internal virtual returns (bool);
}
