// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.24;

import {IGovernance} from "../interfaces/IGovernance.sol";
import {IErrors} from "../interfaces/IErrors.sol";

/// @title Governable
/// @notice Abstract contract providing access control modifiers based on external Governance roles
/// @dev Inherit this contract to protect functions with onlyGovernor, onlyManager, and onlySuperAdmin modifiers
abstract contract Governable is IErrors {
    // --- State Variables ---
    address internal _governance;

    /// @notice Sets the governance contract address
    /// @param governance_ Address of the deployed governance contract
    constructor(address governance_) {
        _governance = governance_;
    }

    // --- Modifiers ---

    /// @notice Modifier that allows only the governor to call the function
    modifier onlyGovernor() {
        if (msg.sender != governor()) {
            revert Unauthorized();
        }
        _;
    }

    /// @notice Modifier that allows only the manager to call the function
    modifier onlyManager() {
        if (msg.sender != manager()) {
            revert Unauthorized();
        }
        _;
    }

    /// @notice Modifier that allows only the superAdmin to call the function
    modifier onlySuperAdmin() {
        if (msg.sender != superAdmin()) {
            revert Unauthorized();
        }
        _;
    }

    modifier onlyAuthorizer() {
        if (msg.sender != authorizer()) revert Unauthorized();
        _;
    }

    // --- View Functions ---

    /// @notice Returns the current governance contract address
    /// @return Address of the governance contract
    function governance() external view returns (address) {
        return _governance;
    }

    /// @notice Returns the current superAdmin address from governance
    /// @return Address of the superAdmin
    function superAdmin() public view returns (address) {
        return IGovernance(_governance).getSuperAdmin();
    }

    /// @notice Returns the current governor address from governance
    /// @return Address of the governor
    function governor() public view returns (address) {
        return IGovernance(_governance).getGovernor();
    }

    /// @notice Returns the current manager address from governance
    /// @return Address of the manager
    function manager() public view returns (address) {
        return IGovernance(_governance).getManager();
    }

    /// @notice Returns the current authorizer address from governance
    /// @return Address of the authorizer
    function authorizer() public view returns (address) {
        return IGovernance(_governance).getAuthorizer();
    }
}
