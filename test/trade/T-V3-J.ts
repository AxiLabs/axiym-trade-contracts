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
    checkTradeReceipt,
    depositSegregatedTreasuryAtTime,
    mintAndOnTradeAtTime,
} from "./helpers/helpers";
import { TradeState } from "./enums/trade-status.enum";

describe.only("T-V3-J: OnTradeExchange - Single Trade Execution (no partial execution)", function () {
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
    let axiymFeeCompanyAccount: CompanyAccount;

    let timestampPrior: number;
    let totalOnAmount: BigNumber;

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

        // Setup Contracts
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

        companyAccount1 = await CompanyAccountFactory.create(
            relay,
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

        axiymFeeCompanyAccount = await CompanyAccountFactory.create(
            relay,
            protocol.governance.address,
            protocol.authRegistry.address,
            signer2.address
        );

        await onTradeExchange
            .connect(authorizer)
            .addCompanyAccount(companyAccount1.address);
        await onTradeExchange
            .connect(governor)
            .setFeeCompanyAccount(axiymFeeCompanyAccount.address);

        const blockNumBefore = await ethers.provider.getBlockNumber();
        const blockBefore = await ethers.provider.getBlock(blockNumBefore);
        timestampPrior = blockBefore.timestamp;
    });

    describe("Single Trade Execution Uint", function () {
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
                BigNumber.from(150).mul(USD), // amount
                BigNumber.from(0), // fee
                2, // nonce
                protocol.IUSD,
                onTradeExchange,
                relay,
                timestampPrior + 86400 * 2
            );

            // stop auto execution
            await ethers.provider.send("evm_setNextBlockTimestamp", [
                timestampPrior + 86400 * 3,
            ]);
            await onTradeExchange.connect(governor).setAutoExecution(false); // move id 2, to where 1 is, and false = put it before

            // stop deposit treasury
            await depositSegregatedTreasuryAtTime(
                segregatedTreasury.address, // on trade treasury address
                BigNumber.from(150).mul(USD), // amount
                protocol.USDC, // stablecoin
                relay, // relay address
                timestampPrior + 86400 * 4
            );

            // execute trade
            await ethers.provider.send("evm_setNextBlockTimestamp", [
                timestampPrior + 86400 * 5,
            ]);
            await onTradeExchange.connect(relay).executeSingleTrade(2);
        });
        it("should have correct OnTradeExchange queue", async function () {
            await checkTradeBook(onTradeExchange, [1], false); // head -> tail, 1
        });
        it("should have correct OnTradeExchange stats", async function () {
            await checkOnTradeExchangeStats(
                onTradeExchange,
                protocol.IUSD, // off asset
                protocol.USDC, // on asset
                BigNumber.from(100).mul(USD), // total queued amount
                BigNumber.from(250).mul(USD), // total queued cumulative
                BigNumber.from(100).mul(USD), // IUSD balance
                BigNumber.from(0) // no USDT
            );
        });
        it("should have correct SegregatedTreasury stats", async function () {
            await checkSegregatedTreasuryStats(
                segregatedTreasury,
                protocol.IUSD, // off asset
                protocol.USDC, // on asset
                BigNumber.from(150).mul(USD), // IUSD balance
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
                BigNumber.from(150).mul(USD), // sell asset quote amount#
                BigNumber.from(150).mul(USD), // buy asset quote amount
                BigNumber.from(0).mul(USD), // axiymFee
                BigNumber.from(0).mul(USD), // totalFee
                BigNumber.from(150).mul(USD), // initialpayoutSize
                BigNumber.from(0).mul(USD), // currentpayoutSize
                companyAccount1.address, // company account which made tx
                protocol.IUSD.address, // sell asset address
                protocol.USDC.address, // buy asset address
                BigNumber.from(timestampPrior + 86400 * 2), // created at
                BigNumber.from(timestampPrior + 86400 * 5), // executed at
                BigNumber.from(0), // cancelled at
                TradeState.Executed,
                false // verbose
            );
        });
        it("should have correct trade 2, payment receipt 1", async function () {
            await checkTradeReceipt(
                onTradeExchange, // trade pool contract
                BigNumber.from(2), // trade uint
                0, // receipt index
                BigNumber.from(150).mul(USD), // payout size
                BigNumber.from(0).mul(USD), // axiymFee associated wtih this payment
                BigNumber.from(0).mul(USD), // providerFee associated with this payment
                BigNumber.from(timestampPrior + 86400 * 5), // executed at (executed in same block)
                false // verbose
            );
        });
    });
    describe("Single Trade Execution Bytes", function () {
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
                BigNumber.from(150).mul(USD), // amount
                BigNumber.from(0), // fee
                2, // nonce
                protocol.IUSD,
                onTradeExchange,
                relay,
                timestampPrior + 86400 * 2
            );

            // stop auto execution
            await ethers.provider.send("evm_setNextBlockTimestamp", [
                timestampPrior + 86400 * 3,
            ]);
            await onTradeExchange.connect(governor).setAutoExecution(false); // move id 2, to where 1 is, and false = put it before

            // stop deposit treasury
            await depositSegregatedTreasuryAtTime(
                segregatedTreasury.address, // on trade treasury address
                BigNumber.from(150).mul(USD), // amount
                protocol.USDC, // stablecoin
                relay, // relay address
                timestampPrior + 86400 * 4
            );

            // execute trade bytes
            const tradeBytes2 = await onTradeExchange.getTradeBytesFromUint(2);
            await ethers.provider.send("evm_setNextBlockTimestamp", [
                timestampPrior + 86400 * 5,
            ]);
            await onTradeExchange
                .connect(relay)
                .executeSingleTradeBytes(tradeBytes2);
        });
        it("should have correct OnTradeExchange queue", async function () {
            await checkTradeBook(onTradeExchange, [1], false); // head -> tail, 1
        });
        it("should have correct OnTradeExchange stats", async function () {
            await checkOnTradeExchangeStats(
                onTradeExchange,
                protocol.IUSD, // off asset
                protocol.USDC, // on asset
                BigNumber.from(100).mul(USD), // total queued amount
                BigNumber.from(250).mul(USD), // total queued cumulative
                BigNumber.from(100).mul(USD), // IUSD balance
                BigNumber.from(0) // no USDT
            );
        });
        it("should have correct SegregatedTreasury stats", async function () {
            await checkSegregatedTreasuryStats(
                segregatedTreasury,
                protocol.IUSD, // off asset
                protocol.USDC, // on asset
                BigNumber.from(150).mul(USD), // IUSD balance
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
                BigNumber.from(150).mul(USD), // sell asset quote amount#
                BigNumber.from(150).mul(USD), // buy asset quote amount
                BigNumber.from(0).mul(USD), // axiymFee
                BigNumber.from(0).mul(USD), // totalFee
                BigNumber.from(150).mul(USD), // initialpayoutSize
                BigNumber.from(0).mul(USD), // currentpayoutSize
                companyAccount1.address, // company account which made tx
                protocol.IUSD.address, // sell asset address
                protocol.USDC.address, // buy asset address
                BigNumber.from(timestampPrior + 86400 * 2), // created at
                BigNumber.from(timestampPrior + 86400 * 5), // executed at
                BigNumber.from(0), // cancelled at
                TradeState.Executed,
                false // verbose
            );
        });
        it("should have correct trade 2, payment receipt 1", async function () {
            await checkTradeReceipt(
                onTradeExchange, // trade pool contract
                BigNumber.from(2), // trade uint
                0, // receipt index
                BigNumber.from(150).mul(USD), // payout size
                BigNumber.from(0).mul(USD), // axiymFee associated wtih this payment
                BigNumber.from(0).mul(USD), // providerFee associated with this payment
                BigNumber.from(timestampPrior + 86400 * 5), // executed at (executed in same block)
                false // verbose
            );
        });
    });
});
