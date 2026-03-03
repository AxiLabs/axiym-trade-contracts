// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.24;

import {IAuthRegistry} from "../interfaces/IAuthRegistry.sol";
import {Governable} from "../governance/Governable.sol";
import {ContractVersion} from "../enums/ContractVersion.sol";

/// @title AuthRegistry - A contract for managing a registry of approved auth addresses
contract AuthRegistry is IAuthRegistry, Governable {
    ContractVersion public immutable version = ContractVersion.AuthRegistry;

    // --- State ---
    mapping(address => bool) private _authAddress;
    mapping(uint256 => address) private _authAddressKeys;
    uint256 private _authAddressesCount;

    // --- Events ---
    event AuthAddressAdded(address indexed authAddress);
    event AuthAddressDisabled(address indexed authAddress);

    // --- Constructor ---
    constructor(address governance_) Governable(governance_) {}

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Auth Address Management Functions
    // ════════════════════════════════════════════════════════════════════════════

    /// @notice Adds a new authorized address
    /// @param authAddress_ The address to authorize
    function addAuthAddress(address authAddress_) external onlyGovernor {
        if (_authAddress[authAddress_]) revert AddressExists();

        _authAddress[authAddress_] = true;
        _authAddressKeys[_authAddressesCount] = authAddress_;
        _authAddressesCount++;

        emit AuthAddressAdded(authAddress_);
    }

    /// @notice Disables an authorized address
    /// @param authAddress_ The address to disable
    function disableAuthAddress(address authAddress_) external onlyGovernor {
        if (!_authAddress[authAddress_]) revert AddressInvalid();

        _authAddress[authAddress_] = false;

        emit AuthAddressDisabled(authAddress_);
    }

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Getters
    // ════════════════════════════════════════════════════════════════════════════

    /// @notice Checks if an address is authorized
    /// @param address_ The address to check
    function isAuthAddress(address address_) external view returns (bool) {
        return _authAddress[address_];
    }

    /// @notice Returns the authorized address at a given index
    /// @param idx_ The index of the authorized address
    function getAuthAddressByIdx(uint256 idx_) external view returns (address) {
        return _authAddressKeys[idx_];
    }

    /// @notice Returns the total count of authorized addresses
    function authAddressesCount() external view returns (uint256) {
        return _authAddressesCount;
    }
}
