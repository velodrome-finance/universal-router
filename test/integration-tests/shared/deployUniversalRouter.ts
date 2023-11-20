import hre from 'hardhat'
const { ethers } = hre
import { UniversalRouter, Permit2 } from '../../../typechain'
import {
  V2_FACTORY_MAINNET,
  V3_FACTORY_MAINNET,
  POOL_IMPLEMENTATION,
  ROUTER_REWARDS_DISTRIBUTOR,
  LOOKSRARE_REWARDS_DISTRIBUTOR,
  LOOKSRARE_TOKEN,
  CL_POOL_IMPLEMENTATION,
} from './constants'

export async function deployRouter(
  permit2: Permit2,
  mockLooksRareRewardsDistributor?: string,
  mockLooksRareToken?: string,
  mockReentrantProtocol?: string
): Promise<UniversalRouter> {
  const routerParameters = {
    permit2: permit2.address,
    weth9: '0x4200000000000000000000000000000000000006',
    seaportV1_5: '0x00000000000000ADc04C56Bf30aC9d3c0aAF14dC',
    seaportV1_4: '0x00000000000001ad428e4906aE43D8F9852d0dD6',
    openseaConduit: '0x1E0049783F008A0085193E00003D00cd54003c71',
    nftxZap: mockReentrantProtocol ?? '0x941A6d105802CCCaa06DE58a13a6F49ebDCD481C', // unsupported until below
    x2y2: '0x0000000000000000000000000000000000000000',
    foundation: '0x0000000000000000000000000000000000000000',
    sudoswap: '0x0000000000000000000000000000000000000000',
    elementMarket: '0x0000000000000000000000000000000000000000',
    nft20Zap: '0x0000000000000000000000000000000000000000',
    cryptopunks: '0x0000000000000000000000000000000000000000',
    looksRareV2: '0x0000000000000000000000000000000000000000',
    routerRewardsDistributor: ROUTER_REWARDS_DISTRIBUTOR,
    looksRareRewardsDistributor: mockLooksRareRewardsDistributor ?? LOOKSRARE_REWARDS_DISTRIBUTOR,
    looksRareToken: mockLooksRareToken ?? LOOKSRARE_TOKEN, // unsupported from above
    v2Factory: V2_FACTORY_MAINNET,
    v3Factory: V3_FACTORY_MAINNET,
    v2Implementation: POOL_IMPLEMENTATION,
    clImplementation: CL_POOL_IMPLEMENTATION,
  }

  const routerFactory = await ethers.getContractFactory('UniversalRouter')
  const router = (await routerFactory.deploy(routerParameters)) as unknown as UniversalRouter
  return router
}

export default deployRouter

export async function deployPermit2(): Promise<Permit2> {
  const permit2Factory = await ethers.getContractFactory('Permit2')
  const permit2 = (await permit2Factory.deploy()) as unknown as Permit2
  return permit2
}

export async function deployRouterAndPermit2(
  mockLooksRareRewardsDistributor?: string,
  mockLooksRareToken?: string
): Promise<[UniversalRouter, Permit2]> {
  const permit2 = await deployPermit2()
  const router = await deployRouter(permit2, mockLooksRareRewardsDistributor, mockLooksRareToken)
  return [router, permit2]
}
