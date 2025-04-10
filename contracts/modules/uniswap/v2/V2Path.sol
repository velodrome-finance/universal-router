// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.6.0;

import {BytesLib} from '../v3/BytesLib.sol';
import {Constants} from '../../../libraries/Constants.sol';

/// @title Functions for manipulating path data for multihop swaps
library V2Path {
    using BytesLib for bytes;

    /// UniV2 functions

    /// @dev Check the path has at least 2 tokens (doesnt account for incorrectly encoded arguments)
    function v2HasMultipleTokens(bytes calldata path) internal pure returns (bool) {
        return path.length >= Constants.V2_MULTIPLE_TOKENS_MIN_LENGTH;
    }

    /// @dev Slice the path to get last 2 tokens
    function v2GetLastTokens(bytes calldata path) internal pure returns (bytes calldata) {
        return path[path.length - Constants.ADDR_SIZE * 2:];
    }

    /// @dev Slice the path to remove the last token
    function v2RemoveLastToken(bytes calldata path) internal pure returns (bytes calldata) {
        return path[:path.length - Constants.ADDR_SIZE];
    }

    /// @dev Get the number of tokens in the path
    function v2Length(bytes calldata path) internal pure returns (uint256) {
        return path.length / (Constants.ADDR_SIZE);
    }

    /// @dev Get the token0, token1 pair at the given index
    function pairAt(bytes calldata path, uint256 index) internal pure returns (bytes calldata) {
        uint256 start = index * Constants.ADDR_SIZE;
        return path[start:start + Constants.ADDR_SIZE * 2];
    }

    /// @dev Get token0 and token1
    function v2DecodePair(bytes calldata path) internal pure returns (address token0, address token1) {
        assembly {
            token0 := shr(96, calldataload(path.offset))
            token1 := shr(96, calldataload(add(path.offset, 20)))
        }
    }

    /// @dev Slice the path to get the first 2 tokens
    function v2GetFirstTokens(bytes calldata path) internal pure returns (bytes calldata) {
        return path[:Constants.V2_MULTIPLE_TOKENS_MIN_LENGTH];
    }

    /// VeloV2 functions

    /// @dev Get stable param (2nd argument - between token0 and token1)
    function getFirstStable(bytes calldata path) internal pure returns (bool stable) {
        assembly {
            stable := byte(0, calldataload(add(path.offset, 20)))
        }
    }

    /// @dev Get token0, stable and token1 param
    function decodeRoute(bytes calldata path) internal pure returns (address token0, address token1, bool stable) {
        assembly {
            token0 := shr(96, calldataload(path.offset))
            stable := byte(0, calldataload(add(path.offset, 20)))
            token1 := shr(96, calldataload(add(path.offset, 21)))
        }
    }

    /// @dev Slice the path to remove the last route
    function veloRemoveLastRoute(bytes calldata path) internal pure returns (bytes calldata) {
        return path[:path.length - Constants.VELO_PARTIAL_ROUTE_SIZE];
    }

    /// @dev Slice the path to get the last route
    function veloGetLastRoute(bytes calldata path) internal pure returns (bytes calldata) {
        return path[path.length - Constants.VELO_ROUTE_SIZE:];
    }

    /// @dev Slice the path to get the first route
    function getFirstRoute(bytes calldata path) internal pure returns (bytes calldata) {
        return path[:Constants.VELO_ROUTE_SIZE];
    }

    /// @dev Get the number of routes in the path
    /// Path is an odd number of elements. Removing the initial address makes the path divisible by (stable, address)j
    function veloLength(bytes calldata path) internal pure returns (uint256) {
        return (path.length - Constants.ADDR_SIZE) / (Constants.VELO_PARTIAL_ROUTE_SIZE);
    }

    /// @dev Get the route at the given index
    function veloRouteAt(bytes calldata path, uint256 index) internal pure returns (bytes calldata) {
        uint256 start = index * (Constants.VELO_PARTIAL_ROUTE_SIZE);
        uint256 end = start + Constants.VELO_ROUTE_SIZE;
        return path[start:end];
    }

    /// @dev Get the token0, token1 pair at the given index
    function veloDecodePair(bytes calldata path) internal pure returns (address token0, address token1) {
        assembly {
            token0 := shr(96, calldataload(path.offset))
            token1 := shr(96, calldataload(add(path.offset, 21)))
        }
    }

    /// Common functions

    /// @dev Get the first token in the path
    function decodeFirstToken(bytes calldata path) internal pure returns (address tokenA) {
        tokenA = path.toAddress();
    }

    /// @dev Get the last token in the path
    function getTokenOut(bytes calldata path) internal pure returns (address tokenOut) {
        assembly {
            tokenOut := shr(96, calldataload(add(path.offset, sub(path.length, 20))))
        }
    }
}
