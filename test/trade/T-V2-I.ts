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
    checkCompanyAccount,
    checkOnTradeExchangeStats,
    checkSegregatedTreasuryStats,
    checkTradeBook,
    depositSegregatedTreasuryAtTime,
    executeQueueAtTime,
    mintAndOnTradeAtTime,
} from "./helpers/helpers";

describe("T-V2-I: OnTradeExchange - 50 trades cleared by 1 Treasury Deposit", function () {
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
            superAdmin,
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
            superAdmin,
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

        totalOnAmount = BigNumber.from(0);
    });

    describe("Scenario: 50 Sequential Trades then 1 Clearing Deposit", function () {
        beforeEach(async function () {
            // ═══════════════════════════════════════════════════════
            // Stack 50 random on-ramp trades
            // ═══════════════════════════════════════════════════════
            for (let i = 0; i < 50; i++) {
                const amount = BigNumber.from(
                    Math.floor(Math.random() * 99) + 1
                ).mul(USD);
                totalOnAmount = totalOnAmount.add(amount);

                await mintAndOnTradeAtTime(
                    signer1,
                    companyAccount1,
                    amount,
                    BigNumber.from(0), // fee
                    i + 1, // nonce
                    protocol.IUSD,
                    onTradeExchange,
                    relay,
                    timestampPrior + 86400 * (i + 1) // Day 1 to Day 50
                );
            }

            // Day 51: Deposit the exact total required into the treasury
            await depositSegregatedTreasuryAtTime(
                segregatedTreasury.address,
                totalOnAmount,
                protocol.USDC,
                relay,
                timestampPrior + 86400 * 51
            );

            // Day 52: Execute the queue to process all 50 trades
            await executeQueueAtTime(
                onTradeExchange,
                relay,
                timestampPrior + 86400 * 52
            );
        });

        it("should have an empty trade queue after execution", async function () {
            await checkTradeBook(onTradeExchange, [], false);
        });

        it("should have correct OnTradeExchange stats (0 remaining in queue)", async function () {
            await checkOnTradeExchangeStats(
                onTradeExchange,
                protocol.IUSD,
                protocol.USDC,
                BigNumber.from(0), // total queued amount
                totalOnAmount, // total queued cumulative
                BigNumber.from(0), // IUSD balance (moved to treasury)
                BigNumber.from(0)
            );
        });

        it("should have correct SegregatedTreasury stats (holding total deposited amount)", async function () {
            await checkSegregatedTreasuryStats(
                segregatedTreasury,
                protocol.IUSD,
                protocol.USDC,
                totalOnAmount, // IUSD balance
                BigNumber.from(0) // USDC balance (all given to company account)
            );
        });

        it("should have credited the company account with the total USDC amount", async function () {
            await checkCompanyAccount(
                companyAccount1.address,
                protocol.USDC,
                protocol.IUSD,
                totalOnAmount, // USDC balance
                BigNumber.from(0) // IUSD balance
            );
        });

        it("should show 0 balance for the fee company account", async function () {
            await checkCompanyAccount(
                axiymFeeCompanyAccount.address,
                protocol.USDC,
                protocol.IUSD,
                BigNumber.from(0),
                BigNumber.from(0),
                false
            );
        });
    });
});
