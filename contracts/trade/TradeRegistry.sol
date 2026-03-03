// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.24;

import {TradeState} from "../trade/enums/TradeState.sol";
import {Trade} from "../trade/structs/Trade.sol";
import {LinkedList} from "./LinkedList.sol";
import {IErrors} from "../interfaces/IErrors.sol";
import {TradePaymentReceipt} from "./structs/TradePaymentReceipt.sol";

/// @title TradeRegistry
/// @notice Registry for trade storage, creation, and lifecycle management
abstract contract TradeRegistry is LinkedList, IErrors {
    /// @notice Mapping of trade uint ID to Trade struct
    mapping(uint256 => Trade) internal _trades;

    /// @notice Monotonically increasing trade counter
    uint256 internal _tradeCount;

    /// @notice Trade repayments
    mapping(uint256 => TradePaymentReceipt[]) internal _tradePayments; // tradeUint => trade payments

    constructor() {
        _tradeCount = 1; // 0 is reserved for HEAD
    }

    // --- Events ---
    event TradeCreated(
        bytes16 indexed tradeBytes,
        uint256 indexed tradeId,
        address indexed companyAccount,
        address sellAsset,
        address buyAsset,
        uint256 sellAssetQuoteAmount, // gross sell asset (pre-FX, pre-fees)
        uint256 buyAssetQuoteValue, // gross buy asset value (mid-market)
        uint256 axiymFee, // buy-asset denominated fee
        uint256 totalFee, // buy-asset denominated total fee
        uint256 initialPayoutSize // buy-asset payout to company
    );
    event TradeExecuted(bytes16 indexed tradeBytes, uint256 indexed tradeId);
    event TradeCancelled(bytes16 indexed tradeBytes, uint256 indexed tradeId);

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Trade Creation
    // ════════════════════════════════════════════════════════════════════════════

    /// @notice Creates a new trade and registers it in the linked list
    /// @param tradeBytes_ Trade ID in bytes16 format
    /// @param sellAssetQuoteAmount_ Amount of USDT to sell, this includes all fees.
    /// @param buyAssetQuoteValue_ Amount of USDT to sell, including all fees, at mid-market rate.
    /// @param axiymFee_ Axiym fee charged on the trade, in USD.
    /// @param totalFee_ Total fee charged on the trade, in USD.
    /// @param initialPayoutSize_ The payout size to the company account
    /// @param companyAccount_ The company account address involved
    /// @param sellAsset_ The ERC20 token being sold
    /// @param buyAsset_ The ERC20 token being bought
    /// @return tradeUint The newly created trade identifier
    function _createTrade(
        bytes16 tradeBytes_,
        uint256 sellAssetQuoteAmount_,
        uint256 buyAssetQuoteValue_,
        uint256 axiymFee_,
        uint256 totalFee_,
        uint256 initialPayoutSize_,
        address companyAccount_,
        address sellAsset_,
        address buyAsset_
    ) internal returns (uint256) {
        uint256 tradeUint = _tradeCount;

        // create trade struct in storage
        _trades[tradeUint] = Trade({
            sellAssetQuoteAmount: sellAssetQuoteAmount_,
            buyAssetQuoteValue: buyAssetQuoteValue_,
            axiymFee: axiymFee_,
            totalFee: totalFee_,
            initialPayoutSize: initialPayoutSize_,
            currentPayoutSize: initialPayoutSize_,
            companyAccount: companyAccount_,
            tradePool: address(this),
            sellAsset: sellAsset_,
            buyAsset: buyAsset_,
            createdAt: block.timestamp,
            executedAt: 0,
            cancelledAt: 0,
            status: TradeState.Pending
        });

        // register mapping between uint256 and bytes16 IDs
        _registerTrade(tradeUint, tradeBytes_);

        // increment trade count for next trade
        _tradeCount += 1;

        emit TradeCreated(
            tradeBytes_,
            tradeUint,
            companyAccount_,
            sellAsset_,
            buyAsset_,
            sellAssetQuoteAmount_,
            buyAssetQuoteValue_,
            axiymFee_,
            totalFee_,
            initialPayoutSize_
        );
        return tradeUint;
    }

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Trade Lifecycle Management
    // ════════════════════════════════════════════════════════════════════════════

    /// @notice Updates a trade for a payment
    /// @param tradeUint_ The internal numeric ID
    /// @param tradePayment_ The payment details
    /// @param payoutSize_ The payout sisze
    function _updateRegistry(
        uint256 tradeUint_,
        TradePaymentReceipt memory tradePayment_,
        uint256 payoutSize_
    ) internal {
        Trade storage trade = _trades[tradeUint_];

        if (trade.createdAt == 0) revert TradeDoesNotExist();
        if (trade.status != TradeState.Pending) revert InvalidTradeState();

        // we handle any rounding here
        if (payoutSize_ >= trade.currentPayoutSize) {
            trade.currentPayoutSize = 0;
        } else {
            trade.currentPayoutSize -= payoutSize_;
        }

        if (trade.currentPayoutSize == 0) {
            trade.status = TradeState.Executed;
            trade.executedAt = block.timestamp;
        }

        _tradePayments[tradeUint_].push(tradePayment_);
    }

    function _cancelRegistry(uint256 tradeUint_) internal returns (uint256) {
        Trade storage trade = _trades[tradeUint_];

        if (trade.status != TradeState.Pending) revert InvalidTradeState();

        trade.cancelledAt = block.timestamp;
        trade.status = TradeState.Cancelled;

        return trade.currentPayoutSize;
    }

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Trade Getters
    // ════════════════════════════════════════════════════════════════════════════

    /// @notice Returns the full trade struct for a given tradeUint
    /// @param tradeUint_ The internal numeric ID
    /// @return The trade struct
    function getTradeData(uint256 tradeUint_) public view returns (Trade memory) {
        Trade memory trade = _trades[tradeUint_];
        if (trade.createdAt == 0) revert TradeDoesNotExist();
        return trade;
    }

    /// @notice Returns the full trade struct for a given bytes16 ID
    /// @param tradeBytes_ The bytes16 identifier
    /// @return The trade struct
    function getTradeDataBytes(
        bytes16 tradeBytes_
    ) public view returns (Trade memory) {
        uint256 tradeUint = _tradesBytesToUint[tradeBytes_];
        if (tradeUint == 0) revert TradeDoesNotExist();
        return _trades[tradeUint];
    }

    /// @notice Checks if a trade is in Pending state by uint256 ID
    /// @param tradeUint_ The trade ID to check
    /// @return True if the trade is pending
    function isTradePending(uint256 tradeUint_) public view returns (bool) {
        return _trades[tradeUint_].status == TradeState.Pending;
    }

    /// @notice Checks if a trade is in Pending state by bytes16 ID
    /// @param tradeBytes_ The bytes16 trade ID to check
    /// @return True if the trade is pending
    function isTradePendingBytes(bytes16 tradeBytes_) external view returns (bool) {
        uint256 tradeUint = _tradesBytesToUint[tradeBytes_];
        if (tradeUint == 0) return false;
        return isTradePending(tradeUint);
    }

    /// @notice Returns current trade count
    /// @return The total number of trades created
    function tradeCount() external view returns (uint256) {
        return _tradeCount;
    }

    /// @notice Returns all payments made for a specific trade
    /// @param tradeUint_ The internal numeric ID
    /// @return An array of TradePayment structs
    function getTradePayments(
        uint256 tradeUint_
    ) public view returns (TradePaymentReceipt[] memory) {
        if (_trades[tradeUint_].createdAt == 0) revert TradeDoesNotExist();
        return _tradePayments[tradeUint_];
    }

    /// @notice Returns all payments made for a specific trade using bytes16 ID
    /// @param tradeBytes_ The bytes16 identifier
    /// @return An array of TradePayment structs
    function getTradePaymentsBytes(
        bytes16 tradeBytes_
    ) external view returns (TradePaymentReceipt[] memory) {
        uint256 tradeUint = _tradesBytesToUint[tradeBytes_];
        return getTradePayments(tradeUint);
    }
}
