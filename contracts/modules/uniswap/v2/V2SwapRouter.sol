// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {ERC20} from 'solmate/src/tokens/ERC20.sol';

import {UniswapImmutables} from '../UniswapImmutables.sol';
import {IPool} from '../../../interfaces/external/IPool.sol';
import {IPoolFactory} from '../../../interfaces/external/IPoolFactory.sol';
import {Permit2Payments} from '../../Permit2Payments.sol';

import {Constants} from '../../../libraries/Constants.sol';
import {UniswapV2Library} from './UniswapV2Library.sol';
import {V2Path} from './V2Path.sol';

/// @title Router for Uniswap v2 Trades
abstract contract V2SwapRouter is UniswapImmutables, Permit2Payments {
    using V2Path for bytes;

    error V2TooLittleReceived();
    error V2TooMuchRequested();
    error V2InvalidPath();
    error InvalidPath();

    /// @notice Calculates the v2 address for a pair without making any external calls
    /// @param isUni Whether this is a Uniswap V2 path or not
    /// @param path The encoded token0, token1 (and stable)
    /// @return pair The resultant v2 pair address
    function pairFor(bool isUni, bytes calldata path) internal view returns (address pair) {
        address token0;
        address token1;
        address tokenA;
        address tokenB;
        bytes32 salt;
        address factory;
        bytes32 initCodeHash;

        if (isUni) {
            factory = UNISWAP_V2_FACTORY;
            initCodeHash = UNISWAP_V2_PAIR_INIT_CODE_HASH;
            (tokenA, tokenB) = path.v2DecodePair();
            (token0, token1) = UniswapV2Library.sortTokens({tokenA: tokenA, tokenB: tokenB});
            salt = keccak256(abi.encodePacked(token0, token1));
        } else {
            factory = VELODROME_V2_FACTORY;
            initCodeHash = VELODROME_V2_INIT_CODE_HASH;
            bool stable;
            (tokenA, tokenB, stable) = path.decodeRoute();
            (token0, token1) = UniswapV2Library.sortTokens({tokenA: tokenA, tokenB: tokenB});
            salt = keccak256(abi.encodePacked(token0, token1, stable));
        }

        pair = UniswapV2Library.pairForSalt({factory: factory, initCodeHash: initCodeHash, salt: salt});
    }

    /// @notice Calculates the v2 address for a pair and the pair's token0
    /// @param isUni Whether this is a Uniswap V2 path or not
    /// @param path The encoded token0, token1 (and stable)
    /// @return pair The resultant v2 pair address
    /// @return token0 The token considered token0 in this pair
    function pairAndToken0For(bool isUni, bytes calldata path) internal view returns (address pair, address token0) {
        (address tokenA, address tokenB) = isUni ? path.v2DecodePair() : path.veloDecodePair();

        (token0,) = UniswapV2Library.sortTokens({tokenA: tokenA, tokenB: tokenB});
        pair = pairFor({isUni: isUni, path: path});
    }

    /// @notice Calculates the v2 address for a pair and fetches the reserves for each token
    /// @param isUni Whether this is a Uniswap V2 path or not
    /// @param path The encoded token0, token1 (and stable)
    /// @return pair The resultant v2 pair address
    /// @return reserveA The reserves for tokenA
    /// @return reserveB The reserves for tokenB
    function pairAndReservesFor(bool isUni, bytes calldata path)
        internal
        view
        returns (address pair, uint256 reserveA, uint256 reserveB)
    {
        address token0;
        (pair, token0) = pairAndToken0For({isUni: isUni, path: path});
        (uint256 reserve0, uint256 reserve1,) = IPool(pair).getReserves();
        (reserveA, reserveB) = path.decodeFirstToken() == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    /// @notice Returns the input amount needed for a desired output amount in a multi-hop trade
    /// @param amountOut The desired output amount
    /// @param path The path of the multi-hop trade
    /// @param isUni Whether this is a Uniswap V2 path or not
    /// @return amount The input amount of the input token
    /// @return pair The first pair in the trade
    function getAmountInMultihop(uint256 amountOut, bytes calldata path, bool isUni)
        internal
        view
        returns (uint256 amount, address pair)
    {
        if (isUni ? !path.hasMultipleTokens() : !path.hasMultipleRoutes()) revert InvalidPath();
        amount = amountOut;
        uint256 reserveIn;
        uint256 reserveOut;
        if (isUni) {
            while (path.hasMultipleTokens()) {
                (pair, reserveIn, reserveOut) = pairAndReservesFor({isUni: true, path: path.v2GetLastTokens()});
                amount = UniswapV2Library.getAmountIn({
                    fee: Constants.V2_FEE,
                    amountOut: amount,
                    reserveIn: reserveIn,
                    reserveOut: reserveOut,
                    isUni: isUni,
                    stable: false
                });
                path = path.v2RemoveLastToken();
            }
        } else {
            while (path.hasMultipleRoutes()) {
                bytes calldata veloPath = path.veloGetLastRoute();
                bool stable = veloPath.getFirstStable();
                (pair, reserveIn, reserveOut) = pairAndReservesFor({isUni: false, path: veloPath});
                amount = UniswapV2Library.getAmountIn({
                    fee: IPoolFactory(VELODROME_V2_FACTORY).getFee({_pool: pair, _stable: stable}),
                    amountOut: amount,
                    reserveIn: reserveIn,
                    reserveOut: reserveOut,
                    isUni: isUni,
                    stable: stable
                });

                path = path.veloRemoveLastRoute();
            }
        }
    }

    /// @dev path only contains addresses
    function _v2Swap(bytes calldata path, address recipient, address pair) private {
        unchecked {
            if (!path.hasMultipleTokens()) revert V2InvalidPath();

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
                    ? pairAndToken0For({isUni: true, path: path.pairAt(i + 1)})
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
            (address input, address output, bool stable) = routes.veloRouteAt(0).decodeRoute();
            (address token0,) = UniswapV2Library.sortTokens({tokenA: input, tokenB: output});
            uint256 finalPairIndex = length - 1;
            for (uint256 i; i < length; i++) {
                (input, output, stable) = routes.veloRouteAt(i).decodeRoute();
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
                    ? pairAndToken0For({isUni: false, path: routes.veloRouteAt(i + 1)})
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
    /// @param isUni Whether this is a Uniswap V2 path or not
    function v2SwapExactInput(
        address recipient,
        uint256 amountIn,
        uint256 amountOutMinimum,
        bytes calldata path,
        address payer,
        bool isUni
    ) internal {
        ERC20 tokenOut = ERC20(path.getTokenOut());
        address firstPair = isUni
            ? pairFor({isUni: true, path: path.v2GetFirstTokens()})
            : pairFor({isUni: false, path: path.getFirstRoute()});
        if (
            amountIn != Constants.ALREADY_PAID // amountIn of 0 to signal that the pair already has the tokens
        ) {
            payOrPermit2Transfer({token: path.decodeFirstToken(), payer: payer, recipient: firstPair, amount: amountIn});
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
    /// @param isUni Whether this is a Uniswap V2 path or not
    function v2SwapExactOutput(
        address recipient,
        uint256 amountOut,
        uint256 amountInMaximum,
        bytes calldata path,
        address payer,
        bool isUni
    ) internal {
        (uint256 amountIn, address firstPair) = getAmountInMultihop({amountOut: amountOut, path: path, isUni: isUni});
        if (amountIn > amountInMaximum) revert V2TooMuchRequested();

        payOrPermit2Transfer({token: path.decodeFirstToken(), payer: payer, recipient: firstPair, amount: amountIn});

        isUni
            ? _v2Swap({path: path, recipient: recipient, pair: firstPair})
            : _veloSwap({routes: path, recipient: recipient, pair: firstPair});
    }
}
