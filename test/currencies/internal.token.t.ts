/* eslint-disable node/no-missing-import */
import { expect } from "chai";
import { ethers } from "hardhat";
import { BigNumber } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import { AuthRegistry, Governance, IUSD } from "../../typechain";

import { IUSDFactory } from "./factories/iusd.factory";
import { GovernanceFactory } from "../governance/factories/governance.factory";
import { AuthRegistryFactory } from "../auth_registry/factories/auth-registry.factory";

describe("IUSD Contract (InternalToken)", function () {
    let iusd: IUSD;
    let authRegistry: AuthRegistry;
    let governance: Governance;

    let superAdmin: SignerWithAddress;
    let governor: SignerWithAddress;
    let manager: SignerWithAddress;
    let authorizer: SignerWithAddress;
    let random: SignerWithAddress;
    let relay: SignerWithAddress;
    let borrower: SignerWithAddress;
    let other: SignerWithAddress;

    const amount100 = BigNumber.from(100_000_000); // 100 tokens with 6 decimals
    const amount10 = BigNumber.from(10_000_000); // 10 tokens
    const amount1 = BigNumber.from(1_000_000); // 1 token

    beforeEach(async function () {
        [superAdmin, governor, manager, authorizer, random, relay, borrower, other] =
            await ethers.getSigners();

        governance = await GovernanceFactory.create(
            superAdmin.address,
            governor.address,
            manager.address,
            authorizer.address
        );

        authRegistry = await AuthRegistryFactory.create(governance.address);

        await authRegistry.connect(governor).addAuthAddress(relay.address);

        iusd = await IUSDFactory.create(authRegistry.address);
    });

    describe("Deployment", function () {
        it("should set initial metadata correctly", async function () {
            expect(await iusd.name()).to.equal("IUSD");
            expect(await iusd.symbol()).to.equal("IUSD");
            expect(await iusd.decimals()).to.equal(6);
            expect(await iusd.liquidityCurrency()).to.equal(840);
        });
    });

    describe("approve", function () {
        context("failures", function () {
            beforeEach(async function () {
                await iusd.connect(relay).mint(borrower.address, amount10);
            });
        });

        context("success", function () {
            beforeEach(async function () {
                await iusd.connect(relay).mint(relay.address, amount10);
            });
            it("should allow approve by non-active account", async function () {
                await expect(iusd.connect(relay).approve(other.address, amount1))
                    .to.emit(iusd, "Approval")
                    .withArgs(relay.address, other.address, amount1);
            });
        });
    });

    describe("ownerApprove", function () {
        context("failures", function () {
            it("should revert if caller is not in auth registry", async function () {
                await expect(
                    iusd
                        .connect(random)
                        .ownerApprove(relay.address, other.address, amount1)
                ).to.be.revertedWith("Unauthorized()");
            });
        });

        context("success", function () {
            beforeEach(async function () {
                await iusd.connect(relay).mint(relay.address, amount10);
                await iusd
                    .connect(relay)
                    .ownerApprove(relay.address, other.address, amount1);
            });
            it("should allowance tokens from one address to another", async function () {
                expect(await iusd.allowance(relay.address, other.address)).to.equal(
                    amount1
                );
            });
        });
    });

    describe("mint", function () {
        context("failures", function () {
            it("should revert if caller is not relay", async function () {
                await expect(
                    iusd.connect(random).mint(other.address, amount10)
                ).to.be.revertedWith("Unauthorized()");
            });
        });

        context("success", function () {
            beforeEach(async function () {
                await iusd.connect(relay).mint(other.address, amount10);
            });
            it("should increase balance of minted account", async function () {
                expect(await iusd.balanceOf(other.address)).to.equal(amount10);
            });
        });
    });

    describe("burn", function () {
        context("failures", function () {
            it("should revert if caller is not relay", async function () {
                await expect(
                    iusd.connect(random).burn(other.address, amount1)
                ).to.be.revertedWith("Unauthorized()");
            });
        });

        context("success", function () {
            beforeEach(async function () {
                await iusd.connect(relay).mint(other.address, amount10);
                await iusd.connect(relay).burn(other.address, amount1);
            });
            it("should reduce balance of burned address", async function () {
                expect(await iusd.balanceOf(other.address)).to.equal(
                    amount10.sub(amount1)
                );
            });
        });
    });

    describe("liquidityCurrency", function () {
        it("should return correct currency ID", async function () {
            expect(await iusd.liquidityCurrency()).to.equal(840);
        });
    });
});
