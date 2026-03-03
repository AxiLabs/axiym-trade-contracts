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

describe("T-V2-G: OnTradeExchange - Cancelling Trades in Queue", function () {
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
            [], // no company accounts
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
        axiymFeeCompanyAccount = await CompanyAccountFactory.create(
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
            .setFeeCompanyAccount(axiymFeeCompanyAccount.address);

        const blockNumBefore = await ethers.provider.getBlockNumber();
        const blockBefore = await ethers.provider.getBlock(blockNumBefore);
        timestampPrior = blockBefore.timestamp;
    });

    describe("Cancel Trade Uint", function () {
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

            // cancel trade
            await ethers.provider.send("evm_setNextBlockTimestamp", [
                timestampPrior + 86400 * 3,
            ]);
            await onTradeExchange.connect(relay).cancelTrade(1); // move id 2, to where 1 is, and false = put it before
        });
        it("should have correct OnTradeExchange queue", async function () {
            await checkTradeBook(onTradeExchange, [2], false); // head -> tail, 1
        });
        it("should have correct OnTradeExchange stats", async function () {
            await checkOnTradeExchangeStats(
                onTradeExchange,
                protocol.IUSD, // off asset
                protocol.USDC, // on asset
                BigNumber.from(100).mul(USD), // total queued amount
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
                BigNumber.from(100).mul(USD), // currentpayoutSize
                companyAccount1.address, // company account which made tx
                protocol.IUSD.address, // sell asset address
                protocol.USDC.address, // buy asset address
                BigNumber.from(timestampPrior + 86400), // created at
                BigNumber.from(0), // executed at
                BigNumber.from(timestampPrior + 86400 * 3), // cancelled at
                TradeState.Cancelled,
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
    describe("Cancel Trade Bytes", function () {
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

            await ethers.provider.send("evm_setNextBlockTimestamp", [
                timestampPrior + 86400 * 3,
            ]);
            await onTradeExchange.connect(relay).cancelTradeBytes(tradeBytes1); // move id 2, to where 1 is, and false = put it before
        });
        it("should have correct OnTradeExchange queue", async function () {
            await checkTradeBook(onTradeExchange, [2], false); // head -> tail, 1
        });
        it("should have correct OnTradeExchange stats", async function () {
            await checkOnTradeExchangeStats(
                onTradeExchange,
                protocol.IUSD, // off asset
                protocol.USDC, // on asset
                BigNumber.from(100).mul(USD), // total queued amount
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
                BigNumber.from(timestampPrior + 86400 * 3), // cancelled at
                TradeState.Cancelled,
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
});
