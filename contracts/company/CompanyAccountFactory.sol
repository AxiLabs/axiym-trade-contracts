// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.24;

import {Governable} from "../governance/Governable.sol";
import {CompanyAccount} from "../company/CompanyAccount.sol";
import {ContractVersion} from "../enums/ContractVersion.sol";
import {IAuthRegistry} from "../interfaces/IAuthRegistry.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

contract CompanyAccountFactory is Governable {
    using Clones for address;

    ContractVersion public immutable version = ContractVersion.CompanyAccountFactory;
    address internal immutable _authRegistry;

    address public immutable implementation;

    event CompanyAccountCreated(
        address indexed companyAccount,
        address indexed signer
    );

    constructor(address governance_, address authRegistry_) Governable(governance_) {
        _authRegistry = authRegistry_;

        implementation = address(new CompanyAccount());
    }

    function build(address signer_) external returns (address) {
        if (!IAuthRegistry(_authRegistry).isAuthAddress(msg.sender))
            revert Unauthorized();

        address clone = implementation.clone();

        CompanyAccount(clone).initialize(_governance, _authRegistry, signer_);

        emit CompanyAccountCreated(address(clone), signer_);
        return address(clone);
    }

    function authRegistry() external view returns (address) {
        return _authRegistry;
    }
}
