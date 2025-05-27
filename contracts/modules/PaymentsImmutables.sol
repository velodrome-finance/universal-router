// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {IWETH9} from '@uniswap/v4-periphery/src/interfaces/external/IWETH9.sol';
import {IPermit2} from 'permit2/src/interfaces/IPermit2.sol';
import {IPaymentImmutables} from '../interfaces/IPaymentImmutables.sol';

struct PaymentsParameters {
    address permit2;
    address weth9;
}

contract PaymentsImmutables is IPaymentImmutables {
    /// @inheritdoc IPaymentImmutables
    IWETH9 public immutable WETH9;

    /// @inheritdoc IPaymentImmutables
    IPermit2 public immutable PERMIT2;

    constructor(PaymentsParameters memory params) {
        WETH9 = IWETH9(params.weth9);
        PERMIT2 = IPermit2(params.permit2);
    }
}
