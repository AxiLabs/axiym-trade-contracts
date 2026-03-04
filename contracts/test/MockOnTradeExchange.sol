// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.24;

import {ISegregatedTreasury} from "../trade/interfaces/ISegregatedTreasury.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockOnTradeExchange {
    using SafeERC20 for IERC20;

    IERC20 public offAsset;

    constructor(address offAsset_) {
        offAsset = IERC20(offAsset_);
    }

    function callExecuteTrade(
        address treasury_,
        uint256 tradeUint_,
        uint256 amount_,
        uint256 validatedPayoutSize_
    ) external {
        // approve treasury to pull offAsset from this mock
        SafeERC20.forceApprove(offAsset, treasury_, amount_);
        ISegregatedTreasury(treasury_).executeTrade(
            tradeUint_,
            amount_,
            validatedPayoutSize_
        );
    }
}
