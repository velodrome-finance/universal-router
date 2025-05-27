// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {IWETH9} from '@uniswap/v4-periphery/src/interfaces/external/IWETH9.sol';
import {IPermit2} from 'permit2/src/interfaces/IPermit2.sol';

interface IPaymentImmutables {
    /// @notice WETH9 address
    function WETH9() external returns (IWETH9);

    /// @notice Permit2 address
    function PERMIT2() external returns (IPermit2);
}
