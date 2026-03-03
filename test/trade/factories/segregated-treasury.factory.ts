/* eslint-disable node/no-missing-import */
import { ethers } from "hardhat";
import { SegregatedTreasury } from "../../../typechain";

export class SegregatedTreasuryFactory {
    static async attach(address: string): Promise<SegregatedTreasury> {
        const SegregatedTreasury = await ethers.getContractFactory(
            "SegregatedTreasury"
        );
        return SegregatedTreasury.attach(address);
    }
}
