require("@nomicfoundation/hardhat-toolbox");
require("hardhat-gas-reporter");
// require("@nomicfoundation/hardhat-network-helpers");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  networks: {
    mantle_testnet: {
      url: process.env.Mantle_Sepolia_Key,
      accounts: [process.env.PRIVATE1, process.env.PRIVATE2, process.env.PRIVATE3, process.env.PRIVATE4],
    },
    arb_sepolia: {
      url: process.env.ARB_Sepolia_Key,
      accounts: [process.env.PRIVATE1, process.env.PRIVATE2, process.env.PRIVATE3, process.env.PRIVATE4],
    },
    arc_testnet: {
      url: process.env.ARC_Testnet_Key,
      accounts: [process.env.PRIVATE1, process.env.PRIVATE2, process.env.PRIVATE3, process.env.PRIVATE4],
    },
    okx_testnet: {
      url: process.env.OKX_Testnet_Key,
      accounts: [process.env.PRIVATE1, process.env.PRIVATE2, process.env.PRIVATE3, process.env.PRIVATE4],
    },
    base_sepolia: {
      url: process.env.BASE_Sepolia_Key,
      accounts: [process.env.PRIVATE1, process.env.PRIVATE2, process.env.PRIVATE3, process.env.PRIVATE4],
    },
    mantle: {
      url: process.env.Mantle_Mainnet_Key,
      accounts: [process.env.PRIVATE1, process.env.PRIVATE2, process.env.PRIVATE3, process.env.PRIVATE4],
    },
    arb: {
      url: process.env.ARB_Mainnet_Key,
      accounts: [process.env.PRIVATE1, process.env.PRIVATE2, process.env.PRIVATE3, process.env.PRIVATE4],
    },
    okx: {
      url: process.env.OKX_Mainnet_Key,
      accounts: [process.env.PRIVATE1, process.env.PRIVATE2, process.env.PRIVATE3, process.env.PRIVATE4],
    },
    base: {
      url: process.env.BASE_Mainnet_Key,
      accounts: [process.env.PRIVATE1, process.env.PRIVATE2, process.env.PRIVATE3, process.env.PRIVATE4],
    },
  },
  solidity: {
    compilers: [{ version: "0.8.26" }],
    settings: {
      optimizer: {
        enabled: true,
        runs: 2000,
      },
    },
  },
  gasReporter: {
    enabled: true,
    currency: "ETH",
    // coinmarketcap: 'YOUR_API_KEY',
    outputFile: "gas-report.txt",
    noColors: true,
  },
  // etherscan: {
  //   apiKey:
  // },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  mocha: {
    timeout: 5000,
  },
};
