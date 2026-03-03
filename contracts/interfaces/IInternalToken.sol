// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.24;

interface IInternalToken {
    function mint(address, uint256) external;

    function burn(address, uint256) external;

    function ownerApprove(address, address, uint256) external returns (bool);

    function liquidityCurrency() external view returns (uint256);
}
