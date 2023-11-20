import JSBI from 'jsbi'
import bn from 'bignumber.js'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { BigintIsh, CurrencyAmount, Token } from '@uniswap/sdk-core'
import { Pair } from '@uniswap/v2-sdk'
import { getV2PoolReserves } from './mainnetForkHelpers'
import { BigNumber, BigNumberish } from 'ethers'
import { DEFAULT_TICK_SPACING } from './constants'

bn.config({ EXPONENTIAL_AT: 999999, DECIMAL_PLACES: 40 })

export function encodePriceSqrt(reserve1: BigNumberish, reserve0: BigNumberish): BigNumber {
  return BigNumber.from(
    new bn(reserve1.toString())
      .div(reserve0.toString())
      .sqrt()
      .multipliedBy(new bn(2).pow(96))
      .integerValue(3)
      .toString()
  )
}

const tickSpacing = DEFAULT_TICK_SPACING
const sqrtRatioX96 = encodePriceSqrt(1, 1)
const liquidity = 1_000_000

// v2
export const makePair = async (alice: SignerWithAddress, token0: Token, token1: Token, stable: boolean = false) => {
  const reserves = await getV2PoolReserves(alice, token0, token1, stable)
  let reserve0: CurrencyAmount<Token> = CurrencyAmount.fromRawAmount(token0, JSBI.BigInt(reserves.reserve0))
  let reserve1: CurrencyAmount<Token> = CurrencyAmount.fromRawAmount(token1, JSBI.BigInt(reserves.reserve1))

  return new Pair(reserve0, reserve1)
}

const TICK_SPACING_SIZE = 3

// v3
export function encodePath(path: string[], tickSpacings: number[]): string {
  if (path.length != tickSpacings.length + 1) {
    throw new Error('path/fee lengths do not match')
  }

  let encoded = '0x'
  for (let i = 0; i < tickSpacings.length; i++) {
    // 20 byte encoding of the address
    encoded += path[i].slice(2)
    // 3 byte encoding of the fee
    encoded += tickSpacings[i].toString(16).padStart(2 * TICK_SPACING_SIZE, '0')
  }
  // encode the final token
  encoded += path[path.length - 1].slice(2)

  return encoded.toLowerCase()
}

export function expandTo18Decimals(n: number): BigintIsh {
  return JSBI.BigInt(BigNumber.from(n).mul(BigNumber.from(10).pow(18)).toString())
}

export const getMinTick = (tickSpacing: number) => Math.ceil(-887272 / tickSpacing) * tickSpacing
export const getMaxTick = (tickSpacing: number) => Math.floor(887272 / tickSpacing) * tickSpacing
