/* eslint-disable node/no-missing-import */
import {} from "@nomiclabs/hardhat-ethers/signers";
import { ethers } from "hardhat";
import { AuthRegistry } from "../../../typechain";

export class AuthRegistryFactory {
    static async create(governance: string): Promise<AuthRegistry> {
        const AuthRegistry = await ethers.getContractFactory("AuthRegistry");
        const authRegistry = await AuthRegistry.deploy(governance);
        await authRegistry.deployed();

        return authRegistry;
    }
}
