// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IErrors} from "../interfaces/IErrors.sol";
import {ContractVersion} from "../enums/ContractVersion.sol";

/// @title Governor - Timelock governance scheduler and executor contract
/// @notice Allows scheduling, execution, and cancellation of delayed operations with role-based access.
/// @dev Implements proposer, executor, and superAdmin roles for operation management.
contract Governor is IErrors {
    ContractVersion public immutable version = ContractVersion.Governor;

    // --- State ---
    uint256 internal _minDelay;
    address internal _proposer; // multi-sig
    address internal _executor; // multi-sig

    mapping(uint256 => bytes32) public _operationRegistry;
    uint256 public _operationCount;

    mapping(bytes32 => OperationState) internal _operationState;
    mapping(bytes32 => uint256) internal _timestamps;

    uint256 internal constant _DONE_TIMESTAMP = 1;

    // --- Events ---
    event MinDelayChanged(uint256 newMinDelay);
    event ProposerChanged(address indexed newProposer);
    event ExecutorChanged(address indexed newExecutor);
    event OperationScheduled(bytes32 indexed id);
    event OperationExecuted(bytes32 indexed id);
    event OperationCancelled(bytes32 indexed id);

    // --- Modifiers ---
    modifier onlyProposer() {
        if (msg.sender != _proposer) revert Unauthorized();
        _;
    }

    modifier onlyExecutor() {
        if (msg.sender != _executor) revert Unauthorized();
        _;
    }

    modifier selfAuthorized() {
        if (msg.sender != address(this)) revert Unauthorized();
        _;
    }

    // --- Enums ---
    enum OperationState {
        Unset,
        Waiting,
        Ready,
        Done
    }

    // --- Constructor ---

    /// @notice Deploys the Governor contract with roles and minimum delay.
    /// @param minDelay_ Minimum delay in seconds before execution.
    /// @param proposer_ Address allowed to propose operations.
    /// @param executor_ Address allowed to execute operations.
    constructor(uint256 minDelay_, address proposer_, address executor_) {
        if (proposer_ == address(0) || executor_ == address(0))
            revert AddressEmpty();

        _proposer = proposer_;
        _executor = executor_;
        _minDelay = minDelay_;
    }

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 SuperAdmin Functions
    // ════════════════════════════════════════════════════════════════════════════

    /// @notice Update the minimum delay before operations can be executed.
    /// @param minDelay_ New minimum delay in seconds.
    function updateMinDelay(uint256 minDelay_) external selfAuthorized {
        _minDelay = minDelay_;
        emit MinDelayChanged(minDelay_);
    }

    /// @notice Change the proposer role.
    /// @param proposer_ New proposer address.
    function setProposer(address proposer_) external selfAuthorized {
        if (proposer_ == address(0)) revert AddressEmpty();
        _proposer = proposer_;
        emit ProposerChanged(proposer_);
    }

    /// @notice Change the executor role.
    /// @param executor_ New executor address.
    function setExecutor(address executor_) external selfAuthorized {
        if (executor_ == address(0)) revert AddressEmpty();
        _executor = executor_;
        emit ExecutorChanged(executor_);
    }

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Schedule Transaction Function
    // ════════════════════════════════════════════════════════════════════════════

    /// @notice Schedule an operation for future execution.
    /// @param target Target contract address.
    /// @param data Calldata payload.
    /// @param salt Unique salt for operation differentiation.
    function schedule(
        address target,
        bytes calldata data,
        bytes32 salt
    ) external onlyProposer {
        if (target == address(0)) revert AddressEmpty();

        bytes32 id = hashOperation(target, data, salt);

        if (getOperationStatus(id) != OperationState.Unset)
            revert InvalidOperation(id);

        _operationState[id] = OperationState.Waiting;
        _timestamps[id] = block.timestamp + _minDelay;

        _operationRegistry[_operationCount] = id;
        _operationCount++;

        emit OperationScheduled(id);
    }

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Execute Transaction Function
    // ════════════════════════════════════════════════════════════════════════════

    /// @notice Execute a scheduled operation after delay has elapsed.
    /// @param target Target contract address.
    /// @param payload Calldata payload.
    /// @param salt Unique salt matching scheduled operation.
    function execute(
        address target,
        bytes calldata payload,
        bytes32 salt
    ) external onlyExecutor {
        bytes32 id = hashOperation(target, payload, salt);

        if (getOperationStatus(id) != OperationState.Ready)
            revert InvalidOperation(id);

        _timestamps[id] = _DONE_TIMESTAMP;
        _operationState[id] = OperationState.Done;

        (bool success, bytes memory returndata) = target.call(payload);
        if (!success) revert FailedOperation(returndata);

        emit OperationExecuted(id);
    }

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Cancel Transaction Function
    // ════════════════════════════════════════════════════════════════════════════

    /// @notice Cancel a scheduled operation.
    /// @param id Operation ID to cancel.
    function cancel(bytes32 id) external onlyProposer {
        if (getOperationStatus(id) != OperationState.Waiting)
            revert InvalidOperation(id);

        delete _timestamps[id];
        delete _operationState[id];

        emit OperationCancelled(id);
    }

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Getters
    // ════════════════════════════════════════════════════════════════════════════

    /// @notice Get the current status of an operation.
    /// @param id Operation ID.
    /// @return OperationState enum value.
    function getOperationStatus(bytes32 id) public view returns (OperationState) {
        uint256 timestamp = getTimestamp(id);
        if (timestamp == 0) {
            return OperationState.Unset;
        } else if (timestamp == _DONE_TIMESTAMP) {
            return OperationState.Done;
        } else if (timestamp > block.timestamp) {
            return OperationState.Waiting;
        } else {
            return OperationState.Ready;
        }
    }

    /// @notice Returns the timestamp when an operation becomes ready.
    /// @param id Operation ID.
    /// @return Timestamp in unix seconds.
    function getTimestamp(bytes32 id) public view returns (uint256) {
        return _timestamps[id];
    }

    /// @notice Returns whether an operation exists.
    /// @param id Operation ID.
    /// @return True if operation is scheduled, false otherwise.
    function isOperation(bytes32 id) public view returns (bool) {
        return getOperationStatus(id) != OperationState.Unset;
    }

    /// @notice Returns whether an operation is pending execution.
    /// @param id Operation ID.
    /// @return True if operation is waiting or ready, false otherwise.
    function isOperationPending(bytes32 id) public view returns (bool) {
        OperationState state = getOperationStatus(id);
        return state == OperationState.Waiting || state == OperationState.Ready;
    }

    /// @notice Returns whether an operation is ready to execute.
    /// @param id Operation ID.
    /// @return True if operation is ready.
    function isOperationReady(bytes32 id) public view returns (bool) {
        return getOperationStatus(id) == OperationState.Ready;
    }

    /// @notice Returns whether an operation has been executed.
    /// @param id Operation ID.
    /// @return True if operation is done.
    function isOperationDone(bytes32 id) public view returns (bool) {
        return getOperationStatus(id) == OperationState.Done;
    }

    /// @notice Returns the current minimum delay.
    /// @return Delay in seconds.
    function getMinDelay() public view returns (uint256) {
        return _minDelay;
    }

    /// @notice Returns the address of the current proposer.
    /// @return Proposer address.
    function getProposer() external view returns (address) {
        return _proposer;
    }

    /// @notice Returns the address of the current executor.
    /// @return Executor address.
    function getExecutor() external view returns (address) {
        return _executor;
    }

    /// @notice Returns the operation ID at a specific registry index.
    /// @param index Index in the operation registry.
    /// @return Operation ID as bytes32.
    function getOperationByIndex(uint256 index) external view returns (bytes32) {
        return _operationRegistry[index];
    }

    /// @notice Returns the total number of scheduled operations.
    /// @return Operation count.
    function getOperationCount() external view returns (uint256) {
        return _operationCount;
    }

    /// @notice Computes the unique operation ID hash.
    /// @param target Target contract address.
    /// @param data Calldata.
    /// @param salt Salt to distinguish operation.
    /// @return The keccak256 hash of the encoded operation data.
    function hashOperation(
        address target,
        bytes calldata data,
        bytes32 salt
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(target, data, salt));
    }
}
