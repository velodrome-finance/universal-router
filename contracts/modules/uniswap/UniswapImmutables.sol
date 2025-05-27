// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {IUniswapImmutables} from '../../interfaces/IUniswapImmutables.sol';

struct UniswapParameters {
    address v2Factory;
    address v3Factory;
    bytes32 pairInitCodeHash;
    bytes32 poolInitCodeHash;
    address veloV2Factory;
    address veloCLFactory;
    bytes32 veloV2InitCodeHash;
    bytes32 veloCLInitCodeHash;
}

contract UniswapImmutables is IUniswapImmutables {
    ///@inheritdoc IUniswapImmutables
    address public immutable UNISWAP_V2_FACTORY;

    ///@inheritdoc IUniswapImmutables
    bytes32 public immutable UNISWAP_V2_PAIR_INIT_CODE_HASH;

    ///@inheritdoc IUniswapImmutables
    address public immutable UNISWAP_V3_FACTORY;

    ///@inheritdoc IUniswapImmutables
    bytes32 public immutable UNISWAP_V3_POOL_INIT_CODE_HASH;

    ///@inheritdoc IUniswapImmutables
    address public immutable VELODROME_V2_FACTORY;

    ///@inheritdoc IUniswapImmutables
    bytes32 public immutable VELODROME_V2_INIT_CODE_HASH;

    ///@inheritdoc IUniswapImmutables
    address public immutable VELODROME_CL_FACTORY;

    ///@inheritdoc IUniswapImmutables
    bytes32 public immutable VELODROME_CL_POOL_INIT_CODE_HASH;

    constructor(UniswapParameters memory params) {
        UNISWAP_V2_FACTORY = params.v2Factory;
        UNISWAP_V2_PAIR_INIT_CODE_HASH = params.pairInitCodeHash;
        UNISWAP_V3_FACTORY = params.v3Factory;
        UNISWAP_V3_POOL_INIT_CODE_HASH = params.poolInitCodeHash;
        VELODROME_V2_FACTORY = params.veloV2Factory;
        VELODROME_V2_INIT_CODE_HASH = params.veloV2InitCodeHash;
        VELODROME_CL_FACTORY = params.veloCLFactory;
        VELODROME_CL_POOL_INIT_CODE_HASH = params.veloCLInitCodeHash;
    }
}
