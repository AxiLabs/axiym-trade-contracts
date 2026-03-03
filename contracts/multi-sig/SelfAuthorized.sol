// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.24;

import {IErrors} from "../interfaces/IErrors.sol";

/// @title Self Authorized
/// @notice Authorizes current contract to perform actions on itself.
abstract contract SelfAuthorized is IErrors {
    /**
     * @dev Ensure that the `msg.sender` is the current contract.
     */
    function requireSelfCall() private view {
        if (msg.sender != address(this)) revert Unauthorized();
    }

    /// @notice Ensure that a function is authorized.
    /// @dev This modifier authorizes calls by ensuring that the contract called itself.
    modifier authorized() {
        // Modifiers are copied around during compilation. This is a function call to minimized the bytecode size.
        requireSelfCall();
        _;
    }
}
