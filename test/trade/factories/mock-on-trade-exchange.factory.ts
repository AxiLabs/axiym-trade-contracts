/* eslint-disable node/no-missing-import */
import { ethers } from "hardhat";
import { MockOnTradeExchange } from "../../../typechain";

export class MockOnTradeExchangeFactory {
    static async create(offAssetAddress: string): Promise<MockOnTradeExchange> {
        const MockOnTradeExchange = await ethers.getContractFactory(
            "MockOnTradeExchange"
        );
        const mockOnTradeExchange = await MockOnTradeExchange.deploy(
            offAssetAddress
        );
        await mockOnTradeExchange.deployed();

        return mockOnTradeExchange as MockOnTradeExchange;
    }

    static async attach(address: string): Promise<MockOnTradeExchange> {
        const MockOnTradeExchange = await ethers.getContractFactory(
            "MockOnTradeExchange"
        );
        return MockOnTradeExchange.attach(address) as MockOnTradeExchange;
    }
}
