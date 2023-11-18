import 'hardhat-typechain'
import '@nomiclabs/hardhat-ethers'
import '@nomicfoundation/hardhat-chai-matchers'
import '@nomicfoundation/hardhat-foundry'
import dotenv from 'dotenv'
dotenv.config()

const DEFAULT_COMPILER_SETTINGS = {
  version: '0.8.17',
  settings: {
    viaIR: true,
    evmVersion: 'istanbul',
    optimizer: {
      enabled: true,
      runs: 200, // TODO: change back 1_000_000
    },
    metadata: {
      bytecodeHash: 'none',
    },
  },
}

export default {
  paths: {
    sources: './contracts',
  },
  networks: {
    hardhat: {
      allowUnlimitedContractSize: false,
      chainId: 10,
      forking: {
        url: `${process.env.RPC_URL}`,
        blockNumber: 111000000,
      },
    },
    mainnet: {
      url: `${process.env.RPC_URL}`,
    },
    ropsten: {
      url: `${process.env.RPC_URL}`,
    },
    rinkeby: {
      url: `${process.env.RPC_URL}`,
    },
    goerli: {
      url: `${process.env.RPC_URL}`,
    },
    kovan: {
      url: `${process.env.RPC_URL}`,
    },
    arbitrumRinkeby: {
      url: `https://rinkeby.arbitrum.io/rpc`,
    },
    arbitrum: {
      url: `https://arb1.arbitrum.io/rpc`,
    },
    optimismKovan: {
      url: `https://kovan.optimism.io`,
    },
    optimism: {
      url: `https://mainnet.optimism.io`,
    },
    polygon: {
      url: `${process.env.RPC_URL}`,
    },
    base: {
      url: `${process.env.RPC_URL}`,
    },
    baseGoerli: {
      url: `https://goerli.base.org`,
    },
  },
  namedAccounts: {
    deployer: 0,
  },
  solidity: {
    compilers: [DEFAULT_COMPILER_SETTINGS],
  },
  mocha: {
    timeout: 60000,
  },
}
