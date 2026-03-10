// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.24;

interface ICompanyAccount {
    function approveSpender(
        address,
        uint256,
        bytes16,
        bytes16,
        bytes memory
    ) external;
}
