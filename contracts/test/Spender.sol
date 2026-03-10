// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICompanyAccount} from "../interfaces/ICompanyAccount.sol";

import "hardhat/console.sol";

contract Spender {
    address internal _liquidityAsset;

    constructor(address liquidityAsset_) {
        _liquidityAsset = liquidityAsset_;
    }

    function requestApprovalAndTransfer(
        address companyAccount_,
        uint256 amount_,
        bytes16 tradeId_,
        bytes16 nonce_,
        bytes memory signature_
    ) external {
        ICompanyAccount(companyAccount_).approveSpender(
            _liquidityAsset,
            amount_,
            tradeId_,
            nonce_,
            signature_
        );

        IERC20(_liquidityAsset).transferFrom(
            companyAccount_,
            address(this),
            amount_
        );
    }
}
