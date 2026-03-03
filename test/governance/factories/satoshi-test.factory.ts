import {} from "@nomiclabs/hardhat-ethers/signers";
import { ethers } from "hardhat";
import { SatoshiTest } from "../../../typechain";

export class SatoshiTestFactory {
    static async create(governanceAddress: string): Promise<SatoshiTest> {
        const SatoshiTest = await ethers.getContractFactory("SatoshiTest");
        const satoshiTest = await SatoshiTest.deploy(governanceAddress);
        await satoshiTest.deployed();

        return satoshiTest;
    }
}
