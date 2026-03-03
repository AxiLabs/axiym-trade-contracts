// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.24;

import {IGovernance} from "../interfaces/IGovernance.sol";
import {IErrors} from "../interfaces/IErrors.sol";
import {ContractVersion} from "../enums/ContractVersion.sol";

/// @title Governance contract managing superAdmin, governor, and manager roles
/// @notice The superAdmin can update governor and manager with role conflict checks
contract Governance is IGovernance, IErrors {
    ContractVersion public immutable version = ContractVersion.Governance;

    // --- State Variables ---
    address internal superAdmin;
    address internal governor;
    address internal manager;
    address internal authorizer;

    // --- Events ---
    event GovernorTransferred(
        address indexed previousGovernor,
        address indexed newGovernor
    );
    event ManagerTransferred(
        address indexed previousManager,
        address indexed newManager
    );
    event SuperAdminTransferred(
        address indexed previousSuperAdmin,
        address indexed newSuperAdmin
    );
    event AuthorizerTransferred(
        address indexed previousAuthorizer,
        address indexed newAuthorizer
    );

    // --- Modifiers ---
    modifier onlySuperAdmin() {
        if (msg.sender != superAdmin) revert Unauthorized();
        _;
    }

    constructor(
        address _superAdmin,
        address _governor,
        address _manager,
        address _authorizer
    ) {
        if (
            _superAdmin == address(0) ||
            _governor == address(0) ||
            _manager == address(0) ||
            _authorizer == address(0)
        ) revert AddressEmpty();

        superAdmin = _superAdmin;
        governor = _governor;
        manager = _manager;
        authorizer = _authorizer;

        emit SuperAdminTransferred(address(0), _superAdmin);
        emit GovernorTransferred(address(0), _governor);
        emit ManagerTransferred(address(0), _manager);
        emit AuthorizerTransferred(address(0), _authorizer);
    }

    /// @notice Transfers governor role to a new address (only superAdmin)
    /// @param newGovernor New governor address
    function transferGovernor(address newGovernor) external onlySuperAdmin {
        if (newGovernor == address(0)) revert AddressEmpty();
        if (newGovernor == manager) revert GovernorAndManagerCannotBeSame();

        address oldGovernor = governor;
        governor = newGovernor;

        emit GovernorTransferred(oldGovernor, newGovernor);
    }

    /// @notice Transfers manager role to a new address (only superAdmin)
    /// @param newManager New manager address
    function transferManager(address newManager) external onlySuperAdmin {
        if (newManager == address(0)) revert AddressEmpty();
        if (newManager == governor) revert GovernorAndManagerCannotBeSame();

        address oldManager = manager;
        manager = newManager;

        emit ManagerTransferred(oldManager, newManager);
    }

    /// @notice Transfers superAdmin role to a new address (only current superAdmin)
    /// @param newSuperAdmin New superAdmin address
    function transferSuperAdmin(address newSuperAdmin) external onlySuperAdmin {
        if (newSuperAdmin == address(0)) revert AddressEmpty();

        address oldSuperAdmin = superAdmin;
        superAdmin = newSuperAdmin;

        emit SuperAdminTransferred(oldSuperAdmin, newSuperAdmin);
    }

    /// @notice Transfers Authorizer role to a new address (only authorizer itself)
    /// @param newAuthorizer New Authorizer address
    function transferAuthorizer(address newAuthorizer) external {
        if (msg.sender != authorizer) revert Unauthorized();
        if (newAuthorizer == address(0)) revert AddressEmpty();

        address oldAuthorizer = authorizer;
        authorizer = newAuthorizer;

        emit AuthorizerTransferred(oldAuthorizer, newAuthorizer);
    }

    // --- Getters ---

    /// @notice Returns the current superAdmin address
    function getSuperAdmin() external view returns (address) {
        return superAdmin;
    }

    /// @notice Returns the current governor address
    function getGovernor() external view returns (address) {
        return governor;
    }

    /// @notice Returns the current manager address
    function getManager() external view returns (address) {
        return manager;
    }

    /// @notice Returns the current manager address
    function getAuthorizer() external view returns (address) {
        return authorizer;
    }
}
