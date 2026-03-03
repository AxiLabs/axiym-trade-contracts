/* eslint-disable node/no-missing-import */
import {} from "@nomiclabs/hardhat-ethers/signers";
import { ethers } from "hardhat";
import { BigNumber } from "ethers";
import { MultiSig } from "../../../typechain";

export class MultiSigFactory {
    static async create(owners: string[], threshold: BigNumber): Promise<MultiSig> {
        const MultiSig = await ethers.getContractFactory("MultiSig");
        const multisig = await MultiSig.deploy(owners, threshold);
        await multisig.deployed();

        return multisig;
    }
}
