// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.24;

import {SelfAuthorized} from "./SelfAuthorized.sol";
import {IOwnerManager} from "./interfaces/IOwnerManager.sol";
import {IErrors} from "../interfaces/IErrors.sol";

/// @title Owner Manager
/// @notice Manages MultiSig owners and a _threshold to authorize transactions.
abstract contract OwnerManager is SelfAuthorized, IOwnerManager {
    /// @dev Mapping of owner addresses to boolean for quick lookup.
    mapping(address => bool) internal _owners;

    /// @dev Array of owner addresses for enumeration.
    address[] internal _ownerList;

    /// @dev The number of owners.
    uint256 internal _ownerCount;

    /// @dev The _threshold of owners required to sign a transaction.
    uint256 internal _threshold;

    /// @dev Boolean for initialization
    bool _initialized;

    // --- Events ---
    event ChangedThreshold(uint256 threshold);
    event RemovedOwner(address oldOwner);
    event AddedOwner(address newOwner);

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Owner Functions
    // ════════════════════════════════════════════════════════════════════════════

    /// @notice Sets the initial owners and threshold of the MultiSig.
    /// @param owners_ List of MultiSig owners.
    /// @param threshold_ Number of required confirmations for a MultiSig transaction.
    function _setupOwners(address[] memory owners_, uint256 threshold_) internal {
        if (_initialized) revert AlreadyInitialized();
        if (threshold_ > owners_.length || threshold_ == 0)
            revert InvalidThreshold();

        for (uint256 i = 0; i < owners_.length; i++) {
            address owner = owners_[i];
            _requireCanAddOwner(owner);
            _owners[owner] = true;
            _ownerList.push(owner);
        }

        _ownerCount = owners_.length;
        _threshold = threshold_;
        _initialized = true;
    }

    /// @notice Adds a new owner to the MultiSig and optionally updates the threshold.
    /// @param owner_ The address of the owner to add.
    /// @param threshold_ The new threshold to set after adding the owner.
    function addOwnerWithThreshold(
        address owner_,
        uint256 threshold_
    ) public override authorized {
        _requireCanAddOwner(owner_);
        _owners[owner_] = true;
        _ownerList.push(owner_);
        ++_ownerCount;
        emit AddedOwner(owner_);
        if (_threshold != threshold_) changeThreshold(threshold_);
    }

    /// @notice Removes an owner from the MultiSig and optionally updates the threshold.
    /// @param owner_ The owner address to remove.
    /// @param threshold_ The new threshold to set after removal (must be reachable).
    function removeOwner(
        address owner_,
        uint256 threshold_
    ) public override authorized {
        if (!_owners[owner_]) revert OwnerIncorrect();
        if (--_ownerCount < threshold_) revert ThresholdUnreachable();
        _owners[owner_] = false;

        for (uint256 i = 0; i < _ownerList.length; i++) {
            if (_ownerList[i] == owner_) {
                _ownerList[i] = _ownerList[_ownerList.length - 1]; // move last element to this index
                _ownerList.pop(); // remove last
                break;
            }
        }

        if (_threshold != threshold_) {
            changeThreshold(threshold_);
        }

        emit RemovedOwner(owner_);
    }

    /// @notice Replaces an existing owner with a new owner while preserving function signature.
    /// @param oldOwner_ The existing owner to be replaced.
    /// @param newOwner_ The new owner address to add.
    function swapOwner(address oldOwner_, address newOwner_) public authorized {
        _requireCanAddOwner(newOwner_);
        if (!_owners[oldOwner_]) revert OwnerIncorrect();

        _owners[oldOwner_] = false;
        _owners[newOwner_] = true;

        // Replace oldOwner in _ownerList with newOwner
        for (uint256 i = 0; i < _ownerList.length; i++) {
            if (_ownerList[i] == oldOwner_) {
                _ownerList[i] = newOwner_;
                break;
            }
        }

        emit RemovedOwner(oldOwner_);
        emit AddedOwner(newOwner_);
    }

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Threshold Functions
    // ════════════════════════════════════════════════════════════════════════════

    /// @notice Changes threshold
    /// @param threshold_ The new threshold
    function changeThreshold(uint256 threshold_) public override authorized {
        if (threshold_ == 0 || threshold_ > _ownerCount) revert InvalidThreshold();
        _threshold = threshold_;
        emit ChangedThreshold(_threshold);
    }

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Require Functions
    // ════════════════════════════════════════════════════════════════════════════

    /// @notice Checks whether a new owner can be added to the MultiSig.
    /// @param owner_ The address of the owner to add.
    function _requireCanAddOwner(address owner_) internal view {
        _requireIsValidOwner(owner_);
        if (_owners[owner_]) revert OwnerExists();
    }

    /// @notice Checks whether a owner is valid (not null, not MultiSig)
    /// @param owner_ The address to check.
    function _requireIsValidOwner(address owner_) internal view {
        if (owner_ == address(0) || owner_ == address(this)) revert InvalidOwner();
    }

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Getter Functions
    // ════════════════════════════════════════════════════════════════════════════

    /// @notice Returns the current _threshold of required confirmations for MultiSig transactions.
    function getThreshold() public view override returns (uint256) {
        return _threshold;
    }

    /// @notice Checks whether a given address is currently an owner.
    /// @param owner_ The address to check.
    function isOwner(address owner_) public view override returns (bool) {
        return _owners[owner_];
    }

    /// @notice Returns the list of all current owners of the MultiSig.
    function getOwners() public view override returns (address[] memory) {
        return _ownerList;
    }
}
