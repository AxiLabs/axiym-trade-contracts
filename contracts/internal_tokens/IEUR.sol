// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {InternalToken} from "./InternalToken.sol";

contract IEUR is InternalToken {
    constructor(
        address authRegistry_
    ) InternalToken("IEUR", "IEUR", 978, authRegistry_) {}
}
