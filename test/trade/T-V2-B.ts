import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ethers } from "hardhat";
import { expect } from "chai";
import {
    CompanyAccount,
    OnTradeExchange,
    SegregatedTreasury,
} from "../../typechain";
import { CompanyAccountFactory } from "../company_account/factories/company-accounts.factory";

import { BigNumber } from "ethers";
import { USD } from "../common/constants.factory";

import { OnTradeProtocolFactory } from "./factories/on-trade-protocol.factory";
import {
    checkOnTradeExchangeStats,
    checkSegregatedTreasuryStats,
    checkTrade,
    checkTradeBook,
    mintAndOnTradeAtTime,
} from "./helpers/helpers";
import { TradeState } from "./enums/trade-status.enum";

describe("T-V2-B: OnTradeExchange - Moving Trades in Queue & getQueuedTrades", function () {
    let superAdmin: SignerWithAddress;
    let governor: SignerWithAddress;
    let manager: SignerWithAddress;
    let authorizer: SignerWithAddress;
    let owner: SignerWithAddress;
    let relay: SignerWithAddress;

    let protocol: any;

    let signer1: SignerWithAddress;
    let receiver1: SignerWithAddress;
    let signer2: SignerWithAddress;
    let receiver2: SignerWithAddress;

    let onTradeExchange: OnTradeExchange;
    let segregatedTreasury: SegregatedTreasury;

    let companyAccount1: CompanyAccount;
    let feeCompanyAccount: CompanyAccount;

    let debug = false;
    let timestampPrior: number;

    beforeEach(async function () {
        [
            superAdmin,
            governor,
            manager,
            authorizer,
            owner,
            relay,
            signer1,
            receiver1,
            signer2,
            receiver2,
        ] = await ethers.getSigners();

        // create and setup contracts
        protocol = await OnTradeProtocolFactory.create(
            superAdmin,
            governor,
            manager,
            authorizer,
            relay.address,
            false
        );

        // setup currencies
        await OnTradeProtocolFactory.addIUSD(protocol, false);
        await OnTradeProtocolFactory.addUSDC(protocol, relay, false);

        // setup exchange pools and treasury
        await OnTradeProtocolFactory.createOnRamp(
            protocol,
            owner.address,
            protocol.IUSD.address,
            protocol.USDC.address,
            [], // no company accounys
            ethers.constants.AddressZero // zero axiym fee address
        );

        // rename pools for ease of use
        onTradeExchange = protocol.onTradeExchanges[0];
        segregatedTreasury = protocol.segregatedTreasuries[0];

        // create company account - on ramp
        companyAccount1 = await CompanyAccountFactory.create(
            superAdmin, // deployer
            protocol.governance.address,
            protocol.authRegistry.address,
            signer1.address
        );

        await CompanyAccountFactory.setup(
            companyAccount1,
            protocol.governor,
            protocol.authorizer,
            signer1,
            [protocol.IUSD.address],
            [receiver1.address],
            [[onTradeExchange.address]]
        );

        // create axiym fee company account
        feeCompanyAccount = await CompanyAccountFactory.create(
            superAdmin, // deployer
            protocol.governance.address,
            protocol.authRegistry.address,
            signer2.address
        );

        // authorize companyAccount 1 and 2 for exchangePool 1
        await onTradeExchange
            .connect(authorizer)
            .addCompanyAccount(companyAccount1.address);
        await onTradeExchange
            .connect(governor)
            .setFeeCompanyAccount(feeCompanyAccount.address);

        const blockNumBefore = await ethers.provider.getBlockNumber();
        const blockBefore = await ethers.provider.getBlock(blockNumBefore);
        timestampPrior = blockBefore.timestamp;
    });

    describe("Move Trade Uint", function () {
        beforeEach(async function () {
            await mintAndOnTradeAtTime(
                signer1,
                companyAccount1,
                BigNumber.from(100).mul(USD), // amount
                BigNumber.from(0), // fee
                1, // nonce
                protocol.IUSD,
                onTradeExchange,
                relay,
                timestampPrior + 86400
            );
            await mintAndOnTradeAtTime(
                signer1,
                companyAccount1,
                BigNumber.from(100).mul(USD), // amount
                BigNumber.from(0), // fee
                2, // nonce
                protocol.IUSD,
                onTradeExchange,
                relay,
                timestampPrior + 86400 * 2
            );
            await onTradeExchange.connect(relay).move(2, 1, false); // move id 2, to where 1 is, and false = put it before
        });
        it("should have correct OnTradeExchange queue", async function () {
            await checkTradeBook(onTradeExchange, [2, 1], false); // head -> tail, 1
        });
        it("should have correct OnTradeExchange stats", async function () {
            await checkOnTradeExchangeStats(
                onTradeExchange,
                protocol.IUSD, // off asset
                protocol.USDC, // on asset
                BigNumber.from(200).mul(USD), // total queued amount
                BigNumber.from(200).mul(USD), // total queued cumulative
                BigNumber.from(200).mul(USD), // IUSD balance
                BigNumber.from(0) // no USDT
            );
        });
        it("should have correct SegregatedTreasury stats", async function () {
            await checkSegregatedTreasuryStats(
                segregatedTreasury,
                protocol.IUSD, // off asset
                protocol.USDC, // on asset
                BigNumber.from(0).mul(USD), // IUSD balance
                BigNumber.from(0) // no USDT
            );
        });
        it("should have correct trade 1 stats", async function () {
            await checkTrade(
                onTradeExchange, // trade pool contract
                BigNumber.from(1), // trade uint
                BigNumber.from(100).mul(USD), // sell asset quote amount#
                BigNumber.from(100).mul(USD), // buy asset quote amount
                BigNumber.from(0).mul(USD), // axiymFee
                BigNumber.from(0).mul(USD), // totalFee
                BigNumber.from(100).mul(USD), // initialpayoutSize
                BigNumber.from(100).mul(USD), // initialpayoutSize
                companyAccount1.address, // company account which made tx
                protocol.IUSD.address, // sell asset address
                protocol.USDC.address, // buy asset address
                BigNumber.from(timestampPrior + 86400), // created at
                BigNumber.from(0), // executed at
                BigNumber.from(0), // cancelled at
                TradeState.Pending,
                false // verbose
            );
        });
        it("should have correct trade 2 stats", async function () {
            await checkTrade(
                onTradeExchange, // trade pool contract
                BigNumber.from(2), // trade uint
                BigNumber.from(100).mul(USD), // sell asset quote amount#
                BigNumber.from(100).mul(USD), // buy asset quote amount
                BigNumber.from(0).mul(USD), // axiymFee
                BigNumber.from(0).mul(USD), // totalFee
                BigNumber.from(100).mul(USD), // initialpayoutSize
                BigNumber.from(100).mul(USD), // initialpayoutSize
                companyAccount1.address, // company account which made tx
                protocol.IUSD.address, // sell asset address
                protocol.USDC.address, // buy asset address
                BigNumber.from(timestampPrior + 86400 * 2), // created at
                BigNumber.from(0), // executed at
                BigNumber.from(0), // cancelled at
                TradeState.Pending,
                false // verbose
            );
        });
    });
    describe("Move Trade Bytes", function () {
        beforeEach(async function () {
            await mintAndOnTradeAtTime(
                signer1,
                companyAccount1,
                BigNumber.from(100).mul(USD), // amount
                BigNumber.from(0), // fee
                1, // nonce
                protocol.IUSD,
                onTradeExchange,
                relay,
                timestampPrior + 86400
            );
            await mintAndOnTradeAtTime(
                signer1,
                companyAccount1,
                BigNumber.from(100).mul(USD), // amount
                BigNumber.from(0), // fee
                2, // nonce
                protocol.IUSD,
                onTradeExchange,
                relay,
                timestampPrior + 86400 * 2
            );
            const tradeBytes1 = await onTradeExchange.getTradeBytesFromUint(1);
            const tradeBytes2 = await onTradeExchange.getTradeBytesFromUint(2);

            await onTradeExchange
                .connect(relay)
                .moveBytes(tradeBytes2, tradeBytes1, false); // move id 2, to where 1 is, and false = put it before
        });
        it("should have correct OnTradeExchange queue", async function () {
            await checkTradeBook(onTradeExchange, [2, 1], false); // head -> tail, 1
        });
        it("should have correct OnTradeExchange stats", async function () {
            await checkOnTradeExchangeStats(
                onTradeExchange,
                protocol.IUSD, // off asset
                protocol.USDC, // on asset
                BigNumber.from(200).mul(USD), // total queued amount
                BigNumber.from(200).mul(USD), // total queued cumulative
                BigNumber.from(200).mul(USD), // IUSD balance
                BigNumber.from(0) // no USDT
            );
        });
        it("should have correct SegregatedTreasury stats", async function () {
            await checkSegregatedTreasuryStats(
                segregatedTreasury,
                protocol.IUSD, // off asset
                protocol.USDC, // on asset
                BigNumber.from(0).mul(USD), // IUSD balance
                BigNumber.from(0) // no USDT
            );
        });
        it("should have correct trade 1 stats", async function () {
            await checkTrade(
                onTradeExchange, // trade pool contract
                BigNumber.from(1), // trade uint
                BigNumber.from(100).mul(USD), // sell asset quote amount#
                BigNumber.from(100).mul(USD), // buy asset quote amount
                BigNumber.from(0).mul(USD), // axiymFee
                BigNumber.from(0).mul(USD), // totalFee
                BigNumber.from(100).mul(USD), // initialpayoutSize
                BigNumber.from(100).mul(USD), // initialpayoutSize
                companyAccount1.address, // company account which made tx
                protocol.IUSD.address, // sell asset address
                protocol.USDC.address, // buy asset address
                BigNumber.from(timestampPrior + 86400), // created at
                BigNumber.from(0), // executed at
                BigNumber.from(0), // cancelled at
                TradeState.Pending,
                false // verbose
            );
        });
        it("should have correct trade 2 stats", async function () {
            await checkTrade(
                onTradeExchange, // trade pool contract
                BigNumber.from(2), // trade uint
                BigNumber.from(100).mul(USD), // sell asset quote amount#
                BigNumber.from(100).mul(USD), // buy asset quote amount
                BigNumber.from(0).mul(USD), // axiymFee
                BigNumber.from(0).mul(USD), // totalFee
                BigNumber.from(100).mul(USD), // initialpayoutSize
                BigNumber.from(100).mul(USD), // initialpayoutSize
                companyAccount1.address, // company account which made tx
                protocol.IUSD.address, // sell asset address
                protocol.USDC.address, // buy asset address
                BigNumber.from(timestampPrior + 86400 * 2), // created at
                BigNumber.from(0), // executed at
                BigNumber.from(0), // cancelled at
                TradeState.Pending,
                false // verbose
            );
        });
    });
    describe("getQueuedTradesPaginated", function () {
        beforeEach(async function () {
            for (let i = 1; i <= 4; i++) {
                await mintAndOnTradeAtTime(
                    signer1,
                    companyAccount1,
                    BigNumber.from(100).mul(USD),
                    BigNumber.from(0),
                    i,
                    protocol.IUSD,
                    onTradeExchange,
                    relay,
                    timestampPrior + 86400 * i
                );
            }
        });

        context("success", function () {
            it("should return first page correctly", async function () {
                const [tradeIds, , nextId] =
                    await onTradeExchange.getQueuedTradesPaginated(0, 2);

                expect(tradeIds.length).to.equal(2);
                expect(tradeIds[0]).to.equal(1);
                expect(tradeIds[1]).to.equal(2);
                expect(nextId).to.equal(3);
            });

            it("should return second page correctly", async function () {
                const [tradeIds1, ,] =
                    await onTradeExchange.getQueuedTradesPaginated(0, 2);

                const lastIdOfPage1 = tradeIds1[tradeIds1.length - 1];

                const [tradeIds, , nextId2] =
                    await onTradeExchange.getQueuedTradesPaginated(lastIdOfPage1, 2);

                expect(tradeIds.length).to.equal(2);
                expect(tradeIds[0]).to.equal(3);
                expect(tradeIds[1]).to.equal(4);
                expect(nextId2).to.equal(0);
            });

            it("should return trimmed array when page size exceeds remaining trades", async function () {
                const [tradeIds, , nextId] =
                    await onTradeExchange.getQueuedTradesPaginated(0, 10);

                expect(tradeIds.length).to.equal(4);
                expect(nextId).to.equal(0);
            });

            it("should return empty arrays when queue is empty", async function () {
                for (let i = 1; i <= 4; i++) {
                    await onTradeExchange.connect(relay).cancelTrade(i);
                }

                const [tradeIds, , nextId] =
                    await onTradeExchange.getQueuedTradesPaginated(0, 10);

                expect(tradeIds.length).to.equal(0);
                expect(nextId).to.equal(0);
            });

            it("should return 0 nextId when last page is exactly full", async function () {
                const [tradeIds, , nextId] =
                    await onTradeExchange.getQueuedTradesPaginated(0, 4);

                expect(tradeIds.length).to.equal(4);
                expect(nextId).to.equal(0);
            });

            it("should paginate through all trades correctly", async function () {
                const allIds: number[] = [];
                let startId = 0;
                const pageSize = 2;

                while (true) {
                    const [tradeIds, , nextId] =
                        await onTradeExchange.getQueuedTradesPaginated(
                            startId,
                            pageSize
                        );

                    for (const id of tradeIds) {
                        allIds.push(id.toNumber());
                    }

                    if (nextId.eq(0)) break;
                    startId = tradeIds[tradeIds.length - 1].toNumber();
                }

                expect(allIds).to.deep.equal([1, 2, 3, 4]);
            });
        });
    });
});
