// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import 'forge-std/Test.sol';

import {Payments} from 'contracts/modules/Payments.sol';
import {ICLPool} from 'contracts/interfaces/external/ICLPool.sol';
import {INonfungiblePositionManagerCL} from 'contracts/interfaces/external/INonfungiblePositionManager.sol';
import {RouterParameters} from 'contracts/types/RouterParameters.sol';
import {UniversalRouter} from 'contracts/UniversalRouter.sol';
import {Constants} from 'contracts/libraries/Constants.sol';

import '../BaseForkFixture.t.sol';

abstract contract BaseSlipstreamFixture is BaseForkFixture {
    address public pool; // first hop
    address public pool2; // second hop

    function setUp() public virtual override {
        rootForkBlockNumber = 121503000; //cl factory creation - 121501661
        super.setUp();

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

        INonfungiblePositionManagerCL.MintParams memory params = INonfungiblePositionManagerCL.MintParams({
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
