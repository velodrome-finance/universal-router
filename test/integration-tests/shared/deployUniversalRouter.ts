import hre from 'hardhat'
const { ethers } = hre
import { UniversalRouter } from '../../../typechain'
import {
  V2_FACTORY_MAINNET,
  V3_FACTORY_MAINNET,
  V2_INIT_CODE_HASH_MAINNET,
  V3_INIT_CODE_HASH_MAINNET,
  PERMIT2_ADDRESS,
  VELO_V2_FACTORY_MAINNET,
  VELO_CL_FACTORY_MAINNET,
  VELO_V2_INIT_CODE_HASH_MAINNET,
  VELO_CL_INIT_CODE_HASH_MAINNET,
  ZERO_ADDRESS,
} from './constants'
import { deployV4PoolManager } from './v4Helpers'

export async function deployRouter(
  owner?: string,
  v4PoolManager?: string,
  mockReentrantWETH?: string
): Promise<UniversalRouter> {
  let poolManager: string

  if (v4PoolManager) {
    poolManager = v4PoolManager
  } else if (owner !== undefined) {
    poolManager = (await deployV4PoolManager(owner)).address
  } else {
    throw new Error('Either v4PoolManager must be set or owner must be provided')
  }
  const routerParameters = {
    permit2: PERMIT2_ADDRESS,
    weth9: mockReentrantWETH ?? '0x4200000000000000000000000000000000000006',
    v2Factory: V2_FACTORY_MAINNET,
    v3Factory: V3_FACTORY_MAINNET,
    pairInitCodeHash: V2_INIT_CODE_HASH_MAINNET,
    poolInitCodeHash: V3_INIT_CODE_HASH_MAINNET,
    v4PoolManager: poolManager,
    veloV2Factory: VELO_V2_FACTORY_MAINNET,
    veloCLFactory: VELO_CL_FACTORY_MAINNET,
    veloV2InitCodeHash: VELO_V2_INIT_CODE_HASH_MAINNET,
    veloCLInitCodeHash: VELO_CL_INIT_CODE_HASH_MAINNET,
    rootHLMessageModule: ZERO_ADDRESS,
  }

  const routerFactory = await ethers.getContractFactory('UniversalRouter')
  const router = (await routerFactory.deploy(routerParameters)) as unknown as UniversalRouter
  return router
}

export default deployRouter
