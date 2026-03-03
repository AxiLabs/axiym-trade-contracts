/* eslint-disable node/no-missing-import */
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { CompanyAccount } from "../../../typechain";
import { randomBytes } from "crypto";

export class CompanyAccountFactory {
    static async create(
        superAdmin: SignerWithAddress,
        governance: string,
        authRegistry: string,
        signer: string
    ): Promise<CompanyAccount> {
        const CompanyAccountFactory = await ethers.getContractFactory(
            "CompanyAccount",
            superAdmin
        );
        const companyAccount = await CompanyAccountFactory.deploy(
            governance,
            authRegistry,
            signer
        );
        await companyAccount.deployed();

        return companyAccount as CompanyAccount;
    }

    static async setup(
        companyAccount: CompanyAccount,
        governor: SignerWithAddress,
        authorizer: SignerWithAddress,
        signer: SignerWithAddress,
        liquidityAssets: string[],
        receivers: string[],
        spenders: string[][]
    ): Promise<void> {
        for (let i = 0; i < liquidityAssets.length; i++) {
            const asset = liquidityAssets[i];
            for (const spender of spenders[i]) {
                await companyAccount.connect(governor).addSpender(asset, spender);
            }
        }

        // Add receivers (onlyAuthorizer + signer signature)
        for (const receiver of receivers) {
            const nonce = `0x${randomBytes(16).toString("hex")}`;

            const messageHash = ethers.utils.solidityKeccak256(
                ["address", "address", "uint256", "bytes16"],
                [ethers.constants.AddressZero, receiver, 0, nonce]
            );
            const signature = await signer.signMessage(
                ethers.utils.arrayify(messageHash)
            );

            await companyAccount
                .connect(authorizer)
                .addReceiver(receiver, nonce, signature);
        }
    }
}
