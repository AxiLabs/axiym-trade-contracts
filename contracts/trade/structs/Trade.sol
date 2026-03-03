// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.24;

import {TradeState} from "../enums/TradeState.sol";
import {TradePaymentReceipt} from "./TradePaymentReceipt.sol";

struct Trade {
    uint256 sellAssetQuoteAmount; // total amount of gross asset being sold (pre-FX, pre-fees)
    uint256 buyAssetQuoteValue; // value of sell asset expressed in buy asset (calculated using mid-market rates)
    uint256 axiymFee; // Fixed Axiym fee for the trade, expressed in units of the buy asset, calculated at pricing time.
    uint256 totalFee; // Total fees for the trade, expressed in units of the buy asset, calculated at pricing time.
    uint256 initialPayoutSize; // start payout size in buy asset
    uint256 currentPayoutSize; // current payout size in buy asset
    address companyAccount; // company account involved
    address tradePool; // tradePool request sent from
    address sellAsset; // asset being sold
    address buyAsset; // asset being bought
    uint256 createdAt; // time trade was created
    uint256 executedAt; // time trade was executed
    uint256 cancelledAt; // time trade was cancelled
    TradeState status; // status of trade (pending, executed, etc.)
}
