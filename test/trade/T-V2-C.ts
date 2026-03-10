import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ethers } from "hardhat";
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
    checkCompanyAccount,
    checkOnTradeExchangeStats,
    checkSegregatedTreasuryStats,
    checkTrade,
    checkTradeBook,
    checkTradeReceipt,
    depositSegregatedTreasuryAtTime,
    mintAndOnTradeAtTime,
} from "./helpers/helpers";
import { TradeState } from "./enums/trade-status.enum";

describe("T-V2-C: OnTradeExchange - Varying scenarios (no partial execution, with pre-funding, no fees, auto-execute)", function () {
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

    describe("OnRamp Request (100), with Treasury Pre-funded (100)", function () {
        beforeEach(async function () {
            // Day 0: pre-funded treasury with 100
            await depositSegregatedTreasuryAtTime(
                segregatedTreasury.address, // on trade treasury address
                BigNumber.from(100).mul(USD), // amount
                protocol.USDC, // stablecoin
                relay, // relay address
                timestampPrior + 86400
            );

            // Day 1: mint and on-trade 100
            await mintAndOnTradeAtTime(
                signer1,
                companyAccount1,
                BigNumber.from(100).mul(USD), // amount
                BigNumber.from(0), // fee
                1, // nonce
                protocol.IUSD,
                onTradeExchange,
                relay,
                timestampPrior + 86400 * 2
            );
        });
        it("should have correct OnTradeExchange queue", async function () {
            await checkTradeBook(onTradeExchange, [], false); // head -> tail
        });
        it("should have correct OnTradeExchange stats", async function () {
            await checkOnTradeExchangeStats(
                onTradeExchange,
                protocol.IUSD, // off asset
                protocol.USDC, // on asset
                BigNumber.from(0).mul(USD), // total queued amount
                BigNumber.from(100).mul(USD), // total queued cumulative
                BigNumber.from(0).mul(USD), // IUSD balance
                BigNumber.from(0) // no USDT
            );
        });
        it("should have correct SegregatedTreasury stats", async function () {
            await checkSegregatedTreasuryStats(
                segregatedTreasury,
                protocol.IUSD, // off asset
                protocol.USDC, // on asset
                BigNumber.from(100).mul(USD), // IUSD balance
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
                BigNumber.from(0).mul(USD), // currentpayoutSize
                companyAccount1.address, // company account which made tx
                protocol.IUSD.address, // sell asset address
                protocol.USDC.address, // buy asset address
                BigNumber.from(timestampPrior + 86400 * 2), // created at
                BigNumber.from(timestampPrior + 86400 * 2), // executed at (executed in same block)
                BigNumber.from(0), // cancelled at
                TradeState.Executed,
                false // verbose
            );
        });
        it("should have correct trade 1, payment receipt 1", async function () {
            await checkTradeReceipt(
                onTradeExchange, // trade pool contract
                BigNumber.from(1), // trade uint
                0, // receipt index
                BigNumber.from(100).mul(USD), // payout size
                BigNumber.from(0).mul(USD), // axiymFee associated wtih this payment
                BigNumber.from(0).mul(USD), // totalFee associated with this payment
                BigNumber.from(timestampPrior + 86400 * 2), // executed at (executed in same block)
                false // verbose
            );
        });
        it("should have correct company account 1 balances", async function () {
            await checkCompanyAccount(
                companyAccount1.address,
                protocol.USDC,
                protocol.IUSD,
                BigNumber.from(100).mul(USD), // usdc balance
                BigNumber.from(0).mul(USD) // iusd balance
            );
        });
        it("should have correct fee company account balances", async function () {
            await checkCompanyAccount(
                axiymFeeCompanyAccount.address,
                protocol.USDC,
                protocol.IUSD,
                BigNumber.from(0).mul(USD), // on asset balance
                BigNumber.from(0).mul(USD), // off asset balance
                false
            );
        });
    });
    describe("OnRamp Request (60), with Treasury Pre-funded (100)", function () {
        beforeEach(async function () {
            // Day 0: pre-funded treasury with 100
            await depositSegregatedTreasuryAtTime(
                segregatedTreasury.address, // on trade treasury address
                BigNumber.from(100).mul(USD), // amount
                protocol.USDC, // stablecoin
                relay, // relay address
                timestampPrior + 86400
            );

            // Day 1: mint and on-trade 100
            await mintAndOnTradeAtTime(
                signer1,
                companyAccount1,
                BigNumber.from(60).mul(USD), // amount
                BigNumber.from(0), // fee
                1, // nonce
                protocol.IUSD,
                onTradeExchange,
                relay,
                timestampPrior + 86400 * 2
            );
        });
        it("should have correct OnTradeExchange queue", async function () {
            await checkTradeBook(onTradeExchange, [], false); // head -> tail
        });
        it("should have correct OnTradeExchange stats", async function () {
            await checkOnTradeExchangeStats(
                onTradeExchange,
                protocol.IUSD, // off asset
                protocol.USDC, // on asset
                BigNumber.from(0).mul(USD), // total queued amount
                BigNumber.from(60).mul(USD), // total queued cumulative
                BigNumber.from(0).mul(USD), // IUSD balance
                BigNumber.from(0) // no USDT
            );
        });
        it("should have correct SegregatedTreasury stats", async function () {
            await checkSegregatedTreasuryStats(
                segregatedTreasury,
                protocol.IUSD, // off asset
                protocol.USDC, // on asset
                BigNumber.from(60).mul(USD), // IUSD balance
                BigNumber.from(40).mul(USD) // 40 USDT
            );
        });
        it("should have correct trade 1 stats", async function () {
            await checkTrade(
                onTradeExchange, // trade pool contract
                BigNumber.from(1), // trade uint
                BigNumber.from(60).mul(USD), // sell asset quote amount
                BigNumber.from(60).mul(USD), // buy asset quote amount
                BigNumber.from(0).mul(USD), // axiymFee
                BigNumber.from(0).mul(USD), // totalFee
                BigNumber.from(60).mul(USD), // initialpayoutSize
                BigNumber.from(0).mul(USD), // currentpayoutSize
                companyAccount1.address, // company account which made tx
                protocol.IUSD.address, // sell asset address
                protocol.USDC.address, // buy asset address
                BigNumber.from(timestampPrior + 86400 * 2), // created at
                BigNumber.from(timestampPrior + 86400 * 2), // executed at (executed in same block)
                BigNumber.from(0), // cancelled at
                TradeState.Executed,
                false // verbose
            );
        });
        it("should have correct trade 1, payment receipt 1", async function () {
            await checkTradeReceipt(
                onTradeExchange, // trade pool contract
                BigNumber.from(1), // trade uint
                0, // receipt index
                BigNumber.from(60).mul(USD), // payout size
                BigNumber.from(0).mul(USD), // axiymFee associated wtih this payment
                BigNumber.from(0).mul(USD), // totalFee associated with this payment
                BigNumber.from(timestampPrior + 86400 * 2), // executed at (executed in same block)
                false // verbose
            );
        });
        it("should have correct company account 1 balances", async function () {
            await checkCompanyAccount(
                companyAccount1.address,
                protocol.USDC,
                protocol.IUSD,
                BigNumber.from(60).mul(USD), // usdc balance
                BigNumber.from(0).mul(USD) // iusd balance
            );
        });
        it("should have correct fee company account balances", async function () {
            await checkCompanyAccount(
                axiymFeeCompanyAccount.address,
                protocol.USDC,
                protocol.IUSD,
                BigNumber.from(0).mul(USD), // on asset balance
                BigNumber.from(0).mul(USD), // off asset balance
                false
            );
        });
    });
    describe("OnRamp Request (150), with Treasury Pre-funded (100)", function () {
        beforeEach(async function () {
            // Day 0: pre-funded treasury with 100
            await depositSegregatedTreasuryAtTime(
                segregatedTreasury.address, // on trade treasury address
                BigNumber.from(100).mul(USD), // amount
                protocol.USDC, // stablecoin
                relay, // relay address
                timestampPrior + 86400
            );

            // Day 1: mint and on-trade 100
            await mintAndOnTradeAtTime(
                signer1,
                companyAccount1,
                BigNumber.from(150).mul(USD), // amount
                BigNumber.from(0), // fee
                1, // nonce
                protocol.IUSD,
                onTradeExchange,
                relay,
                timestampPrior + 86400 * 2
            );
        });

        it("should have correct OnTradeExchange queue", async function () {
            await checkTradeBook(onTradeExchange, [1], false); // head -> tail
        });

        it("should have correct OnTradeExchange stats", async function () {
            await checkOnTradeExchangeStats(
                onTradeExchange,
                protocol.IUSD, // off asset
                protocol.USDC, // on asset
                BigNumber.from(150).mul(USD), // total queued amount
                BigNumber.from(150).mul(USD), // total queued cumulative
                BigNumber.from(150).mul(USD), // IUSD balance
                BigNumber.from(0) // no USDT
            );
        });

        it("should have correct SegregatedTreasury stats", async function () {
            await checkSegregatedTreasuryStats(
                segregatedTreasury,
                protocol.IUSD, // off asset
                protocol.USDC, // on asset
                BigNumber.from(0).mul(USD), // IUSD balance
                BigNumber.from(100).mul(USD) // USDT balance
            );
        });

        it("should have correct trade 1 stats", async function () {
            await checkTrade(
                onTradeExchange, // trade pool contract
                BigNumber.from(1), // trade uint
                BigNumber.from(150).mul(USD), // sell asset quote amount#
                BigNumber.from(150).mul(USD), // buy asset quote amount
                BigNumber.from(0).mul(USD), // axiymFee
                BigNumber.from(0).mul(USD), // totalFee
                BigNumber.from(150).mul(USD), // initialpayoutSize
                BigNumber.from(150).mul(USD), // currentpayoutSize
                companyAccount1.address, // company account which made tx
                protocol.IUSD.address, // sell asset address
                protocol.USDC.address, // buy asset address
                BigNumber.from(timestampPrior + 86400 * 2), // created at
                BigNumber.from(0), // executed at (executed in same block)
                BigNumber.from(0), // cancelled at
                TradeState.Pending,
                false // verbose
            );
        });
        it("should have correct company account 1 balances", async function () {
            await checkCompanyAccount(
                companyAccount1.address,
                protocol.USDC,
                protocol.IUSD,
                BigNumber.from(0).mul(USD), // usdc balance
                BigNumber.from(0).mul(USD) // iusd balance
            );
        });
        it("should have correct fee company account balances", async function () {
            await checkCompanyAccount(
                axiymFeeCompanyAccount.address,
                protocol.USDC,
                protocol.IUSD,
                BigNumber.from(0).mul(USD), // on asset balance
                BigNumber.from(0).mul(USD), // off asset balance
                false
            );
        });
    });
});
