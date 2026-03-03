// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Governable} from "../governance/Governable.sol";
import {ContractVersion} from "../enums/ContractVersion.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Satoshi Test
/// @notice Contract for use in Satoshi Tests
/// @dev Contains withdraw functions for native and ERC20 funds.
contract SatoshiTest is Governable {
    ContractVersion public immutable version = ContractVersion.SatoshiTest;

    event NativeWithdrawn(address superAdmin, uint256 amount);
    event ERC20Withdrawn(address token, address superAdmin, uint256 amount);
    event NativeCoinReceived(address indexed from, uint256 amount);

    constructor(address governance_) Governable(governance_) {}

    // =========================
    // Native Withdraw
    // =========================

    function withdrawAll() external onlyManager {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds");

        (bool success, ) = superAdmin().call{value: balance}("");
        require(success, "Transfer failed");

        emit NativeWithdrawn(superAdmin(), balance);
    }

    // =========================
    // ERC20 Handling
    // =========================

    /// @notice Withdraw specific ERC20 token balance
    function withdrawERC20(address token) external onlyManager {
        require(token != address(0), "Invalid token");

        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance > 0, "No token balance");

        bool success = IERC20(token).transfer(superAdmin(), balance);
        require(success, "Token transfer failed");

        emit ERC20Withdrawn(token, superAdmin(), balance);
    }

    /// @notice Withdraw specific amount of ERC20
    function withdrawERC20Amount(
        address token,
        uint256 amount
    ) external onlyManager {
        require(token != address(0), "Invalid token");
        require(amount > 0, "Invalid amount");

        bool success = IERC20(token).transfer(superAdmin(), amount);
        require(success, "Token transfer failed");

        emit ERC20Withdrawn(token, superAdmin(), amount);
    }

    /// @notice Get ERC20 balance held by contract
    function getERC20Balance(address token) external view returns (uint256) {
        require(token != address(0), "Invalid token");
        return IERC20(token).balanceOf(address(this));
    }

    // =========================
    // Native Receiving
    // =========================

    receive() external payable {
        emit NativeCoinReceived(msg.sender, msg.value);
    }

    fallback() external payable {
        emit NativeCoinReceived(msg.sender, msg.value);
    }
}
