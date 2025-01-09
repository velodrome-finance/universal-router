// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import 'forge-std/Test.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import '@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol';
import {ERC20} from 'solmate/src/tokens/ERC20.sol';
import {Permit2} from 'permit2/src/Permit2.sol';

import {Payments} from 'contracts/modules/Payments.sol';
import {IPool} from 'contracts/interfaces/external/IPool.sol';
import {IPoolFactory} from 'contracts/interfaces/external/IPoolFactory.sol';
import {RouterParameters, Route} from 'contracts/base/RouterImmutables.sol';
import {DeployTest} from 'script/deployParameters/DeployTest.s.sol';
import {UniversalRouter} from 'contracts/UniversalRouter.sol';
import {Constants} from 'contracts/libraries/Constants.sol';
import {Commands} from 'contracts/libraries/Commands.sol';

import {TestConstants} from '../utils/TestConstants.t.sol';

abstract contract BaseV2Fixture is Test, TestConstants {
    event UniversalRouterSwap(address indexed sender, address indexed recipient);

    UniversalRouter public router;
    address public pair;

    function createAndSeedPair(address tokenA, address tokenB, bool _stable)
        internal
        virtual
        returns (address newPair)
    {
        newPair = FACTORY.getPair(tokenA, tokenB, _stable);
        if (newPair == address(0)) {
            newPair = FACTORY.createPair(tokenA, tokenB, _stable);
        }

        deal(tokenA, address(this), 100 * 10 ** ERC20(tokenA).decimals());
        deal(tokenB, address(this), 100 * 10 ** ERC20(tokenB).decimals());
        ERC20(tokenA).transfer(address(newPair), 100 * 10 ** ERC20(tokenA).decimals());
        ERC20(tokenB).transfer(address(newPair), 100 * 10 ** ERC20(tokenB).decimals());
        IPool(newPair).mint(address(this));
    }

    function token0() internal virtual returns (address);
    function token1() internal virtual returns (address);

    function setUpTokens() internal virtual {}

    function labelContracts() internal virtual {
        vm.label(address(router), 'UniversalRouter');
        vm.label(RECIPIENT, 'recipient');
        vm.label(address(FACTORY), 'V2 Pool Factory');
        vm.label(POOL_IMPLEMENTATION, 'V2 Pool Implementation');
        vm.label(address(WETH), 'WETH');
        vm.label(FROM, 'from');
        vm.label(pair, string.concat(ERC20(token0()).symbol(), '-', string.concat(ERC20(token1()).symbol()), 'Pool'));
    }
}
