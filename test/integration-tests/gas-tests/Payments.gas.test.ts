import type { Contract } from '@ethersproject/contracts'
import { UniversalRouter } from '../../../typechain'
import { abi as TOKEN_ABI } from '../../../artifacts/solmate/src/tokens/ERC20.sol/ERC20.json'
import { resetFork, DAI, WETH } from '../shared/mainnetForkHelpers'
import { ALICE_ADDRESS, DEADLINE, ETH_ADDRESS, ONE_PERCENT_BIPS, WETH_HOLDER, DAI_HOLDER } from '../shared/constants'
import { expandTo18DecimalsBN } from '../shared/helpers'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import hre from 'hardhat'
import deployUniversalRouter from '../shared/deployUniversalRouter'
import { RoutePlanner, CommandType } from '../shared/planner'
import snapshotGasCost from '@uniswap/snapshot-gas-cost'
const { ethers } = hre
import WETH_ABI from '../../../artifacts/@uniswap/v4-periphery/src/interfaces/external/IWETH9.sol/IWETH9.json'
import { BigNumber } from 'ethers'
import { ADDRESS_THIS } from '@uniswap/router-sdk'

describe('Payments Gas Tests', () => {
  let alice: SignerWithAddress
  let bob: SignerWithAddress
  let router: UniversalRouter
  let daiContract: Contract
  let wethContract: Contract
  let planner: RoutePlanner

  beforeEach(async () => {
    await resetFork()
    await hre.network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [ALICE_ADDRESS],
    })
    await hre.network.provider.request({
      method: 'hardhat_setBalance',
      params: [DAI_HOLDER, '0xf00000000000000'],
    })
    alice = await ethers.getSigner(ALICE_ADDRESS)
    bob = (await ethers.getSigners())[1]
    daiContract = new ethers.Contract(DAI.address, TOKEN_ABI, alice)
    wethContract = new ethers.Contract(WETH.address, new ethers.utils.Interface(WETH_ABI.abi), alice)
    router = (await deployUniversalRouter(alice.address)).connect(alice) as UniversalRouter
    planner = new RoutePlanner()
    // seed alice with tokens
    const daiHolder = await ethers.getImpersonatedSigner(DAI_HOLDER)
    const wethHolder = await ethers.getImpersonatedSigner(WETH_HOLDER)
    await daiContract.connect(daiHolder).transfer(alice.address, expandTo18DecimalsBN(100000))
    await wethContract.connect(wethHolder).transfer(alice.address, expandTo18DecimalsBN(100))
  })

  describe('Individual Command Tests', () => {
    // These tests are not representative of actual situations - but allow us to monitor the cost of the commands

    it('gas: TRANSFER with ERC20', async () => {
      // seed router with tokens
      const amountOfDAI: BigNumber = expandTo18DecimalsBN(3)
      await daiContract.transfer(router.address, amountOfDAI)

      planner.addCommand(CommandType.TRANSFER, [DAI.address, ALICE_ADDRESS, amountOfDAI])
      const { commands, inputs } = planner

      await snapshotGasCost(router['execute(bytes,bytes[],uint256)'](commands, inputs, DEADLINE))
    })

    it('gas: UNWRAP_WETH', async () => {
      // seed router with WETH
      const amount: BigNumber = expandTo18DecimalsBN(3)
      await wethContract.transfer(router.address, amount)

      planner.addCommand(CommandType.UNWRAP_WETH, [alice.address, amount])
      const { commands, inputs } = planner

      await snapshotGasCost(router['execute(bytes,bytes[],uint256)'](commands, inputs, DEADLINE))
    })

    it('gas: TRANSFER with ETH', async () => {
      // seed router with WETH and unwrap it into the router
      const amount: BigNumber = expandTo18DecimalsBN(3)
      await wethContract.transfer(router.address, amount)
      planner.addCommand(CommandType.UNWRAP_WETH, [ADDRESS_THIS, amount])
      let { commands, inputs } = planner
      await router['execute(bytes,bytes[],uint256)'](commands, inputs, DEADLINE)

      // now do a transfer of those ETH as the command
      planner = new RoutePlanner()
      planner.addCommand(CommandType.TRANSFER, [ETH_ADDRESS, ALICE_ADDRESS, amount])
      ;({ commands, inputs } = planner)

      await snapshotGasCost(router['execute(bytes,bytes[],uint256)'](commands, inputs, DEADLINE))
    })

    it('gas: SWEEP with ERC20', async () => {
      // seed router with tokens
      const amountOfDAI: BigNumber = expandTo18DecimalsBN(3)
      await daiContract.transfer(router.address, amountOfDAI)

      planner.addCommand(CommandType.SWEEP, [DAI.address, ALICE_ADDRESS, amountOfDAI])
      const { commands, inputs } = planner

      await snapshotGasCost(router['execute(bytes,bytes[],uint256)'](commands, inputs, DEADLINE))
    })

    it('gas: WRAP_ETH', async () => {
      // seed router with WETH and unwrap it into the router
      const amount: BigNumber = expandTo18DecimalsBN(3)
      await wethContract.transfer(router.address, amount)
      planner.addCommand(CommandType.UNWRAP_WETH, [ADDRESS_THIS, amount])
      let { commands, inputs } = planner
      await router['execute(bytes,bytes[],uint256)'](commands, inputs, DEADLINE)

      // now wrap those ETH as the command
      planner = new RoutePlanner()
      planner.addCommand(CommandType.WRAP_ETH, [ALICE_ADDRESS, amount])
      ;({ commands, inputs } = planner)

      await snapshotGasCost(router['execute(bytes,bytes[],uint256)'](commands, inputs, DEADLINE))
    })

    it('gas: UNWRAP_WETH_WITH_FEE', async () => {
      // seed router with WETH
      const amount: BigNumber = expandTo18DecimalsBN(3)
      await wethContract.transfer(router.address, amount)

      planner.addCommand(CommandType.UNWRAP_WETH, [alice.address, amount])
      planner.addCommand(CommandType.PAY_PORTION, [ETH_ADDRESS, bob.address, 50])
      planner.addCommand(CommandType.SWEEP, [ETH_ADDRESS, alice.address, 0])
      const { commands, inputs } = planner

      await snapshotGasCost(router['execute(bytes,bytes[],uint256)'](commands, inputs, DEADLINE))
    })

    it('gas: SWEEP_WITH_FEE', async () => {
      // seed router with tokens
      const amountOfDAI: BigNumber = expandTo18DecimalsBN(3)
      await daiContract.transfer(router.address, amountOfDAI)

      planner.addCommand(CommandType.PAY_PORTION, [DAI.address, bob.address, ONE_PERCENT_BIPS])
      planner.addCommand(CommandType.SWEEP, [DAI.address, alice.address, 1])
      const { commands, inputs } = planner

      await snapshotGasCost(router['execute(bytes,bytes[],uint256)'](commands, inputs, DEADLINE))
    })
  })
})
