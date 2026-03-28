import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { IUSDFactory } from "../../currencies/factories/iusd.factory";
import { USDCFactory } from "../../currencies/factories/usdc.factory";
import { OnTradeExchangeFactory } from "./on-trade-exchange.factory";
import { SegregatedTreasuryFactory } from "./segregated-treasury.factory";
import { GovernanceFactory } from "../../governance/factories/governance.factory";
import { AuthRegistryFactory } from "../../auth_registry/factories/auth-registry.factory";
import { ethers } from "hardhat";

export class OnTradeProtocolFactory {
    static async create(
        superAdmin: SignerWithAddress,
        governor: SignerWithAddress,
        manager: SignerWithAddress,
        authorizer: SignerWithAddress,
        relayAddress: string,
        verbose = true
    ): Promise<any> {
        const protocol: any = {};
        protocol.superAdmin = superAdmin;
        protocol.governor = governor;
        protocol.manager = manager;
        protocol.authorizer = authorizer;

        protocol.governance = await GovernanceFactory.create(
            superAdmin.address,
            governor.address,
            manager.address,
            authorizer.address
        );
        verbose && console.log("governance created");

        protocol.authRegistry = await AuthRegistryFactory.create(
            protocol.governance.address
        );
        verbose && console.log("auth registry created");

        await protocol.authRegistry.connect(governor).addAuthAddress(relayAddress);
        verbose && console.log("relay addresses added to auth registry");

        return protocol;
    }

    static async addIUSD(protocol: any, verbose = false): Promise<void> {
        protocol.IUSD = await IUSDFactory.create(protocol.authRegistry.address);
        verbose && console.log("IUSD created");
    }

    static async addUSDC(
        protocol: any,
        relay: SignerWithAddress,
        verbose = false
    ): Promise<void> {
        protocol.USDC = await USDCFactory.create(relay);
        verbose && console.log("USDC created");
    }

    /// @notice Deploys TetherToken (exact Tron USDT replica) and mints initialSupply to relay
    static async addTetherToken(
        protocol: any,
        relay: SignerWithAddress,
        initialSupply: any,
        verbose = false
    ): Promise<void> {
        const factory = await ethers.getContractFactory("TetherToken", relay);
        protocol.USDT = await factory.deploy(initialSupply, "Tether USD", "USDT", 6);
        await protocol.USDT.deployed();
        verbose &&
            console.log("TetherToken created, supply:", initialSupply.toString());
    }

    static async createOnRamp(
        protocol: any,
        ownerAddress: string,
        offAssetAddress: string,
        onAssetAddress: string,
        companyAccounts: string[],
        feeCompanyAccountAddress: string,
        verbose?: boolean
    ): Promise<void> {
        const onTradeExchange = await OnTradeExchangeFactory.create(
            protocol.governance.address,
            ownerAddress,
            protocol.authRegistry.address,
            offAssetAddress,
            onAssetAddress
        );
        verbose && console.log("OnTradeExchange created");

        if (feeCompanyAccountAddress !== ethers.constants.AddressZero) {
            await onTradeExchange
                .connect(protocol.governor)
                .setFeeCompanyAccount(feeCompanyAccountAddress);
            verbose && console.log("fee company account set");
        }

        for (const companyAccount of companyAccounts) {
            await onTradeExchange
                .connect(protocol.authorizer)
                .addCompanyAccount(companyAccount);
            verbose && console.log(`company account ${companyAccount} added`);
        }

        if (!protocol.onTradeExchanges) protocol.onTradeExchanges = [];
        if (!protocol.segregatedTreasuries) protocol.segregatedTreasuries = [];

        protocol.onTradeExchanges.push(onTradeExchange);

        const segregatedTreasuryAddress = await onTradeExchange.segregatedTreasury();
        protocol.segregatedTreasuries.push(
            await SegregatedTreasuryFactory.attach(segregatedTreasuryAddress)
        );
    }
}
