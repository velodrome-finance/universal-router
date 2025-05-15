// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {ActionConstants} from '@uniswap/v4-periphery/src/libraries/ActionConstants.sol';

/// @title Constant state
/// @notice Constant state used by the Universal Router
library Constants {
    /// @dev Used for identifying cases when a v2 pair has already received input tokens
    uint256 internal constant ALREADY_PAID = 0;

    /// @notice used to signal that an action should use the entire balance of a currency
    /// This value is equivalent to 1<<255, i.e. a singular 1 in the most significant bit.
    uint256 internal constant TOTAL_BALANCE = ActionConstants.CONTRACT_BALANCE;

    /// @dev Used as a flag for identifying the transfer of ETH instead of a token
    address internal constant ETH = address(0);

    /// @dev The length of the bytes encoded address
    uint256 internal constant ADDR_SIZE = 20;

    /// @dev The length of the bytes encoded bool
    uint256 internal constant BOOL_SIZE = 1;

    /// @dev The minimum length of an encoding that contains 2 or more tokens
    uint256 internal constant V2_MULTIPLE_TOKENS_MIN_LENGTH = ADDR_SIZE * 2;

    /// @dev The length of a bytes encoded route (token0, token1, stable)
    uint256 internal constant VELO_ROUTE_SIZE = ADDR_SIZE * 2 + BOOL_SIZE;

    /// @dev The length of a partial bytes encoded route (useful to remove route, calculate length)
    uint256 internal constant VELO_PARTIAL_ROUTE_SIZE = BOOL_SIZE + ADDR_SIZE;

    /// @dev The uniswap v2 swap fee
    uint256 internal constant V2_FEE = 30;

    /// @dev The length of the bytes encoded fee
    uint256 internal constant V3_FEE_SIZE = 3;

    /// @dev The offset of a single token address (20) and pool fee (3)
    uint256 internal constant NEXT_V3_POOL_OFFSET = ADDR_SIZE + V3_FEE_SIZE;

    /// @dev The offset of an encoded pool key
    /// Token (20) + Fee (3) + Token (20) = 43
    uint256 internal constant V3_POP_OFFSET = NEXT_V3_POOL_OFFSET + ADDR_SIZE;

    /// @dev The minimum length of an encoding that contains 2 or more pools
    uint256 internal constant MULTIPLE_V3_POOLS_MIN_LENGTH = V3_POP_OFFSET + NEXT_V3_POOL_OFFSET;
}
