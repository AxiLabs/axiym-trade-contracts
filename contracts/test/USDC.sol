// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {
        _mint(msg.sender, 100000000 * 10 ** 6); // optional initial supply
    }

    /// @notice Override decimals to 6 to mimic USDC standard
    function decimals() public pure override returns (uint8) {
        return 6;
    }
}
