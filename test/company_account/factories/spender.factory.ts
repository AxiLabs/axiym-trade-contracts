/* eslint-disable node/no-missing-import */
import { ethers } from "hardhat";
import { Spender } from "../../../typechain";

export class SpenderFactory {
    static async create(liquidityAsset: string): Promise<Spender> {
        const SpenderFactory = await ethers.getContractFactory("Spender");
        const spender = await SpenderFactory.deploy(liquidityAsset);
        await spender.deployed();

        return spender as Spender;
    }
}
