// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {ERC20} from 'solmate/src/tokens/ERC20.sol';

import {UniswapImmutables} from '../UniswapImmutables.sol';
import {IPool} from '../../../interfaces/external/IPool.sol';
import {Permit2Payments} from '../../Permit2Payments.sol';

import {Constants} from '../../../libraries/Constants.sol';
import {UniswapV2Library} from './UniswapV2Library.sol';
import {UniswapFlag} from '../../../libraries/UniswapFlag.sol';
import {V2Path} from './V2Path.sol';

/// @title Router for Uniswap v2 Trades
abstract contract V2SwapRouter is UniswapImmutables, Permit2Payments {
    using V2Path for bytes;

    error V2TooLittleReceived();
    error V2TooMuchRequested();
    error V2InvalidPath();

    /// @dev path only contains addresses
    function _v2Swap(bytes calldata path, address recipient, address pair) private {
        unchecked {
            if (!path.v2HasMultipleTokens()) revert V2InvalidPath();

            // cached to save on duplicate operations
            (address token0, address token1) = path.v2DecodePair();
            (token0,) = UniswapV2Library.sortTokens({tokenA: token0, tokenB: token1});
            uint256 finalPairIndex = path.v2Length() - 1;
            uint256 penultimatePairIndex = finalPairIndex - 1;
            for (uint256 i; i < finalPairIndex; i++) {
                (address input,) = (path.pairAt(i).v2DecodePair());
                (uint256 reserve0, uint256 reserve1,) = IPool(pair).getReserves();
                (uint256 reserveInput, uint256 reserveOutput) =
                    input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
                uint256 amountInput = ERC20(input).balanceOf(pair) - reserveInput;
                uint256 amountOutput = UniswapV2Library.getAmountOut({
                    amountIn: amountInput,
                    reserveIn: reserveInput,
                    reserveOut: reserveOutput
                });
                (uint256 amount0Out, uint256 amount1Out) =
                    input == token0 ? (uint256(0), amountOutput) : (amountOutput, uint256(0));
                address nextPair;
                (nextPair, token0) = i < penultimatePairIndex
                    ? UniswapV2Library.pairAndToken0For({
                        factory: UNISWAP_V2_FACTORY,
                        initCodeHash: UNISWAP_V2_PAIR_INIT_CODE_HASH,
                        path: path.pairAt(i + 1)
                    })
                    : (recipient, address(0));
                IPool(pair).swap({amount0Out: amount0Out, amount1Out: amount1Out, to: nextPair, data: new bytes(0)});
                pair = nextPair;
            }
        }
    }

    /// @dev path contains token addresses and stable boolean
    function _veloSwap(bytes calldata routes, address recipient, address pair) private {
        unchecked {
            uint256 length = routes.veloLength();
            if (length == 0) revert V2InvalidPath();

            // cached to save on duplicate operations
            (address from, address to) = routes.veloRouteAt(0).veloDecodePair();
            (address token0,) = UniswapV2Library.sortTokens({tokenA: from, tokenB: to});
            uint256 finalPairIndex = length - 1;
            for (uint256 i; i < length; i++) {
                (address input, address output, bool stable) = routes.veloRouteAt(i).decodeRoute();
                (uint256 reserve0, uint256 reserve1,) = IPool(pair).getReserves();

                (uint256 reserveInput, uint256 reserveOutput) =
                    input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
                uint256 amountInput = ERC20(input).balanceOf(pair) - reserveInput;
                uint256 amountOutput = UniswapV2Library.getAmountOut({
                    factory: VELODROME_V2_FACTORY,
                    pair: pair,
                    amountIn: amountInput,
                    reserveIn: reserveInput,
                    reserveOut: reserveOutput,
                    from: input,
                    to: output,
                    stable: stable
                });
                (uint256 amount0Out, uint256 amount1Out) =
                    input == token0 ? (uint256(0), amountOutput) : (amountOutput, uint256(0));
                address nextPair;
                (nextPair, token0) = i < finalPairIndex
                    ? UniswapV2Library.pairAndToken0For({
                        factory: VELODROME_V2_FACTORY,
                        initCodeHash: VELODROME_V2_INIT_CODE_HASH,
                        path: routes.veloRouteAt(i + 1)
                    })
                    : (recipient, address(0));
                IPool(pair).swap({amount0Out: amount0Out, amount1Out: amount1Out, to: nextPair, data: new bytes(0)});
                pair = nextPair;
            }
        }
    }

    /// @notice Performs a Uniswap v2 exact input swap
    /// @param recipient The recipient of the output tokens
    /// @param amountIn The amount of input tokens for the trade
    /// @param amountOutMinimum The minimum desired amount of output tokens
    /// @param path The path of the trade as an array of token addresses
    /// @param payer The address that will be paying the input
    function v2SwapExactInput(
        address recipient,
        uint256 amountIn,
        uint256 amountOutMinimum,
        bytes calldata path,
        address payer
    ) internal {
        bool isUni = UniswapFlag.get();
        ERC20 tokenOut = ERC20(path.getTokenOut());
        address firstPair = isUni
            ? UniswapV2Library.pairFor({
                factory: UNISWAP_V2_FACTORY,
                initCodeHash: UNISWAP_V2_PAIR_INIT_CODE_HASH,
                path: path.v2GetFirstTokens()
            })
            : UniswapV2Library.pairFor({
                factory: VELODROME_V2_FACTORY,
                initCodeHash: VELODROME_V2_INIT_CODE_HASH,
                path: path.getFirstRoute()
            });
        if (
            amountIn != Constants.ALREADY_PAID // amountIn of 0 to signal that the pair already has the tokens
        ) {
            payOrPermit2Transfer(path.decodeFirstToken(), payer, firstPair, amountIn);
        }

        uint256 balanceBefore = tokenOut.balanceOf(recipient);

        isUni
            ? _v2Swap({path: path, recipient: recipient, pair: firstPair})
            : _veloSwap({routes: path, recipient: recipient, pair: firstPair});

        uint256 amountOut = tokenOut.balanceOf(recipient) - balanceBefore;
        if (amountOut < amountOutMinimum) revert V2TooLittleReceived();
    }

    /// @notice Performs a Uniswap v2 exact output swap
    /// @param recipient The recipient of the output tokens
    /// @param amountOut The amount of output tokens to receive for the trade
    /// @param amountInMaximum The maximum desired amount of input tokens
    /// @param path The path of the trade as an array of token addresses
    /// @param payer The address that will be paying the input
    function v2SwapExactOutput(
        address recipient,
        uint256 amountOut,
        uint256 amountInMaximum,
        bytes calldata path,
        address payer
    ) internal {
        bool isUni = UniswapFlag.get();
        (address factory, bytes32 initCodeHash) = isUni
            ? (UNISWAP_V2_FACTORY, UNISWAP_V2_PAIR_INIT_CODE_HASH)
            : (VELODROME_V2_FACTORY, VELODROME_V2_INIT_CODE_HASH);
        (uint256 amountIn, address firstPair) = UniswapV2Library.getAmountInMultihop({
            factory: factory,
            initCodeHash: initCodeHash,
            amountOut: amountOut,
            path: path
        });
        if (amountIn > amountInMaximum) revert V2TooMuchRequested();

        payOrPermit2Transfer(path.decodeFirstToken(), payer, firstPair, amountIn);

        isUni
            ? _v2Swap({path: path, recipient: recipient, pair: firstPair})
            : _veloSwap({routes: path, recipient: recipient, pair: firstPair});
    }
}
