// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.24;

import "./IOwnerManager.sol";

interface IMultiSig is IOwnerManager {
    function execTransaction(
        address,
        bytes calldata,
        bytes calldata,
        bytes32
    ) external;

    function checkSignatures(
        bytes32,
        bytes calldata
    ) external view returns (uint256);

    function getTransactionHash(
        address,
        bytes calldata,
        bytes32
    ) external view returns (bytes32);

    function getExecutedHash(uint256) external view returns (bytes32);

    function isExecuted(bytes32) external view returns (bool);
}
