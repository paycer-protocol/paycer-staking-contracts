import { HardhatUserConfig } from "hardhat/types";
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-etherscan";
import "@openzeppelin/hardhat-upgrades";
import "hardhat-typechain";
import "hardhat-deploy";
import "hardhat-contract-sizer";
import "solidity-coverage";
import { config as dotEnvConfig } from "dotenv";

dotEnvConfig();

const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "";
const mnemonic = process.env.WORKER_SEED || "";

const defaultConfig = {
  accounts: { mnemonic },
}

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.3",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  defaultNetwork: "hardhat",
  networks: {
    localnetwork: {
      url: "http://127.0.0.1:8545",
      chainId: 1337,
      ...defaultConfig
    },
    matic: {
      url: 'https://polygon-mainnet.g.alchemy.com/v2/cANvWkbPj4YVMamvJ6oumU17g3aMgpkB',
      chainId: 137,
      gas: 2100000 * 6, 
      gasPrice: 8000000000 * 6,
      ...defaultConfig
    },
    mumbai: {
      url: 'https://polygon-mumbai.g.alchemy.com/v2/rrlMyCQOsW8fj4N-jrRFUc8HMemEVpUG',
      chainId: 80001,
      ...defaultConfig
    },
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY,
  },
  namedAccounts: {
    deployer: 0,
    testAccount: 1,
    rewardTreasury: 2,
    
  },
  mocha: {
    timeout: "1000000s"
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: true,
    disambiguatePaths: false,
  }
};

export default config;
