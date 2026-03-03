/// @title IOnTradeExchange
/// @notice Unified interface for the OnTradeExchange system
/// @dev Inherits Registry and Queue functionality to provide a complete API
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.24;
import {Trade} from "../structs/Trade.sol";

interface IOnTradeExchange {
    function getTradeData(uint256) external view returns (Trade memory);
}
