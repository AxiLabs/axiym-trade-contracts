/* eslint-disable node/no-missing-import */
import { ethers } from "hardhat";
import { OwnerStore } from "../../../typechain";

export class OwnerStoreFactory {
    static async create(owner: string): Promise<OwnerStore> {
        const OwnerStore = await ethers.getContractFactory("OwnerStore");
        const ownerStore = await OwnerStore.deploy(owner);
        await ownerStore.deployed();

        return ownerStore;
    }
}
