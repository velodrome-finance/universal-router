// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import 'forge-std/Test.sol';
import {Permit2} from 'permit2/src/Permit2.sol';
import {ERC20} from 'solmate/src/tokens/ERC20.sol';
import {ICLFactory} from 'contracts/interfaces/external/ICLFactory.sol';
import {ICLPool} from 'contracts/interfaces/external/ICLPool.sol';
import {INonfungiblePositionManager} from 'contracts/interfaces/external/INonfungiblePositionManager.sol';
import {UniversalRouter} from '../../contracts/UniversalRouter.sol';
import {Payments} from '../../contracts/modules/Payments.sol';
import {Constants} from '../../contracts/libraries/Constants.sol';
import {Commands} from '../../contracts/libraries/Commands.sol';
import {RouterParameters, Route} from '../../contracts/base/RouterImmutables.sol';

contract UniswapV3NoPermit2Test is Test {
    address constant RECIPIENT = address(10);
    uint256 constant AMOUNT = 1 ether;
    uint256 constant BALANCE = 100000 ether;
    ICLFactory constant CL_FACTORY = ICLFactory(0x548118C7E0B865C2CfA94D15EC86B666468ac758);
    INonfungiblePositionManager constant NFT = INonfungiblePositionManager(0xbB5DFE1380333CEE4c2EeBd7202c80dE2256AdF4);
    address constant CL_POOL_IMPLEMENTATION = address(0xE0A596c403E854FFb9C828aB4f07eEae04A05D37);
    ERC20 constant WETH = ERC20(0x4200000000000000000000000000000000000006);
    ERC20 constant OP = ERC20(0x4200000000000000000000000000000000000042);
    ERC20 constant USDC = ERC20(0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85);
    Permit2 constant PERMIT2 = Permit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    address constant FROM = address(1234);
    int24 constant TICK_SPACING = 200;

    UniversalRouter public router;
    address public pool; // first hop
    address public pool2; // second hop

    function setUp() public virtual {
        vm.createSelectFork(vm.envString('RPC_URL'), 118300000);

        RouterParameters memory params = RouterParameters({
            permit2: address(PERMIT2),
            weth9: address(WETH),
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
            v2Factory: address(0),
            v3Factory: address(CL_FACTORY),
            v2Implementation: address(0),
            clImplementation: CL_POOL_IMPLEMENTATION
        });
        router = new UniversalRouter(params);
        labelContracts();

        pool = createAndSeedPool(address(WETH), address(OP), TICK_SPACING);
        pool2 = createAndSeedPool(address(WETH), address(USDC), TICK_SPACING);

        vm.startPrank(FROM);
        deal(FROM, BALANCE);
        deal(address(WETH), FROM, BALANCE);
        deal(address(OP), FROM, BALANCE);
        ERC20(address(WETH)).approve(address(router), type(uint256).max);
        ERC20(address(OP)).approve(address(router), type(uint256).max);
    }

    function testExactInputERC20ToWETH() public {
        uint256 amountOutMin = 1e12;
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_IN)));
        bytes memory path = abi.encodePacked(address(OP), TICK_SPACING, address(WETH));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.MSG_SENDER, AMOUNT, amountOutMin, path, true);

        router.execute(commands, inputs);
        assertEq(OP.balanceOf(FROM), BALANCE - AMOUNT);
        assertGt(WETH.balanceOf(FROM), BALANCE);
    }

    function testExactInputWETHToERC20() public {
        uint256 amountOutMin = 1e12;
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_IN)));
        bytes memory path = abi.encodePacked(address(WETH), TICK_SPACING, address(OP));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.MSG_SENDER, AMOUNT, amountOutMin, path, true);

        router.execute(commands, inputs);
        assertEq(WETH.balanceOf(FROM), BALANCE - AMOUNT);
        assertGt(OP.balanceOf(FROM), BALANCE);
    }

    function testExactInputERC20ToETH() public {
        uint256 amountOutMin = 1e12;
        bytes memory commands =
            abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_IN)), bytes1(uint8(Commands.UNWRAP_WETH)));
        bytes memory path = abi.encodePacked(address(OP), TICK_SPACING, address(WETH));
        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(address(router), AMOUNT, amountOutMin, path, true);
        inputs[1] = abi.encode(FROM, 0);
        uint256 ethBalanceBefore = FROM.balance;

        router.execute(commands, inputs);

        uint256 ethBalanceAfter = FROM.balance;
        assertEq(OP.balanceOf(FROM), BALANCE - AMOUNT);
        assertGt(ethBalanceAfter - ethBalanceBefore, amountOutMin);
    }

    function testExactInputERC20ToWETHToERC20() public {
        uint256 amountOutMin = 1e12;
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_IN)));
        bytes memory path = abi.encodePacked(address(OP), TICK_SPACING, address(WETH), TICK_SPACING, address(USDC));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.MSG_SENDER, AMOUNT, amountOutMin, path, true);

        router.execute(commands, inputs);
        assertEq(OP.balanceOf(FROM), BALANCE - AMOUNT);
        assertEq(WETH.balanceOf(FROM), BALANCE);
        assertGt(USDC.balanceOf(FROM), 0);
    }

    function testExactOutputERC20ToWETH() public {
        uint256 amountInMax = BALANCE;
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_OUT)));
        // see L46 of SwapRouter, exact output are executed in reverse order
        bytes memory path = abi.encodePacked(address(WETH), TICK_SPACING, address(OP));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.MSG_SENDER, AMOUNT, amountInMax, path, true);

        router.execute(commands, inputs);
        assertLt(ERC20(address(OP)).balanceOf(FROM), BALANCE);
        assertEq(ERC20(address(WETH)).balanceOf(FROM), BALANCE + AMOUNT);
    }

    function testExactOutputWETHToERC20() public {
        uint256 amountInMax = BALANCE;
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_OUT)));
        bytes memory path = abi.encodePacked(address(OP), TICK_SPACING, address(WETH));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.MSG_SENDER, AMOUNT, amountInMax, path, true);

        router.execute(commands, inputs);
        assertLt(ERC20(address(WETH)).balanceOf(FROM), BALANCE);
        assertEq(ERC20(address(OP)).balanceOf(FROM), BALANCE + AMOUNT);
    }

    function testExactOutputERC20ToETH() public {
        uint256 amountInMax = BALANCE;
        bytes memory commands =
            abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_OUT)), bytes1(uint8(Commands.UNWRAP_WETH)));
        bytes memory path = abi.encodePacked(address(WETH), TICK_SPACING, address(OP));
        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(address(router), AMOUNT, amountInMax, path, true);
        inputs[1] = abi.encode(FROM, 0);
        uint256 ethBalanceBefore = FROM.balance;

        router.execute(commands, inputs);

        uint256 ethBalanceAfter = FROM.balance;
        assertLt(OP.balanceOf(FROM), BALANCE - AMOUNT);
        assertEq(ethBalanceAfter - ethBalanceBefore, AMOUNT);
    }

    function createAndSeedPool(address tokenA, address tokenB, int24 tickSpacing) internal returns (address newPool) {
        (tokenA, tokenB) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        newPool = CL_FACTORY.getPool(tokenA, tokenB, tickSpacing);
        if (newPool == address(0)) {
            newPool = CL_FACTORY.createPool(tokenA, tokenB, tickSpacing, encodePriceSqrt(1, 1));
        }

        // less of A
        uint256 amountA = 5_000_000 * 10 ** ERC20(tokenA).decimals();
        uint256 amountB = 5_000_000 * 10 ** ERC20(tokenB).decimals();
        deal(tokenA, address(this), amountA);
        deal(tokenB, address(this), amountB);
        ERC20(tokenA).approve(address(newPool), amountA);
        ERC20(tokenB).approve(address(newPool), amountB);
        ERC20(tokenA).approve(address(NFT), amountA);
        ERC20(tokenB).approve(address(NFT), amountB);

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: address(tokenA),
            token1: address(tokenB),
            tickSpacing: TICK_SPACING,
            tickLower: getMinTick(TICK_SPACING),
            tickUpper: getMaxTick(TICK_SPACING),
            recipient: FROM,
            amount0Desired: amountA,
            amount1Desired: amountB,
            amount0Min: 0,
            amount1Min: 0,
            deadline: block.timestamp,
            sqrtPriceX96: 0
        });
        NFT.mint(params);
    }

    function labelContracts() internal {
        vm.label(address(router), 'UniversalRouter');
        vm.label(RECIPIENT, 'Recipient');
        vm.label(address(CL_FACTORY), 'CL Pool Factory');
        vm.label(CL_POOL_IMPLEMENTATION, 'CL Pool Implementation');
        vm.label(address(NFT), 'Position Manager');
        vm.label(address(WETH), 'WETH');
        vm.label(address(OP), 'OP');
        vm.label(address(USDC), 'USDC');
        vm.label(FROM, 'from');
    }

    function encodePriceSqrt(uint256 reserve1, uint256 reserve0) public pure returns (uint160) {
        reserve1 = reserve1 * 2 ** 192;
        uint256 division = reserve1 / reserve0;
        uint256 sqrtX96 = sqrt(division);

        return SafeCast.toUint160(sqrtX96);
    }

    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function getMinTick(int24 tickSpacing) public pure returns (int24) {
        return (-887272 / tickSpacing) * tickSpacing;
    }

    function getMaxTick(int24 tickSpacing) public pure returns (int24) {
        return (887272 / tickSpacing) * tickSpacing;
    }
}

library SafeCast {
    /// @notice Cast a uint256 to a uint160, revert on overflow
    /// @param y The uint256 to be downcasted
    /// @return z The downcasted integer, now type uint160
    function toUint160(uint256 y) internal pure returns (uint160 z) {
        require((z = uint160(y)) == y);
    }

    /// @notice Cast a int256 to a int128, revert on overflow or underflow
    /// @param y The int256 to be downcasted
    /// @return z The downcasted integer, now type int128
    function toInt128(int256 y) internal pure returns (int128 z) {
        require((z = int128(y)) == y);
    }

    /// @notice Cast a uint256 to a int256, revert on overflow
    /// @param y The uint256 to be casted
    /// @return z The casted integer, now type int256
    function toInt256(uint256 y) internal pure returns (int256 z) {
        require(y < 2 ** 255);
        z = int256(y);
    }
}
