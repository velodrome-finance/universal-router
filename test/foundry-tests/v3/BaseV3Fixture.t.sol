// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import 'forge-std/Test.sol';

import {Permit2} from 'permit2/src/Permit2.sol';
import {ERC20} from 'solmate/src/tokens/ERC20.sol';

import {Payments} from 'contracts/modules/Payments.sol';
import {ICLPool} from 'contracts/interfaces/external/ICLPool.sol';
import {ICLFactory} from 'contracts/interfaces/external/ICLFactory.sol';
import {INonfungiblePositionManager} from 'contracts/interfaces/external/INonfungiblePositionManager.sol';
import {RouterParameters, Route} from 'contracts/base/RouterImmutables.sol';
import {DeployTest} from 'script/deployParameters/DeployTest.s.sol';
import {UniversalRouter} from 'contracts/UniversalRouter.sol';
import {Constants} from 'contracts/libraries/Constants.sol';
import {Commands} from 'contracts/libraries/Commands.sol';

import {TestConstants} from '../utils/TestConstants.t.sol';

abstract contract BaseV3Fixture is Test, TestConstants {
    event UniversalRouterSwap(address indexed sender, address indexed recipient);

    UniversalRouter public router;
    address public pool; // first hop
    address public pool2; // second hop

    function setUp() public virtual {
        vm.createSelectFork(vm.envString('RPC_URL'), 118300000);

        DeployTest deploy = new DeployTest();
        deploy.run();

        router = deploy.router();
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
