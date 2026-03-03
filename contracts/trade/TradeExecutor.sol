// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.24;

import {TradeQueue} from "./TradeQueue.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Governable} from "../governance/Governable.sol";
import {Trade} from "./structs/Trade.sol";
import {TradeState} from "../trade/enums/TradeState.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title TradeExecutor
/// @notice Handles execution of queued trades with treasury interaction
abstract contract TradeExecutor is TradeQueue, Governable, ReentrancyGuard {
    /// @notice The trade pool asset (internal currency, e.g. IUSD)
    IERC20 internal immutable _offAsset;

    /// @notice The treasury asset (external currency, e.g. USDT)
    IERC20 internal immutable _onAsset;

    /// @notice Whether queue execution happens automatically
    bool internal _autoExecution = true;

    /// @notice Whether queue allowed partial execution
    bool internal _partialExecution = false;

    /// @notice Maximum number of trades to execute in one queue run
    uint256 internal _maxTrades;

    /// @notice Gas threshold for stopping queue execution
    uint256 internal _gasThreshold = 150000;

    // --- Events ---
    event AutoExecutionSet(bool newAutoExecution);
    event PartialExecutionSet(bool newPartialExecution);
    event QueueExecuted(uint256 totalExecuted, uint256 remainingBalance);
    event GasThresholdSet(uint256 gasThreshold);
    event MaxTradesSet(uint256 maxTrades);

    // --- Constructor ---
    /// @param governance_ Governance address
    /// @param authRegistry_ Auth registry address
    /// @param offAsset_ Address of the internal exchange asset (IUSD)
    /// @param onAsset_ Address of external asset (USDT)
    constructor(
        address governance_,
        address authRegistry_,
        address offAsset_,
        address onAsset_
    ) TradeQueue(authRegistry_) Governable(governance_) {
        _offAsset = IERC20(offAsset_);
        _onAsset = IERC20(onAsset_);
    }

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Execution Configuration
    // ════════════════════════════════════════════════════════════════════════════

    /// @notice Enable or disable auto execution mode
    /// @param newAutoExecution_ True to enable auto execution, false to disable
    function setAutoExecution(bool newAutoExecution_) external onlyGovernor {
        _autoExecution = newAutoExecution_;
        emit AutoExecutionSet(newAutoExecution_);
    }

    /// @notice Enable or disable partial execution mode
    /// @param newPartialExecution_ True to enable partial execution, false to disable
    function setPartialExecution(bool newPartialExecution_) external onlyGovernor {
        _partialExecution = newPartialExecution_;
        emit PartialExecutionSet(newPartialExecution_);
    }

    /// @notice Set gas threshold for queue execution
    /// @param newGasThreshold_ Minimum gas remaining before stopping queue execution
    function setGasThreshold(uint256 newGasThreshold_) external onlyGovernor {
        _gasThreshold = newGasThreshold_;
        emit GasThresholdSet(newGasThreshold_);
    }

    /// @notice Set max trades to execute in one queue run
    /// @param newMaxTrades_ Maximum number of trades to execute
    function setMaxTrades(uint256 newMaxTrades_) external onlyGovernor {
        _maxTrades = newMaxTrades_;
        emit MaxTradesSet(newMaxTrades_);
    }

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Queue Execution
    // ════════════════════════════════════════════════════════════════════════════

    /// @notice Run execution engine
    function executeQueue() external onlyAuthAddress nonReentrant {
        if (_partialExecution) {
            _runExecutionEngine(true);
        } else {
            _runExecutionEngine(false);
        }
    }

    /// @notice Run execution engine internal
    function _executeQueue() internal {
        if (_partialExecution) {
            _runExecutionEngine(true);
        } else {
            _runExecutionEngine(false);
        }
    }

    /// @notice Executes execution engine, with partial allowed or not allowed
    function _runExecutionEngine(bool allowPartial) internal {
        uint256 available = _getTreasuryBalance();
        if (available == 0) return;

        uint256 totalExecuted;
        uint256 executedCount;
        uint256 gasLimit = _gasThreshold;

        (, uint256 currentTrade) = getNext(0);

        while (currentTrade != 0 && available > 0) {
            if (gasleft() < gasLimit) break;
            if (_maxTrades > 0 && executedCount >= _maxTrades) break;

            Trade storage trade = _trades[currentTrade];
            (, uint256 nextTrade) = getNext(currentTrade);

            if (trade.status == TradeState.Pending) {
                uint256 paymentAmount = 0;

                if (available >= trade.currentPayoutSize) {
                    // Sufficient funds for full payment
                    paymentAmount = trade.currentPayoutSize;
                } else if (allowPartial) {
                    // Insufficient funds, but partial payments are allowed
                    paymentAmount = available;
                }

                // If we determined a valid payment amount, execute it
                if (paymentAmount > 0) {
                    available -= paymentAmount;
                    totalExecuted += paymentAmount;
                    executedCount++;

                    _executeTrade(currentTrade, trade, paymentAmount);
                }
            }
            currentTrade = nextTrade;
        }

        emit QueueExecuted(totalExecuted, available);
    }

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Single Trade Execution Functions
    // ════════════════════════════════════════════════════════════════════════════

    /// @notice Internal helper to execute a trade with partial/full logic
    /// @param tradeId_ The trade ID
    function executeSingleTrade(
        uint256 tradeId_
    ) external onlyAuthAddress nonReentrant {
        Trade storage trade = _trades[tradeId_];

        _executeSingleTradeInternal(tradeId_, trade);
    }

    /// @notice Internal helper to execute a trade with partial/full logic
    /// @param tradeBytes_ The trade bytes
    function executeSingleTradeBytes(
        bytes16 tradeBytes_
    ) external onlyAuthAddress nonReentrant {
        // decode the tradeId from bytes
        Trade storage trade = _trades[_tradesBytesToUint[tradeBytes_]];

        _executeSingleTradeInternal(_tradesBytesToUint[tradeBytes_], trade);
    }

    /// @notice Internal helper to execute a trade with partial/full logic
    /// @param tradeId_ The trade ID
    /// @param trade_ Storage pointer to the trade
    function _executeSingleTradeInternal(
        uint256 tradeId_,
        Trade storage trade_
    ) internal {
        if (trade_.status != TradeState.Pending) revert InvalidStatus();

        uint256 available = _getTreasuryBalance();
        uint256 amount;

        if (available >= trade_.currentPayoutSize) {
            amount = trade_.currentPayoutSize;
        } else if (_partialExecution) {
            amount = available;
        } else {
            revert InsufficientTreasuryBalance();
        }

        _executeTrade(tradeId_, trade_, amount);
    }

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Functions overridden in child
    // ════════════════════════════════════════════════════════════════════════════

    function _getTreasuryBalance() internal view virtual returns (uint256);

    function _executeTrade(
        uint256 tradeUint_,
        Trade storage trade_,
        uint256 amount_
    ) internal virtual;

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Getters
    // ════════════════════════════════════════════════════════════════════════════

    /// @notice Returns the auth registry address
    /// @return The auth registry address
    function authRegistry() external view returns (address) {
        return _authRegistry;
    }

    /// @notice Returns whether auto execution is enabled
    /// @return True if auto execution is enabled
    function autoExecution() external view returns (bool) {
        return _autoExecution;
    }

    /// @notice Returns the maximum trades per execution
    /// @return The max trades limit
    function maxTrades() external view returns (uint256) {
        return _maxTrades;
    }

    /// @notice Returns the gas threshold for execution
    /// @return The gas threshold
    function gasThreshold() external view returns (uint256) {
        return _gasThreshold;
    }

    /// @notice Returns the off asset (internal currency)
    /// @return The off asset address
    function offAsset() external view returns (address) {
        return address(_offAsset);
    }

    /// @notice Returns the on asset (external currency)
    /// @return The on asset address
    function onAsset() external view returns (address) {
        return address(_onAsset);
    }

    /// @notice Returns the on partialExecution
    /// @return The on asset address
    function partialExecution() external view returns (bool) {
        return _partialExecution;
    }
}
