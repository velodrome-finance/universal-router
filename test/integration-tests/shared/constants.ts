import hre from 'hardhat'
const { ethers } = hre

// Router Helpers
export const MAX_UINT = '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'
export const MAX_UINT128 = '0xffffffffffffffffffffffffffffffff'
export const MAX_UINT160 = '0xffffffffffffffffffffffffffffffffffffffff'
export const DEADLINE = 2000000000
export const CONTRACT_BALANCE = '0x8000000000000000000000000000000000000000000000000000000000000000'
export const OPEN_DELTA = 0
export const ALREADY_PAID = 0
export const ALICE_ADDRESS = '0xacd03d601e5bb1b275bb94076ff46ed9d753435a'
export const USDC_HOLDER = '0xcE8CcA271Ebc0533920C83d39F417ED6A0abB7D0'
export const WETH_HOLDER = '0x86Bb63148d17d445Ed5398ef26Aa05Bf76dD5b59'
export const DAI_HOLDER = '0x1eed63efba5f81d95bfe37d82c8e736b974f477b'
export const ETH_ADDRESS = ethers.constants.AddressZero
export const ZERO_ADDRESS = ethers.constants.AddressZero
export const ONE_PERCENT_BIPS = 100
export const MSG_SENDER: string = '0x0000000000000000000000000000000000000001'
export const ADDRESS_THIS: string = '0x0000000000000000000000000000000000000002'
export const SOURCE_MSG_SENDER: boolean = true
export const SOURCE_ROUTER: boolean = false
export const SLIPSTREAM_FLAG: boolean = false
export const V3_FLAG: boolean = true

// Constructor Params
export const PERMIT2_ADDRESS = '0x000000000022D473030F116dDEE9F6B43aC78BA3'
export const V2_FACTORY_MAINNET = '0x0c3c1c532F1e39EdF36BE9Fe0bE1410313E074Bf'
export const V3_FACTORY_MAINNET = '0x1F98431c8aD98523631AE4a59f267346ea31F984'
export const V3_INIT_CODE_HASH_MAINNET = '0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54'
export const V2_INIT_CODE_HASH_MAINNET = '0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f'
export const V3_NFT_POSITION_MANAGER_MAINNET = '0xC36442b4a4522E871399CD717aBDD847Ab11FE88'
export const V4_POSITION_DESCRIPTOR_ADDRESS = '0x0000000000000000000000000000000000000000' // TODO, deploy this in-line and use the proper address in posm's constructor
export const VELO_V2_FACTORY_MAINNET = '0xF1046053aa5682b4F9a81b5481394DA16BE5FF5a'
export const VELO_CL_FACTORY_MAINNET = '0xCc0bDDB707055e04e497aB22a59c2aF4391cd12F'
export const VELO_V2_IMPLEMENTATION_MAINNET = '0x95885Af5492195F0754bE71AD1545Fe81364E531'
export const VELO_CL_INIT_CODE_HASH_MAINNET = '0x3e17c3f6d9f39d14b65192404b8d70a2f921655d3f7f5e7481ab3fcf0756e8ea'
export const WETH = '0x4200000000000000000000000000000000000006'
