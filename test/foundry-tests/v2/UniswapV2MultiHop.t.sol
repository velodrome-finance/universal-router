// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import './BaseV2Fixture.t.sol';

abstract contract UniswapV2MultiHopTest is BaseV2Fixture {
    ERC20 constant bUSDC = ERC20(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);

    address public firstPair;
    address public secondPair;

    function setUp() public virtual {
        vm.createSelectFork(vm.envString('RPC_URL'), 114000000);
        setUpTokens();

        DeployTest deploy = new DeployTest();
        deploy.run();

        router = deploy.router();
        firstPair = createAndSeedPair(token0(), address(bUSDC), stable0());
        secondPair = createAndSeedPair(token1(), address(bUSDC), stable1());

        vm.startPrank(FROM);
        deal(FROM, BALANCE);
        deal(token0(), FROM, BALANCE);
        deal(token1(), FROM, BALANCE);
        ERC20(token0()).approve(address(PERMIT2), type(uint256).max);
        ERC20(token1()).approve(address(PERMIT2), type(uint256).max);
        PERMIT2.approve(token0(), address(router), type(uint160).max, type(uint48).max);
        PERMIT2.approve(token1(), address(router), type(uint160).max, type(uint48).max);

        labelContracts();
    }

    modifier skipIfTrue() {
        if (!stable0() && !stable1()) _;
    }

    function createAndSeedPair(address tokenA, address tokenB, bool _stable)
        internal
        override
        returns (address newPair)
    {
        newPair = FACTORY.getPair(tokenA, tokenB, _stable);
        if (newPair == address(0)) {
            newPair = FACTORY.createPair(tokenA, tokenB, _stable);
        }

        deal(tokenA, address(this), 1_000_000 * 10 ** ERC20(tokenA).decimals());
        deal(tokenB, address(this), 1_000_000 * 10 ** ERC20(tokenB).decimals());
        ERC20(tokenA).transfer(address(newPair), 1_000_000 * 10 ** ERC20(tokenA).decimals());
        ERC20(tokenB).transfer(address(newPair), 1_000_000 * 10 ** ERC20(tokenB).decimals());
        IPool(newPair).mint(address(this));
    }

    function labelContracts() internal virtual override {
        vm.label(address(router), 'UniversalRouter');
        vm.label(RECIPIENT, 'recipient');
        vm.label(address(FACTORY), 'V2 Pool Factory');
        vm.label(POOL_IMPLEMENTATION, 'V2 Pool Implementation');
        vm.label(address(WETH), 'WETH');
        vm.label(address(bUSDC), 'Bridged USDC');
        vm.label(FROM, 'from');
        vm.label(firstPair, string.concat(ERC20(token0()).symbol(), '-bUSDC Pool'));
        vm.label(secondPair, string.concat(ERC20(token1()).symbol(), '-bUSDC Pool'));
    }

    function testMultiHopExactInput0For1() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_IN)));
        uint256 amount = 10 ** ERC20(token0()).decimals();
        Route[] memory routes = new Route[](2);
        routes[0] = Route(token0(), address(bUSDC), stable0());
        routes[1] = Route(address(bUSDC), token1(), stable1());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.MSG_SENDER, amount, 0, routes, true);

        router.execute(commands, inputs);
        assertEq(ERC20(token0()).balanceOf(FROM), BALANCE - amount);
        assertGt(ERC20(token1()).balanceOf(FROM), BALANCE);
    }

    function testMultiHopExactInput1For0() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_IN)));
        uint256 amount = 10 ** ERC20(token1()).decimals();
        Route[] memory routes = new Route[](2);
        routes[0] = Route(token1(), address(bUSDC), stable1());
        routes[1] = Route(address(bUSDC), token0(), stable0());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.MSG_SENDER, amount, 0, routes, true);

        router.execute(commands, inputs);
        assertEq(ERC20(token1()).balanceOf(FROM), BALANCE - amount);
        assertGt(ERC20(token0()).balanceOf(FROM), BALANCE);
    }

    function testMultiHopExactInput0For1FromRouter() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_IN)));
        uint256 amount = 10 ** ERC20(token0()).decimals();
        deal(token0(), address(router), amount);
        Route[] memory routes = new Route[](2);
        routes[0] = Route(token0(), address(bUSDC), stable0());
        routes[1] = Route(address(bUSDC), token1(), stable1());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.MSG_SENDER, amount, 0, routes, false);

        router.execute(commands, inputs);
        assertGt(ERC20(token1()).balanceOf(FROM), BALANCE);
    }

    function testMultiHopExactInput1For0FromRouter() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_IN)));
        uint256 amount = 10 ** ERC20(token1()).decimals();
        deal(token1(), address(router), amount);
        Route[] memory routes = new Route[](2);
        routes[0] = Route(token1(), address(bUSDC), stable1());
        routes[1] = Route(address(bUSDC), token0(), stable0());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.MSG_SENDER, amount, 0, routes, false);

        router.execute(commands, inputs);
        assertGt(ERC20(token0()).balanceOf(FROM), BALANCE);
    }

    function testMultiHopExactOutput0For1() public skipIfTrue {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_OUT)));
        uint256 amount = 10 ** ERC20(token0()).decimals();
        Route[] memory routes = new Route[](2);
        routes[0] = Route(token0(), address(bUSDC), stable0());
        routes[1] = Route(address(bUSDC), token1(), stable1());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.MSG_SENDER, amount, type(uint256).max, routes, true);

        router.execute(commands, inputs);
        assertLt(ERC20(token0()).balanceOf(FROM), BALANCE);
        assertGe(ERC20(token1()).balanceOf(FROM), BALANCE + amount);
    }

    function testMultiHopExactOutput1For0() public skipIfTrue {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_OUT)));
        uint256 amount = 10 ** ERC20(token1()).decimals();
        Route[] memory routes = new Route[](2);
        routes[0] = Route(token1(), address(bUSDC), stable1());
        routes[1] = Route(address(bUSDC), token0(), stable0());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.MSG_SENDER, amount, type(uint256).max, routes, true);

        router.execute(commands, inputs);
        assertLt(ERC20(token1()).balanceOf(FROM), BALANCE);
        assertGe(ERC20(token0()).balanceOf(FROM), BALANCE + amount);
    }

    function testMultiHopExactOutput0For1FromRouter() public skipIfTrue {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_OUT)));
        uint256 amount = 10 ** ERC20(token0()).decimals();
        deal(token0(), address(router), BALANCE);
        Route[] memory routes = new Route[](2);
        routes[0] = Route(token0(), address(bUSDC), stable0());
        routes[1] = Route(address(bUSDC), token1(), stable1());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.MSG_SENDER, amount, type(uint256).max, routes, false);

        router.execute(commands, inputs);
        assertGe(ERC20(token1()).balanceOf(FROM), BALANCE + amount);
    }

    function testMultiHopExactOutput1For0FromRouter() public skipIfTrue {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_OUT)));
        uint256 amount = 10 ** ERC20(token1()).decimals();
        deal(token1(), address(router), BALANCE);
        Route[] memory routes = new Route[](2);
        routes[0] = Route(token1(), address(bUSDC), stable1());
        routes[1] = Route(address(bUSDC), token0(), stable0());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.MSG_SENDER, amount, type(uint256).max, routes, false);

        router.execute(commands, inputs);
        assertGe(ERC20(token0()).balanceOf(FROM), BALANCE + amount);
    }

    // stability of token0 and bUSDC pair
    function stable0() internal virtual returns (bool);
    // stability of token1 and bUSDC pair
    function stable1() internal virtual returns (bool);
}
