/* eslint-disable node/no-missing-import */
import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

// import types
import { AuthRegistry, Governance } from "../../typechain";
import { GovernanceFactory } from "../governance/factories/governance.factory";
import { AuthRegistryFactory } from "./factories/auth-registry.factory";

// import constants

describe("Auth Registry Contract", function () {
    let authRegistry: AuthRegistry;
    let random: SignerWithAddress;
    let governance: Governance;
    let superAdmin: SignerWithAddress;
    let governor: SignerWithAddress;
    let manager: SignerWithAddress;
    let relayWallet: SignerWithAddress;
    let relayWallet2: SignerWithAddress;

    beforeEach(async function () {
        [superAdmin, governor, manager, random, relayWallet, relayWallet2] =
            await ethers.getSigners();

        governance = await GovernanceFactory.create(
            superAdmin.address,
            governor.address,
            manager.address
        );

        authRegistry = await AuthRegistryFactory.create(governance.address);
    });

    describe("Deployment", function () {
        it("should have set correct governance", async function () {
            expect(await authRegistry.governance()).to.equal(governance.address);
        });
    });

    describe("AddRelayAddress", function () {
        context("success", function () {
            it("should not be relay to start", async function () {
                expect(
                    await authRegistry.isAuthAddress(relayWallet.address)
                ).to.be.eq(false);
                expect(await authRegistry.authAddressesCount()).to.be.eq(0);
            });

            it("should succeed if called by governor", async function () {
                await authRegistry
                    .connect(governor)
                    .addAuthAddress(relayWallet.address);

                expect(await authRegistry.getAuthAddressByIdx(0)).to.be.eq(
                    relayWallet.address
                );
                expect(await authRegistry.authAddressesCount()).to.be.eq(1);
            });

            it("should emit AuthAddressAdded event", async function () {
                await expect(
                    authRegistry
                        .connect(governor)
                        .addAuthAddress(relayWallet.address)
                )
                    .to.emit(authRegistry, "AuthAddressAdded")
                    .withArgs(relayWallet.address);
            });
        });

        context("failures", function () {
            it("should revert if called by non-governor", async function () {
                await expect(
                    authRegistry.connect(random).addAuthAddress(relayWallet.address)
                ).to.be.revertedWith("Unauthorized()");
            });

            it("should revert if address already exists", async function () {
                await authRegistry
                    .connect(governor)
                    .addAuthAddress(relayWallet.address);

                await expect(
                    authRegistry
                        .connect(governor)
                        .addAuthAddress(relayWallet.address)
                ).to.be.revertedWith("AddressExists()");
            });
        });
    });

    describe("DisableRelayAddress", function () {
        beforeEach(async function () {
            await authRegistry.connect(governor).addAuthAddress(relayWallet.address);
        });

        context("success", function () {
            it("should succeed if called by governor", async function () {
                await authRegistry
                    .connect(governor)
                    .disableAuthAddress(relayWallet.address);
                expect(
                    await authRegistry.isAuthAddress(relayWallet.address)
                ).to.be.eq(false);
                expect(await authRegistry.getAuthAddressByIdx(0)).to.be.eq(
                    relayWallet.address
                );
                expect(await authRegistry.authAddressesCount()).to.be.eq(1);
            });

            it("should emit AuthAddressDisabled event", async function () {
                await expect(
                    authRegistry
                        .connect(governor)
                        .disableAuthAddress(relayWallet.address)
                )
                    .to.emit(authRegistry, "AuthAddressDisabled")
                    .withArgs(relayWallet.address);
            });
        });

        context("failures", function () {
            it("should revert if called by non-governor", async function () {
                await expect(
                    authRegistry
                        .connect(random)
                        .disableAuthAddress(relayWallet.address)
                ).to.be.revertedWith("Unauthorized()");
            });

            it("should revert if address does not exist", async function () {
                await expect(
                    authRegistry
                        .connect(governor)
                        .disableAuthAddress(relayWallet2.address)
                ).to.be.revertedWith("AddressInvalid()");
            });
        });
    });
});
