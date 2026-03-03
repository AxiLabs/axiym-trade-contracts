/* eslint-disable node/no-missing-import */
import { ethers } from "hardhat";
import { OnTradeExchange } from "../../../typechain";

export class OnTradeExchangeFactory {
    static async create(
        governance: string,
        owner: string,
        authRegistryAddress: string,
        offAssetAddress: string,
        onAssetAddress: string,
        companyAccounts: string[] = [],
        feecompanyAccountAddress: string
    ): Promise<OnTradeExchange> {
        const OnTradeExchange = await ethers.getContractFactory("OnTradeExchange");

        const onTradeExchange = await OnTradeExchange.deploy(
            governance,
            owner,
            authRegistryAddress,
            offAssetAddress,
            onAssetAddress,
            companyAccounts,
            feecompanyAccountAddress
        );
        await onTradeExchange.deployed();

        return onTradeExchange;
    }

    static async attach(address: string): Promise<OnTradeExchange> {
        const OnTradeExchange = await ethers.getContractFactory("OnTradeExchange");
        return OnTradeExchange.attach(address);
    }
}
