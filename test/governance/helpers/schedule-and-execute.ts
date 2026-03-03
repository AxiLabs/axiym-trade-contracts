import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Governor } from "../../../typechain";
import { ethers } from "hardhat";

export async function scheduleAndExecute(
    governor: Governor,
    proposer: SignerWithAddress,
    executor: SignerWithAddress,
    target: string,
    calldata: string,
    salt?: string
) {
    const finalSalt = salt ?? ethers.utils.hexlify(ethers.utils.randomBytes(32));

    // compute operation id exactly like contract
    const id = await governor.hashOperation(target, calldata, finalSalt);

    // schedule
    await governor.connect(proposer).schedule(target, calldata, finalSalt);

    // fetch timestamp from contract
    const ts = await governor.getTimestamp(id);
    const now = (await ethers.provider.getBlock("latest")).timestamp;

    const delay = ts.toNumber() - now;

    if (delay > 0) {
        await ethers.provider.send("evm_increaseTime", [delay + 10]);
        await ethers.provider.send("evm_mine", []);
    }

    // sanity check ready
    const ready = await governor.isOperationReady(id);
    if (!ready) throw new Error("Operation not ready");

    // execute
    await governor.connect(executor).execute(target, calldata, finalSalt);

    return id;
}
