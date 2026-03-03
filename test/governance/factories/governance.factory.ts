/* eslint-disable node/no-missing-import */
import {} from "@nomiclabs/hardhat-ethers/signers";
import { ethers } from "hardhat";
import { Governance } from "../../../typechain";

export class GovernanceFactory {
    static async create(
        superAdmin: string,
        governor: string,
        manager: string,
        authorizer: string
    ): Promise<Governance> {
        const Governance = await ethers.getContractFactory("Governance");
        const governance = await Governance.deploy(
            superAdmin,
            governor,
            manager,
            authorizer
        );
        await governance.deployed();

        return governance;
    }
}
