import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { IUSDFactory } from "../../currencies/factories/iusd.factory";
import { USDCFactory } from "../../currencies/factories/usdc.factory";
import { OnTradeExchangeFactory } from "./on-trade-exchange.factory";
import { SegregatedTreasuryFactory } from "./segregated-treasury.factory";
import { GovernanceFactory } from "../../governance/factories/governance.factory";
import { AuthRegistryFactory } from "../../auth_registry/factories/auth-registry.factory";

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

        // --- create governance ---
        protocol.governance = await GovernanceFactory.create(
            superAdmin.address,
            governor.address,
            manager.address,
            authorizer.address
        );
        verbose && console.log("governance created");

        // -- create registries
        protocol.authRegistry = await AuthRegistryFactory.create(
            protocol.governance.address
        );
        verbose && console.log("auth registry created");

        // -- add relay address to auth registry
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

    static async createOnRamp(
        protocol: any,
        ownerAddress: string,
        offAssetAddress: string,
        onAssetAddress: string,
        companyAccounts: string[],
        feecompanyAccountAddress: string,
        verbose?: boolean
    ): Promise<void> {
        const onTradeExchange = await OnTradeExchangeFactory.create(
            protocol.governance.address,
            ownerAddress,
            protocol.authRegistry.address,
            offAssetAddress,
            onAssetAddress,
            companyAccounts,
            feecompanyAccountAddress
        );
        verbose && console.log("OnTradeExchange created");

        if (!protocol.onTradeExchanges) {
            protocol.onTradeExchanges = [];
        }

        if (!protocol.segregatedTreasuries) {
            protocol.segregatedTreasuries = [];
        }

        protocol.onTradeExchanges.push(onTradeExchange);

        const segregatedTreasuryAddress = await onTradeExchange.segregatedTreasury();

        protocol.segregatedTreasuries.push(
            await SegregatedTreasuryFactory.attach(segregatedTreasuryAddress)
        );
    }
}
