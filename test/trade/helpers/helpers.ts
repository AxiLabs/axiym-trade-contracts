import { expect } from "chai";
import {
    CompanyAccount,
    LinkedListTest,
    OffTradeExchange,
    OnTradeExchange,
    SegregatedTreasury,
} from "../../../typechain";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import { TradeState } from "../enums/trade-status.enum";

export async function checkTradeBook(
    tradeBook: LinkedListTest | OnTradeExchange | OffTradeExchange,
    expected: number[],
    verbose = false
) {
    const HEAD = 0;

    // 🔹 Optional: verbose traversal before checking expectations
    if (verbose) {
        const actual: number[] = [];
        let current = HEAD;

        try {
            for (;;) {
                const [, next] = await tradeBook.getNext(current);
                const nextNum = next.toNumber(); // convert BigNumber → number
                if (nextNum === HEAD) break;
                actual.push(nextNum);
                current = nextNum;
            }
        } catch (err) {
            console.log("Error while traversing trade book:", err);
        }

        console.log(`\n Trade Book: HEAD → ${actual.join(" → ")} → HEAD`);
    }

    // 1. Check size
    const size = await tradeBook.getTradeBookSize();
    expect(size).to.equal(expected.length);

    // 2. Check NEXT links and tradeExists/getTrade for each
    let prevTrade = HEAD;
    for (const trade of expected) {
        const exists = await tradeBook.tradeExists(trade);
        expect(exists).to.be.true;

        const [, nextTrade] = await tradeBook.getNext(prevTrade);
        expect(nextTrade).to.equal(trade);

        const [tradeExists, tradePrev, orderNext] = await tradeBook.getTrade(trade);
        expect(tradeExists).to.be.true;
        expect(tradePrev).to.equal(prevTrade);

        prevTrade = trade;
    }

    // Last trade should loop back to HEAD in NEXT
    const [, lastNext] = await tradeBook.getNext(prevTrade);
    expect(lastNext).to.equal(HEAD);

    if (expected.length > 0) {
        const [, , lastTradeNext] = await tradeBook.getTrade(
            expected[expected.length - 1]
        );
        expect(lastTradeNext).to.equal(HEAD);
    }

    // 3. Check PREV links and getTrade consistency in reverse
    let nextTrade = HEAD;
    for (let i = expected.length - 1; i >= 0; i--) {
        const trade = expected[i];
        const [, prevTrade] = await tradeBook.getPrev(nextTrade);
        expect(prevTrade).to.equal(trade);

        const [tradeExists, tradePrev, orderNext] = await tradeBook.getTrade(trade);
        expect(tradeExists).to.be.true;
        expect(orderNext).to.equal(nextTrade);

        nextTrade = trade;
    }

    const [, firstPrev] = await tradeBook.getPrev(nextTrade);
    expect(firstPrev).to.equal(HEAD);

    if (expected.length > 0) {
        const [, firstTradePrev] = await tradeBook.getPrev(expected[0]);
        expect(firstTradePrev).to.equal(HEAD);
    }

    // 4. If empty list, verify HEAD points to itself
    if (expected.length === 0) {
        const [, nextFromHead] = await tradeBook.getNext(HEAD);
        const [, prevFromHead] = await tradeBook.getPrev(HEAD);
        expect(nextFromHead).to.equal(HEAD);
        expect(prevFromHead).to.equal(HEAD);
    }
}

export async function mintAndOnTradeAtTime(
    signer: SignerWithAddress,
    companyAccount: CompanyAccount,
    amount: BigNumber,
    fee: BigNumber,
    nonceNum: number,
    liquidityAsset: any,
    exchangePool: any,
    relay: SignerWithAddress,
    timestamp?: number
) {
    const total = amount.add(fee);

    await liquidityAsset.connect(relay).mint(companyAccount.address, total);

    if (timestamp !== undefined) {
        await ethers.provider.send("evm_setNextBlockTimestamp", [timestamp]);
    }

    const nonceBytes = ethers.utils.hexZeroPad(ethers.utils.hexlify(nonceNum), 16);
    const messageHash = ethers.utils.solidityKeccak256(
        ["address", "address", "uint256", "bytes16"],
        [liquidityAsset.address, exchangePool.address, total, nonceBytes]
    );
    const signature = await signer.signMessage(ethers.utils.arrayify(messageHash));
    await exchangePool
        .connect(relay)
        .onTrade(
            companyAccount.address,
            nonceBytes,
            total,
            fee,
            nonceBytes,
            signature
        );
}

export async function checkTradeReceipt(
    tradeExchange: OnTradeExchange | OffTradeExchange,
    tradeId: BigNumber,
    receiptIndex: number,
    payoutSize: BigNumber,
    axiymFee: BigNumber,
    otherFee: BigNumber,
    timestamp: BigNumber,

    verbose = false
) {
    const receipts = await tradeExchange.getTradePayments(tradeId);
    const receipt = receipts[receiptIndex];

    if (!receipt) {
        throw new Error(
            `TradePaymentReceipt not found for trade ${tradeId.toString()} at index ${receiptIndex}`
        );
    }

    if (verbose) {
        console.log(
            `\n--- Trade Receipt | Trade ID: ${tradeId.toString()} | Index: ${receiptIndex} ---`
        );
        console.table({
            "Client Payout": receipt.clientPayout.toString(),
            "Axiym Fee": receipt.axiymFee.toString(),
            "Other Fee": receipt.otherFee.toString(),
            Timestamp: receipt.timestamp.toString(),
        });
    }

    expect(receipt.clientPayout).to.eq(payoutSize);
    expect(receipt.axiymFee).to.eq(axiymFee);
    expect(receipt.otherFee).to.eq(otherFee);
    expect(receipt.timestamp).to.eq(timestamp);
}

export async function mintAndOffTradeAtTime(
    signer: SignerWithAddress,
    companyAccount: CompanyAccount,
    sellAssetQuoteAmount: BigNumber,
    buyAssetQuoteValue: BigNumber,
    axiymFee: BigNumber,
    totalFee: BigNumber,
    nonceNum: number,
    liquidityAsset: any,
    offTradeExchange: any,
    relay: SignerWithAddress,
    timestamp?: number
) {
    await liquidityAsset
        .connect(relay)
        .transfer(companyAccount.address, sellAssetQuoteAmount);

    if (timestamp !== undefined) {
        await ethers.provider.send("evm_setNextBlockTimestamp", [timestamp]);
    }
    const nonceBytes = ethers.utils.hexZeroPad(ethers.utils.hexlify(nonceNum), 16);
    const messageHash = ethers.utils.solidityKeccak256(
        ["address", "address", "uint256", "bytes16"],
        [
            liquidityAsset.address,
            offTradeExchange.address,
            sellAssetQuoteAmount,
            nonceBytes,
        ]
    );
    const signature = await signer.signMessage(ethers.utils.arrayify(messageHash));
    await offTradeExchange
        .connect(relay)
        .offTrade(
            companyAccount.address,
            nonceBytes,
            sellAssetQuoteAmount,
            buyAssetQuoteValue,
            axiymFee,
            totalFee,
            nonceBytes,
            signature
        );
}

export async function mintAndSettleAtTime(
    signer: SignerWithAddress,
    companyAccount: CompanyAccount,
    amount: BigNumber,
    onAssetAmount: BigNumber,
    nonceNum: number,
    liquidityAsset: any,
    offTradeExchange: any,
    relay: SignerWithAddress,
    timestamp?: number
) {
    await liquidityAsset.connect(relay).mint(companyAccount.address, amount);

    if (timestamp !== undefined) {
        await ethers.provider.send("evm_setNextBlockTimestamp", [timestamp]);
    }
    const nonceBytes = ethers.utils.hexZeroPad(ethers.utils.hexlify(nonceNum), 16);
    const messageHash = ethers.utils.solidityKeccak256(
        ["address", "address", "uint256", "bytes16"],
        [liquidityAsset.address, offTradeExchange.address, amount, nonceBytes]
    );
    const signature = await signer.signMessage(ethers.utils.arrayify(messageHash));
    await offTradeExchange
        .connect(relay)
        .settle(
            companyAccount.address,
            amount,
            onAssetAmount,
            nonceBytes,
            signature
        );
}

export async function calculateOnAssetAmount(
    amount: BigNumber,
    liquidityAsset: any,
    offTradeExchange: OffTradeExchange
): Promise<any> {
    const queueAmountTotal = await offTradeExchange.queueAmountTotal();
    const onAssetBalance = await liquidityAsset.balanceOf(offTradeExchange.address);

    const onAssetAmount = amount.mul(onAssetBalance).div(queueAmountTotal);

    return onAssetAmount;
}

export async function depositSegregatedTreasuryAtTime(
    segregatedTreasuryAddress: string,
    amount: BigNumber,
    liquidityAsset: any,
    relay: SignerWithAddress,
    timestamp?: number
) {
    if (timestamp !== undefined) {
        await ethers.provider.send("evm_setNextBlockTimestamp", [timestamp]);
    }

    await liquidityAsset.connect(relay).transfer(segregatedTreasuryAddress, amount);
}

export async function depositOffTradeExchangeAtTime(
    onTradeExchangeAddress: string,
    amount: BigNumber,
    liquidityAsset: any,
    relay: SignerWithAddress,
    timestamp?: number
) {
    if (timestamp !== undefined) {
        await ethers.provider.send("evm_setNextBlockTimestamp", [timestamp]);
    }

    await liquidityAsset.connect(relay).mint(onTradeExchangeAddress, amount);
}

export async function executeQueueAtTime(
    onTradeExchange: any,
    relay: SignerWithAddress,
    timestamp?: number
) {
    if (timestamp !== undefined) {
        await ethers.provider.send("evm_setNextBlockTimestamp", [timestamp]);
    }

    await onTradeExchange.connect(relay).executeQueue();
}

export async function checkOnTradeExchangeStats(
    onTradeExchange: OnTradeExchange,
    offAsset: any,
    onAsset: any,
    queueAmountTotal: BigNumber,
    queueAmountCumulative: BigNumber,
    offAssetBalance: BigNumber,
    onAssetBalance: BigNumber,
    verbose = false
) {
    const actualQueueTotal = await onTradeExchange.queueAmountTotal();
    const actualQueueCumulative = await onTradeExchange.queueAmountCumulative();
    const offBalance = await offAsset.balanceOf(onTradeExchange.address);
    const onBalance = await onAsset.balanceOf(onTradeExchange.address);

    if (verbose) {
        console.log("queue total:      ", actualQueueTotal.toString());
        console.log("queue cumulative: ", actualQueueCumulative.toString());
        console.log("offAsset balance: ", offBalance.toString());
        console.log("onAsset balance:  ", onBalance.toString());
    }

    expect(actualQueueTotal).to.be.eq(queueAmountTotal);
    expect(actualQueueCumulative).to.be.eq(queueAmountCumulative);
    expect(offBalance).to.be.eq(offAssetBalance);
    expect(onBalance).to.be.eq(onAssetBalance);
}

export async function checkOffTradeExchangeStats(
    offTradeExchange: OffTradeExchange,
    offAsset: any,
    onAsset: any,
    queueAmountTotal: BigNumber,
    queueAmountCumulative: BigNumber,
    offAssetBalance: BigNumber,
    onAssetBalance: BigNumber,

    verbose = false
) {
    const actualQueueTotal = await offTradeExchange.queueAmountTotal();
    const actualQueueCumulative = await offTradeExchange.queueAmountCumulative();
    const offBalance = await offAsset.balanceOf(offTradeExchange.address);
    const onBalance = await onAsset.balanceOf(offTradeExchange.address);

    if (verbose) {
        console.log("queue total:      ", actualQueueTotal.toString());
        console.log("queue cumulative: ", actualQueueCumulative.toString());
        console.log("offAsset balance: ", offBalance.toString());
        console.log("onAsset balance:  ", onBalance.toString());
    }

    expect(actualQueueTotal).to.be.eq(queueAmountTotal);
    expect(actualQueueCumulative).to.be.eq(queueAmountCumulative);
    expect(offBalance).to.be.eq(offAssetBalance);
    expect(onBalance).to.be.eq(onAssetBalance);
}

export async function checkSegregatedTreasuryStats(
    segregatedTreasury: SegregatedTreasury,
    offAsset: any,
    onAsset: any,
    offAssetBalance: BigNumber,
    onAssetBalance: BigNumber,
    verbose = false
) {
    const offBalance = await offAsset.balanceOf(segregatedTreasury.address);
    const onBalance = await onAsset.balanceOf(segregatedTreasury.address);

    if (verbose) {
        console.log("offAsset balance: ", offBalance.toString());
        console.log("onAsset balance:  ", onBalance.toString());
    }
    expect(offBalance).to.be.eq(offAssetBalance);
    expect(onBalance).to.be.eq(onAssetBalance);
}

export async function checkTrade(
    tradeExchange: OnTradeExchange | OffTradeExchange | OnTradeExchange,
    tradeId: BigNumber,
    sellAssetQuoteAmount: BigNumber,
    buyAssetQuoteValue: BigNumber,
    axiymFee: BigNumber,
    totalFee: BigNumber,
    initialPayoutSize: BigNumber,
    currentPayoutSize: BigNumber,
    companyAccount: string,
    sellAsset: string,
    buyAsset: string,
    createdAt: BigNumber,
    executedAt: BigNumber,
    cancelledAt: BigNumber,
    status: TradeState,

    verbose = false
) {
    const trade = await tradeExchange.getTradeData(tradeId);

    if (verbose) {
        console.log(`\n--- Trade ID: ${tradeId.toString()} ---`);
        console.table({
            "Sell Asset Quote Amount": trade.sellAssetQuoteAmount.toString(),
            "Buy Asset Quote Value": trade.buyAssetQuoteValue.toString(),
            "Axiym Fee": trade.axiymFee.toString(),
            "Total Fee": trade.totalFee.toString(),
            "Initial Payout Size": trade.initialPayoutSize.toString(),
            "Current Payout Size": trade.currentPayoutSize.toString(),
            "Company Account": trade.companyAccount,
            "Sell Asset": trade.sellAsset,
            "Buy Asset": trade.buyAsset,
            "Created At": trade.createdAt.toString(),
            "Executed At": trade.executedAt.toString(),
            "Cancelled At": trade.cancelledAt.toString(),
            Status: trade.status,
        });
    }

    // pricing / fee assertions
    expect(trade.sellAssetQuoteAmount).to.eq(sellAssetQuoteAmount);
    expect(trade.buyAssetQuoteValue).to.eq(buyAssetQuoteValue);
    expect(trade.axiymFee).to.eq(axiymFee);
    expect(trade.totalFee).to.eq(totalFee);

    // payout assertions
    expect(trade.initialPayoutSize).to.eq(initialPayoutSize);
    expect(trade.currentPayoutSize).to.eq(currentPayoutSize);

    // parties / assets
    expect(trade.companyAccount).to.eq(companyAccount);
    expect(trade.sellAsset).to.eq(sellAsset);
    expect(trade.buyAsset).to.eq(buyAsset);

    // lifecycle
    expect(trade.createdAt).to.eq(createdAt);
    expect(trade.executedAt).to.eq(executedAt);
    expect(trade.cancelledAt).to.eq(cancelledAt);
    expect(trade.status).to.eq(status);
}

export async function checkCompanyAccount(
    companyAccount: string,
    onAsset: any,
    offAsset: any,
    onAssetBalance: BigNumber,
    offAssetBalance: BigNumber,
    verbose = false
) {
    // Fetch actual balances
    const actualOnBalance = await onAsset.balanceOf(companyAccount);
    const actualOffBalance = await offAsset.balanceOf(companyAccount);

    // Optional verbose logs
    if (verbose) {
        console.log("company account:  ", companyAccount);
        console.log("onAsset:          ", onAsset.address);
        console.log("offAsset:         ", offAsset.address);
        console.log("onAsset balance:  ", actualOnBalance.toString());
        console.log("offAsset balance: ", actualOffBalance.toString());
    }

    // Assertions
    expect(actualOnBalance).to.be.eq(onAssetBalance);
    expect(actualOffBalance).to.be.eq(offAssetBalance);
}

export function expectWithin(
    actual: BigNumber,
    expected: BigNumber,
    tolerance: BigNumber
) {
    const diff = actual.gt(expected) ? actual.sub(expected) : expected.sub(actual);

    expect(
        diff.lte(tolerance),
        `Expected ${actual.toString()} to be within ${tolerance.toString()} of ${expected.toString()}`
    ).to.be.true;
}
