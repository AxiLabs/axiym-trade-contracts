import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ethers } from "hardhat";
import {
    CompanyAccount,
    OnTradeExchange,
    SegregatedTreasury,
} from "../../typechain";

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
import { CompanyAccountFactory } from "../company_account/factories/company-accounts.factory";

describe.only("T-V3-A: OnTradeExchange - Adding OnTrades to queue", function () {
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
            relay, // deployer
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
            relay, // deployer
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

    describe("Single On-Ramp Request", function () {
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
                BigNumber.from(100).mul(USD), // total queued cumulative
                BigNumber.from(100).mul(USD), // IUSD balance
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
    });

    describe("Double On-Ramp Request", function () {
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
        });
        it("should have correct OnTradeExchange queue", async function () {
            await checkTradeBook(onTradeExchange, [1, 2], false); // head -> tail, 1
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
});
