/* eslint-disable node/no-missing-import */
import {} from "@nomiclabs/hardhat-ethers/signers";
import { ethers } from "hardhat";
import { LinkedListTest } from "../../../typechain";

export class LinkedListTestFactory {
    static async create(): Promise<LinkedListTest> {
        const LinkedListTest = await ethers.getContractFactory("LinkedListTest");
        const linkedListTest = await LinkedListTest.deploy();
        await linkedListTest.deployed();

        return linkedListTest;
    }
}
