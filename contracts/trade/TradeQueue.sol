// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.24;

import {TradeRegistry} from "./TradeRegistry.sol";
import {Trade} from "../trade/structs/Trade.sol";
import {TradeState} from "../trade/enums/TradeState.sol";
import {IAuthRegistry} from "../interfaces/IAuthRegistry.sol";
import {Governable} from "../governance/Governable.sol";

/// @title TradeQueue
/// @notice Manages queue-specific operations and state for trades
abstract contract TradeQueue is TradeRegistry, Governable {
    /// @notice Authorization registry
    address internal _authRegistry;

    /// @notice Total amount currently in the queue
    uint256 internal _queueAmountTotal;

    /// @notice Cumulative amount that has ever been queued
    uint256 internal _queueAmountCumulative;

    // --- Events ---
    event TradeAddedToQueue(
        bytes16 indexed tradeBytes,
        uint256 indexed tradeUint,
        uint256 amount
    );
    event TradeRemovedFromQueue(
        bytes16 indexed tradeBytes,
        uint256 indexed tradeUint
    );
    event TradeMoved(
        bytes16 indexed tradeBytes_,
        uint256 indexed tradeUint_,
        bytes16 indexed tradeBytesTarget_,
        uint256 tradeUintTarget_,
        bool direction
    );
    event QueueMoved(
        uint256 indexed tradeId,
        uint256 indexed targetId,
        bool direction
    );
    event AuthRegistryTransferred(
        address indexed oldAuthRegistry,
        address indexed newAuthRegistry
    );

    //--- Modifiers ---
    /// @notice Restricts function access to authorized addresses only
    modifier onlyAuthAddress() {
        if (!IAuthRegistry(_authRegistry).isAuthAddress(msg.sender))
            revert Unauthorized();
        _;
    }

    constructor(address governance_, address authRegistry_) Governable(governance_) {
        _authRegistry = authRegistry_;
    }

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Governance Functions
    // ════════════════════════════════════════════════════════════════════════════
    /// @notice Updates the AuthRegistry address
    /// @param newAuthRegistry_ New AuthRegistry address
    function setAuthRegistry(address newAuthRegistry_) external onlyGovernor {
        if (newAuthRegistry_ == address(0)) revert AddressEmpty();
        if (newAuthRegistry_ == _authRegistry) revert AddressExists();

        address oldAuthRegistry = _authRegistry;
        _authRegistry = newAuthRegistry_;

        emit AuthRegistryTransferred(oldAuthRegistry, newAuthRegistry_);
    }

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Queue Management - External
    // ════════════════════════════════════════════════════════════════════════════

    /// @notice Move a trade in the queue by uint ID
    /// @param tradeUint_ Trade ID to move
    /// @param targetUint_ Target trade ID to move before/after
    /// @param direction_ True for forward, false for backward
    function move(
        uint256 tradeUint_,
        uint256 targetUint_,
        bool direction_
    ) external onlyAuthAddress {
        bool moved = _move(tradeUint_, targetUint_, direction_);
        if (!moved) revert QueueMoveFailed();

        emit QueueMoved(tradeUint_, targetUint_, direction_);
    }

    /// @notice Move a trade in the queue by bytes16 ID
    /// @param tradeBytes_ Trade ID to move
    /// @param targetBytes_ Target trade ID to move before/after
    /// @param direction_ True for forward, false for backward
    function moveBytes(
        bytes16 tradeBytes_,
        bytes16 targetBytes_,
        bool direction_
    ) external onlyAuthAddress {
        bool moved = _moveBytes(tradeBytes_, targetBytes_, direction_);
        if (!moved) revert QueueMoveFailed();

        emit QueueMoved(
            _tradesBytesToUint[tradeBytes_],
            _tradesBytesToUint[targetBytes_],
            direction_
        );
    }

    /// @notice Cancels a trade by removing from queue and updating registry
    /// @param tradeUint_ Trade id
    function cancelTrade(uint256 tradeUint_) external onlyAuthAddress {
        // remove trade from queue
        uint256 status = _remove(tradeUint_);
        if (status == 0) revert QueueRemoveFailed();

        // set cancelled in trade registry
        uint256 currentPayoutSize = _cancelRegistry(tradeUint_);

        // reduce queue total by current payout size
        _queueAmountTotal -= currentPayoutSize;

        // execute post cancel transfers etc.
        Trade storage trade = _trades[tradeUint_];
        _executeCancel(tradeUint_, trade);

        emit TradeCancelled(_tradesUintToBytes[tradeUint_], tradeUint_);
    }

    /// @notice Cancels a trade by removing from queue and updating registry
    /// @param tradeBytes_ Trade id
    function cancelTradeBytes(bytes16 tradeBytes_) external onlyAuthAddress {
        // remove trade from queue
        bytes16 removedBytes = _removeBytes(tradeBytes_);
        if (removedBytes == bytes16(0)) revert QueueRemoveFailed();

        // set cancelled in trade registry
        uint256 currentPayoutSize = _cancelRegistry(
            getTradeUintFromBytes(tradeBytes_)
        );

        // reduce queue total by current payout size
        _queueAmountTotal -= currentPayoutSize;

        // execute post cancel transfers etc.
        Trade storage trade = _trades[_tradesBytesToUint[tradeBytes_]];
        _executeCancel(_tradesBytesToUint[tradeBytes_], trade);

        emit TradeCancelled(tradeBytes_, _tradesBytesToUint[tradeBytes_]);
    }

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Queue Management - Internal
    // ════════════════════════════════════════════════════════════════════════════

    /// @notice Adds a trade to the queue (at the tail)
    /// @param tradeUint_ The trade ID to add
    /// @param amount_ The trade amount to track in queue totals
    function _addToQueue(uint256 tradeUint_, uint256 amount_) internal {
        // add to linked list at tail
        _pushTail(tradeUint_);

        // update queue state
        _queueAmountTotal += amount_;
        _queueAmountCumulative += amount_;

        emit TradeAddedToQueue(_tradesUintToBytes[tradeUint_], tradeUint_, amount_);
    }

    /// @notice Removes a trade from the queue
    /// @param tradeUint_ The trade ID to remove
    /// @param trade_ The trade struct from storage
    /// @param amount_ The trade amount to deduct from queue totals
    function _updateQueue(
        uint256 tradeUint_,
        Trade storage trade_,
        uint256 amount_
    ) internal {
        if (amount_ == trade_.currentPayoutSize) {
            _remove(tradeUint_);
            _queueAmountTotal -= amount_;
            emit TradeRemovedFromQueue(_tradesUintToBytes[tradeUint_], tradeUint_);
        } else {
            _queueAmountTotal -= amount_;
        }
    }

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Functions overridden in child
    // ════════════════════════════════════════════════════════════════════════════

    function _executeCancel(
        uint256 tradeUint_,
        Trade storage trade_
    ) internal virtual;

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Queue Getters
    // ════════════════════════════════════════════════════════════════════════════

    /// @notice Returns the trade at the head of the queue
    /// @return tradeUint_ The trade ID at the head
    /// @return trade The trade struct
    function getHeadTrade()
        external
        view
        returns (uint256 tradeUint_, Trade memory trade)
    {
        (, uint256 nextTradeId) = getNext(0); // HEAD == 0
        if (nextTradeId == 0) return (0, _getEmptyTrade());
        return (nextTradeId, getTradeData(nextTradeId));
    }

    /// @notice Returns the trade at the tail of the queue
    /// @return tradeUint_ The trade ID at the tail
    /// @return trade The trade struct
    function getTailTrade()
        external
        view
        returns (uint256 tradeUint_, Trade memory trade)
    {
        (, uint256 prevTradeId) = getPrev(0); // HEAD == 0
        if (prevTradeId == 0) return (0, _getEmptyTrade());
        return (prevTradeId, getTradeData(prevTradeId));
    }

    /// @notice Returns all queued trades
    /// @return tradeIds Array of trade IDs
    /// @return trades Array of trade structs
    function getAllQueuedTrades()
        external
        view
        returns (uint256[] memory tradeIds, Trade[] memory trades)
    {
        uint256 listSize = getTradeBookSize();
        tradeIds = new uint256[](listSize);
        trades = new Trade[](listSize);

        (, uint256 current) = getNext(0); // start at head
        for (uint256 i = 0; i < listSize; i++) {
            tradeIds[i] = current;
            trades[i] = getTradeData(current);
            (, current) = getNext(current);
        }
    }

    /// @notice Returns a paginated list of queued trades
    /// @dev Pass nextId as startId_ for subsequent pages. Returns trimmed arrays without assembly.
    /// @param startId_ The trade ID to start from (0 for head)
    /// @param pageSize_ The number of trades to return per page
    /// @return tradeIds Array of trade IDs for this page
    /// @return trades Array of trade structs for this page
    /// @return nextId The next trade ID to use as startId_ for the next page (0 if end of queue)
    function getQueuedTradesPaginated(
        uint256 startId_,
        uint256 pageSize_
    )
        external
        view
        returns (uint256[] memory tradeIds, Trade[] memory trades, uint256 nextId)
    {
        uint256[] memory tempIds = new uint256[](pageSize_);
        Trade[] memory tempTrades = new Trade[](pageSize_);

        (, uint256 current) = getNext(startId_);
        uint256 count;

        while (current != 0 && count < pageSize_) {
            tempIds[count] = current;
            tempTrades[count] = getTradeData(current);
            (, current) = getNext(current);
            count++;
        }

        nextId = current;

        tradeIds = new uint256[](count);
        trades = new Trade[](count);
        for (uint256 i = 0; i < count; i++) {
            tradeIds[i] = tempIds[i];
            trades[i] = tempTrades[i];
        }
    }

    /// @notice Returns an empty trade struct
    /// @return Empty trade struct with default values
    function _getEmptyTrade() internal pure returns (Trade memory) {
        return
            Trade({
                sellAssetQuoteAmount: 0,
                buyAssetQuoteValue: 0,
                axiymFee: 0,
                totalFee: 0,
                initialPayoutSize: 0,
                currentPayoutSize: 0,
                companyAccount: address(0),
                tradePool: address(0),
                sellAsset: address(0),
                buyAsset: address(0),
                createdAt: 0,
                executedAt: 0,
                cancelledAt: 0,
                status: TradeState.Unspecified
            });
    }

    /// @notice Returns total amount currently in queue
    /// @return The total queued amount
    function queueAmountTotal() external view returns (uint256) {
        return _queueAmountTotal;
    }

    /// @notice Returns cumulative amount ever queued
    /// @return The cumulative queued amount
    function queueAmountCumulative() external view returns (uint256) {
        return _queueAmountCumulative;
    }
}
