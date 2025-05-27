// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

/// @notice Constants used by Create3 deployment scripts
abstract contract Constants {
    // 01 - 39 is reserved for use by superchain contracts

    // 40 - 50 is reserved for use by slipstream contracts

    // 51 - 59 is reserved for use by superchain contracts

    // 60 - 70 is reserved for use by universal router contracts
    bytes11 public constant UNIVERSAL_ROUTER_ENTROPY = 0x0000000000000000000060; // used previously, no longer usable
    bytes11 public constant UNIVERSAL_ROUTER_ENTROPY_V2 = 0x0000000000000000000061;

    bytes11 public constant PERMIT2_ENTROPY = 0x0000000000000000000069;
    bytes11 public constant UNSUPPORTED_PROTOCOL_ENTROPY = 0x0000000000000000000070;
}
