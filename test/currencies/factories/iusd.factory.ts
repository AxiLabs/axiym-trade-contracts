/* eslint-disable node/no-missing-import */
import { ethers } from "hardhat";
import { IUSD } from "../../../typechain";

export class IUSDFactory {
    static async create(authRegistry: string): Promise<IUSD> {
        const IUSD = await ethers.getContractFactory("IUSD");
        const iUSD = await IUSD.deploy(authRegistry);
        await iUSD.deployed();

        return iUSD;
    }
}
