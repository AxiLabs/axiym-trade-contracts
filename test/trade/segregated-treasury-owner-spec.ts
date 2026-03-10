import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ethers } from "hardhat";
import { expect } from "chai";

import {
    CompanyAccount,
    OnTradeExchange,
    SegregatedTreasury,
} from "../../typechain";
import { OnTradeProtocolFactory } from "./factories/on-trade-protocol.factory";

import { BigNumber } from "ethers";
import { USD } from "../common/constants.factory";
import { CompanyAccountFactory } from "../company_account/factories/company-accounts.factory";

describe("SegregatedTreasury – Owner Functions", function () {
    let superAdmin: SignerWithAddress;
    let governor: SignerWithAddress;
    let manager: SignerWithAddress;
    let authorizer: SignerWithAddress;
    let owner: SignerWithAddress;
    let relay: SignerWithAddress;
    let randomUser: SignerWithAddress;

    let protocol: any;
    let onTradeExchange: OnTradeExchange;
    let segregatedTreasury: SegregatedTreasury;
    let axiymFeeCompanyAccount: CompanyAccount;

    beforeEach(async function () {
        [superAdmin, governor, manager, authorizer, owner, relay, randomUser] =
            await ethers.getSigners();

        protocol = await OnTradeProtocolFactory.create(
            superAdmin,
            governor,
            manager,
            authorizer,
            relay.address,
            false
        );

        await OnTradeProtocolFactory.addIUSD(protocol, false);
        await OnTradeProtocolFactory.addUSDC(protocol, relay, false);

        // create axiym fee company account
        axiymFeeCompanyAccount = await CompanyAccountFactory.create(
            superAdmin, // deployer
            protocol.governance.address,
            protocol.authRegistry.address,
            randomUser.address
        );

        await OnTradeProtocolFactory.createOnRamp(
            protocol,
            owner.address,
            protocol.IUSD.address,
            protocol.USDC.address,
            [],
            ethers.constants.AddressZero
        );

        onTradeExchange = protocol.onTradeExchanges[0];
        segregatedTreasury = protocol.segregatedTreasuries[0];
    });
    describe("pause", function () {
        context("failure cases", function () {
            it("should revert if called by non-owner", async function () {
                await expect(
                    segregatedTreasury.connect(randomUser).pause()
                ).to.be.revertedWith("NotOwner()");
            });
        });
        context("success", function () {
            it("should pause the treasury", async function () {
                await segregatedTreasury.connect(owner).pause();
                expect(await segregatedTreasury.paused()).to.be.true;
            });
        });
    });
    describe("unpause", function () {
        beforeEach(async function () {
            await segregatedTreasury.connect(owner).pause();
        });
        context("failure cases", function () {
            it("should revert if called by non-owner", async function () {
                await expect(
                    segregatedTreasury.connect(randomUser).unpause()
                ).to.be.revertedWith("NotOwner()");
            });
        });
        context("success", function () {
            it("should unpause the treasury", async function () {
                await segregatedTreasury.connect(owner).unpause();
                expect(await segregatedTreasury.paused()).to.be.false;
            });
        });
    });
    describe("setOwner", function () {
        context("failure cases", function () {
            it("should revert if not called by owner", async function () {
                await expect(
                    segregatedTreasury
                        .connect(randomUser)
                        .setOwner(randomUser.address)
                ).to.be.revertedWith("NotOwner()");
            });
            it("should revert if new owner is zero address", async function () {
                await expect(
                    segregatedTreasury
                        .connect(owner)
                        .setOwner(ethers.constants.AddressZero)
                ).to.be.revertedWith("AddressEmpty()");
            });
            it("should revert if new owner is same as current", async function () {
                await expect(
                    segregatedTreasury.connect(owner).setOwner(owner.address)
                ).to.be.revertedWith("OwnerExists()");
            });
        });
        context("success", function () {
            it("should update owner correctly", async function () {
                await segregatedTreasury.connect(owner).setOwner(randomUser.address);
                expect(await segregatedTreasury.owner()).to.eq(randomUser.address);
            });
        });
    });

    describe("setReceiveAddress", function () {
        context("failure cases", function () {
            it("should revert if not owner", async function () {
                await expect(
                    segregatedTreasury
                        .connect(randomUser)
                        .setReceiveAddress(randomUser.address)
                ).to.be.revertedWith("NotOwner()");
            });
            it("should revert if address is zero", async function () {
                await expect(
                    segregatedTreasury
                        .connect(owner)
                        .setReceiveAddress(ethers.constants.AddressZero)
                ).to.be.revertedWith("AddressEmpty()");
            });
        });
        context("success", function () {
            it("should update receive address", async function () {
                await segregatedTreasury
                    .connect(owner)
                    .setReceiveAddress(randomUser.address);
                expect(await segregatedTreasury.receiveAddress()).to.eq(
                    randomUser.address
                );
            });
        });
    });

    describe("withdraw", function () {
        beforeEach(async function () {
            await segregatedTreasury
                .connect(owner)
                .setReceiveAddress(randomUser.address);

            // fund treasury with USDT
            await protocol.USDC.connect(relay).transfer(
                segregatedTreasury.address,
                BigNumber.from(100).mul(USD)
            );
        });
        context("failure cases", function () {
            it("should revert if not owner", async function () {
                await expect(
                    segregatedTreasury
                        .connect(randomUser)
                        .withdraw(BigNumber.from(1))
                ).to.be.revertedWith("NotOwner()");
            });
            it("should revert if amount is zero", async function () {
                await expect(
                    segregatedTreasury.connect(owner).withdraw(BigNumber.from(0))
                ).to.be.revertedWith("ZeroAmount()");
            });
            it("should revert if insufficient treasury balance", async function () {
                await expect(
                    segregatedTreasury
                        .connect(owner)
                        .withdraw(BigNumber.from(1000).mul(USD))
                ).to.be.revertedWith("InsufficientTreasuryBalance()");
            });
        });
        context("success", function () {
            it("should transfer funds to receive address", async function () {
                await segregatedTreasury
                    .connect(owner)
                    .withdraw(BigNumber.from(40).mul(USD));
                expect(
                    await protocol.USDC.balanceOf(segregatedTreasury.address)
                ).to.eq(BigNumber.from(60).mul(USD));
                expect(await protocol.USDC.balanceOf(randomUser.address)).to.eq(
                    BigNumber.from(40).mul(USD)
                );
            });
        });
    });
});
