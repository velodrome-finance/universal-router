#!/bin/bash

# Set environment variables

# Encode the RouterParameters
ENCODED_PARAMS=$(cast abi-encode "constructor(address,address,address,address,address,address,address,address,address,address,address,address,address,address,address,address,address,address,address,address)" \
    "0x592B5C472aF554B4E33a1A0e9e02b04664dd788B" \
    "0x4200000000000000000000000000000000000006" \
    "0x0000000000000000000000000000000000000000" \
    "0x0000000000000000000000000000000000000000" \
    "0x0000000000000000000000000000000000000000" \
    "0x0000000000000000000000000000000000000000" \
    "0x0000000000000000000000000000000000000000" \
    "0x0000000000000000000000000000000000000000" \
    "0x0000000000000000000000000000000000000000" \
    "0x0000000000000000000000000000000000000000" \
    "0x0000000000000000000000000000000000000000" \
    "0x0000000000000000000000000000000000000000" \
    "0x0000000000000000000000000000000000000000" \
    "0x0000000000000000000000000000000000000000" \
    "0x0000000000000000000000000000000000000000" \
    "0x0000000000000000000000000000000000000000" \
    "0x31832f2a97Fd20664D76Cc421207669b55CE4BC0" \
    "0x04625B046C69577EfC40e6c0Bb83CDBAfab5a55F" \
    "0x10499d88Bd32AF443Fc936F67DE32bE1c8Bb374C" \
    "0x321f7Dfb9B2eA9131B8C17691CF6e01E5c149cA8")

# Verify the contract
forge verify-contract \
    0x652e53c6a4fe39b6b30426d9c96376a105c89a95 \
    contracts/UniversalRouter.sol:UniversalRouter \
    --chain-id 1135 \
    --num-of-optimizations 1000000 \
    --watch \
    --via-ir \
    --compiler-version "v0.8.17" \
    --evm-version paris \
    --rpc-url https://rpc.api.lisk.com \
    --verifier blockscout \
    --verifier-url 'https://blockscout.lisk.com/api/' \
    --constructor-args $ENCODED_PARAMS