import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import { Governance } from "../../typechain";
import { GovernanceFactory } from "./factories/governance.factory";

describe("Governance contract", function () {
    let governance: Governance;

    let superAdmin: SignerWithAddress;
    let governor: SignerWithAddress;
    let manager: SignerWithAddress;
    let authorizer: SignerWithAddress;
    let other: SignerWithAddress;

    beforeEach(async function () {
        [superAdmin, governor, manager, authorizer, other] =
            await ethers.getSigners();

        governance = await GovernanceFactory.create(
            superAdmin.address,
            governor.address,
            manager.address,
            authorizer.address
        );
    });

    describe("Deployment", function () {
        it("should set the correct initial roles", async function () {
            expect(await governance.getSuperAdmin()).to.equal(superAdmin.address);
            expect(await governance.getGovernor()).to.equal(governor.address);
            expect(await governance.getManager()).to.equal(manager.address);
            expect(await governance.getAuthorizer()).to.equal(authorizer.address);
        });
    });

    describe("Transfer Governor", function () {
        context("failures", function () {
            it("reverts if caller is not superAdmin", async function () {
                await expect(
                    governance.connect(other).transferGovernor(other.address)
                ).to.be.revertedWith("Unauthorized()");
            });

            it("reverts if new governor is zero address", async function () {
                await expect(
                    governance.transferGovernor(ethers.constants.AddressZero)
                ).to.be.revertedWith("AddressEmpty()");
            });

            it("reverts if new governor is current manager", async function () {
                await expect(
                    governance.transferGovernor(manager.address)
                ).to.be.revertedWith("GovernorAndManagerCannotBeSame()");
            });
        });

        context("success", function () {
            it("allows superAdmin to transfer governor", async function () {
                await expect(governance.transferGovernor(other.address))
                    .to.emit(governance, "GovernorTransferred")
                    .withArgs(governor.address, other.address);

                expect(await governance.getGovernor()).to.equal(other.address);
            });
        });
    });

    describe("Transfer Manager", function () {
        context("failures", function () {
            it("reverts if caller is not superAdmin", async function () {
                await expect(
                    governance.connect(other).transferManager(other.address)
                ).to.be.revertedWith("Unauthorized()");
            });

            it("reverts if new manager is zero address", async function () {
                await expect(
                    governance.transferManager(ethers.constants.AddressZero)
                ).to.be.revertedWith("AddressEmpty()");
            });

            it("reverts if new manager is current governor", async function () {
                await expect(
                    governance.transferManager(governor.address)
                ).to.be.revertedWith("GovernorAndManagerCannotBeSame()");
            });
        });

        context("success", function () {
            it("allows superAdmin to transfer manager", async function () {
                await expect(governance.transferManager(other.address))
                    .to.emit(governance, "ManagerTransferred")
                    .withArgs(manager.address, other.address);

                expect(await governance.getManager()).to.equal(other.address);
            });
        });
    });

    describe("Transfer SuperAdmin", function () {
        context("failures", function () {
            it("reverts if caller is not superAdmin", async function () {
                await expect(
                    governance.connect(other).transferSuperAdmin(other.address)
                ).to.be.revertedWith("Unauthorized()");
            });

            it("reverts if new superAdmin is zero address", async function () {
                await expect(
                    governance.transferSuperAdmin(ethers.constants.AddressZero)
                ).to.be.revertedWith("AddressEmpty()");
            });
        });

        context("success", function () {
            it("allows superAdmin to transfer superAdmin", async function () {
                await expect(governance.transferSuperAdmin(other.address))
                    .to.emit(governance, "SuperAdminTransferred")
                    .withArgs(superAdmin.address, other.address);

                expect(await governance.getSuperAdmin()).to.equal(other.address);
            });
        });
    });

    describe("Transfer Authorizer", function () {
        context("failures", function () {
            it("reverts if caller is not authorizer", async function () {
                await expect(
                    governance.connect(other).transferAuthorizer(other.address)
                ).to.be.revertedWith("Unauthorized()");
            });
            it("reverts if superAdmin tries to transfer authorizer", async function () {
                await expect(
                    governance.connect(superAdmin).transferAuthorizer(other.address)
                ).to.be.revertedWith("Unauthorized()");
            });
            it("reverts if new authorizer is zero address", async function () {
                await expect(
                    governance
                        .connect(authorizer)
                        .transferAuthorizer(ethers.constants.AddressZero)
                ).to.be.revertedWith("AddressEmpty()");
            });
        });

        context("success", function () {
            it("allows authorizer to transfer authorizer", async function () {
                await expect(
                    governance.connect(authorizer).transferAuthorizer(other.address)
                )
                    .to.emit(governance, "AuthorizerTransferred")
                    .withArgs(authorizer.address, other.address);

                expect(await governance.getAuthorizer()).to.equal(other.address);
            });
        });
    });
});
