/* eslint-disable node/no-missing-import */
import { ethers } from "hardhat";
import { OffTradeExchange } from "../../../typechain";

export class OffTradeExchangeFactory {
    static async create(
        governance: string,
        authRegistryAddress: string,
        offAssetAddress: string,
        onAssetAddress: string,
        companyAccounts: string[] = [],
        settlementAccounts: string[] = [],
        feecompanyAccountAddress: string
    ): Promise<OffTradeExchange> {
        const OffTradeExchange = await ethers.getContractFactory("OffTradeExchange");

        const offTradeExchange = await OffTradeExchange.deploy(
            governance,
            authRegistryAddress,
            offAssetAddress,
            onAssetAddress,
            companyAccounts,
            settlementAccounts,
            feecompanyAccountAddress
        );
        await offTradeExchange.deployed();

        return offTradeExchange;
    }

    static async attach(address: string): Promise<OffTradeExchange> {
        const OffTradeExchange = await ethers.getContractFactory("OffTradeExchange");
        return OffTradeExchange.attach(address);
    }
}
