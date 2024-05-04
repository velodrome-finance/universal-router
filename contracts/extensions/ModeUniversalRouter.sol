// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {UniversalRouter} from '../UniversalRouter.sol';
import {RouterParameters} from '../base/RouterImmutables.sol';
import {IFeeSharing} from '../interfaces/external/IFeeSharing.sol';

contract ModeUniversalRouter is UniversalRouter {
    constructor(RouterParameters memory params, address sfs, uint256 tokenId) UniversalRouter(params) {
        IFeeSharing(sfs).assign(tokenId);
    }
}
