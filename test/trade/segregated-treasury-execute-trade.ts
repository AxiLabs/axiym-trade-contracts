import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ethers } from "hardhat";
import { expect } from "chai";

import { MockOnTradeExchange, SegregatedTreasury } from "../../typechain";
import { OnTradeProtocolFactory } from "./factories/on-trade-protocol.factory";
import { MockOnTradeExchangeFactory } from "./factories/mock-on-trade-exchange.factory";
import { SegregatedTreasuryFactory } from "./factories/segregated-treasury.factory";

import { BigNumber } from "ethers";
import { USD } from "../common/constants.factory";

describe("SegregatedTreasury – executeTrade Isolation", function () {
    let owner: SignerWithAddress;
    let relay: SignerWithAddress;
    let randomUser: SignerWithAddress;
    let superAdmin: SignerWithAddress;
    let governor: SignerWithAddress;
    let manager: SignerWithAddress;
    let authorizer: SignerWithAddress;

    let protocol: any;
    let segregatedTreasury: SegregatedTreasury;
    let mockExchange: MockOnTradeExchange;

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

        // deploy mock exchange
        mockExchange = await MockOnTradeExchangeFactory.create(
            protocol.IUSD.address
        );

        // deploy treasury directly with mock as onTradeExchange
        const TreasuryFactory = await ethers.getContractFactory(
            "SegregatedTreasury"
        );
        const deployedTreasury = await TreasuryFactory.deploy(
            mockExchange.address,
            owner.address,
            protocol.IUSD.address,
            protocol.USDC.address
        );
        await deployedTreasury.deployed();

        segregatedTreasury = await SegregatedTreasuryFactory.attach(
            deployedTreasury.address
        );

        // fund treasury with USDC (onAsset)
        await protocol.USDC.connect(relay).transfer(
            segregatedTreasury.address,
            BigNumber.from(1000).mul(USD)
        );

        // fund mock exchange with IUSD (offAsset)
        await protocol.IUSD.connect(relay).mint(
            mockExchange.address,
            BigNumber.from(1000).mul(USD)
        );
    });
    describe("executeTrade", function () {
        context("success", function () {
            it("should execute trade correctly and swap assets", async function () {
                const amount = BigNumber.from(100).mul(USD);

                await mockExchange.callExecuteTrade(
                    segregatedTreasury.address,
                    1,
                    amount,
                    amount
                );

                expect(await protocol.USDC.balanceOf(mockExchange.address)).to.equal(
                    amount
                );
                expect(
                    await protocol.IUSD.balanceOf(segregatedTreasury.address)
                ).to.equal(amount);
            });

            it("should reduce treasury onAsset balance correctly", async function () {
                const amount = BigNumber.from(100).mul(USD);

                await mockExchange.callExecuteTrade(
                    segregatedTreasury.address,
                    1,
                    amount,
                    amount
                );

                expect(
                    await protocol.USDC.balanceOf(segregatedTreasury.address)
                ).to.equal(BigNumber.from(900).mul(USD));
            });

            it("should emit TradePayment event", async function () {
                const amount = BigNumber.from(100).mul(USD);

                await expect(
                    mockExchange.callExecuteTrade(
                        segregatedTreasury.address,
                        1,
                        amount,
                        amount
                    )
                )
                    .to.emit(segregatedTreasury, "TradePayment")
                    .withArgs(1, amount);
            });

            it("should allow partial payment where amount is less than validatedPayoutSize", async function () {
                const amount = BigNumber.from(50).mul(USD);
                const validatedPayout = BigNumber.from(100).mul(USD);

                await mockExchange.callExecuteTrade(
                    segregatedTreasury.address,
                    1,
                    amount,
                    validatedPayout
                );

                expect(await protocol.USDC.balanceOf(mockExchange.address)).to.equal(
                    amount
                );
            });

            it("should allow amount equal to validatedPayoutSize", async function () {
                const amount = BigNumber.from(100).mul(USD);

                await mockExchange.callExecuteTrade(
                    segregatedTreasury.address,
                    1,
                    amount,
                    amount
                );

                expect(await protocol.USDC.balanceOf(mockExchange.address)).to.equal(
                    amount
                );
            });
        });
        context("failure cases", function () {
            it("should revert if called by non-onTradeExchange", async function () {
                const amount = BigNumber.from(100).mul(USD);

                await expect(
                    segregatedTreasury
                        .connect(randomUser)
                        .executeTrade(1, amount, amount)
                ).to.be.revertedWith("NotOnTradeExchange()");
            });
            it("should revert if amount exceeds validatedPayoutSize", async function () {
                const amount = BigNumber.from(100).mul(USD);
                const validatedPayout = BigNumber.from(50).mul(USD);

                await expect(
                    mockExchange.callExecuteTrade(
                        segregatedTreasury.address,
                        1,
                        amount,
                        validatedPayout
                    )
                ).to.be.revertedWith("AmountExceedsCurrentPayout()");
            });
            it("should revert if insufficient treasury onAsset balance", async function () {
                const amount = BigNumber.from(2000).mul(USD);

                await expect(
                    mockExchange.callExecuteTrade(
                        segregatedTreasury.address,
                        1,
                        amount,
                        amount
                    )
                ).to.be.revertedWith("InsufficientTreasuryBalance()");
            });
            it("should revert when paused", async function () {
                await segregatedTreasury.connect(owner).pause();
                const amount = BigNumber.from(100).mul(USD);

                await expect(
                    mockExchange.callExecuteTrade(
                        segregatedTreasury.address,
                        1,
                        amount,
                        amount
                    )
                ).to.be.revertedWith("EnforcedPause()");
            });
        });
    });
});
