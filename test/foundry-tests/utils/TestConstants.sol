// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {IPermit2} from 'permit2/src/interfaces/IPermit2.sol';
import {ERC20} from 'solmate/src/tokens/ERC20.sol';
import {IUniswapV2Factory} from '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';

import {VelodromeTimeLibrary} from '../../../contracts/libraries/VelodromeTimeLibrary.sol';
import {IPoolFactory} from '../../../contracts/interfaces/external/IPoolFactory.sol';

abstract contract TestConstants {
    uint256 public constant TOKEN_1 = 1e18;
    uint256 public constant USDC_1 = 1e6;
    uint256 public constant POOL_1 = 1e9;

    // maximum number of tokens, used in fuzzing
    uint256 public constant MAX_TOKENS = 1e40;
    uint256 public constant MAX_BPS = 10_000;
    uint112 public constant MAX_BUFFER_CAP = type(uint112).max;

    uint256 constant PRECISION = 10 ** 18;

    uint256 public constant DAY = 1 days;
    uint256 public constant WEEK = VelodromeTimeLibrary.WEEK;

    address public constant SUPERCHAIN_ERC20_BRIDGE = 0x4200000000000000000000000000000000000028;

    address public constant OPEN_USDT_ADDRESS = 0x1217BfE6c773EEC6cc4A38b5Dc45B92292B6E189;
    address public constant PERMIT2_ADDRESS = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address public constant WETH9_ADDRESS = 0x4200000000000000000000000000000000000006;
    address public constant bUSDC_ADDRESS = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
    address public constant UNI_V2_FACTORY_ADDRESS = 0x0c3c1c532F1e39EdF36BE9Fe0bE1410313E074Bf;
    address public constant VELO_V2_FACTORY_ADDRESS = 0xF1046053aa5682b4F9a81b5481394DA16BE5FF5a;
    address public constant VELO_V2_POOL_IMPLEMENTATION = 0x95885Af5492195F0754bE71AD1545Fe81364E531;

    /// TEST PARAMS ///
    address constant RECIPIENT = address(10);
    uint256 constant BALANCE = 100000 ether;
    uint256 constant AMOUNT = 1 ether;
    address constant FROM = address(1234);

    IPermit2 constant PERMIT2 = IPermit2(PERMIT2_ADDRESS);
    ERC20 constant WETH9 = ERC20(WETH9_ADDRESS);
    ERC20 constant bUSDC = ERC20(bUSDC_ADDRESS);

    // Uni specific
    IUniswapV2Factory constant UNI_V2_FACTORY = IUniswapV2Factory(UNI_V2_FACTORY_ADDRESS);
    // Velo specific
    IPoolFactory constant VELO_V2_FACTORY = IPoolFactory(VELO_V2_FACTORY_ADDRESS);
}
