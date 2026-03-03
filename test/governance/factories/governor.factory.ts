/* eslint-disable node/no-missing-import */
import { ethers } from "hardhat";
import { BigNumber } from "ethers";
import { Governor } from "../../../typechain";

export class GovernorFactory {
    static async create(
        minDelay: BigNumber,
        proposer: string,
        executor: string
    ): Promise<Governor> {
        const Governor = await ethers.getContractFactory("Governor");

        const governor = await Governor.deploy(minDelay, proposer, executor);
        await governor.deployed();

        return governor;
    }

    static async attach(address: string): Promise<Governor> {
        const Governor = await ethers.getContractFactory("Governor");
        return Governor.attach(address);
    }
}
