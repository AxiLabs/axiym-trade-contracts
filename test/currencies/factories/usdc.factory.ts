/* eslint-disable node/no-missing-import */
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ethers } from "hardhat";
import { USDC } from "../../../typechain";

export class USDCFactory {
    static async create(relay: SignerWithAddress): Promise<USDC> {
        const USDC = await ethers.getContractFactory("USDC", relay);
        const usdc = await USDC.deploy();
        await usdc.deployed();

        return usdc;
    }
}
