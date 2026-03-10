// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Governable} from "../governance/Governable.sol";
import {ContractVersion} from "../enums/ContractVersion.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAuthRegistry} from "../interfaces/IAuthRegistry.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title CompanyAccount
/// @notice Manages signers, liquidity assets, and receivers for a company account.
/// Provides registry-style enumeration using counts and mappings.
contract CompanyAccount is Governable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice The contract version
    ContractVersion public immutable version = ContractVersion.CompanyAccount;

    // --- State ---
    address internal _authRegistry;
    bool internal _paused;
    mapping(bytes16 => bool) private _nonces;

    // signer state variables
    mapping(address => bool) internal _signers; // signer => bool
    mapping(uint256 => address) internal _signerByIndex; // idx => signer
    uint256 internal _signerCount; // count of signers

    // receiver state variables
    mapping(address => bool) internal _receivers; // receiver => bool
    mapping(uint256 => address) internal _receiverByIndex; // idx => receiver
    uint256 internal _receiverCount; // count of receivers

    // spenders state variables
    mapping(address => mapping(address => bool)) internal _spenders; // liquidityAsset => spender => bool
    mapping(address => mapping(uint256 => address)) internal _spenderByIndex; // liquidityAsset => idx => spender
    mapping(address => mapping(address => uint256)) internal _spenderIndex; // liquidityAsset => spender => idx
    mapping(address => uint256) internal _spenderCount; // count of spenders

    // liquidity asset state variables
    mapping(uint256 => address) internal _liquidityAssetByIndex; // idx => liquidityAsset
    mapping(address => bool) internal _liquidityAssetExists; // liquidityAsset => bool
    uint256 internal _liquidityAssetCount; // total number of liquidityAssets

    // --- Events ---
    event Paused();
    event Unpaused();
    event SignerAdded(address indexed signer);
    event SignerRemoved(address indexed signer);
    event ReceiverAdded(address indexed receiver);
    event ReceiverRemoved(address indexed receiver);
    event SpenderAdded(address indexed liquidityAsset, address indexed spender);
    event SpenderRemoved(address indexed liquidityAsset, address indexed spender);
    event SpenderApproved(
        address indexed liquidityAsset,
        address indexed spender,
        uint256 amount
    );
    event Withdraw(
        address indexed liquidityAsset,
        address indexed receiver,
        uint256 amount
    );
    event OperationAuthorized(
        address indexed signer,
        address indexed target,
        uint256 amount,
        bytes16 nonce
    );
    event AuthRegistryTransferred(
        address indexed oldAuthRegistry,
        address indexed newAuthRegistry
    );

    // --- Modifiers ---
    modifier notPaused() {
        if (_paused) revert GovernorPaused();
        _;
    }

    /// @notice Constructs the CompanyAccount contract
    /// @param governance_ The governance address
    /// @param authRegistry_ The address of the AuthRegistry contract
    /// @param signer_ The initial signer address
    constructor(
        address governance_,
        address authRegistry_,
        address signer_
    ) Governable(governance_) {
        _authRegistry = authRegistry_;

        if (signer_ == address(0)) revert AddressEmpty();
        _signers[signer_] = true;
        _signerByIndex[_signerCount] = signer_;
        _signerCount++;
        emit SignerAdded(signer_);
    }

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 superAdmin Functions
    // ════════════════════════════════════════════════════════════════════════════

    /// @notice Pause.
    function pause() external onlyManager {
        _paused = true;
        emit Paused();
    }

    /// @notice Unpause.
    function unpause() external onlyManager {
        _paused = false;
        emit Unpaused();
    }

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Governance Functions
    // ════════════════════════════════════════════════════════════════════════════
    /// @notice Updates the AuthRegistry address
    /// @param newAuthRegistry_ New AuthRegistry address
    function setAuthRegistry(address newAuthRegistry_) external onlyGovernor {
        if (newAuthRegistry_ == address(0)) revert AddressEmpty();
        if (newAuthRegistry_ == _authRegistry) revert AddressExists();

        address oldAuthRegistry = _authRegistry;
        _authRegistry = newAuthRegistry_;

        emit AuthRegistryTransferred(oldAuthRegistry, newAuthRegistry_);
    }

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Signer Functions
    // ════════════════════════════════════════════════════════════════════════════

    /// @notice Adds a new signer
    /// @param signer_ The address to be added as a signer
    function addSigner(address signer_) external onlyGovernor {
        if (signer_ == address(0)) revert AddressEmpty();
        if (_signers[signer_]) revert AddressExists();

        _signers[signer_] = true;
        _signerByIndex[_signerCount] = signer_;
        _signerCount++;

        emit SignerAdded(signer_);
    }

    /// @notice Removes an existing signer
    /// @param signer_ The address of the signer to remove
    function removeSigner(address signer_) external onlyGovernor {
        if (!_signers[signer_]) revert AddressInvalid();
        _signers[signer_] = false;

        emit SignerRemoved(signer_);
    }

    /// @notice Authorizes a specific operation.
    function _authorizeOperation(
        address liquidityAsset_,
        address address_,
        uint256 amount_,
        bytes16 id_,
        bytes16 nonce_,
        bytes memory signature_
    ) private {
        if (_nonces[nonce_]) revert InvalidAccountNonce();

        address signer = _recoverSigner(
            liquidityAsset_,
            address_,
            amount_,
            id_,
            nonce_,
            signature_
        );

        if (!_signers[signer]) revert Unauthorized();

        _nonces[nonce_] = true;

        emit OperationAuthorized(signer, address_, amount_, nonce_);
    }

    /// @notice Recovers signer from parameters
    function _recoverSigner(
        address liquidityAsset_,
        address address_,
        uint256 amount_,
        bytes16 id_,
        bytes16 nonce_,
        bytes memory signature_
    ) private view returns (address) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }

        bytes32 messageHash = MessageHashUtils.toEthSignedMessageHash(
            keccak256(
                abi.encodePacked(
                    liquidityAsset_,
                    address_,
                    amount_,
                    id_,
                    nonce_,
                    address(this),
                    chainId
                )
            )
        );

        return ECDSA.recover(messageHash, signature_);
    }

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Receiver Functions
    // ════════════════════════════════════════════════════════════════════════════

    /// @notice Adds a receiver
    /// @param receiver_ The address to be added as a receiver
    /// @param nonce_ A nonce
    /// @param signature_ Signature authorizing the operation
    function addReceiver(
        address receiver_,
        bytes16 nonce_,
        bytes memory signature_
    ) external onlyAuthorizer {
        if (receiver_ == address(0)) revert AddressEmpty();
        if (_receivers[receiver_]) revert AddressExists();

        _authorizeOperation(
            address(0),
            receiver_,
            0,
            bytes16(0),
            nonce_,
            signature_
        );

        _receivers[receiver_] = true;
        _receiverByIndex[_receiverCount] = receiver_;
        _receiverCount++;

        emit ReceiverAdded(receiver_);
    }

    /// @notice Removes a receiver
    /// @param receiver_ The address to be removed as a receiver
    function removeReceiver(address receiver_) external onlyGovernor {
        if (receiver_ == address(0)) revert AddressEmpty();
        if (!_receivers[receiver_]) revert AddressInvalid();

        _receivers[receiver_] = false;

        emit ReceiverRemoved(receiver_);
    }

    /// @notice Withdraws a specified amount of a liquidity asset to an approved receiver.
    /// @param liquidityAsset_ The address of the ERC20 liquidity asset to withdraw.
    /// @param receiver_ The address of the receiver (must be an approved receiver).
    /// @param amount_ The amount of the asset to withdraw.
    /// @param id_ Unique Id
    /// @param nonce_ A unique nonce to prevent replay attacks.
    /// @param signature_ The ECDSA signature from an approved signer authorizing the withdrawal.
    function withdraw(
        address liquidityAsset_,
        address receiver_,
        uint256 amount_,
        bytes16 id_,
        bytes16 nonce_,
        bytes memory signature_
    ) external notPaused nonReentrant {
        if (!IAuthRegistry(_authRegistry).isAuthAddress(msg.sender))
            revert Unauthorized();

        if (!_receivers[receiver_]) revert InvalidReceiver();

        _authorizeOperation(
            liquidityAsset_,
            receiver_,
            amount_,
            id_,
            nonce_,
            signature_
        );

        IERC20(liquidityAsset_).safeTransfer(receiver_, amount_);

        emit Withdraw(liquidityAsset_, receiver_, amount_);
    }

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Spender Functions
    // ════════════════════════════════════════════════════════════════════════════

    /// @notice Adds a new spender for a given liquidity asset
    /// @param liquidityAsset The token/asset address
    /// @param spender_ The address to be added as a spender
    function addSpender(
        address liquidityAsset,
        address spender_
    ) external onlyGovernor {
        if (spender_ == address(0)) revert AddressEmpty();
        if (_spenders[liquidityAsset][spender_]) revert AddressExists();

        uint256 size;
        assembly {
            size := extcodesize(spender_)
        }
        if (size == 0) revert NotContract();

        uint256 count = _spenderCount[liquidityAsset];

        _spenders[liquidityAsset][spender_] = true;
        _spenderByIndex[liquidityAsset][count] = spender_;
        _spenderIndex[liquidityAsset][spender_] = count;
        _spenderCount[liquidityAsset] = count + 1;

        emit SpenderAdded(liquidityAsset, spender_);
    }

    /// @notice Removes an existing spender for a given liquidity asset
    /// @param liquidityAsset The token/asset address
    /// @param spender_ The address of the spender to remove
    function removeSpender(
        address liquidityAsset,
        address spender_
    ) external onlyGovernor {
        if (!_spenders[liquidityAsset][spender_]) revert AddressInvalid();

        _spenders[liquidityAsset][spender_] = false;

        uint256 count = _spenderCount[liquidityAsset];
        uint256 index = _spenderIndex[liquidityAsset][spender_];

        if (index != count - 1) {
            address last = _spenderByIndex[liquidityAsset][count - 1];
            _spenderByIndex[liquidityAsset][index] = last;
            _spenderIndex[liquidityAsset][last] = index;
        }

        delete _spenderByIndex[liquidityAsset][count - 1];
        delete _spenderIndex[liquidityAsset][spender_];
        _spenderCount[liquidityAsset] = count - 1;

        emit SpenderRemoved(liquidityAsset, spender_);
    }

    /// @notice Called by approved spending contracts to request an ERC20 approval
    /// @param liquidityAsset_ The token/asset address
    /// @param amount_ Amount to approve
    /// @param id_ Unique Id
    /// @param nonce_ A unique nonce
    /// @param signature_ Signature authorizing the operation
    function approveSpender(
        address liquidityAsset_,
        uint256 amount_,
        bytes16 id_,
        bytes16 nonce_,
        bytes memory signature_
    ) external notPaused nonReentrant {
        if (!_spenders[liquidityAsset_][msg.sender]) revert Unauthorized();

        _authorizeOperation(
            liquidityAsset_,
            msg.sender,
            amount_,
            id_,
            nonce_,
            signature_
        );

        SafeERC20.forceApprove(IERC20(liquidityAsset_), msg.sender, amount_);

        emit SpenderApproved(liquidityAsset_, msg.sender, amount_);
    }

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Getters
    // ════════════════════════════════════════════════════════════════════════════

    /// @notice Returns the total number of signers
    function signerCount() external view returns (uint256) {
        return _signerCount;
    }

    /// @notice Returns the signer at a specific index
    function signerByIndex(uint256 index) external view returns (address) {
        return _signerByIndex[index];
    }

    /// @notice Returns the total number of liquidity assets
    function liquidityAssetCount() external view returns (uint256) {
        return _liquidityAssetCount;
    }

    /// @notice Returns the liquidity asset at a specific index
    function liquidityAssetByIndex(uint256 index) external view returns (address) {
        return _liquidityAssetByIndex[index];
    }

    /// @notice Returns the total number of receivers
    function receiverCount() external view returns (uint256) {
        return _receiverCount;
    }

    /// @notice Returns the receiver at a specific index
    function receiverByIndex(uint256 index) external view returns (address) {
        return _receiverByIndex[index];
    }

    /// @notice Checks if an address is an active signer
    function isSigner(address addr) external view returns (bool) {
        return _signers[addr];
    }

    /// @notice Checks if an address is an active receiver
    function isReceiver(address receiver) external view returns (bool) {
        return _receivers[receiver];
    }

    /// @notice Returns the total number of spenders for a given liquidity asset
    function spenderCount(address liquidityAsset) external view returns (uint256) {
        return _spenderCount[liquidityAsset];
    }

    /// @notice Returns the spender at a specific index for a given liquidity asset
    function spenderByIndex(
        address liquidityAsset,
        uint256 index
    ) external view returns (address) {
        return _spenderByIndex[liquidityAsset][index];
    }

    /// @notice Checks if an address is an active spender for a given liquidity asset
    function isSpender(
        address liquidityAsset,
        address spender
    ) external view returns (bool) {
        return _spenders[liquidityAsset][spender];
    }

    /// @notice Checks if a nonce has already been used
    function isNonceUsed(bytes16 nonce) external view returns (bool) {
        return _nonces[nonce];
    }

    /// @notice Returns the address of the AuthRegistry contract
    function authRegistry() external view returns (address) {
        return _authRegistry;
    }

    /// @notice Returns whether the contract is paused
    function paused() external view returns (bool) {
        return _paused;
    }
}
