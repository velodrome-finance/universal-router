// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.0;

import {ERC20} from 'solmate/src/tokens/ERC20.sol';

import {IPoolFactory} from '../../../interfaces/external/IPoolFactory.sol';
import {IPool} from '../../../interfaces/external/IPool.sol';

import {Constants} from '../../../libraries/Constants.sol';
import {V2Path} from './V2Path.sol';

/// @title Uniswap v2 Helper Library
/// @notice Calculates the recipient address for a command
library UniswapV2Library {
    using V2Path for bytes;

    error InvalidReserves();
    error StableExactOutputUnsupported();

    /// @notice Calculates the v2 address for a pair
    /// @param factory The address of the v2 pool factory
    /// @param initCodeHash The hash of the pair initcode
    /// @param salt The salt for the pair
    /// @return pair The resultant v2 pair address
    function pairForSalt(address factory, bytes32 initCodeHash, bytes32 salt) internal pure returns (address pair) {
        pair = address(uint160(uint256(keccak256(abi.encodePacked(hex'ff', factory, salt, initCodeHash)))));
    }

    /// @notice Given an input asset amount returns the maximum output amount of the other asset
    /// @param amountIn The token input amount
    /// @param reserveIn The reserves available of the input token
    /// @param reserveOut The reserves available of the output token
    /// @return amountOut The output amount of the output token
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountOut)
    {
        if (reserveIn == 0 || reserveOut == 0) revert InvalidReserves();
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

    /// @notice Given an input asset amount returns the maximum output amount of the other asset
    /// @param factory The address of the v2 pool factory
    /// @param pair The address of the pair
    /// @param amountIn The token input amount
    /// @param reserveIn The reserves available of the input token
    /// @param reserveOut The reserves available of the output token
    /// @param from The address of the input token
    /// @param to The address of the output token
    /// @param stable Whether the pair is stable or not
    /// @return amountOut The output amount of the output token
    function getAmountOut(
        address factory,
        address pair,
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut,
        address from,
        address to,
        bool stable
    ) internal view returns (uint256 amountOut) {
        if (reserveIn == 0 || reserveOut == 0) revert InvalidReserves();
        // adapted from _getAmountOut in Pool.sol
        amountIn -= (amountIn * IPoolFactory(factory).getFee(pair, stable)) / 10_000;
        if (stable) {
            uint256 decimalsIn = 10 ** ERC20(from).decimals();
            uint256 decimalsOut = 10 ** ERC20(to).decimals();
            uint256 normalizedReserveIn = reserveIn * 1e18 / decimalsIn;
            uint256 normalizedReserveOut = reserveOut * 1e18 / decimalsOut;
            uint256 normalizedAmountIn = amountIn * 1e18 / decimalsIn;
            uint256 xy = _k(normalizedReserveIn, normalizedReserveOut);
            uint256 y = normalizedReserveOut - getY(normalizedAmountIn + normalizedReserveIn, xy, normalizedReserveOut);
            return (y * decimalsOut) / 1e18;
        } else {
            amountOut = (amountIn * reserveOut) / (reserveIn + amountIn);
        }
    }

    /// @notice Returns the input amount needed for a desired output amount in a single-hop trade
    /// @param fee The swap fee
    /// @param amountOut The desired output amount
    /// @param reserveIn The reserves available of the input token
    /// @param reserveOut The reserves available of the output token
    /// @param stable Whether the pair is stable or not (only used for Velo, should be false for uniswap)
    /// @return amountIn The input amount of the input token
    function getAmountIn(uint256 fee, uint256 amountOut, uint256 reserveIn, uint256 reserveOut, bool isUni, bool stable)
        internal
        pure
        returns (uint256 amountIn)
    {
        if (reserveIn == 0 || reserveOut == 0) revert InvalidReserves();
        if (isUni) {
            uint256 numerator = reserveIn * amountOut * 1000;
            uint256 denominator = (reserveOut - amountOut) * 997;
            amountIn = (numerator / denominator) + 1;
        } else if (!stable) {
            amountIn = (amountOut * reserveIn) / (reserveOut - amountOut);
            amountIn = amountIn * 10_000 / (10_000 - fee) + 1;
        } else {
            revert StableExactOutputUnsupported();
        }
    }

    /// @notice Sorts two tokens to return token0 and token1
    /// @param tokenA The first token to sort
    /// @param tokenB The other token to sort
    /// @return token0 The smaller token by address value
    /// @return token1 The larger token by address value
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    /// @notice Calculates k based on stable AMM formula given normalized reserves
    function _k(uint256 normalizedReservesA, uint256 normalizedReservesB) internal pure returns (uint256) {
        uint256 _a = (normalizedReservesA * normalizedReservesB) / 1e18;
        uint256 _b =
            ((normalizedReservesA * normalizedReservesA) / 1e18 + (normalizedReservesB * normalizedReservesB) / 1e18);
        return (_a * _b) / 1e18; // x3y+y3x >= k
    }

    function _f(uint256 x0, uint256 y) internal pure returns (uint256) {
        uint256 _a = (x0 * y) / 1e18;
        uint256 _b = ((x0 * x0) / 1e18 + (y * y) / 1e18);
        return (_a * _b) / 1e18;
    }

    function _d(uint256 x0, uint256 y) internal pure returns (uint256) {
        return (3 * x0 * ((y * y) / 1e18)) / 1e18 + ((((x0 * x0) / 1e18) * x0) / 1e18);
    }

    function getY(uint256 x0, uint256 xy, uint256 y) internal pure returns (uint256) {
        for (uint256 i = 0; i < 255; i++) {
            uint256 k = _f(x0, y);
            if (k < xy) {
                // there are two cases where dy == 0
                // case 1: The y is converged and we find the correct answer
                // case 2: _d(x0, y) is too large compare to (xy - k) and the rounding error
                //         screwed us.
                //         In this case, we need to increase y by 1
                uint256 dy = ((xy - k) * 1e18) / _d(x0, y);
                if (dy == 0) {
                    if (k == xy) {
                        // We found the correct answer. Return y
                        return y;
                    }
                    if (_f(x0, y + 1) > xy) {
                        // If _f(x0, y + 1) > xy, then we are close to the correct answer.
                        // There's no closer answer than y + 1
                        return y + 1;
                    }
                    dy = 1;
                }
                y = y + dy;
            } else {
                uint256 dy = ((k - xy) * 1e18) / _d(x0, y);
                if (dy == 0) {
                    if (k == xy || _f(x0, y - 1) < xy) {
                        // Likewise, if k == xy, we found the correct answer.
                        // If _f(x0, y - 1) < xy, then we are close to the correct answer.
                        // There's no closer answer than "y"
                        // It's worth mentioning that we need to find y where f(x0, y) >= xy
                        // As a result, we can't return y - 1 even it's closer to the correct answer
                        return y;
                    }
                    dy = 1;
                }
                y = y - dy;
            }
        }
        revert('!y');
    }
}
