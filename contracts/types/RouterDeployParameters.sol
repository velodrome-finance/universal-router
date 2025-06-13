// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

struct RouterDeployParameters {
    // Payment parameters
    address permit2;
    address weth9;
    // Uniswap swapping parameters
    address v2Factory;
    address v3Factory;
    bytes32 pairInitCodeHash;
    bytes32 poolInitCodeHash;
    address v4PoolManager;
    // Velodrome swapping parameters
    address veloV2Factory;
    address veloCLFactory;
    bytes32 veloV2InitCodeHash;
    bytes32 veloCLInitCodeHash;
}
