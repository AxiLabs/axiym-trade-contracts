// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.24;

interface IOwnerManager {
    function addOwnerWithThreshold(address, uint256) external;

    function removeOwner(address, uint256) external;

    function swapOwner(address, address) external;

    function changeThreshold(uint256) external;

    function getThreshold() external view returns (uint256);

    function isOwner(address) external view returns (bool);

    function getOwners() external view returns (address[] memory);
}
