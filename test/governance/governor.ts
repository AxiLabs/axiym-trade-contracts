import { expect } from "chai";
import { ethers } from "hardhat";
import { Governor, OwnerStore, USDC } from "../../typechain";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { OwnerStoreFactory } from "./factories/owner-store.factory";
import { scheduleAndExecute } from "./helpers/schedule-and-execute";
import { USDCFactory } from "../currencies/factories/usdc.factory";
import { BigNumber } from "ethers";

describe("Governor Contract", function () {
    let governor: Governor;
    let proposer: SignerWithAddress;
    let executor: SignerWithAddress;
    let otherAccount: SignerWithAddress;
    let relay: SignerWithAddress;
    const minDelay = 86400;

    let ownerStore: OwnerStore;
    let usdc: USDC;

    beforeEach(async function () {
        [proposer, executor, otherAccount, relay] = await ethers.getSigners();

        const GovernorFactory = await ethers.getContractFactory("Governor");
        governor = await GovernorFactory.deploy(
            minDelay,
            proposer.address,
            executor.address
        );
        await governor.deployed();

        ownerStore = await OwnerStoreFactory.create(governor.address);

        usdc = await USDCFactory.create(relay);
    });

    /* ───────── CONSTRUCTOR ───────── */

    describe("Constructor", function () {
        context("failures", function () {
            it("reverts if proposer zero", async function () {
                const Factory = await ethers.getContractFactory("Governor");
                await expect(
                    Factory.deploy(
                        minDelay,
                        ethers.constants.AddressZero,
                        executor.address
                    )
                ).to.be.revertedWith("AddressEmpty()");
            });
            it("reverts if executor zero", async function () {
                const Factory = await ethers.getContractFactory("Governor");
                await expect(
                    Factory.deploy(
                        minDelay,
                        proposer.address,
                        ethers.constants.AddressZero
                    )
                ).to.be.revertedWith("AddressEmpty()");
            });
        });

        context("success", function () {
            it("sets initial values", async function () {
                expect(await governor.getMinDelay()).to.equal(minDelay);
                expect(await governor.getProposer()).to.equal(proposer.address);
                expect(await governor.getExecutor()).to.equal(executor.address);
                expect(await governor.getOperationCount()).to.equal(0);
            });
        });
    });

    describe("updateMinDelay", function () {
        context("failures", function () {
            it("reverts if called directly", async function () {
                await expect(
                    governor.connect(otherAccount).updateMinDelay(999)
                ).to.be.revertedWith("Unauthorized()");
            });
        });
        context("success", function () {
            it("updates via governance execution", async function () {
                const newDelay = 999;

                const calldata = governor.interface.encodeFunctionData(
                    "updateMinDelay",
                    [newDelay]
                );

                await scheduleAndExecute(
                    governor,
                    proposer,
                    executor,
                    governor.address,
                    calldata
                );

                expect(await governor.getMinDelay()).to.equal(newDelay);
            });
        });
    });

    describe("setProposer", function () {
        context("failures", function () {
            it("reverts if called directly", async function () {
                await expect(
                    governor.connect(otherAccount).setProposer(otherAccount.address)
                ).to.be.revertedWith("Unauthorized()");
            });
            it("reverts if zero via governance", async function () {
                const calldata = governor.interface.encodeFunctionData(
                    "setProposer",
                    [ethers.constants.AddressZero]
                );
                await expect(
                    scheduleAndExecute(
                        governor,
                        proposer,
                        executor,
                        governor.address,
                        calldata
                    )
                ).to.be.reverted;
            });
        });
        context("success", function () {
            it("updates proposer via governance", async function () {
                const calldata = governor.interface.encodeFunctionData(
                    "setProposer",
                    [otherAccount.address]
                );
                await scheduleAndExecute(
                    governor,
                    proposer,
                    executor,
                    governor.address,
                    calldata
                );
                expect(await governor.getProposer()).to.equal(otherAccount.address);
            });
        });
    });

    describe("setExecutor", function () {
        context("failures", function () {
            it("reverts if called directly", async function () {
                await expect(
                    governor.connect(otherAccount).setExecutor(otherAccount.address)
                ).to.be.revertedWith("Unauthorized()");
            });
        });
        context("success", function () {
            it("updates executor via governance", async function () {
                const calldata = governor.interface.encodeFunctionData(
                    "setExecutor",
                    [otherAccount.address]
                );
                await scheduleAndExecute(
                    governor,
                    proposer,
                    executor,
                    governor.address,
                    calldata
                );
                expect(await governor.getExecutor()).to.equal(otherAccount.address);
            });
        });
    });

    describe("schedule + execute external target", function () {
        let data: string;
        let salt: string;
        beforeEach(async function () {
            data = ownerStore.interface.encodeFunctionData("setValue", [3141]);
            salt = ethers.utils.id("salt");
        });
        context("failures", function () {
            it("reverts if non proposer schedules", async function () {
                await expect(
                    governor
                        .connect(otherAccount)
                        .schedule(ownerStore.address, data, salt)
                ).to.be.revertedWith("Unauthorized()");
            });
            it("reverts if executor runs early", async function () {
                await governor
                    .connect(proposer)
                    .schedule(ownerStore.address, data, salt);

                await expect(
                    governor
                        .connect(executor)
                        .execute(ownerStore.address, data, salt)
                ).to.be.reverted;
            });
        });
        context("success", function () {
            it("executes after delay", async function () {
                await scheduleAndExecute(
                    governor,
                    proposer,
                    executor,
                    ownerStore.address,
                    data,
                    salt
                );
                expect(await ownerStore.getValue()).to.equal(3141);
            });
        });
    });

    describe("schedule + execute external token transfer", function () {
        let data: string;
        let salt: string;
        beforeEach(async function () {
            await usdc.connect(relay).transfer(governor.address, BigNumber.from(1));
            data = usdc.interface.encodeFunctionData("transfer", [
                otherAccount.address,
                BigNumber.from(1),
            ]);
            salt = ethers.utils.id("salt");
        });
        context("failures", function () {
            it("reverts if non proposer schedules", async function () {
                await expect(
                    governor
                        .connect(otherAccount)
                        .schedule(ownerStore.address, data, salt)
                ).to.be.revertedWith("Unauthorized()");
            });
            it("reverts if executor runs early", async function () {
                await governor
                    .connect(proposer)
                    .schedule(ownerStore.address, data, salt);
                await expect(
                    governor
                        .connect(executor)
                        .execute(ownerStore.address, data, salt)
                ).to.be.reverted;
            });
        });
        context("success", function () {
            it("executes after delay", async function () {
                await scheduleAndExecute(
                    governor,
                    proposer,
                    executor,
                    usdc.address,
                    data,
                    salt
                );
                expect(await usdc.balanceOf(otherAccount.address)).to.equal(
                    BigNumber.from(1)
                );
            });
        });
    });

    describe("Getters", function () {
        it("returns correct delay", async () => {
            expect(await governor.getMinDelay()).to.equal(minDelay);
        });
        it("returns correct proposer", async () => {
            expect(await governor.getProposer()).to.equal(proposer.address);
        });
        it("returns correct executor", async () => {
            expect(await governor.getExecutor()).to.equal(executor.address);
        });
    });
});
