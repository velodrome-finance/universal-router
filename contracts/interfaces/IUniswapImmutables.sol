// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

interface IUniswapImmutables {
    /// @notice The address of UniswapV2Factory
    function UNISWAP_V2_FACTORY() external returns (address);

    /// @notice The UniswapV2Pair initcodehash
    function UNISWAP_V2_PAIR_INIT_CODE_HASH() external returns (bytes32);

    /// @notice The address of UniswapV3Factory
    function UNISWAP_V3_FACTORY() external returns (address);

    /// @notice The UniswapV3Pool initcodehash
    function UNISWAP_V3_POOL_INIT_CODE_HASH() external returns (bytes32);

    /// @notice The address of Velodrome V2 PoolFactory
    function VELODROME_V2_FACTORY() external returns (address);

    /// @notice The VelodromeV2 Pool initcodehash
    function VELODROME_V2_INIT_CODE_HASH() external returns (bytes32);

    /// @notice The address of Velodrome CL PoolFactory
    function VELODROME_CL_FACTORY() external returns (address);

    /// @notice The Velodrome CLPool initcodehash
    function VELODROME_CL_POOL_INIT_CODE_HASH() external returns (bytes32);
}
