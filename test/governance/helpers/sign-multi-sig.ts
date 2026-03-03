import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ethers } from "hardhat";
import { Governance, Governor } from "../../../typechain";

export async function signMultiSigTx(
    owners: SignerWithAddress[],
    to: string,
    data: string,
    nonce: string,
    multisigAddress: string
): Promise<string> {
    const chainId = (await ethers.provider.getNetwork()).chainId;

    // 1. Calculate the inner keccak256(data) first
    const dataHash = ethers.utils.solidityKeccak256(["bytes"], [data]);

    const messageHash = ethers.utils.arrayify(
        ethers.utils.solidityKeccak256(
            ["uint256", "address", "address", "bytes32", "bytes32"],
            [
                chainId, // chain ID
                multisigAddress, // multi sig address
                to, // address to send tx to
                dataHash,
                nonce,
            ]
        )
    );

    // 2. Map through owners and sign
    const signatures = await Promise.all(
        owners.map((owner) => owner.signMessage(messageHash))
    );

    // 3. Concatenate into a single hex string
    return "0x" + signatures.map((sig) => sig.slice(2)).join("");
}
