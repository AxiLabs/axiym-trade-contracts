// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.24;

import {ContractVersion} from "../../enums/ContractVersion.sol";

/// @title ISegregatedTreasury
/// @notice Interface for the SegregatedTreasury logic
interface ISegregatedTreasury {
    function pause() external;

    function unpause() external;

    function setOwner(address) external;

    function setReceiveAddress(address) external;

    function executeTrade(uint256, uint256) external;

    function version() external view returns (ContractVersion);

    function onTradeExchange() external view returns (address);

    function offAsset() external view returns (address);

    function onAsset() external view returns (address);

    function owner() external view returns (address);

    function receiveAddress() external view returns (address);
}
