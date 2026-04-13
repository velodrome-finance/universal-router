// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

struct RouterParameters {
    address v2Factory;
    address v3Factory;
    bytes32 pairInitCodeHash;
    bytes32 poolInitCodeHash;
    address veloV2Factory;
    address veloCLFactory;
    bytes32 veloV2InitCodeHash;
    bytes32 veloCLInitCodeHash;
    address veloCLFactory2;
    bytes32 veloCLInitCodeHash2;
    address veloCLFactory3;
    bytes32 veloCLInitCodeHash3;
}

contract RouterImmutables {
    address internal immutable UNISWAP_V2_FACTORY;
    bytes32 internal immutable UNISWAP_V2_PAIR_INIT_CODE_HASH;
    address internal immutable UNISWAP_V3_FACTORY;
    bytes32 internal immutable UNISWAP_V3_POOL_INIT_CODE_HASH;
    address internal immutable VELODROME_V2_FACTORY;
    bytes32 internal immutable VELODROME_V2_INIT_CODE_HASH;
    address internal immutable VELODROME_CL_FACTORY;
    bytes32 internal immutable VELODROME_CL_POOL_INIT_CODE_HASH;
    address internal immutable VELODROME_CL_FACTORY_2;
    bytes32 internal immutable VELODROME_CL_POOL_INIT_CODE_HASH_2;
    address internal immutable VELODROME_CL_FACTORY_3;
    bytes32 internal immutable VELODROME_CL_POOL_INIT_CODE_HASH_3;

    constructor(RouterParameters memory params) {
        UNISWAP_V2_FACTORY = params.v2Factory;
        UNISWAP_V2_PAIR_INIT_CODE_HASH = params.pairInitCodeHash;
        UNISWAP_V3_FACTORY = params.v3Factory;
        UNISWAP_V3_POOL_INIT_CODE_HASH = params.poolInitCodeHash;
        VELODROME_V2_FACTORY = params.veloV2Factory;
        VELODROME_V2_INIT_CODE_HASH = params.veloV2InitCodeHash;
        VELODROME_CL_FACTORY = params.veloCLFactory;
        VELODROME_CL_POOL_INIT_CODE_HASH = params.veloCLInitCodeHash;
        VELODROME_CL_FACTORY_2 = params.veloCLFactory2;
        VELODROME_CL_POOL_INIT_CODE_HASH_2 = params.veloCLInitCodeHash2;
        VELODROME_CL_FACTORY_3 = params.veloCLFactory3;
        VELODROME_CL_POOL_INIT_CODE_HASH_3 = params.veloCLInitCodeHash3;
    }
}
