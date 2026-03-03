// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {InternalToken} from "./InternalToken.sol";

contract IUSD is InternalToken {
    constructor(address authRegistry_) InternalToken("IUSD", "IUSD", 840, authRegistry_) {}
}
