import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "ethers";

import {
    CompanyAccount,
    OnTradeExchange,
    SegregatedTreasury,
} from "../../typechain";

import { USD } from "../common/constants.factory";
import { CompanyAccountFactory } from "../company_account/factories/company-accounts.factory";
import { OnTradeProtocolFactory } from "./factories/on-trade-protocol.factory";

import {
    depositSegregatedTreasuryAtTime,
    executeQueueAtTime,
    mintAndOnTradeAtTime,
} from "./helpers/helpers";

describe.only("T-V3-M: OnTradeExchange – random partial repayments until cleared", function () {
    let superAdmin: SignerWithAddress;
    let governor: SignerWithAddress;
    let manager: SignerWithAddress;
    let authorizer: SignerWithAddress;
    let owner: SignerWithAddress;
    let relay: SignerWithAddress;

    let signer1: SignerWithAddress;
    let receiver1: SignerWithAddress;
    let signer2: SignerWithAddress;
    let receiver2: SignerWithAddress;

    let protocol: any;
    let onTradeExchange: OnTradeExchange;
    let segregatedTreasury: SegregatedTreasury;

    let companyAccount1: CompanyAccount;
    let axiymFeeCompanyAccount: CompanyAccount;

    let timestampPrior: number;

    const TRADE_AMOUNT = BigNumber.from(100).mul(USD);
    const TOTAL_FEE = BigNumber.from(1).mul(USD);

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

        const block = await ethers.provider.getBlock("latest");
        timestampPrior = block.timestamp;

        await onTradeExchange.connect(governor).setPartialExecution(true);
    });

    it("should clear a single trade via 50 random partial treasury deposits", async function () {
        // Day 1: mint + on-trade 100
        await mintAndOnTradeAtTime(
            signer1,
            companyAccount1,
            TRADE_AMOUNT,
            TOTAL_FEE,
            1,
            protocol.IUSD,
            onTradeExchange,
            relay,
            timestampPrior + 86400
        );

        let remaining = TRADE_AMOUNT;
        let currentTime = timestampPrior + 86400 * 2;

        // Generate 49 random small deposits
        for (let i = 0; i < 49; i++) {
            if (remaining.lte(0)) break;

            // random between 1 and 3 USD
            const randomUsd = Math.floor(Math.random() * 3) + 1;
            let depositAmount = BigNumber.from(randomUsd).mul(USD);

            if (depositAmount.gt(remaining)) {
                depositAmount = remaining;
            }

            remaining = remaining.sub(depositAmount);

            await depositSegregatedTreasuryAtTime(
                segregatedTreasury.address,
                depositAmount,
                protocol.USDC,
                relay,
                currentTime
            );

            currentTime += 3600; // +1 hour per iteration

            await executeQueueAtTime(onTradeExchange, relay, currentTime);

            currentTime += 3600; // +1 hour per iteration
        }

        // Final deposit to clear remainder exactly
        if (remaining.gt(0)) {
            await depositSegregatedTreasuryAtTime(
                segregatedTreasury.address,
                remaining,
                protocol.USDC,
                relay,
                currentTime
            );

            currentTime += 3600; // +1 hour per iteration
            await executeQueueAtTime(onTradeExchange, relay, currentTime);
        }

        // ---- Assertions over ALL receipts ----

        const receipts = await onTradeExchange.getTradePayments(BigNumber.from(1));

        let totalPayout = BigNumber.from(0);
        let totalAxiymFee = BigNumber.from(0);

        for (const receipt of receipts) {
            totalPayout = totalPayout.add(receipt.clientPayout);
            totalAxiymFee = totalAxiymFee.add(receipt.axiymFee);
        }

        console.log("total payout", totalPayout);
        expect(totalPayout).to.eq(TRADE_AMOUNT);
        console.log("total axiym fee", totalAxiymFee);
        expect(totalAxiymFee).to.eq(TOTAL_FEE);
    });
});
