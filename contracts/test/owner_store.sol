// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract OwnerStore is Ownable {
    uint256 private _value;

    error ErrorTest();

    // Constructor to set the initial owner
    constructor(address initialOwner_) Ownable(initialOwner_) {}

    // A function only the owner can call
    function setValue(uint256 value_) external onlyOwner {
        _value = value_;
    }

    // Public getter for testing purposes
    function getValue() external view returns (uint256) {
        return _value;
    }

    // Anyone can call this
    function ping() external pure returns (string memory) {
        return "pong";
    }

    function revertTest() external pure {
        revert ErrorTest();
    }
}
