// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import 'forge-std/Test.sol';
import {IPermit2} from 'permit2/src/interfaces/IPermit2.sol';
import {ERC20} from 'solmate/src/tokens/ERC20.sol';
import {IPoolFactory} from '../../contracts/interfaces/external/IPoolFactory.sol';
import {IUniswapV2Factory} from '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import {IPool} from '../../contracts/interfaces/external/IPool.sol';
import {UniversalRouter} from '../../contracts/UniversalRouter.sol';
import {Payments} from '../../contracts/modules/Payments.sol';
import {ActionConstants} from '@uniswap/v4-periphery/src/libraries/ActionConstants.sol';
import {Commands} from '../../contracts/libraries/Commands.sol';
import {RouterParameters} from '../../contracts/types/RouterParameters.sol';

abstract contract UniswapV2MultiHopTest is Test {
    address constant RECIPIENT = address(10);
    uint256 constant BALANCE = 100000 ether;
    IUniswapV2Factory constant FACTORY = IUniswapV2Factory(0x0c3c1c532F1e39EdF36BE9Fe0bE1410313E074Bf);
    ERC20 constant WETH9 = ERC20(0x4200000000000000000000000000000000000006);
    ERC20 constant bUSDC = ERC20(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    IPermit2 constant PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    address constant FROM = address(1234);

    UniversalRouter public router;
    address public firstPair;
    address public secondPair;

    function setUp() public virtual {
        vm.createSelectFork(vm.envString('FORK_URL'), 114000000);
        setUpTokens();

        RouterParameters memory params = RouterParameters({
            permit2: address(PERMIT2),
            weth9: address(WETH9),
            v2Factory: address(FACTORY),
            v3Factory: address(0),
            pairInitCodeHash: bytes32(0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f),
            poolInitCodeHash: bytes32(0),
            v4PoolManager: address(0),
            v3NFTPositionManager: address(0),
            v4PositionManager: address(0),
            veloV2Factory: address(0),
            veloV2Implementation: address(0)
        });
        router = new UniversalRouter(params);

        // pair doesn't exist, make a mock one
        if (FACTORY.getPair(token0(), address(bUSDC)) == address(0)) {
            firstPair = FACTORY.createPair(token0(), address(bUSDC));
            deal(token0(), firstPair, 100 ether);
            deal(address(bUSDC), firstPair, 100 ether);
            IPool(firstPair).sync();
        }

        // pair doesn't exist, make a mock one
        if (FACTORY.getPair(token1(), address(bUSDC)) == address(0)) {
            secondPair = FACTORY.createPair(token1(), address(bUSDC));
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
