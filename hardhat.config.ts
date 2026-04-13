import * as dotenv from "dotenv";

import { task } from "hardhat/config";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";

require("@nomiclabs/hardhat-waffle");
require("hardhat-contract-sizer");
require("hardhat-gas-reporter");

dotenv.config();

const config: any = {
    solidity: {
        version: "0.8.24",
        gasReporter: {
            currency: "USD",
            gasPrice: 20,
            enabled: true,
        },
        settings: {
            evmVersion: "paris",
            optimizer: {
                enabled: true,
                runs: 200,
            },
        },
    },
    typechain: {
        outDir: "typechain",
        target: "ethers-v5",
    },
    contractSizer: {
        alphaSort: true,
        disambiguatePaths: false,
        runOnCompile: false,
        strict: true,
    },
    networks: {
        avalanche_fuji: {
            url: `${process.env.TEST_AVAX_RPC_URL}`,
        },
        avalanche: {
            url: `${process.env.PROD_AVAX_RPC_URL}`,
        },
        tron_shasta: {
            url: `${process.env.TEST_TRON_RPC_URL}`,
        },
        //sepolia_test: {
        //    url: `${process.env.SEPOLIA_TEST_URL}`,
        //    accounts: [
        //        `0x${process.env.SEPOLIA_TEST_DEPLOYER_PRIVATE_KEY}`,
        //        `0x${process.env.SEPOLIA_TEST_OWNER1_PRIVATE_KEY}`,
        //        `0x${process.env.SEPOLIA_TEST_OWNER2_PRIVATE_KEY}`,
        //    ],
        //},
        localhost: {
            url: "http://localhost:8545",
        },
    },
    etherscan: {
        apiKey: process.env.ETHERSCAN_API_KEY,
    },
};

export default config;
