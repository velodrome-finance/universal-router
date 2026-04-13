// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {ERC20} from 'solmate/src/tokens/ERC20.sol';
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
    uint256 public constant MAX_RESERVES = 1e26;

    uint256 constant PRECISION = 10 ** 18;

    uint256 public constant DAY = 1 days;

    address public constant SUPERCHAIN_ERC20_BRIDGE = 0x4200000000000000000000000000000000000028;

    // OPEN_USDT related
    address public constant OPEN_USDT_ADDRESS = 0x1217BfE6c773EEC6cc4A38b5Dc45B92292B6E189;

    address public constant OPEN_USDT_OPTIMISM_BRIDGE_ADDRESS = 0x7bD2676c85cca9Fa2203ebA324fb8792fbd520b8;
    address public constant OPEN_USDT_BASE_BRIDGE_ADDRESS = 0x4F0654395d621De4d1101c0F98C1Dba73ca0a61f;

    address public constant OPEN_USDT_OPTIMISM_MAILBOX_ADDRESS = 0xd4C1905BB1D26BC93DAC913e13CaCC278CdCC80D;
    address public constant OPEN_USDT_BASE_MAILBOX_ADDRESS = 0xeA87ae93Fa0019a82A727bfd3eBd1cFCa8f64f1D;
    address payable public constant OPTIMISM_ROUTER_ICA_ADDRESS = payable(0x3E343D07D024E657ECF1f8Ae8bb7a12f08652E75);
    address payable public constant BASE_ROUTER_ICA_ADDRESS = payable(0x44647Cd983E80558793780f9a0c7C2aa9F384D07);

    address public constant OPEN_USDT_OPTIMISM_ISM_ADDRESS = 0x6d5dC676B03f5252c976EBa33d629fF15F03Be16;
    address public constant OPEN_USDT_BASE_ISM_ADDRESS = 0x9C53d53B652Feb2014aC6719E1Cd42B5B24B4A28;

    // XVELO related
    address public constant VOTING_ESCROW = 0xFAf8FD17D9840595845582fCB047DF13f006787d;
    address public constant VELO_ADDRESS = 0x9560e827aF36c94D2Ac33a39bCE1Fe78631088Db;
    address public constant XVELO_ADDRESS = 0x7f9AdFbd38b669F03d1d11000Bc76b9AaEA28A81;
    address public constant XVELO_TOKEN_BRIDGE_ADDRESS = 0x1A9d17828897d6289C6dff9DC9F5cc3bAEa17814;
    address public constant XVELO_MODE_MAILBOX_ADDRESS = 0x2f2aFaE1139Ce54feFC03593FeE8AB2aDF4a85A7;
    address public constant XVELO_METAL_MAILBOX_ADDRESS = 0x730f8a4128Fa8c53C777B62Baa1abeF94cAd34a9;
    address public constant ROOT_HL_MESSAGE_MODULE_ADDRESS = 0x2BbA7515F7cF114B45186274981888D8C2fBA15E;

    // Deployed USDC warp route (HypERC20Collateral with 5 bps fee for EVM-to-EVM)
    address public constant USDC_OPTIMISM_BRIDGE = 0x02bFd67829317D666dc7dFA030F18eaCC12c2cfb;
    address public constant USDC_BASE_BRIDGE = 0x37e637891A558B5b621723cbf8Fc771525f280C1;
    address public constant OPTIMISM_USDC_ADDRESS = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
    address public constant BASE_USDC_ADDRESS = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    // common
    address public constant ROOT_STORAGE_GAS_ORACLE = 0x27e88AeB8EA4B159d81df06355Ea3d20bEB1de38;
    address public constant LEAF_STORAGE_GAS_ORACLE = 0xE7487b4DF583c63D6841997ab56324D0a825e7F4;
    address public constant ROOT_IGP = 0xD8A76C4D91fCbB7Cc8eA795DFDF870E48368995C;
    address public constant LEAF_IGP = 0x931dFCc8c1141D6F532FD023bd87DAe0080c835d;
    address public constant LEAF_IGP_2 = 0x2b79328DA089E89A9E9c08732b56dd31F01011Db;
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

    // Base specific CL Factory
    ICLFactory constant CL_FACTORY_BASE = ICLFactory(0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A);
    bytes32 constant CL_POOL_INIT_CODE_HASH_BASE = 0xffb9af9ea6d9e39da47392ecc7055277b9915b8bfc9f83f105821b7791a6ae30;

    ICLFactory constant CL_FACTORY_2 = ICLFactory(0xaDe65c38CD4849aDBA595a4323a8C7DdfE89716a);
    bytes32 constant CL_POOL_INIT_CODE_HASH_2 = keccak256(
        abi.encodePacked(
            hex'3d602d80600a3d3981f3363d3d373d3d3d363d73',
            0x942e97a4c6FdC38B4CD1c0298D37d81fDD8E5A16,
            hex'5af43d82803e903d91602b57fd5bf3'
        )
    );

    INonfungiblePositionManagerCL constant NFT =
        INonfungiblePositionManagerCL(0x416b433906b1B72FA758e166e239c43d68dC6F29);
    INonfungiblePositionManagerCL constant NFT_BASE =
        INonfungiblePositionManagerCL(0x827922686190790b37229fd06084350E74485b72);
    INonfungiblePositionManagerCL constant NFT_2 =
        INonfungiblePositionManagerCL(0xa990C6a764b73BF43cee5Bb40339c3322FB9D55F);

    // Tokens
    ERC20 constant VELO = ERC20(0x3c8B650257cFb5f272f799F5e2b4e65093a11a05);
    ERC20 constant USDC = ERC20(0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85);
    ERC20 constant USDT = ERC20(0x94b008aA00579c1307B0EF2c499aD98a8ce58e58);
    ERC20 constant DAI = ERC20(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);
    ERC20 constant OP = ERC20(0x4200000000000000000000000000000000000042);
    ERC20 constant WETH = ERC20(WETH9_ADDRESS);
    int24 constant TICK_SPACING = 200;
    uint24 constant FEE = 500;
    // Tokens on Base
    ERC20 constant USDC_BASE = ERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
    ERC20 constant USDT_BASE = ERC20(0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2);
    ERC20 constant DAI_BASE = ERC20(0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb);

    // Constants for pool flag
    uint24 constant TICK_SPACING_WITH_FLAG = uint24(TICK_SPACING) | 0x100000;
}
