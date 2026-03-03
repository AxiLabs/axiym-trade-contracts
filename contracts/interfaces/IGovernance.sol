// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.24;

interface IGovernance {
    function transferGovernor(address) external;

    function transferManager(address) external;

    function transferSuperAdmin(address) external;

    function getSuperAdmin() external view returns (address);

    function getGovernor() external view returns (address);

    function getManager() external view returns (address);

    function getAuthorizer() external view returns (address);
}
