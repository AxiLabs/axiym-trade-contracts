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
            accounts: [
                `0x${process.env.TEST_AVAX_DEPLOYER_PRIVATE_KEY}`,
                `0x${process.env.TEST_AVAX_SUPERADMIN_PRIVATE_KEY}`,
                `0x${process.env.TEST_AVAX_GOVERNOR_PRIVATE_KEY}`,
                `0x${process.env.TEST_AVAX_MANAGER_PRIVATE_KEY}`,
                `0x${process.env.TEST_AVAX_AUTHORIZER_PRIVATE_KEY}`,
                `0x${process.env.TEST_AVAX_SIGNER1_PRIVATE_KEY}`,
                `0x${process.env.TEST_AVAX_SIGNER2_PRIVATE_KEY}`,
                `0x${process.env.TEST_AVAX_SIGNER3_PRIVATE_KEY}`,
            ],
        },
        avalanche: {
            url: `${process.env.PROD_AVAX_RPC_URL}`,
            accounts: [
                `0x${process.env.PROD_DEPLOYER_PRIVATE_KEY}`,
                `0x${process.env.PROD_GOVERNOR_PRIVATE_KEY}`,
                `0x${process.env.PROD_MANAGER_PRIVATE_KEY}`,
            ],
        },
        tron_shasta: {
            url: `${process.env.TEST_TRON_RPC_URL}`,
            accounts: [
                `0x${process.env.TEST_TRON_DEPLOYER_PRIVATE_KEY}`,
                `0x${process.env.TEST_TRON_SUPERADMIN_PRIVATE_KEY}`,
                `0x${process.env.TEST_TRON_GOVERNOR_PRIVATE_KEY}`,
                `0x${process.env.TEST_TRON_MANAGER_PRIVATE_KEY}`,
                `0x${process.env.TEST_TRON_SIGNER1_PRIVATE_KEY}`,
                `0x${process.env.TEST_TRON_SIGNER2_PRIVATE_KEY}`,
                `0x${process.env.TEST_TRON_SIGNER3_PRIVATE_KEY}`,
            ],
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
            //accounts: [
            //  `0x${process.env.STAGING_DEPLOYER_PRIVATE_KEY}`,
            //  `0x${process.env.STAGING_ADMIN_PRIVATE_KEY}`,
            //  `0x${process.env.STAGING_GOVERNOR_PRIVATE_KEY}`,
            //  `0x${process.env.STAGING_DEVELOPER_PRIVATE_KEY}`,
            //  `0x${process.env.STAGING_LENDER_PRIVATE_KEY}`,
            //  `0x${process.env.STAGING_LOAN_MANAGER_PRIVATE_KEY}`,
            //  `0x${process.env.STAGING_SUPERADMIN_PRIVATE_KEY}`,
            //  `0x${process.env.STAGING_BORROWER_PRIVATE_KEY}`,
            //],
        },
    },
    etherscan: {
        apiKey: process.env.ETHERSCAN_API_KEY,
    },
};

export default config;
