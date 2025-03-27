// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

struct UniswapParameters {
    address v2Factory;
    address v3Factory;
    bytes32 pairInitCodeHash;
    bytes32 poolInitCodeHash;
    address veloV2Factory;
    address veloCLFactory;
    address veloV2Implementation;
    bytes32 veloCLInitCodeHash;
}

struct Route {
    address from;
    address to;
    bool stable;
}

contract UniswapImmutables {
    /// @notice The address of UniswapV2Factory
    address internal immutable UNISWAP_V2_FACTORY;

    /// @notice The UniswapV2Pair initcodehash
    bytes32 internal immutable UNISWAP_V2_PAIR_INIT_CODE_HASH;

    /// @notice The address of UniswapV3Factory
    address internal immutable UNISWAP_V3_FACTORY;

    /// @notice The UniswapV3Pool initcodehash
    bytes32 internal immutable UNISWAP_V3_POOL_INIT_CODE_HASH;

    /// @notice The address of Velodrome V2 PoolFactory
    address internal immutable VELODROME_V2_FACTORY;

    /// @dev The address of the VelodromeV2 Pool implementation
    address internal immutable VELODROME_V2_IMPLEMENTATION;

    /// @notice The address of Velodrome CL PoolFactory
    address internal immutable VELODROME_CL_FACTORY;

    /// @notice The Velodrome CLPool initcodehash
    bytes32 internal immutable VELODROME_CL_POOL_INIT_CODE_HASH;

    constructor(UniswapParameters memory params) {
        UNISWAP_V2_FACTORY = params.v2Factory;
        UNISWAP_V2_PAIR_INIT_CODE_HASH = params.pairInitCodeHash;
        UNISWAP_V3_FACTORY = params.v3Factory;
        UNISWAP_V3_POOL_INIT_CODE_HASH = params.poolInitCodeHash;
        VELODROME_V2_FACTORY = params.veloV2Factory;
        VELODROME_V2_IMPLEMENTATION = params.veloV2Implementation;
        VELODROME_CL_FACTORY = params.veloCLFactory;
        VELODROME_CL_POOL_INIT_CODE_HASH = params.veloCLInitCodeHash;
    }
}
