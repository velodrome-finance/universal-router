// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {Permit2} from 'permit2/src/Permit2.sol';
import {ERC20} from 'solmate/src/tokens/ERC20.sol';
import {ICLFactory} from 'contracts/interfaces/external/ICLFactory.sol';
import {IPoolFactory} from 'contracts/interfaces/external/IPoolFactory.sol';
import {INonfungiblePositionManager} from 'contracts/interfaces/external/INonfungiblePositionManager.sol';

abstract contract TestConstants {
    // V2 Contracts
    IPoolFactory constant FACTORY = IPoolFactory(0xF1046053aa5682b4F9a81b5481394DA16BE5FF5a);
    address constant POOL_IMPLEMENTATION = address(0x95885Af5492195F0754bE71AD1545Fe81364E531);

    // CL Contracts
    ICLFactory constant CL_FACTORY = ICLFactory(0x548118C7E0B865C2CfA94D15EC86B666468ac758);
    address constant CL_POOL_IMPLEMENTATION = address(0xE0A596c403E854FFb9C828aB4f07eEae04A05D37);
    INonfungiblePositionManager constant NFT = INonfungiblePositionManager(0xbB5DFE1380333CEE4c2EeBd7202c80dE2256AdF4);

    // Tokens
    ERC20 constant VELO = ERC20(0x3c8B650257cFb5f272f799F5e2b4e65093a11a05);
    ERC20 constant USDC = ERC20(0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85);
    ERC20 constant DAI = ERC20(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);
    ERC20 constant WETH = ERC20(0x4200000000000000000000000000000000000006);
    ERC20 constant OP = ERC20(0x4200000000000000000000000000000000000042);
    int24 constant TICK_SPACING = 200;

    Permit2 constant PERMIT2 = Permit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    address constant RECIPIENT = address(10);
    address constant FROM = address(1234);
    uint256 constant BALANCE = 100000 ether;
    uint256 constant AMOUNT = 1 ether;
}
