// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.24;

import {Governable} from "../governance/Governable.sol";
import {CompanyAccount} from "../company/CompanyAccount.sol";
import {ContractVersion} from "../enums/ContractVersion.sol";
import {IAuthRegistry} from "../interfaces/IAuthRegistry.sol";

contract CompanyAccountFactory is Governable {
    ContractVersion public immutable version = ContractVersion.CompanyAccountFactory;
    address internal immutable _authRegistry;

    event CompanyAccountCreated(
        address indexed companyAccount,
        address indexed signer
    );

    constructor(address governance_, address authRegistry_) Governable(governance_) {
        _authRegistry = authRegistry_;
    }

    function build(address signer_) external returns (address) {
        if (!IAuthRegistry(_authRegistry).isAuthAddress(msg.sender))
            revert Unauthorized();

        CompanyAccount account = new CompanyAccount(
            _governance,
            _authRegistry,
            signer_
        );

        emit CompanyAccountCreated(address(account), signer_);
        return address(account);
    }
}
