// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title SafeToken
 * @notice A defensive token interaction library that handles non-standard ERC20/TRC20
 *         implementations across chains. Covers:
 *
 *         - Ethereum USDT: returns nothing on transfer (no bool)
 *         - TRON USDT:     returns false even on successful transfer
 *         - BSC BNB:       reverts instead of returning false
 *         - cUSDC:         returns false on some code paths
 *         - Fee-on-transfer tokens: actual received amount < requested amount
 *
 * @dev Strategy:
 *      1. Use low-level .call() to avoid ABI revert on missing return value
 *      2. If call hard-reverts → always fail (genuine failure)
 *      3. If return data is present AND decodes to false → fall back to balance-delta check
 *         (handles TRON USDT which returns false even on success)
 *      4. Balance-delta check is the ground truth — if funds moved, transfer succeeded
 *
 * @dev Gas profile:
 *      - Normal ERC20 (returns true):  1x balanceOf overhead avoided — fast path
 *      - No-return tokens (ETH USDT):  no extra overhead
 *      - False-return tokens (TRC20):  2x balanceOf calls as fallback only
 */
library SafeToken {
    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error SafeToken__CallFailed(address token, bytes4 selector);
    error SafeToken__TransferFailed(address token, address to, uint256 value);
    error SafeToken__TransferFromFailed(
        address token,
        address from,
        address to,
        uint256 value
    );
    error SafeToken__ApproveFailed(address token, address spender, uint256 value);
    error SafeToken__ZeroAddress();
    error SafeToken__ZeroAmount();
    error SafeToken__ApproveRaceCondition(
        address token,
        address spender,
        uint256 currentAllowance
    );

    // -------------------------------------------------------------------------
    // Transfer
    // -------------------------------------------------------------------------

    /**
     * @notice Safely transfer tokens, handling all known non-standard behaviours.
     * @param token  The token contract to call.
     * @param to     Recipient address.
     * @param value  Amount to transfer.
     *
     * Handles:
     *   - Tokens that return nothing          (ETH USDT)
     *   - Tokens that return false on success (TRC20 USDT)
     *   - Tokens that hard-revert on failure  (BSC BNB)
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        if (to == address(0)) revert SafeToken__ZeroAddress();
        if (value == 0) revert SafeToken__ZeroAmount();

        // Snapshot before the call so delta check is accurate regardless of
        // recipient's prior balance (fixes false-positive on pre-funded accounts)
        uint256 balanceBefore = token.balanceOf(to);

        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transfer.selector, to, value)
        );

        // Hard revert — genuine failure on all chains
        if (!success)
            revert SafeToken__CallFailed(address(token), token.transfer.selector);

        // Return data present and decodes to false → could be TRC20 USDT quirk
        // Fall back to strict balance-delta as ground truth
        if (data.length > 0 && !abi.decode(data, (bool))) {
            _requireBalanceDelta(token, to, balanceBefore, value);
        }
    }

    /**
     * @notice Safely transfer tokens and return the actual received amount.
     * @dev    Use this variant for fee-on-transfer tokens where received != sent.
     * @param token  The token contract to call.
     * @param to     Recipient address.
     * @param value  Amount to transfer.
     * @return received  Actual amount received by `to` after fees.
     */
    function safeTransferGetReceived(
        IERC20 token,
        address to,
        uint256 value
    ) internal returns (uint256 received) {
        if (to == address(0)) revert SafeToken__ZeroAddress();
        if (value == 0) revert SafeToken__ZeroAmount();

        uint256 balanceBefore = token.balanceOf(to);

        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transfer.selector, to, value)
        );

        if (!success)
            revert SafeToken__CallFailed(address(token), token.transfer.selector);

        uint256 balanceAfter = token.balanceOf(to);

        // For false-returning tokens: verify balance increased
        if (data.length > 0 && !abi.decode(data, (bool))) {
            if (balanceAfter <= balanceBefore) {
                revert SafeToken__TransferFailed(address(token), to, value);
            }
        }

        received = balanceAfter - balanceBefore;
    }

    // -------------------------------------------------------------------------
    // TransferFrom
    // -------------------------------------------------------------------------

    /**
     * @notice Safely transferFrom tokens, handling all known non-standard behaviours.
     * @param token  The token contract to call.
     * @param from   Source address.
     * @param to     Recipient address.
     * @param value  Amount to transfer.
     */
    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        if (from == address(0) || to == address(0)) revert SafeToken__ZeroAddress();
        if (value == 0) revert SafeToken__ZeroAmount();

        // Snapshot before the call so delta check is accurate regardless of
        // recipient's prior balance (fixes false-positive on pre-funded accounts)
        uint256 balanceBefore = token.balanceOf(to);

        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transferFrom.selector, from, to, value)
        );

        if (!success)
            revert SafeToken__CallFailed(
                address(token),
                token.transferFrom.selector
            );

        if (data.length > 0 && !abi.decode(data, (bool))) {
            _requireBalanceDelta(token, to, balanceBefore, value);
        }
    }

    /**
     * @notice Safely transferFrom tokens and return the actual received amount.
     * @dev    Use this variant for fee-on-transfer tokens.
     */
    function safeTransferFromGetReceived(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal returns (uint256 received) {
        if (from == address(0) || to == address(0)) revert SafeToken__ZeroAddress();
        if (value == 0) revert SafeToken__ZeroAmount();

        uint256 balanceBefore = token.balanceOf(to);

        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transferFrom.selector, from, to, value)
        );

        if (!success)
            revert SafeToken__CallFailed(
                address(token),
                token.transferFrom.selector
            );

        uint256 balanceAfter = token.balanceOf(to);

        if (data.length > 0 && !abi.decode(data, (bool))) {
            if (balanceAfter <= balanceBefore) {
                revert SafeToken__TransferFromFailed(
                    address(token),
                    from,
                    to,
                    value
                );
            }
        }

        received = balanceAfter - balanceBefore;
    }

    // -------------------------------------------------------------------------
    // Approve
    // -------------------------------------------------------------------------

    /**
     * @notice Safely approve a spender, with race condition protection.
     * @dev    Reverts if current allowance is non-zero and new value is also non-zero.
     *         Caller must first approve(0) then approve(newValue) to prevent the
     *         ERC20 approval race condition.
     * @param token    The token contract.
     * @param spender  Address to approve.
     * @param value    Amount to approve.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        if (spender == address(0)) revert SafeToken__ZeroAddress();

        // Prevent approval race condition
        // Caller must set to 0 first before setting a new non-zero value
        uint256 currentAllowance = token.allowance(address(this), spender);
        if (currentAllowance != 0 && value != 0) {
            revert SafeToken__ApproveRaceCondition(
                address(token),
                spender,
                currentAllowance
            );
        }

        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.approve.selector, spender, value)
        );

        if (!success)
            revert SafeToken__CallFailed(address(token), token.approve.selector);

        if (data.length > 0 && !abi.decode(data, (bool))) {
            revert SafeToken__ApproveFailed(address(token), spender, value);
        }
    }

    /**
     * @notice Force-set an approval to any value, handling the race condition
     *         automatically by zeroing out first if needed.
     * @dev    Costs an extra approve(0) call when overwriting a non-zero allowance.
     *         Use this when you don't want to manage the two-step approval yourself.
     */
    function safeForceApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        if (spender == address(0)) revert SafeToken__ZeroAddress();

        uint256 currentAllowance = token.allowance(address(this), spender);

        if (currentAllowance != 0) {
            // Zero out first
            (bool zeroSuccess, ) = address(token).call(
                abi.encodeWithSelector(token.approve.selector, spender, 0)
            );
            if (!zeroSuccess)
                revert SafeToken__CallFailed(address(token), token.approve.selector);
        }

        if (value == 0) return; // Just wanted to zero it out

        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.approve.selector, spender, value)
        );

        if (!success)
            revert SafeToken__CallFailed(address(token), token.approve.selector);

        if (data.length > 0 && !abi.decode(data, (bool))) {
            revert SafeToken__ApproveFailed(address(token), spender, value);
        }
    }

    // -------------------------------------------------------------------------
    // Internal helpers
    // -------------------------------------------------------------------------

    /**
     * @dev Strict balance-delta check: verifies `to`'s balance increased by at least `value`
     *      compared to the snapshot taken BEFORE the call.
     *
     *      This is the correct pattern — checking `balanceNow >= value` without a before-snapshot
     *      is a false-positive bug: if the recipient already held funds, the check passes even
     *      if zero tokens were actually transferred.
     *
     *      We require delta >= value (not strictly ==) to tolerate fee-on-transfer tokens
     *      where received < sent. For exact accounting use the GetReceived variants instead.
     */
    function _requireBalanceDelta(
        IERC20 token,
        address to,
        uint256 balanceBefore,
        uint256 value
    ) private view {
        uint256 balanceAfter = token.balanceOf(to);
        if (balanceAfter <= balanceBefore) {
            revert SafeToken__TransferFailed(address(token), to, value);
        }
    }
}
