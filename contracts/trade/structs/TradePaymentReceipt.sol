// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.24;

struct TradePaymentReceipt {
    uint256 clientPayout; // amount paid out
    uint256 axiymFee; // possibly already paid but proportion recorded here
    uint256 otherFee; // provider fee if it exists
    uint256 timestamp;
}
