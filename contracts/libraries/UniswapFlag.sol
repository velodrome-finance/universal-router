// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {TransientSlot} from './TransientSlot.sol';

/// @title UniswapFlag
/// @notice Library for managing a transient flag indicating whether the current operation is using Uniswap
library UniswapFlag {
    using TransientSlot for *;

    // keccak256(abi.encode(uint256(keccak256("dispatcher.storage.isUniswap")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 constant UNISWAP_FLAG_SLOT = 0x593c81333f1d6f058ce1404adf17985c81984916d7a32594ebecda3745b1a300;

    function set(bool flag) internal {
        UNISWAP_FLAG_SLOT.asBoolean().tstore(flag);
    }

    function get() internal view returns (bool) {
        return UNISWAP_FLAG_SLOT.asBoolean().tload();
    }
}
