import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { IUSDFactory } from "../../currencies/factories/iusd.factory";
import { USDCFactory } from "../../currencies/factories/usdc.factory";
import { OffTradeExchangeFactory } from "./off-trade-exchange.factory";
import { GovernanceFactory } from "../../governance/factories/governance.factory";
import { AuthRegistryFactory } from "../../auth_registry/factories/auth-registry.factory";

export class OffTradeProtocolFactory {
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

    static async createOffTradeExchange(
        protocol: any,
        offAssetAddress: string,
        onAssetAddress: string,
        companyAccounts: string[],
        settlementAccounts: string[],
        feecompanyAccountAddress: string,
        verbose?: boolean
    ): Promise<void> {
        const offTradeExchange = await OffTradeExchangeFactory.create(
            protocol.governance.address,
            protocol.authRegistry.address,
            offAssetAddress,
            onAssetAddress,
            companyAccounts,
            settlementAccounts,
            feecompanyAccountAddress
        );
        verbose && console.log("OffTradeExchange created");

        if (!protocol.offTradeExchanges) {
            protocol.offTradeExchanges = [];
        }

        protocol.offTradeExchanges.push(offTradeExchange);
    }
}
