// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.24;

import {OwnerManager} from "./OwnerManager.sol";
import {IMultiSig} from "./interfaces/IMultiSig.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title MultiSig
 * @notice A multi-signature wallet with support for confirmations using signed messages.
 */
contract MultiSig is OwnerManager, IMultiSig {
    // --- State Variables ---

    /// @notice Tracks executed transaction hashes to prevent replay attacks
    mapping(bytes32 => bool) public _signedMessages;

    /// @notice Tracks executed transaction hashes in order
    mapping(uint256 => bytes32) public _executedHashes;

    /// @notice Count of executed transactions
    uint256 public _executedCount;

    // --- Events ---
    event MultiSigSetup(
        address indexed deployer,
        address[] owners,
        uint256 threshold
    );
    event ExecutionSuccess(bytes32 indexed txHash, uint256 timestamp);

    // --- Constructor ---

    /// @notice Initializes the multisig wallet with owners and threshold.
    /// @param owners_ Array of addresses that will be owners of the MultiSig.
    /// @param threshold_ Number of required signatures for a transaction.
    constructor(address[] memory owners_, uint256 threshold_) {
        if (owners_.length == 0) revert ZeroOwners();
        if (threshold_ == 0 || threshold_ > owners_.length)
            revert InvalidThreshold();

        _setup(owners_, threshold_);
    }

    // --- Internal Setup ---

    /// @notice Internal function to initialize owners and threshold.
    /// @param owners_ Array of addresses that will be the owners.
    /// @param threshold_ Number of required signatures for transactions.
    function _setup(address[] memory owners_, uint256 threshold_) internal {
        _setupOwners(owners_, threshold_);
        emit MultiSigSetup(msg.sender, owners_, threshold_);
    }

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Transaction Execution Functions
    // ════════════════════════════════════════════════════════════════════════════

    /// @notice Executes a transaction after verifying required signatures.
    /// @param to_ Destination address.
    /// @param data_ Transaction calldata.
    /// @param signatures_ Concatenated signatures of the owners.
    /// @param nonce_ Unique nonce to prevent replay attacks.
    function execTransaction(
        address to_, // governor contract
        bytes calldata data_, // packet sent to governor (to, data, salt)
        bytes calldata signatures_,
        bytes32 nonce_
    ) external {
        // Get transaction hash and check not already executed
        bytes32 txHash = getTransactionHash(to_, data_, nonce_);
        if (_signedMessages[txHash]) revert AlreadyExecuted();

        // Validate signatures (reverts if invalid)
        _validateSignatures(txHash, signatures_);

        // Signatures valid, update state
        _signedMessages[txHash] = true;
        _executedHashes[_executedCount] = txHash;
        _executedCount++;

        // Make external call
        (bool success, bytes memory returnData) = to_.call{value: 0}(data_);

        // Revert if failure
        if (!success) {
            // If there is return data, it's a revert reason or custom error
            if (returnData.length > 0) {
                assembly {
                    let returndata_size := mload(returnData)
                    revert(add(32, returnData), returndata_size)
                }
            } else {
                revert TransactionExecutionFailed();
            }
        }

        emit ExecutionSuccess(txHash, block.timestamp);
    }

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Simulation Functions
    // ════════════════════════════════════════════════════════════════════════════

    /// @notice Simulates execution of a transaction without persisting state.
    /// @param to_ Destination address of the transaction.
    /// @param data_ Calldata to execute on the destination.
    function simulateTransaction(address to_, bytes calldata data_) external {
        (bool success, bytes memory returnData) = to_.call{value: 0}(data_);

        if (!success) {
            if (returnData.length > 0) {
                assembly {
                    revert(add(32, returnData), mload(returnData))
                }
            } else {
                revert SimulationCallFailed();
            }
        }

        // ALWAYS REVERT
        revert SimulationSuccess();
    }

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Signature Verification Functions
    // ════════════════════════════════════════════════════════════════════════════

    /// @notice Internal function to validate signatures.
    /// @param txHash_ Hash of the transaction.
    /// @param signatures_ Concatenated signatures.
    function _validateSignatures(
        bytes32 txHash_,
        bytes calldata signatures_
    ) internal view returns (uint256) {
        if (_threshold == 0) revert InvalidThreshold();

        // Check signature length
        uint256 sigLength = signatures_.length;
        if (sigLength % 65 != 0) revert InvalidSignatureLength();

        uint256 totalSignatures = sigLength / 65;
        if (totalSignatures < _threshold) revert InsufficientSignatures();

        // Track seen owners in memory to prevent duplicates
        address[] memory seenOwners = new address[](totalSignatures);
        uint256 validCount = 0;

        for (uint256 i = 0; i < totalSignatures; i++) {
            // Extract signature (65 bytes each)
            address signer = ECDSA.recover(
                txHash_,
                signatures_[i * 65:(i + 1) * 65]
            );

            // Check if owner
            if (!_owners[signer]) revert NotOwner();

            // Check for duplicates (linear search in memory)
            for (uint256 j = 0; j < i; j++) {
                if (seenOwners[j] == signer) revert DuplicateOwner();
            }

            seenOwners[i] = signer;
            validCount++;
        }

        if (validCount < _threshold) revert InsufficientValidOwners();

        return validCount;
    }

    ///
    /// @notice Public view function to check signatures without executing.
    /// @param txHash_ Hash of the transaction.
    /// @param signatures_ Concatenated signatures.
    function checkSignatures(
        bytes32 txHash_,
        bytes calldata signatures_
    ) public view override returns (uint256) {
        return _validateSignatures(txHash_, signatures_);
    }

    /// @notice Generates a hash for a transaction for signing purposes.
    /// @dev Includes chainId to prevent cross-chain replay attacks.
    /// @param to Destination address.
    /// @param data Transaction calldata.
    /// @param nonce Unique nonce to prevent replay attacks.
    function getTransactionHash(
        address to,
        bytes calldata data,
        bytes32 nonce
    ) public view returns (bytes32) {
        return
            MessageHashUtils.toEthSignedMessageHash(
                keccak256(
                    abi.encodePacked(
                        block.chainid,
                        address(this),
                        to,
                        keccak256(data),
                        nonce
                    )
                )
            );
    }

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Getter Functions
    // ════════════════════════════════════════════════════════════════════════════

    /// @notice Returns the hash of the transaction at a specific index.
    function getExecutedHash(uint256 index) external view returns (bytes32) {
        return _executedHashes[index];
    }

    /// @notice Returns whether a transaction hash has been executed.
    function isExecuted(bytes32 txHash) external view returns (bool) {
        return _signedMessages[txHash];
    }

    /// @notice Returns executed count
    function executedCount() external view returns (uint256) {
        return _executedCount;
    }
}
