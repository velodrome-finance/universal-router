// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import 'forge-std/Test.sol';

import {IUniswapV3Pool} from '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import {INonfungiblePositionManager} from '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';

import {Payments} from 'contracts/modules/Payments.sol';
import {ICLPool} from 'contracts/interfaces/external/ICLPool.sol';
import {RouterParameters} from 'contracts/types/RouterParameters.sol';
import {UniversalRouter} from 'contracts/UniversalRouter.sol';
import {Constants} from 'contracts/libraries/Constants.sol';

import '../BaseForkFixture.t.sol';

abstract contract BaseV3Fixture is BaseForkFixture {
    address public pool; // first hop
    address public pool2; // second hop

    function setUp() public virtual override {
        rootForkBlockNumber = 118300000;
        super.setUp();

        labelContracts();

        pool = createAndSeedPool(address(WETH), address(OP), FEE);
        pool2 = createAndSeedPool(address(WETH), address(USDC), FEE);

        vm.startPrank(FROM);
        deal(FROM, BALANCE);
        deal(address(WETH), FROM, BALANCE);
        deal(address(OP), FROM, BALANCE);
        ERC20(address(WETH)).approve(address(router), type(uint256).max);
        ERC20(address(OP)).approve(address(router), type(uint256).max);
    }

    function createAndSeedPool(address tokenA, address tokenB, uint24 fee) internal returns (address newPool) {
        (tokenA, tokenB) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        newPool = V3_FACTORY.getPool(tokenA, tokenB, fee);
        if (newPool == address(0)) {
            newPool = V3_FACTORY.createPool(tokenA, tokenB, fee);
        }
        int24 tickSpacing = IUniswapV3Pool(newPool).tickSpacing();

        // less of A
        uint256 amountA = 5_000_000 * 10 ** ERC20(tokenA).decimals();
        uint256 amountB = 5_000_000 * 10 ** ERC20(tokenB).decimals();
        deal(tokenA, address(this), amountA);
        deal(tokenB, address(this), amountB);
        ERC20(tokenA).approve(address(newPool), amountA);
        ERC20(tokenB).approve(address(newPool), amountB);
        ERC20(tokenA).approve(address(V3_NFT), amountA);
        ERC20(tokenB).approve(address(V3_NFT), amountB);

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: address(tokenA),
            token1: address(tokenB),
            fee: fee,
            tickLower: getMinTick({tickSpacing: tickSpacing}),
            tickUpper: getMaxTick({tickSpacing: tickSpacing}),
            recipient: FROM,
            amount0Desired: amountA,
            amount1Desired: amountB,
            amount0Min: 0,
            amount1Min: 0,
            deadline: block.timestamp
        });
        V3_NFT.mint(params);
    }

    function labelContracts() internal {
        vm.label(RECIPIENT, 'Recipient');
        vm.label(address(V3_FACTORY), 'CL Pool Factory');
        vm.label(address(V3_NFT), 'Position Manager');
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
