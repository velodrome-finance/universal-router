// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {ERC20} from 'solmate/src/tokens/ERC20.sol';
import {IPermit2} from 'permit2/src/interfaces/IPermit2.sol';
import {IUniswapV2Factory} from '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import {IUniswapV3Factory} from '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import {INonfungiblePositionManager} from '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';

import {INonfungiblePositionManagerCL} from 'contracts/interfaces/external/INonfungiblePositionManager.sol';
import {IPoolFactory} from 'contracts/interfaces/external/IPoolFactory.sol';
import {ICLFactory} from 'contracts/interfaces/external/ICLFactory.sol';

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

    address public constant SUPERCHAIN_ERC20_BRIDGE = 0x4200000000000000000000000000000000000028;

    // OPEN_USDT related
    address public constant OPEN_USDT_ADDRESS = 0x1217BfE6c773EEC6cc4A38b5Dc45B92292B6E189;

    address public constant OPEN_USDT_OPTIMISM_BRIDGE_ADDRESS = 0x7bD2676c85cca9Fa2203ebA324fb8792fbd520b8;
    address public constant OPEN_USDT_BASE_BRIDGE_ADDRESS = 0x4F0654395d621De4d1101c0F98C1Dba73ca0a61f;

    address public constant OPEN_USDT_OPTIMISM_MAILBOX_ADDRESS = 0xd4C1905BB1D26BC93DAC913e13CaCC278CdCC80D;
    address public constant OPEN_USDT_BASE_MAILBOX_ADDRESS = 0xeA87ae93Fa0019a82A727bfd3eBd1cFCa8f64f1D;
    address public constant OPTIMISM_ROUTER_ICA_ADDRESS = 0x03D6cC17d45E9EA27ED757A8214d1F07F7D901aD;
    address public constant BASE_ROUTER_ICA_ADDRESS = 0x4767D22117bBeeb295413000B620B93FD8522d53;

    address public constant OPEN_USDT_OPTIMISM_ISM_ADDRESS = 0x6d5dC676B03f5252c976EBa33d629fF15F03Be16;
    address public constant OPEN_USDT_BASE_ISM_ADDRESS = 0x9C53d53B652Feb2014aC6719E1Cd42B5B24B4A28;

    // XVELO related
    address public constant VOTING_ESCROW = 0xFAf8FD17D9840595845582fCB047DF13f006787d;
    address public constant VELO_ADDRESS = 0x9560e827aF36c94D2Ac33a39bCE1Fe78631088Db;
    address public constant XVELO_ADDRESS = 0x7f9AdFbd38b669F03d1d11000Bc76b9AaEA28A81;
    address public constant XVELO_TOKEN_BRIDGE_ADDRESS = 0x1A9d17828897d6289C6dff9DC9F5cc3bAEa17814;
    address public constant XVELO_MODE_MAILBOX_ADDRESS = 0x2f2aFaE1139Ce54feFC03593FeE8AB2aDF4a85A7;
    address public constant ROOT_HL_MESSAGE_MODULE_ADDRESS = 0x2BbA7515F7cF114B45186274981888D8C2fBA15E;
    address public constant MODE_PERMIT2_ADDRESS = 0xbF055A2D7450b55c194c32e285deDb956416CAF3;

    // common
    address public constant ROOT_STORAGE_GAS_ORACLE = 0x27e88AeB8EA4B159d81df06355Ea3d20bEB1de38;
    address public constant LEAF_STORAGE_GAS_ORACLE = 0xC9B8ea6230d6687a4b13fD3C0b8f0Ec607B26465;
    address public constant ROOT_IGP = 0xD8A76C4D91fCbB7Cc8eA795DFDF870E48368995C;
    address public constant LEAF_IGP = 0x931dFCc8c1141D6F532FD023bd87DAe0080c835d;
    address public constant PERMIT2_ADDRESS = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address public constant WETH9_ADDRESS = 0x4200000000000000000000000000000000000006;
    address public constant bUSDC_ADDRESS = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
    address public constant UNI_V2_FACTORY_ADDRESS = 0x0c3c1c532F1e39EdF36BE9Fe0bE1410313E074Bf;
    address public constant VELO_V2_FACTORY_ADDRESS = 0xF1046053aa5682b4F9a81b5481394DA16BE5FF5a;
    address public constant VELO_V2_POOL_IMPLEMENTATION = 0x95885Af5492195F0754bE71AD1545Fe81364E531;
    bytes32 public constant VELO_V2_INIT_CODE_HASH = keccak256(
        abi.encodePacked(
            hex'3d602d80600a3d3981f3363d3d373d3d3d363d73',
            VELO_V2_POOL_IMPLEMENTATION,
            hex'5af43d82803e903d91602b57fd5bf3'
        )
    );

    /// TEST PARAMS ///
    address constant RECIPIENT = address(10);
    uint256 constant BALANCE = 100000 ether;
    uint256 constant AMOUNT = 1 ether;
    address constant FROM = address(1234);

    IPermit2 constant PERMIT2 = IPermit2(PERMIT2_ADDRESS);
    IPermit2 constant MODE_PERMIT2 = IPermit2(MODE_PERMIT2_ADDRESS);
    ERC20 constant bUSDC = ERC20(bUSDC_ADDRESS);

    // Uni specific
    IUniswapV2Factory constant UNI_V2_FACTORY = IUniswapV2Factory(UNI_V2_FACTORY_ADDRESS);
    bytes32 constant V2_INIT_CODE_HASH = 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f;

    IUniswapV3Factory constant V3_FACTORY = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    bytes32 constant V3_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;
    INonfungiblePositionManager constant V3_NFT =
        INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    // Velo specific
    IPoolFactory constant VELO_V2_FACTORY = IPoolFactory(VELO_V2_FACTORY_ADDRESS);

    ICLFactory constant CL_FACTORY = ICLFactory(0xCc0bDDB707055e04e497aB22a59c2aF4391cd12F);
    bytes32 constant CL_POOL_INIT_CODE_HASH = keccak256(
        abi.encodePacked(
            hex'3d602d80600a3d3981f3363d3d373d3d3d363d73',
            0xc28aD28853A547556780BEBF7847628501A3bCbb,
            hex'5af43d82803e903d91602b57fd5bf3'
        )
    );

    INonfungiblePositionManagerCL constant NFT =
        INonfungiblePositionManagerCL(0x416b433906b1B72FA758e166e239c43d68dC6F29);

    // Tokens
    ERC20 constant VELO = ERC20(0x3c8B650257cFb5f272f799F5e2b4e65093a11a05);
    ERC20 constant USDC = ERC20(0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85);
    ERC20 constant DAI = ERC20(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);
    ERC20 constant OP = ERC20(0x4200000000000000000000000000000000000042);
    ERC20 constant WETH = ERC20(WETH9_ADDRESS);
    int24 constant TICK_SPACING = 200;
    uint24 constant FEE = 500;
}
