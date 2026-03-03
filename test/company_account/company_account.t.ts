/* eslint-disable node/no-missing-import */
import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import {
    CompanyAccount,
    USDC,
    Spender,
    Governance,
    AuthRegistry,
} from "../../typechain";

import { USD } from "../common/constants.factory";
import { BigNumber } from "ethers";
import { GovernanceFactory } from "../governance/factories/governance.factory";
import { AuthRegistryFactory } from "../auth_registry/factories/auth-registry.factory";
import { USDCFactory } from "../currencies/factories/usdc.factory";
import { CompanyAccountFactory } from "./factories/company-accounts.factory";
import { SpenderFactory } from "./factories/spender.factory";

describe.only("CompanyAccount Contract", function () {
    let superAdmin: SignerWithAddress;
    let governor: SignerWithAddress;
    let manager: SignerWithAddress;
    let authorizer: SignerWithAddress;
    let signer1: SignerWithAddress;
    let signer2: SignerWithAddress;
    let receiver1: SignerWithAddress;
    let receiver2: SignerWithAddress;
    let relayWallet: SignerWithAddress;

    let authRegistry: AuthRegistry;
    let governance: Governance;
    let companyAccount: CompanyAccount;
    let usdc: USDC;
    let spender: Spender;

    beforeEach(async function () {
        [
            superAdmin,
            governor,
            manager,
            authorizer,
            signer1,
            signer2,
            receiver1,
            receiver2,
            relayWallet,
        ] = await ethers.getSigners();

        governance = await GovernanceFactory.create(
            superAdmin.address,
            governor.address,
            manager.address,
            authorizer.address
        );

        authRegistry = await AuthRegistryFactory.create(governance.address);
        await authRegistry.connect(governor).addAuthAddress(relayWallet.address);

        usdc = await USDCFactory.create(relayWallet);

        companyAccount = await CompanyAccountFactory.create(
            superAdmin,
            governance.address,
            authRegistry.address,
            signer1.address
        );

        // transfer 1000 USDC to companyAccount
        await usdc
            .connect(relayWallet)
            .transfer(companyAccount.address, BigNumber.from(1000).mul(USD));

        // deploy spender contract for tests
        spender = await SpenderFactory.create(usdc.address);
    });

    describe("constructor", function () {
        it("should initialize signer, governance, and liquidity asset counts correctly", async function () {
            expect(await companyAccount.signerCount()).to.equal(1);
            expect(await companyAccount.signerByIndex(0)).to.equal(signer1.address);
            expect(await companyAccount.liquidityAssetCount()).to.equal(0);
        });
    });
    describe("addSigner", function () {
        context("success", function () {
            it("should add a new signer", async function () {
                await companyAccount.connect(governor).addSigner(signer2.address);
                expect(await companyAccount.isSigner(signer2.address)).to.be.true;
                expect(await companyAccount.signerCount()).to.equal(2);
            });
        });
        context("failures", function () {
            it("should revert if address is zero", async function () {
                await expect(
                    companyAccount
                        .connect(governor)
                        .addSigner(ethers.constants.AddressZero)
                ).to.be.revertedWith("AddressEmpty()");
            });
            it("should revert if address already exists", async function () {
                await expect(
                    companyAccount.connect(governor).addSigner(signer1.address)
                ).to.be.revertedWith("AddressExists()");
            });
            it("should revert if called by non-governor", async function () {
                await expect(
                    companyAccount.connect(signer2).addSigner(signer2.address)
                ).to.be.revertedWith("Unauthorized()");
            });
        });
    });

    describe("removeSigner", function () {
        context("success", function () {
            it("should remove a signer", async function () {
                await companyAccount.connect(governor).removeSigner(signer1.address);
                expect(await companyAccount.isSigner(signer1.address)).to.be.false;
            });
        });
        context("failures", function () {
            it("should revert if signer does not exist", async function () {
                await expect(
                    companyAccount.connect(governor).removeSigner(signer2.address)
                ).to.be.revertedWith("AddressInvalid()");
            });
            it("should revert if called by non-manager", async function () {
                await expect(
                    companyAccount.connect(signer2).removeSigner(signer1.address)
                ).to.be.revertedWith("Unauthorized()");
            });
        });
    });

    describe("addReceiver", function () {
        const nonce = ethers.utils.hexlify(ethers.utils.randomBytes(16));
        let signature: string;
        beforeEach(async function () {
            const messageHash = ethers.utils.solidityKeccak256(
                ["address", "address", "uint256", "bytes16"],
                [ethers.constants.AddressZero, receiver1.address, 0, nonce]
            );
            signature = await signer1.signMessage(
                ethers.utils.arrayify(messageHash)
            );
        });
        context("success", function () {
            it("should add a receiver", async function () {
                await companyAccount
                    .connect(authorizer)
                    .addReceiver(receiver1.address, nonce, signature);
                expect(
                    await companyAccount.isReceiver(receiver1.address)
                ).to.be.true;
                expect(await companyAccount.receiverCount()).to.equal(1);
            });
        });
        context("failures", function () {
            it("should revert if called with zero addresses", async function () {
                await expect(
                    companyAccount
                        .connect(authorizer)
                        .addReceiver(ethers.constants.AddressZero, nonce, signature)
                ).to.be.revertedWith("AddressEmpty()");
            });
            it("should revert if already a receiver", async function () {
                await companyAccount
                    .connect(authorizer)
                    .addReceiver(receiver1.address, nonce, signature);
                await expect(
                    companyAccount
                        .connect(authorizer)
                        .addReceiver(receiver1.address, nonce, signature)
                ).to.be.revertedWith("AddressExists()");
            });
            it("should revert if signature invalid", async function () {
                const messageHash2 = ethers.utils.solidityKeccak256(
                    ["address", "address", "uint256", "bytes16"],
                    [ethers.constants.AddressZero, receiver2.address, 0, nonce]
                );
                const signature2 = await signer1.signMessage(
                    ethers.utils.arrayify(messageHash2)
                );
                await expect(
                    companyAccount
                        .connect(authorizer)
                        .addReceiver(receiver1.address, nonce, signature2)
                ).to.be.revertedWith("Unauthorized()");
            });
        });
    });

    describe("removeReceiver", function () {
        const nonce = ethers.utils.hexlify(ethers.utils.randomBytes(16));
        let signature: string;
        beforeEach(async function () {
            const messageHash = ethers.utils.solidityKeccak256(
                ["address", "address", "uint256", "bytes16"],
                [ethers.constants.AddressZero, receiver1.address, 0, nonce]
            );
            signature = await signer1.signMessage(
                ethers.utils.arrayify(messageHash)
            );
            await companyAccount
                .connect(authorizer)
                .addReceiver(receiver1.address, nonce, signature);
        });
        context("success", function () {
            it("should remove a receiver", async function () {
                await companyAccount
                    .connect(governor)
                    .removeReceiver(receiver1.address);
                expect(await companyAccount.isReceiver(usdc.address)).to.be.false;
            });
        });
        context("failures", function () {
            it("should revert if receiver invalid", async function () {
                await expect(
                    companyAccount
                        .connect(governor)
                        .removeReceiver(ethers.constants.AddressZero)
                ).to.be.revertedWith("AddressEmpty()");
            });
            it("should revert if receiver does not exist", async function () {
                await expect(
                    companyAccount
                        .connect(governor)
                        .removeReceiver(receiver2.address)
                ).to.be.revertedWith("AddressInvalid()");
            });
        });
    });

    describe("addSpender", function () {
        context("success", function () {
            it("should add spender contract", async function () {
                await companyAccount
                    .connect(governor)
                    .addSpender(usdc.address, spender.address);
            });
        });
        context("failures", function () {
            it("should revert if spender is not a contract", async function () {
                await expect(
                    companyAccount
                        .connect(governor)
                        .addSpender(usdc.address, signer2.address)
                ).to.be.revertedWith("NotContract()");
            });
            it("should revert if spender exists", async function () {
                await companyAccount
                    .connect(governor)
                    .addSpender(usdc.address, spender.address);
                await expect(
                    companyAccount
                        .connect(governor)
                        .addSpender(usdc.address, spender.address)
                ).to.be.revertedWith("AddressExists()");
            });
        });
    });

    describe("removeSpender", function () {
        beforeEach(async function () {
            await companyAccount
                .connect(governor)
                .addSpender(usdc.address, spender.address);
        });
        context("success", function () {
            it("should remove a spender contract", async function () {
                await companyAccount
                    .connect(governor)
                    .removeSpender(usdc.address, spender.address);
                expect(
                    await companyAccount.isSpender(usdc.address, spender.address)
                );
            });
        });
        context("failures", function () {
            it("should revert if spender does not exist", async function () {
                await expect(
                    companyAccount
                        .connect(governor)
                        .removeSpender(usdc.address, signer2.address)
                ).to.be.revertedWith("AddressInvalid()");
            });
        });
    });

    describe("approveSpender", function () {
        const nonce = ethers.utils.hexlify(ethers.utils.randomBytes(16));
        let signature: string;
        beforeEach(async function () {
            await companyAccount
                .connect(governor)
                .addSpender(usdc.address, spender.address);
            const messageHash = ethers.utils.solidityKeccak256(
                ["address", "address", "uint256", "bytes16"],
                [usdc.address, spender.address, 100, nonce]
            );
            signature = await signer1.signMessage(
                ethers.utils.arrayify(messageHash)
            );
        });
        context("success", function () {
            it("spender can approve and transfer USDC", async function () {
                // approve first
                await spender.requestApprovalAndTransfer(
                    companyAccount.address,
                    100,
                    nonce,
                    signature
                );
                expect(await usdc.balanceOf(spender.address)).to.equal(100);
            });
        });
        context("failures", function () {
            it("should revert if not authorized spender", async function () {
                await expect(
                    companyAccount
                        .connect(signer2)
                        .approveSpender(
                            companyAccount.address,
                            100,
                            nonce,
                            signature
                        )
                ).to.be.revertedWith("Unauthorized()");
            });
            it("should revert if nonce already used", async function () {
                await spender.requestApprovalAndTransfer(
                    companyAccount.address,
                    100,
                    nonce,
                    signature
                );
                await expect(
                    spender.requestApprovalAndTransfer(
                        companyAccount.address,
                        100,
                        nonce,
                        signature
                    )
                ).to.be.revertedWith("InvalidAccountNonce()");
            });
        });
    });

    describe("withdraw", function () {
        const nonce = ethers.utils.hexlify(ethers.utils.randomBytes(16));
        let signature: string;

        beforeEach(async function () {
            const messageHash = ethers.utils.solidityKeccak256(
                ["address", "address", "uint256", "bytes16"],
                [ethers.constants.AddressZero, receiver1.address, 0, nonce]
            );
            signature = await signer1.signMessage(
                ethers.utils.arrayify(messageHash)
            );
            await companyAccount
                .connect(authorizer)
                .addReceiver(receiver1.address, nonce, signature);
        });

        context("success", function () {
            it("receiver can withdraw tokens", async function () {
                const nonce2 = ethers.utils.hexlify(ethers.utils.randomBytes(16));
                const messageHash2 = ethers.utils.solidityKeccak256(
                    ["address", "address", "uint256", "bytes16"],
                    [usdc.address, receiver1.address, 100, nonce2]
                );
                const signature2 = await signer1.signMessage(
                    ethers.utils.arrayify(messageHash2)
                );
                await companyAccount
                    .connect(relayWallet)
                    .withdraw(
                        usdc.address,
                        receiver1.address,
                        100,
                        nonce2,
                        signature2
                    );
                expect(await usdc.balanceOf(receiver1.address)).to.equal(100);
            });
        });
        context("failures", function () {
            it("should revert if not authorized by registry", async function () {
                await expect(
                    companyAccount
                        .connect(signer2)
                        .withdraw(
                            usdc.address,
                            signer2.address,
                            100,
                            nonce,
                            signature
                        )
                ).to.be.revertedWith("Unauthorized()");
            });
            it("should revert if receiver invalid", async function () {
                await expect(
                    companyAccount
                        .connect(relayWallet)
                        .withdraw(
                            usdc.address,
                            ethers.constants.AddressZero,
                            100,
                            nonce,
                            signature
                        )
                ).to.be.revertedWith("InvalidReceiver()");
            });
        });
    });

    describe("pause/unpause", function () {
        context("success", function () {
            it("should update paused state correctly", async function () {
                // initially not paused
                expect(await companyAccount.paused()).to.be.false;

                // pause the contract
                await companyAccount.connect(manager).pause();
                expect(await companyAccount.paused()).to.be.true;

                // unpause the contract
                await companyAccount.connect(manager).unpause();
                expect(await companyAccount.paused()).to.be.false;
            });
        });

        context("failures", function () {
            it("non-superAdmin cannot pause or unpause", async function () {
                await expect(
                    companyAccount.connect(governor).pause()
                ).to.be.revertedWith("Unauthorized()");
                await companyAccount.connect(manager).pause();
                await expect(
                    companyAccount.connect(governor).unpause()
                ).to.be.revertedWith("Unauthorized()");
            });
        });
    });
});
