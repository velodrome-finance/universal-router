// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import 'forge-std/Test.sol';
import {Permit2} from 'permit2/src/Permit2.sol';
import {ERC20} from 'solmate/src/tokens/ERC20.sol';
import {IPoolFactory} from 'contracts/interfaces/external/IPoolFactory.sol';
import {IPool} from 'contracts/interfaces/external/IPool.sol';
import {UniversalRouter} from '../../contracts/UniversalRouter.sol';
import {Payments} from '../../contracts/modules/Payments.sol';
import {Constants} from '../../contracts/libraries/Constants.sol';
import {Commands} from '../../contracts/libraries/Commands.sol';
import {RouterParameters, Route} from '../../contracts/base/RouterImmutables.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import '@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol';

abstract contract UniswapV2MultiHopTest is Test {
    address constant RECIPIENT = address(10);
    uint256 constant BALANCE = 100000 ether;
    IPoolFactory constant FACTORY = IPoolFactory(0xF1046053aa5682b4F9a81b5481394DA16BE5FF5a);
    address constant POOL_IMPLEMENTATION = address(0x95885Af5492195F0754bE71AD1545Fe81364E531);
    ERC20 constant WETH9 = ERC20(0x4200000000000000000000000000000000000006);
    ERC20 constant bUSDC = ERC20(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    Permit2 constant PERMIT2 = Permit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    address constant FROM = address(1234);

    UniversalRouter public router;
    address public firstPair;
    address public secondPair;

    function setUp() public virtual {
        vm.createSelectFork(vm.envString('RPC_URL'), 111000000);
        setUpTokens();

        RouterParameters memory params = RouterParameters({
            permit2: address(PERMIT2),
            weth9: address(WETH9),
            seaportV1_5: address(0),
            seaportV1_4: address(0),
            openseaConduit: address(0),
            nftxZap: address(0),
            x2y2: address(0),
            foundation: address(0),
            sudoswap: address(0),
            elementMarket: address(0),
            nft20Zap: address(0),
            cryptopunks: address(0),
            looksRareV2: address(0),
            routerRewardsDistributor: address(0),
            looksRareRewardsDistributor: address(0),
            looksRareToken: address(0),
            v2Factory: address(FACTORY),
            v3Factory: address(0),
            v2Implementation: POOL_IMPLEMENTATION,
            clImplementation: address(0)
        });
        router = new UniversalRouter(params);

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

    function createAndSeedPair(address tokenA, address tokenB, bool _stable) internal returns (address newPair) {
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

    function token0() internal virtual returns (address);
    function token1() internal virtual returns (address);
    // stability of token0 and bUSDC pair
    function stable0() internal virtual returns (bool);
    // stability of token1 and bUSDC pair
    function stable1() internal virtual returns (bool);

    function setUpTokens() internal virtual {}

    function labelContracts() internal virtual {
        vm.label(address(router), 'UniversalRouter');
        vm.label(RECIPIENT, 'recipient');
        vm.label(address(FACTORY), 'V2 Pool Factory');
        vm.label(POOL_IMPLEMENTATION, 'V2 Pool Implementation');
        vm.label(address(WETH9), 'WETH');
        vm.label(address(bUSDC), 'Bridged USDC');
        vm.label(FROM, 'from');
        vm.label(firstPair, string.concat(ERC20(token0()).symbol(), '-bUSDC Pool'));
        vm.label(secondPair, string.concat(ERC20(token1()).symbol(), '-bUSDC Pool'));
    }
}
