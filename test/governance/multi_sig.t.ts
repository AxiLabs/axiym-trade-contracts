import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import { MultiSig, OwnerStore } from "../../typechain";
import { BigNumber } from "ethers";
import { MultiSigFactory } from "./factories/multi-sig.factory";
import { OwnerStoreFactory } from "./factories/owner-store.factory";
import { signMultiSigTx } from "./helpers/sign-multi-sig";

describe("Multi-Sig contract", function () {
    let multisig: MultiSig;

    let owner1: SignerWithAddress;
    let owner2: SignerWithAddress;
    let owner3: SignerWithAddress;
    let owner4: SignerWithAddress;
    let otherAccount: SignerWithAddress;

    let ownerStore: OwnerStore;

    beforeEach(async function () {
        [owner1, owner2, owner3, owner4, otherAccount] = await ethers.getSigners();

        multisig = await MultiSigFactory.create(
            [owner1.address, owner2.address, owner3.address],
            BigNumber.from(3)
        );

        ownerStore = await OwnerStoreFactory.create(multisig.address);
    });

    describe("Deployment", function () {
        let MultiSigContract: any;
        context("failures", function () {
            beforeEach(async function () {
                MultiSigContract = await ethers.getContractFactory("MultiSig");
            });
            it("should fail if 0 owners", async function () {
                await expect(MultiSigContract.deploy([], 3)).to.be.revertedWith(
                    "ZeroOwners()"
                );
            });
            it("should fail if threshold is 0", async function () {
                const MultiSigContract = await ethers.getContractFactory("MultiSig");
                await expect(
                    MultiSigContract.deploy([owner1.address], 0)
                ).to.be.revertedWith("InvalidThreshold()");
            });
            it("should fail if threshold is greater than owner count", async function () {
                const MultiSigContract = await ethers.getContractFactory("MultiSig");
                await expect(
                    MultiSigContract.deploy([owner1.address], 2)
                ).to.be.revertedWith("InvalidThreshold()");
            });
            it("should fail if an owner is the zero address", async function () {
                const MultiSigContract = await ethers.getContractFactory("MultiSig");
                await expect(
                    MultiSigContract.deploy([ethers.constants.AddressZero], 1)
                ).to.be.revertedWith("InvalidOwner()");
            });
            it("should fail if an owner is the contract itself", async function () {
                const MultiSigContract = await ethers.getContractFactory("MultiSig");
                // Predict the contract address
                const nonce = await owner1.getTransactionCount();
                const futureAddress = ethers.utils.getContractAddress({
                    from: owner1.address,
                    nonce: nonce,
                });
                await expect(
                    MultiSigContract.deploy([futureAddress], 1)
                ).to.be.revertedWith("InvalidOwner()");
            });
            it("should fail if there are duplicate owners", async function () {
                const MultiSigContract = await ethers.getContractFactory("MultiSig");
                await expect(
                    MultiSigContract.deploy([owner1.address, owner1.address], 1)
                ).to.be.revertedWith("OwnerExists()");
            });
        });
        context("success", function () {
            it("should set the correct owners and threshold", async function () {
                expect(await multisig.getThreshold()).to.equal(3);
                const owners = await multisig.getOwners();
                expect(owners).to.include(owner1.address);
                expect(owners).to.include(owner2.address);
                expect(owners).to.include(owner3.address);
                expect(owners.length).to.equal(3);
            });
        });
    });

    describe("execTransaction", function () {
        let nonce: string;
        const newValue = 123;
        beforeEach(async function () {
            nonce = ethers.utils.hexlify(ethers.utils.randomBytes(32));
        });
        context("failures", function () {
            it("should fail if transaction already executed", async function () {
                const data = ownerStore.interface.encodeFunctionData("setValue", [
                    newValue,
                ]);
                const signatures = await signMultiSigTx(
                    [owner1, owner2, owner3],
                    ownerStore.address,
                    data,
                    nonce,
                    multisig.address
                );
                await multisig.execTransaction(
                    ownerStore.address,
                    data,
                    signatures,
                    nonce
                );
                await expect(
                    multisig.execTransaction(
                        ownerStore.address,
                        data,
                        signatures,
                        nonce
                    )
                ).to.be.revertedWith("AlreadyExecuted()");
            });
            it("should fail if signatures length is invalid", async function () {
                const data = ownerStore.interface.encodeFunctionData("setValue", [
                    newValue,
                ]);
                const invalidSigs = "0xabcdef";
                await expect(
                    multisig.execTransaction(
                        ownerStore.address,
                        data,
                        invalidSigs,
                        nonce
                    )
                ).to.be.revertedWith("InvalidSignatureLength()");
            });
            it("should fail if signatures are below threshold", async function () {
                const data = ownerStore.interface.encodeFunctionData("setValue", [
                    newValue,
                ]);
                const signatures = await signMultiSigTx(
                    [owner1, owner2],
                    ownerStore.address,
                    data,
                    nonce,
                    multisig.address
                );
                await expect(
                    multisig.execTransaction(
                        ownerStore.address,
                        data,
                        signatures,
                        nonce
                    )
                ).to.be.revertedWith("InsufficientSignatures()");
            });
            it("should fail if a signer is not an owner", async function () {
                const data = ownerStore.interface.encodeFunctionData("setValue", [
                    newValue,
                ]);

                const signatures = await signMultiSigTx(
                    [owner1, owner2, otherAccount],
                    ownerStore.address,
                    data,
                    nonce,
                    multisig.address
                );
                await expect(
                    multisig.execTransaction(
                        ownerStore.address,
                        data,
                        signatures,
                        nonce
                    )
                ).to.be.revertedWith("NotOwner()");
            });
            it("should fail if duplicate signatures are provided", async function () {
                const data = ownerStore.interface.encodeFunctionData("setValue", [
                    newValue,
                ]);
                // owner1 signs twice
                const signatures = await signMultiSigTx(
                    [owner1, owner1, owner2],
                    ownerStore.address,
                    data,
                    nonce,
                    multisig.address
                );
                await expect(
                    multisig.execTransaction(
                        ownerStore.address,
                        data,
                        signatures,
                        nonce
                    )
                ).to.be.revertedWith("DuplicateOwner()");
            });
            it("should fail if the external call reverts", async function () {
                const data = ownerStore.interface.encodeFunctionData("revertTest");
                const signatures = await signMultiSigTx(
                    [owner1, owner2, owner3],
                    ownerStore.address,
                    data,
                    nonce,
                    multisig.address
                );

                await expect(
                    multisig.execTransaction(
                        ownerStore.address,
                        data,
                        signatures,
                        nonce
                    )
                ).to.be.revertedWith("ErrorTest()");
            });
        });
        context("success", function () {
            it("should execute transaction and change OwnerStore value", async function () {
                const data = ownerStore.interface.encodeFunctionData("setValue", [
                    newValue,
                ]);
                const signatures = await signMultiSigTx(
                    [owner1, owner2, owner3],
                    ownerStore.address,
                    data,
                    nonce,
                    multisig.address
                );
                const txHash = await multisig.getTransactionHash(
                    ownerStore.address,
                    data,
                    nonce
                );
                await multisig.execTransaction(
                    ownerStore.address,
                    data,
                    signatures,
                    nonce
                );
                expect(await ownerStore.getValue()).to.equal(newValue);
                expect(await multisig.isExecuted(txHash)).to.be.true;
                expect(await multisig.executedCount()).to.equal(1);
            });
        });
    });

    describe("addOwnerWithThreshold", function () {
        let data: string;
        let nonce: string;
        beforeEach(() => {
            nonce = ethers.utils.hexlify(ethers.utils.randomBytes(32));
        });
        context("failures", function () {
            it("should fail if adding the zero address", async function () {
                data = multisig.interface.encodeFunctionData(
                    "addOwnerWithThreshold",
                    [ethers.constants.AddressZero, 3]
                );
                const signatures = await signMultiSigTx(
                    [owner1, owner2, owner3],
                    multisig.address,
                    data,
                    nonce,
                    multisig.address
                );
                await expect(
                    multisig.execTransaction(
                        multisig.address,
                        data,
                        signatures,
                        nonce
                    )
                ).to.be.revertedWith("InvalidOwner()");
            });
            it("should fail if adding an existing owner", async function () {
                data = multisig.interface.encodeFunctionData(
                    "addOwnerWithThreshold",
                    [owner1.address, 3]
                );
                const signatures = await signMultiSigTx(
                    [owner1, owner2, owner3],
                    multisig.address,
                    data,
                    nonce,
                    multisig.address
                );
                await expect(
                    multisig.execTransaction(
                        multisig.address,
                        data,
                        signatures,
                        nonce
                    )
                ).to.be.revertedWith("OwnerExists()");
            });
            it("should fail if new threshold greater than owner count", async function () {
                data = multisig.interface.encodeFunctionData(
                    "addOwnerWithThreshold",
                    [owner4.address, 5]
                );
                const signatures = await signMultiSigTx(
                    [owner1, owner2, owner3],
                    multisig.address,
                    data,
                    nonce,
                    multisig.address
                );
                await expect(
                    multisig.execTransaction(
                        multisig.address,
                        data,
                        signatures,
                        nonce
                    )
                ).to.be.revertedWith("InvalidThreshold()");
            });
            it("should fail if adding the multisig itself as an owner", async function () {
                data = multisig.interface.encodeFunctionData(
                    "addOwnerWithThreshold",
                    [multisig.address, 3]
                );
                const signatures = await signMultiSigTx(
                    [owner1, owner2, owner3],
                    multisig.address,
                    data,
                    nonce,
                    multisig.address
                );
                await expect(
                    multisig.execTransaction(
                        multisig.address,
                        data,
                        signatures,
                        nonce
                    )
                ).to.be.revertedWith("InvalidOwner()");
            });
        });
        context("success", function () {
            it("should add a new owner and update threshold", async function () {
                data = multisig.interface.encodeFunctionData(
                    "addOwnerWithThreshold",
                    [owner4.address, 4]
                );
                const signatures = await signMultiSigTx(
                    [owner1, owner2, owner3],
                    multisig.address,
                    data,
                    nonce,
                    multisig.address
                );
                await multisig.execTransaction(
                    multisig.address,
                    data,
                    signatures,
                    nonce
                );

                expect(await multisig.isOwner(owner4.address)).to.be.true;
                expect(await multisig.getThreshold()).to.equal(4);
            });
        });
    });

    describe("removeOwner", function () {
        let data: string;
        let nonce: string;
        beforeEach(async function () {
            nonce = ethers.utils.hexlify(ethers.utils.randomBytes(32));
        });
        context("failures", function () {
            it("should fail if removing an address that is not an owner", async function () {
                // otherAccount is not in the owners mapping
                data = multisig.interface.encodeFunctionData("removeOwner", [
                    otherAccount.address,
                    2,
                ]);
                const signatures = await signMultiSigTx(
                    [owner1, owner2, owner3],
                    multisig.address,
                    data,
                    nonce,
                    multisig.address
                );
                await expect(
                    multisig.execTransaction(
                        multisig.address,
                        data,
                        signatures,
                        nonce
                    )
                ).to.be.revertedWith("OwnerIncorrect()");
            });
            it("should fail if the new threshold is greater than the remaining owners count", async function () {
                const unreachableThreshold = 3;
                data = multisig.interface.encodeFunctionData("removeOwner", [
                    owner3.address,
                    unreachableThreshold,
                ]);
                const signatures = await signMultiSigTx(
                    [owner1, owner2, owner3],
                    multisig.address,
                    data,
                    nonce,
                    multisig.address
                );
                await expect(
                    multisig.execTransaction(
                        multisig.address,
                        data,
                        signatures,
                        nonce
                    )
                ).to.be.revertedWith("ThresholdUnreachable()");
            });
            it("should fail if threshold is updated to zero", async function () {
                data = multisig.interface.encodeFunctionData("removeOwner", [
                    owner3.address,
                    0,
                ]);
                const signatures = await signMultiSigTx(
                    [owner1, owner2, owner3],
                    multisig.address,
                    data,
                    nonce,
                    multisig.address
                );

                // This will fail because changeThreshold(0) is called internally
                await expect(
                    multisig.execTransaction(
                        multisig.address,
                        data,
                        signatures,
                        nonce
                    )
                ).to.be.revertedWith("InvalidThreshold()");
            });
        });
        context("success", function () {
            it("should remove owner and update threshold (3 owners, threshold 3 -> 2 owners, threshold 2)", async function () {
                const ownerToRemove = owner3.address;
                const newThreshold = 2;
                data = multisig.interface.encodeFunctionData("removeOwner", [
                    ownerToRemove,
                    newThreshold,
                ]);
                const signatures = await signMultiSigTx(
                    [owner1, owner2, owner3],
                    multisig.address,
                    data,
                    nonce,
                    multisig.address
                );

                await multisig.execTransaction(
                    multisig.address,
                    data,
                    signatures,
                    nonce
                );

                expect(await multisig.isOwner(ownerToRemove)).to.be.false;
                expect(await multisig.getThreshold()).to.equal(newThreshold);
                const owners = await multisig.getOwners();
                expect(owners.length).to.equal(2);
                expect(owners).to.not.contain(ownerToRemove);
            });

            it("should remove owner but maintain same threshold (3 owners, threshold 2 -> 2 owners, threshold 2)", async function () {
                const customMultisig = await MultiSigFactory.create(
                    [owner1.address, owner2.address, owner3.address],
                    BigNumber.from(2)
                );
                const ownerToRemove = owner3.address;
                const sameThreshold = 2; // threshold remains 2
                const customNonce = ethers.utils.hexlify(
                    ethers.utils.randomBytes(32)
                );
                data = customMultisig.interface.encodeFunctionData("removeOwner", [
                    ownerToRemove,
                    sameThreshold,
                ]);
                const signatures = await signMultiSigTx(
                    [owner1, owner2],
                    customMultisig.address,
                    data,
                    customNonce,
                    customMultisig.address
                );
                await customMultisig.execTransaction(
                    customMultisig.address,
                    data,
                    signatures,
                    customNonce
                );
                expect(await customMultisig.getThreshold()).to.equal(2);
                expect((await customMultisig.getOwners()).length).to.equal(2);
            });
        });
    });

    describe("swapOwner", function () {
        let data: string;
        let nonce: string;
        beforeEach(async function () {
            nonce = ethers.utils.hexlify(ethers.utils.randomBytes(32));
        });
        context("failures", function () {
            it("should fail if the old owner address is not actually an owner", async function () {
                // otherAccount is not an owner
                data = multisig.interface.encodeFunctionData("swapOwner", [
                    otherAccount.address,
                    owner4.address,
                ]);
                const signatures = await signMultiSigTx(
                    [owner1, owner2, owner3],
                    multisig.address,
                    data,
                    nonce,
                    multisig.address
                );
                await expect(
                    multisig.execTransaction(
                        multisig.address,
                        data,
                        signatures,
                        nonce
                    )
                ).to.be.revertedWith("OwnerIncorrect()");
            });
            it("should fail if the new owner is already an owner", async function () {
                // owner2 is already an owner
                data = multisig.interface.encodeFunctionData("swapOwner", [
                    owner1.address,
                    owner2.address,
                ]);
                const signatures = await signMultiSigTx(
                    [owner1, owner2, owner3],
                    multisig.address,
                    data,
                    nonce,
                    multisig.address
                );
                await expect(
                    multisig.execTransaction(
                        multisig.address,
                        data,
                        signatures,
                        nonce
                    )
                ).to.be.revertedWith("OwnerExists()");
            });
            it("should fail if the new owner is the zero address", async function () {
                data = multisig.interface.encodeFunctionData("swapOwner", [
                    owner1.address,
                    ethers.constants.AddressZero,
                ]);
                const signatures = await signMultiSigTx(
                    [owner1, owner2, owner3],
                    multisig.address,
                    data,
                    nonce,
                    multisig.address
                );
                await expect(
                    multisig.execTransaction(
                        multisig.address,
                        data,
                        signatures,
                        nonce
                    )
                ).to.be.revertedWith("InvalidOwner()");
            });
            it("should fail if the new owner is the multisig contract itself", async function () {
                data = multisig.interface.encodeFunctionData("swapOwner", [
                    owner1.address,
                    multisig.address,
                ]);
                const signatures = await signMultiSigTx(
                    [owner1, owner2, owner3],
                    multisig.address,
                    data,
                    nonce,
                    multisig.address
                );
                await expect(
                    multisig.execTransaction(
                        multisig.address,
                        data,
                        signatures,
                        nonce
                    )
                ).to.be.revertedWith("InvalidOwner()");
            });
        });
        context("success", function () {
            it("should replace an old owner with a new owner and preserve state integrity", async function () {
                const oldOwner = owner1.address;
                const newOwner = owner4.address;

                data = multisig.interface.encodeFunctionData("swapOwner", [
                    oldOwner,
                    newOwner,
                ]);

                // Signatures must come from the CURRENT owners before the swap happens
                const signatures = await signMultiSigTx(
                    [owner1, owner2, owner3],
                    multisig.address,
                    data,
                    nonce,
                    multisig.address
                );

                await multisig.execTransaction(
                    multisig.address,
                    data,
                    signatures,
                    nonce
                );

                // 1. Check mapping updates
                expect(await multisig.isOwner(oldOwner)).to.be.false;
                expect(await multisig.isOwner(newOwner)).to.be.true;

                // 2. Check array updates
                const owners = await multisig.getOwners();
                expect(owners).to.include(newOwner);
                expect(owners).to.not.include(oldOwner);
                expect(owners.length).to.equal(3); // Count remains the same

                // 3. Verify threshold is unchanged
                expect(await multisig.getThreshold()).to.equal(3);
            });
        });
    });

    describe("changeThreshold", function () {
        let data: string;
        let nonce: string;
        beforeEach(async function () {
            nonce = ethers.utils.hexlify(ethers.utils.randomBytes(32));
        });
        context("failures", function () {
            it("should fail if the threshold is set to 0", async function () {
                data = multisig.interface.encodeFunctionData("changeThreshold", [0]);
                const signatures = await signMultiSigTx(
                    [owner1, owner2, owner3],
                    multisig.address,
                    data,
                    nonce,
                    multisig.address
                );
                await expect(
                    multisig.execTransaction(
                        multisig.address,
                        data,
                        signatures,
                        nonce
                    )
                ).to.be.revertedWith("InvalidThreshold()");
            });
            it("should fail if the threshold is greater than the current owner count", async function () {
                // Current ownerCount is 3. Trying to set threshold to 4.
                const invalidThreshold = 4;
                data = multisig.interface.encodeFunctionData("changeThreshold", [
                    invalidThreshold,
                ]);
                const signatures = await signMultiSigTx(
                    [owner1, owner2, owner3],
                    multisig.address,
                    data,
                    nonce,
                    multisig.address
                );
                await expect(
                    multisig.execTransaction(
                        multisig.address,
                        data,
                        signatures,
                        nonce
                    )
                ).to.be.revertedWith("InvalidThreshold()");
            });
        });
        context("success", function () {
            it("should successfully change the threshold to a valid value", async function () {
                const newThreshold = 2;
                data = multisig.interface.encodeFunctionData("changeThreshold", [
                    newThreshold,
                ]);
                // Still requires 3 signatures because the current threshold is 3
                const signatures = await signMultiSigTx(
                    [owner1, owner2, owner3],
                    multisig.address,
                    data,
                    nonce,
                    multisig.address
                );

                await multisig.execTransaction(
                    multisig.address,
                    data,
                    signatures,
                    nonce
                );

                expect(await multisig.getThreshold()).to.equal(newThreshold);
            });

            it("should allow changing the threshold back up (if within owner count)", async function () {
                // 1. First, lower it to 2
                let localNonce = ethers.utils.hexlify(ethers.utils.randomBytes(32));
                let dataLower = multisig.interface.encodeFunctionData(
                    "changeThreshold",
                    [2]
                );
                let sigsLower = await signMultiSigTx(
                    [owner1, owner2, owner3],
                    multisig.address,
                    dataLower,
                    localNonce,
                    multisig.address
                );
                await multisig.execTransaction(
                    multisig.address,
                    dataLower,
                    sigsLower,
                    localNonce
                );

                // 2. Now, raise it back to 3
                // Note: Now only 2 signatures are required because the threshold is 2!
                localNonce = ethers.utils.hexlify(ethers.utils.randomBytes(32));
                let dataRaise = multisig.interface.encodeFunctionData(
                    "changeThreshold",
                    [3]
                );
                let sigsRaise = await signMultiSigTx(
                    [owner1, owner2],
                    multisig.address,
                    dataRaise,
                    localNonce,
                    multisig.address
                );

                await expect(
                    multisig.execTransaction(
                        multisig.address,
                        dataRaise,
                        sigsRaise,
                        localNonce
                    )
                )
                    .to.emit(multisig, "ChangedThreshold")
                    .withArgs(3);

                expect(await multisig.getThreshold()).to.equal(3);
            });
        });
    });

    describe("simulateTransaction", function () {
        context("failure simulation (target reverts)", function () {
            it("should bubble the revert reason from the target contract", async function () {
                const data = ownerStore.interface.encodeFunctionData("revertTest");

                await expect(
                    multisig.simulateTransaction(ownerStore.address, data)
                ).to.be.revertedWith("ErrorTest()");
            });
        });

        context("success simulation (target succeeds)", function () {
            it("should revert with SimulationSuccess when the call would succeed", async function () {
                const data = ownerStore.interface.encodeFunctionData("setValue", [
                    123,
                ]);

                await expect(
                    multisig.simulateTransaction(ownerStore.address, data)
                ).to.be.revertedWith("SimulationSuccess()");
            });

            it("should not modify state during simulation", async function () {
                const data = ownerStore.interface.encodeFunctionData("setValue", [
                    999,
                ]);

                // Simulate
                await expect(
                    multisig.simulateTransaction(ownerStore.address, data)
                ).to.be.revertedWith("SimulationSuccess()");

                // Ensure state is unchanged
                expect(await ownerStore.getValue()).to.equal(0);
                expect(await multisig.executedCount()).to.equal(0);
            });
        });

        context("simulation of view / pure calls", function () {
            it("should succeed for pure functions", async function () {
                const data = ownerStore.interface.encodeFunctionData("ping");

                await expect(
                    multisig.simulateTransaction(ownerStore.address, data)
                ).to.be.revertedWith("SimulationSuccess()");
            });
        });
    });
});
