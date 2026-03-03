// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IAuthRegistry} from "../interfaces/IAuthRegistry.sol";
import {IInternalToken} from "../interfaces/IInternalToken.sol";
import {IErrors} from "../interfaces/IErrors.sol";
import {ContractVersion} from "../enums/ContractVersion.sol";

/// @title InternalToken - ERC20 token with auth and borrower restrictions
abstract contract InternalToken is IInternalToken, ERC20, IErrors {
    ContractVersion public immutable version = ContractVersion.InternalToken;

    // --- State ---
    /// @notice Auth registry contract address
    address private immutable _authRegistry;

    /// @notice Liquidity currency identifier
    uint256 private immutable _liquidityCurrency;

    // --- Constructor ---
    /// @param name_ Token name
    /// @param symbol_ Token symbol
    /// @param liquidityCurrency_ Liquidity currency ID
    /// @param authRegistry_ Auth registry contract address
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 liquidityCurrency_,
        address authRegistry_
    ) ERC20(name_, symbol_) {
        _authRegistry = authRegistry_;
        _liquidityCurrency = liquidityCurrency_;
    }

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 ERC20 Overrides
    // ════════════════════════════════════════════════════════════════════════════

    /// @notice Returns decimals (fixed at 6)
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    /// @notice Transfers tokens, restricted to non-active borrower accounts
    /// @param to Recipient address
    /// @param amount Amount to transfer
    function transfer(
        address to,
        uint256 amount
    ) public override returns (bool) {
        _onlyContract();

        return super.transfer(to, amount);
    }

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Owner Functions (Auth Registry only)
    // ════════════════════════════════════════════════════════════════════════════

    /// @notice Approves tokens, restricted to non-active borrower accounts
    /// @param owner Owner address
    /// @param spender Spender address
    /// @param value Amount to transfer
    function ownerApprove(
        address owner,
        address spender,
        uint256 value
    ) external returns (bool) {
        _onlyAuth();
        _approve(owner, spender, value);
        return true;
    }

    /// @notice Mints tokens; restricted to authorized callers
    /// @param to Recipient address
    /// @param amount Amount to mint
    function mint(address to, uint256 amount) external {
        _onlyAuth();
        _mint(to, amount);
    }

    /// @notice Burns tokens; restricted to authorized callers
    /// @param from Address to burn from
    /// @param amount Amount to burn
    function burn(address from, uint256 amount) external {
        _onlyAuth();
        _burn(from, amount);
    }

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Getters
    // ════════════════════════════════════════════════════════════════════════════

    /// @notice Returns the liquidity currency ID
    /// @return uint256 Liquidity currency identifier
    function liquidityCurrency() external view returns (uint256) {
        return _liquidityCurrency;
    }

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Internal Auth Checks
    // ════════════════════════════════════════════════════════════════════════════

    /// @notice Reverts if caller is not authorized in Auth Registry
    function _onlyAuth() internal view {
        if (IAuthRegistry(_authRegistry).isAuthAddress(msg.sender)) return;

        revert Unauthorized();
    }

    /// @notice Reverts if caller is not a contract
    function _onlyContract() internal view {
        uint256 size;
        address addr = msg.sender;

        assembly {size := extcodesize(addr)}

        if (size > 0) return;

        revert NotContract();
    }
}
