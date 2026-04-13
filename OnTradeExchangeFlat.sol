// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.24;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Pausable is Context {
    bool private _paused;

    event Paused(address account);

    event Unpaused(address account);

    error EnforcedPause();

    error ExpectedPause();

    constructor() {
        _paused = false;
    }

    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    modifier whenPaused() {
        _requirePaused();
        _;
    }

    function paused() public view virtual returns (bool) {
        return _paused;
    }

    function _requireNotPaused() internal view virtual {
        if (paused()) {
            revert EnforcedPause();
        }
    }

    function _requirePaused() internal view virtual {
        if (!paused()) {
            revert ExpectedPause();
        }
    }

    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

interface IErrors {
    // Protocol Errors
    error Unauthorized();
    error AddressEmpty();
    error ZeroAmount();
    error NotContract();

    error GovernorAndManagerCannotBeSame();

    error InactiveDeposits();
    error DeactivatePool();
    error InactiveWithdraw();
    error InsufficientFunds();
    error InvalidIMPRank();
    error NotWhiteList();
    error NoDevInterest();

    error NotWhiteListed();
    error NotReceiver();
    error BorrowerNotActiveAccount();
    error ReceiverNotActiveAccount();
    error NotActiveAccount();

    error AddressExists();
    error AddressInvalid();

    error SignerAlreadyAssigned();
    error SignerNotAssigned();
    error AccountAlreadyActive();

    error FeederPoolInvalid(address feederPoolAddress);
    error MasterPoolInvalid(address feederPoolAddress);
    error FeederPoolNotFound(address feederPoolAddress);
    error FeederPoolNotUnique(address feederPoolAddress);
    error InvalidStatus();

    error MasterExists();
    error NotMasterPool();

    error UnregisteredVersion();
    error UnsuccessfulCreation();
    error InvalidBorrowNonce();
    error InvalidRepayNonce();
    error InvalidRefundNonce();

    error ReceivableInitialized();
    error ReceivableOutOfBounds();
    error ReceivableInvalidPacketLength();
    error GovernorPaused();
    error FailedOperation(bytes returndata);
    error InvalidOperation(bytes32 id);
    error InvalidDelay();

    error LengthMismatch();
    error InvalidAccountNonce();
    error InvalidReceiver();

    error NotMasterTreasury();
    error NotExchangePool();
    error InvalidExchangePool();

    error NotCompanyAccount();
    error InvalidCompanyAccount();
    error InvalidFeeCompanyAccount();
    error NotExchangePoolOrTreasury();

    error InvalidWhiteListStatus();
    error InsufficientLPBalance();
    error InvalidPayoutStatus();
    error TradeDoesNotExist();

    error InitWindowExpired();

    // multi-sig safe errors
    error ZeroOwners();
    error InvalidThreshold();
    error InvalidOwner();
    error OwnerIncorrect();
    error OwnerExists();
    error ThresholdUnreachable();
    error AlreadyInitialized();
    error InsufficientSignatures();
    error NotOwner();
    error DuplicateOwner();
    error InsufficientValidOwners();
    error TransactionExecutionFailed();
    error AlreadyExecuted();
    error InvalidSignatureLength();
    error SimulationSuccess();
    error SimulationCallFailed();

    // on-trade pool errors
    error TradeAlreadyExists();
    error InvalidAxiymFeeCompanyAccount();
    error NotOnTradeExchange();
    error InvalidTradeState();
    error QueueMoveFailed();
    error QueueRemoveFailed();
    error InsufficientTreasuryBalance();
    error AmountExceedsCurrentPayout();
    error NotSettlementProvider();
    error InsufficientBalance();
    error InvalidSettleAmount();
    error QueueAmountTotalZero();
    error InvalidFeeStructure();
    error FeesExceedValue();
    error InvalidTradeNonce();
    error InvalidGasThreshold();
    error InvalidMaxTrades();
    error AssetsIdentical();
    error TradeBelowMinimum();
    error CannotRemoveLastOwner();
}

interface IGovernance {
    function transferGovernor(address) external;

    function transferManager(address) external;

    function transferSuperAdmin(address) external;

    function getSuperAdmin() external view returns (address);

    function getGovernor() external view returns (address);

    function getManager() external view returns (address);

    function getAuthorizer() external view returns (address);
}

abstract contract Governable is IErrors {
    address internal _governance;

    constructor(address governance_) {
        _governance = governance_;
    }

    modifier onlyGovernor() {
        if (msg.sender != governor()) {
            revert Unauthorized();
        }
        _;
    }

    modifier onlyManager() {
        if (msg.sender != manager()) {
            revert Unauthorized();
        }
        _;
    }

    modifier onlySuperAdmin() {
        if (msg.sender != superAdmin()) {
            revert Unauthorized();
        }
        _;
    }

    modifier onlyAuthorizer() {
        if (msg.sender != authorizer()) revert Unauthorized();
        _;
    }

    function governance() external view returns (address) {
        return _governance;
    }

    function superAdmin() public view returns (address) {
        return IGovernance(_governance).getSuperAdmin();
    }

    function governor() public view returns (address) {
        return IGovernance(_governance).getGovernor();
    }

    function manager() public view returns (address) {
        return IGovernance(_governance).getManager();
    }

    function authorizer() public view returns (address) {
        return IGovernance(_governance).getAuthorizer();
    }
}

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
}

library SafeToken {
    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error SafeToken__CallFailed(address token, bytes4 selector);
    error SafeToken__TransferFailed(address token, address to, uint256 value);
    error SafeToken__TransferFromFailed(
        address token,
        address from,
        address to,
        uint256 value
    );
    error SafeToken__ApproveFailed(address token, address spender, uint256 value);
    error SafeToken__ZeroAddress();
    error SafeToken__ZeroAmount();
    error SafeToken__ApproveRaceCondition(
        address token,
        address spender,
        uint256 currentAllowance
    );

    // -------------------------------------------------------------------------
    // Transfer
    // -------------------------------------------------------------------------

    /**
     * @notice Safely transfer tokens, handling all known non-standard behaviours.
     * @param token  The token contract to call.
     * @param to     Recipient address.
     * @param value  Amount to transfer.
     *
     * Handles:
     *   - Tokens that return nothing          (ETH USDT)
     *   - Tokens that return false on success (TRC20 USDT)
     *   - Tokens that hard-revert on failure  (BSC BNB)
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        if (to == address(0)) revert SafeToken__ZeroAddress();
        if (value == 0) revert SafeToken__ZeroAmount();

        // Snapshot before the call so delta check is accurate regardless of
        // recipient's prior balance (fixes false-positive on pre-funded accounts)
        uint256 balanceBefore = token.balanceOf(to);

        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transfer.selector, to, value)
        );

        // Hard revert ÔÇö genuine failure on all chains
        if (!success)
            revert SafeToken__CallFailed(address(token), token.transfer.selector);

        // Return data present and decodes to false ÔåÆ could be TRC20 USDT quirk
        // Fall back to strict balance-delta as ground truth
        if (data.length > 0 && !abi.decode(data, (bool))) {
            _requireBalanceDelta(token, to, balanceBefore, value);
        }
    }

    /**
     * @notice Safely transfer tokens and return the actual received amount.
     * @dev    Use this variant for fee-on-transfer tokens where received != sent.
     * @param token  The token contract to call.
     * @param to     Recipient address.
     * @param value  Amount to transfer.
     * @return received  Actual amount received by `to` after fees.
     */
    function safeTransferGetReceived(
        IERC20 token,
        address to,
        uint256 value
    ) internal returns (uint256 received) {
        if (to == address(0)) revert SafeToken__ZeroAddress();
        if (value == 0) revert SafeToken__ZeroAmount();

        uint256 balanceBefore = token.balanceOf(to);

        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transfer.selector, to, value)
        );

        if (!success)
            revert SafeToken__CallFailed(address(token), token.transfer.selector);

        uint256 balanceAfter = token.balanceOf(to);

        // For false-returning tokens: verify balance increased
        if (data.length > 0 && !abi.decode(data, (bool))) {
            if (balanceAfter <= balanceBefore) {
                revert SafeToken__TransferFailed(address(token), to, value);
            }
        }

        received = balanceAfter - balanceBefore;
    }

    // -------------------------------------------------------------------------
    // TransferFrom
    // -------------------------------------------------------------------------

    /**
     * @notice Safely transferFrom tokens, handling all known non-standard behaviours.
     * @param token  The token contract to call.
     * @param from   Source address.
     * @param to     Recipient address.
     * @param value  Amount to transfer.
     */
    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        if (from == address(0) || to == address(0)) revert SafeToken__ZeroAddress();
        if (value == 0) revert SafeToken__ZeroAmount();

        // Snapshot before the call so delta check is accurate regardless of
        // recipient's prior balance (fixes false-positive on pre-funded accounts)
        uint256 balanceBefore = token.balanceOf(to);

        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transferFrom.selector, from, to, value)
        );

        if (!success)
            revert SafeToken__CallFailed(
                address(token),
                token.transferFrom.selector
            );

        if (data.length > 0 && !abi.decode(data, (bool))) {
            _requireBalanceDelta(token, to, balanceBefore, value);
        }
    }

    /**
     * @notice Safely transferFrom tokens and return the actual received amount.
     * @dev    Use this variant for fee-on-transfer tokens.
     */
    function safeTransferFromGetReceived(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal returns (uint256 received) {
        if (from == address(0) || to == address(0)) revert SafeToken__ZeroAddress();
        if (value == 0) revert SafeToken__ZeroAmount();

        uint256 balanceBefore = token.balanceOf(to);

        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transferFrom.selector, from, to, value)
        );

        if (!success)
            revert SafeToken__CallFailed(
                address(token),
                token.transferFrom.selector
            );

        uint256 balanceAfter = token.balanceOf(to);

        if (data.length > 0 && !abi.decode(data, (bool))) {
            if (balanceAfter <= balanceBefore) {
                revert SafeToken__TransferFromFailed(
                    address(token),
                    from,
                    to,
                    value
                );
            }
        }

        received = balanceAfter - balanceBefore;
    }

    // -------------------------------------------------------------------------
    // Approve
    // -------------------------------------------------------------------------

    /**
     * @notice Safely approve a spender, with race condition protection.
     * @dev    Reverts if current allowance is non-zero and new value is also non-zero.
     *         Caller must first approve(0) then approve(newValue) to prevent the
     *         ERC20 approval race condition.
     * @param token    The token contract.
     * @param spender  Address to approve.
     * @param value    Amount to approve.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        if (spender == address(0)) revert SafeToken__ZeroAddress();

        // Prevent approval race condition
        // Caller must set to 0 first before setting a new non-zero value
        uint256 currentAllowance = token.allowance(address(this), spender);
        if (currentAllowance != 0 && value != 0) {
            revert SafeToken__ApproveRaceCondition(
                address(token),
                spender,
                currentAllowance
            );
        }

        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.approve.selector, spender, value)
        );

        if (!success)
            revert SafeToken__CallFailed(address(token), token.approve.selector);

        if (data.length > 0 && !abi.decode(data, (bool))) {
            revert SafeToken__ApproveFailed(address(token), spender, value);
        }
    }

    /**
     * @notice Force-set an approval to any value, handling the race condition
     *         automatically by zeroing out first if needed.
     * @dev    Costs an extra approve(0) call when overwriting a non-zero allowance.
     *         Use this when you don't want to manage the two-step approval yourself.
     */
    function safeForceApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        if (spender == address(0)) revert SafeToken__ZeroAddress();

        uint256 currentAllowance = token.allowance(address(this), spender);

        if (currentAllowance != 0) {
            // Zero out first
            (bool zeroSuccess, ) = address(token).call(
                abi.encodeWithSelector(token.approve.selector, spender, 0)
            );
            if (!zeroSuccess)
                revert SafeToken__CallFailed(address(token), token.approve.selector);
        }

        if (value == 0) return; // Just wanted to zero it out

        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.approve.selector, spender, value)
        );

        if (!success)
            revert SafeToken__CallFailed(address(token), token.approve.selector);

        if (data.length > 0 && !abi.decode(data, (bool))) {
            revert SafeToken__ApproveFailed(address(token), spender, value);
        }
    }

    // -------------------------------------------------------------------------
    // Internal helpers
    // -------------------------------------------------------------------------

    /**
     * @dev Strict balance-delta check: verifies `to`'s balance increased by at least `value`
     *      compared to the snapshot taken BEFORE the call.
     *
     *      This is the correct pattern ÔÇö checking `balanceNow >= value` without a before-snapshot
     *      is a false-positive bug: if the recipient already held funds, the check passes even
     *      if zero tokens were actually transferred.
     *
     *      We require delta >= value (not strictly ==) to tolerate fee-on-transfer tokens
     *      where received < sent. For exact accounting use the GetReceived variants instead.
     */
    function _requireBalanceDelta(
        IERC20 token,
        address to,
        uint256 balanceBefore,
        uint256 value
    ) private view {
        uint256 balanceAfter = token.balanceOf(to);
        if (balanceAfter <= balanceBefore) {
            revert SafeToken__TransferFailed(address(token), to, value);
        }
    }
}

enum TradeState {
    Unspecified,
    Pending,
    Executed,
    Cancelled
}

struct TradePaymentReceipt {
    uint256 clientPayout; // amount paid out
    uint256 axiymFee; // possibly already paid but proportion recorded here
    uint256 otherFee; // provider fee if it exists
    uint256 timestamp;
}

struct Trade {
    uint256 sellAssetQuoteAmount; // total amount of gross asset being sold (pre-FX, pre-fees)
    uint256 buyAssetQuoteValue; // value of sell asset expressed in buy asset (calculated using mid-market rates)
    uint256 axiymFee; // Fixed Axiym fee for the trade, expressed in units of the buy asset, calculated at pricing time.
    uint256 totalFee; // Total fees for the trade, expressed in units of the buy asset, calculated at pricing time.
    uint256 initialPayoutSize; // start payout size in buy asset
    uint256 currentPayoutSize; // current payout size in buy asset
    address companyAccount; // company account involved
    address tradePool; // tradePool request sent from
    address sellAsset; // asset being sold
    address buyAsset; // asset being bought
    uint256 createdAt; // time trade was created
    uint256 executedAt; // time trade was executed
    uint256 cancelledAt; // time trade was cancelled
    TradeState status; // status of trade (pending, executed, etc.)
}

interface IOnTradeExchange {
    function getTradeData(uint256) external view returns (Trade memory);
}

enum ContractVersion {
    Unspecified,
    ERC20,
    InternalToken,
    MasterPoolRegistry,
    Governance,
    MasterPool,
    AuthRegistry,
    FeederPool,
    FeederVault,
    FeederPoolRegistry,
    ReceivableRegistry,
    MasterLiquidator,
    Receivable,
    BorrowerAccountFactory,
    BorrowerAccount,
    MasterTreasuryRegistry,
    CompanyAccountV1,
    TradeRegistry,
    MasterTreasury,
    ExchangePool,
    Governor,
    CompanyAccountFactory,
    OnTradeExchangeV2,
    OffTradeExchangeV2,
    SegregatedTreasury,
    SatoshiTest,
    MultiSig,
    CompanyAccount,
    OnTradeExchange,
    OffTradeExchange
}

interface ISegregatedTreasury {
    function pause() external;

    function unpause() external;

    function setReceiveAddress(address) external;

    function executeTrade(uint256, uint256, uint256) external;

    function version() external view returns (ContractVersion);

    function onTradeExchange() external view returns (address);

    function offAsset() external view returns (address);

    function onAsset() external view returns (address);

    function isOwner(address) external view returns (bool);

    function receiveAddress() external view returns (address);
}
enum CompanyAccountStatus {
    Unspecified,
    Active,
    Deactivated
}

interface ICompanyAccount {
    function approveSpender(
        address,
        uint256,
        bytes16,
        bytes16,
        bytes memory
    ) external;
}

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    uint256 private _status;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == ENTERED;
    }
}

/// @title SegregatedTreasury
/// @notice Treasury contract that holds external assets and facilitates asset swaps with OnTradeExchange
/// @dev Created and managed by OnTradeExchange, executes trades by swapping offAsset for onAsset
contract SegregatedTreasury is
    Pausable,
    ReentrancyGuard,
    IErrors,
    ISegregatedTreasury
{
    using SafeToken for IERC20;

    ContractVersion public immutable version = ContractVersion.SegregatedTreasury;

    // --- Immutable State ---
    /// @notice The associated OnTradeExchange contract address
    address internal immutable _onTradeExchange;

    /// @notice The internal currency asset (e.g. IUSD)
    IERC20 internal immutable _offAsset;

    /// @notice The external treasury asset (e.g. USDT)
    IERC20 internal immutable _onAsset;

    // --- Mutable State ---
    /// @notice Owner of the treasury with admin privileges
    mapping(address => bool) public _owners;
    uint256 internal _ownerCount;

    /// @notice Address to receive withdrawn funds (controlled by owner)
    address internal _receiveAddress;

    // --- Events ---
    event OwnerChanged(address indexed previousOwner, address indexed newOwner);
    event ReceiveAddressChanged(
        address indexed previousAddress,
        address indexed newAddress
    );
    event TradePayment(uint256 indexed tradeUint, uint256 amount);
    event TreasuryWithdraw(address receiveAddress, address onAsset, uint256 amount);

    // --- Modifiers ---
    /// @notice Restricts function access to treasury owner only
    modifier onlyOwner() {
        if (!_owners[msg.sender]) revert NotOwner();
        _;
    }

    /// @notice Restricts function access to OnTradeExchange only
    modifier onlyOnTradeExchange() {
        if (msg.sender != _onTradeExchange) revert NotOnTradeExchange();
        _;
    }

    // --- Constructor ---
    /// @notice Initializes the treasury with associated exxchange and owner
    /// @param onTradeExchange_ Address of the OnTradeExchange contract
    /// @param owner_ Address of the treasury owner
    /// @param offAsset_ Address of the internal exchange asset (IUSD)
    /// @param onAsset_ Address of the external asset (USDT)
    constructor(
        address onTradeExchange_,
        address owner_,
        address offAsset_,
        address onAsset_
    ) {
        if (onTradeExchange_ == address(0)) revert AddressEmpty();
        if (owner_ == address(0)) revert AddressEmpty();

        _onTradeExchange = onTradeExchange_;

        _owners[owner_] = true;
        _ownerCount = 1;

        _offAsset = IERC20(offAsset_);
        _onAsset = IERC20(onAsset_);
    }

    /// @notice Pauses the treasury, preventing trade execution
    function pause() external onlyOwner {
        _pause();
        emit Paused(msg.sender);
    }

    /// @notice Unpauses the treasury, allowing trade execution
    function unpause() external onlyOwner {
        _unpause();
        emit Unpaused(msg.sender);
    }

    /// @notice Updates the treasury owner
    /// @param owner_ Address of the new treasury owner
    function addOwner(address owner_) external onlyOwner {
        if (owner_ == address(0)) revert AddressEmpty();
        if (_owners[owner_]) revert OwnerExists();

        _owners[owner_] = true;
        _ownerCount++;

        emit OwnerChanged(address(0), owner_);
    }

    /// @notice Removes an existing treasury owner
    /// @param owner_ Address of the owner to remove
    function removeOwner(address owner_) external onlyOwner {
        if (!_owners[owner_]) revert NotOwner();

        // prevent removing last owner
        if (_ownerCount == 1) revert CannotRemoveLastOwner();

        _owners[owner_] = false;
        _ownerCount--;

        emit OwnerChanged(owner_, address(0));
    }

    /// @notice Sets the address where withdrawn funds are sent
    /// @param receiveAddress_ New receive address
    function setReceiveAddress(address receiveAddress_) external onlyOwner {
        if (receiveAddress_ == address(0)) revert AddressEmpty();
        if (receiveAddress_ == _receiveAddress) revert AddressExists();

        address previousAddress = _receiveAddress;
        _receiveAddress = receiveAddress_;

        emit ReceiveAddressChanged(previousAddress, receiveAddress_);
    }

    /// @notice Withdraws on asset to registered receive address
    /// @param amount_ Amount to withdraw
    function withdraw(uint256 amount_) external onlyOwner nonReentrant {
        if (amount_ == 0) revert ZeroAmount();
        if (_receiveAddress == address(0)) revert AddressEmpty();

        uint256 bal = _onAsset.balanceOf(address(this));
        if (bal < amount_) revert InsufficientTreasuryBalance();
        _onAsset.safeTransfer(_receiveAddress, amount_);

        emit TreasuryWithdraw(_receiveAddress, address(_onAsset), amount_);
    }

    /// @notice Executes a trade by swapping offAsset for onAsset approval
    /// @dev Called by OnTradeExchange during trade execution
    /// @param tradeUint_ The trade ID to execute
    /// @param validatedPayoutSize_ Post-decrement currentPayoutSize
    function executeTrade(
        uint256 tradeUint_,
        uint256 amount_,
        uint256 validatedPayoutSize_
    ) external onlyOnTradeExchange whenNotPaused nonReentrant {
        // validate amount against the already-decremented payout size passed in by exchange
        if (validatedPayoutSize_ < amount_) revert AmountExceedsCurrentPayout();

        // Check enough USDT
        uint256 bal = _onAsset.balanceOf(address(this));
        if (bal < amount_) revert InsufficientTreasuryBalance();

        // pull offAsset (IUSD) from exchange into treasury
        _offAsset.safeTransferFrom(_onTradeExchange, address(this), amount_);

        // Transfer USDT
        _onAsset.safeTransfer(_onTradeExchange, amount_);

        emit TradePayment(tradeUint_, amount_);
    }

    /// @notice Returns the address of the associated OnTradeExchange
    /// @return The OnTradeExchange contract address
    function onTradeExchange() external view returns (address) {
        return _onTradeExchange;
    }

    /// @notice Returns the internal asset address (IUSD)
    /// @return The offAsset token address
    function offAsset() external view returns (address) {
        return address(_offAsset);
    }

    /// @notice Returns the treasury asset address (USDT)
    /// @return The onAsset token address
    function onAsset() external view returns (address) {
        return address(_onAsset);
    }

    /// @notice Returns whether an address is a treasury owner
    function isOwner(address account) external view returns (bool) {
        return _owners[account];
    }

    /// @notice Returns the address where funds can be withdrawn to
    /// @return The receive address
    function receiveAddress() external view returns (address) {
        return _receiveAddress;
    }

    /// @notice Returns the current balance of offAsset (IUSD) held by treasury
    /// @return The offAsset balance
    function offAssetBalance() external view returns (uint256) {
        return _offAsset.balanceOf(address(this));
    }

    /// @notice Returns the current balance of onAsset (USDT) held by treasury
    /// @return The onAsset balance
    function onAssetBalance() external view returns (uint256) {
        return _onAsset.balanceOf(address(this));
    }
}

interface IAuthRegistry {
    function isAuthAddress(address) external view returns (bool);
}

/// @title LinkedList
/// @notice Contract implementing a circular doubly linked list for trade management.
abstract contract LinkedList {
    /// @notice Total size of the list.
    uint256 internal size;

    /// @notice Mapping of trade ID to its adjacent trades.
    mapping(uint256 => mapping(bool => uint256)) internal trades;
    mapping(bytes16 => uint256) internal _tradesBytesToUint;
    mapping(uint256 => bytes16) internal _tradesUintToBytes;

    uint256 internal constant NULL = 0;
    uint256 internal constant HEAD = 0;
    bytes16 internal constant NULLBYTES = bytes16(0);
    bytes16 internal constant HEADBYTES = bytes16(0);
    bool internal constant PREV = false;
    bool internal constant NEXT = true;

    // ========================
    // ­ƒƒª Internal Conversion
    // ========================

    /// @notice Converts bytes16 trade ID to uint256 internally
    /// @param _tradeBytes The bytes16 trade ID
    /// @return uint256 representation
    function _toUint(bytes16 _tradeBytes) internal view returns (uint256) {
        if (_tradeBytes == NULLBYTES) return NULL;
        return _tradesBytesToUint[_tradeBytes];
    }

    /// @notice Converts uint256 trade ID to bytes16 internally
    /// @param _tradeUint The uint256 trade ID
    /// @return bytes16 representation
    function _toBytes(uint256 _tradeUint) internal view returns (bytes16) {
        if (_tradeUint == 0) return NULLBYTES;
        return _tradesUintToBytes[_tradeUint];
    }

    /// @notice Registers a trade mapping between uint256 and bytes16
    /// @param _tradeUint The uint256 trade ID
    /// @param _tradeBytes The bytes16 trade ID
    function _registerTrade(uint256 _tradeUint, bytes16 _tradeBytes) internal {
        if (_tradeUint == NULL || _tradeBytes == NULLBYTES) revert("NULLENTRY");
        require(
            _tradesBytesToUint[_tradeBytes] == 0 &&
                _tradesUintToBytes[_tradeUint] == bytes16(0),
            "MappingExists"
        );
        _tradesUintToBytes[_tradeUint] = _tradeBytes;
        _tradesBytesToUint[_tradeBytes] = _tradeUint;
    }

    /// @notice Unregisters a trade mapping
    /// @param _tradeUint The uint256 trade ID to unregister
    function _unregisterTrade(uint256 _tradeUint) internal {
        if (_tradeUint == NULL) revert("NULLENTRY");
        bytes16 tradeBytes = _tradesUintToBytes[_tradeUint];
        delete _tradesUintToBytes[_tradeUint];
        delete _tradesBytesToUint[tradeBytes];
    }

    // ========================
    // ­ƒƒª Existence Checks
    // ========================

    /// @notice Checks if an trade exists in the list.
    /// @param _trade The trade ID to check.
    /// @return True if the trade exists, false otherwise.
    function tradeExists(uint256 _trade) public view returns (bool) {
        if (trades[_trade][PREV] == HEAD && trades[_trade][NEXT] == HEAD) {
            return (trades[HEAD][NEXT] == _trade);
        } else {
            return true;
        }
    }

    /// @notice Checks if a bytes16 trade exists in the list.
    /// @param _tradeBytes The bytes16 trade ID to check.
    /// @return True if the trade exists, false otherwise.
    function tradeExistsBytes(bytes16 _tradeBytes) public view returns (bool) {
        return tradeExists(_toUint(_tradeBytes));
    }

    /// @notice Checks if the list contains any trades.
    /// @return True if the list has at least one trade.
    function listExists() public view returns (bool) {
        return (trades[HEAD][PREV] != HEAD || trades[HEAD][NEXT] != HEAD);
    }

    // ========================
    // ­ƒƒª Insertion Helpers
    // ========================

    /// @notice Inserts a new trade after an existing trade.
    /// @param _existingTrade The existing trade to insert after.
    /// @param _newTrade The new trade to insert.
    /// @return True if insertion succeeded.
    function _insertAfter(
        uint256 _existingTrade,
        uint256 _newTrade
    ) internal virtual returns (bool) {
        return _insert(_existingTrade, _newTrade, NEXT);
    }

    /// @notice Inserts a new bytes16 trade after an existing bytes16 trade.
    /// @param _existingTradeBytes The existing trade to insert after.
    /// @param _newTradeBytes The new trade to insert.
    /// @return True if insertion succeeded.
    function _insertAfterBytes(
        bytes16 _existingTradeBytes,
        bytes16 _newTradeBytes
    ) internal virtual returns (bool) {
        return _insertAfter(_toUint(_existingTradeBytes), _toUint(_newTradeBytes));
    }

    /// @notice Inserts a new trade before an existing trade.
    /// @param _existingTrade The existing trade to insert before.
    /// @param _newTrade The new trade to insert.
    /// @return True if insertion succeeded.
    function _insertBefore(
        uint256 _existingTrade,
        uint256 _newTrade
    ) internal virtual returns (bool) {
        return _insert(_existingTrade, _newTrade, PREV);
    }

    /// @notice Inserts a new bytes16 trade before an existing bytes16 trade.
    /// @param _existingTradeBytes The existing trade to insert before.
    /// @param _newTradeBytes The new trade to insert.
    /// @return True if insertion succeeded.
    function _insertBeforeBytes(
        bytes16 _existingTradeBytes,
        bytes16 _newTradeBytes
    ) internal virtual returns (bool) {
        return _insertBefore(_toUint(_existingTradeBytes), _toUint(_newTradeBytes));
    }

    /// @notice Inserts a new trade in the list
    /// @param _existingTrade The existing trade to insert relative to
    /// @param _newTrade The new trade to insert
    /// @param _direction Direction to insert trade (PREV or NEXT)
    /// @return True if insertion succeeded
    function _insert(
        uint256 _existingTrade,
        uint256 _newTrade,
        bool _direction
    ) internal returns (bool) {
        if (tradeExists(_existingTrade) && !tradeExists(_newTrade)) {
            uint256 temp = trades[_existingTrade][_direction];
            _linkTrades(_existingTrade, _newTrade, _direction);
            _linkTrades(_newTrade, temp, _direction);

            size++;
            return true;
        }
        return false;
    }

    // ========================
    // ­ƒƒª Push Helpers
    // ========================

    /// @notice Pushes a new trade to the head of the list.
    /// @param _newTrade The new trade to push.
    /// @return True if push succeeded.
    function _pushHead(uint256 _newTrade) internal virtual returns (bool) {
        return _insert(HEAD, _newTrade, NEXT);
    }

    /// @notice Pushes a new bytes16 trade to the head of the list.
    /// @param _newTradeBytes The new trade to push.
    /// @return True if push succeeded.
    function _pushHeadBytes(bytes16 _newTradeBytes) internal virtual returns (bool) {
        return _pushHead(_toUint(_newTradeBytes));
    }

    /// @notice Pushes a new trade to the tail of the list.
    /// @param _newTrade The new trade to push.
    /// @return True if push succeeded.
    function _pushTail(uint256 _newTrade) internal virtual returns (bool) {
        return _insert(HEAD, _newTrade, PREV);
    }

    /// @notice Pushes a new bytes16 trade to the tail of the list.
    /// @param _newTradeBytes The new trade to push.
    /// @return True if push succeeded.
    function _pushTailBytes(bytes16 _newTradeBytes) internal virtual returns (bool) {
        return _pushTail(_toUint(_newTradeBytes));
    }

    // ========================
    // ­ƒƒª Removal Helpers
    // ========================

    /// @notice Pops the first trade from the head.
    /// @return The removed trade ID, or 0 if empty.
    function _popHead() internal virtual returns (uint256) {
        (, uint256 adj) = getAdjacent(HEAD, NEXT);
        return _remove(adj);
    }

    /// @notice Pops the first bytes16 trade from the head.
    /// @return The removed trade ID, or empty bytes16 if empty.
    function _popHeadBytes() internal virtual returns (bytes16) {
        uint256 tradeUint = _popHead();
        return _toBytes(tradeUint);
    }

    /// @notice Pops the first trade from the tail.
    /// @return The removed trade ID, or 0 if empty.
    function _popTail() internal virtual returns (uint256) {
        (, uint256 adj) = getAdjacent(HEAD, PREV);
        return _remove(adj);
    }

    /// @notice Pops the first bytes16 trade from the tail.
    /// @return The removed trade ID, or empty bytes16 if empty.
    function _popTailBytes() internal virtual returns (bytes16) {
        uint256 tradeUint = _popTail();
        return _toBytes(tradeUint);
    }

    /// @notice Removes a specific trade from the list.
    /// @param _trade The trade ID to remove.
    /// @return The removed trade ID, or 0 if not found.
    function _remove(uint256 _trade) internal returns (uint256) {
        if (_trade == NULL || !tradeExists(_trade)) {
            return 0;
        }
        _linkTrades(trades[_trade][PREV], trades[_trade][NEXT], NEXT);
        delete trades[_trade][PREV];
        delete trades[_trade][NEXT];

        size--;
        return _trade;
    }

    /// @notice Removes a specific bytes16 trade from the list.
    /// @param _tradeBytes The trade ID to remove.
    /// @return The removed trade ID, or empty bytes16 if not found.
    function _removeBytes(bytes16 _tradeBytes) internal virtual returns (bytes16) {
        uint256 tradeUint = _remove(_toUint(_tradeBytes));
        return _toBytes(tradeUint);
    }

    // ========================
    // ­ƒƒª Move Helpers
    // ========================

    /// @notice Move an trade to a new position in the list.
    /// @param _trade The trade to move.
    /// @param _target The reference trade for insertion.
    /// @param _direction The direction relative to the target (PREV = before, NEXT = after).
    /// @return True if the move succeeded.
    function _move(
        uint256 _trade,
        uint256 _target,
        bool _direction
    ) internal virtual returns (bool) {
        if (
            _trade == NULL ||
            _trade == _target ||
            !tradeExists(_trade) ||
            (_target != HEAD && !tradeExists(_target))
        ) {
            return false;
        }

        _remove(_trade);

        if (_direction == PREV) {
            _insertBefore(_target, _trade);
        } else {
            _insertAfter(_target, _trade);
        }

        return true;
    }

    /// @notice Move a bytes16 trade to a new position in the list.
    /// @param _tradeBytes The trade to move.
    /// @param _targetBytes The reference trade for insertion.
    /// @param _direction The direction relative to the target (PREV = before, NEXT = after).
    /// @return True if the move succeeded.
    function _moveBytes(
        bytes16 _tradeBytes,
        bytes16 _targetBytes,
        bool _direction
    ) internal virtual returns (bool) {
        return _move(_toUint(_tradeBytes), _toUint(_targetBytes), _direction);
    }

    // ========================
    // ­ƒƒª Linking Helpers
    // ========================

    /// @notice Links two trades together in the list
    /// @param _existingTrade The existing trade
    /// @param _adjacentTrade The adjacent trade to link
    /// @param _direction The direction to link (PREV or NEXT)
    function _linkTrades(
        uint256 _existingTrade,
        uint256 _adjacentTrade,
        bool _direction
    ) internal {
        trades[_adjacentTrade][!_direction] = _existingTrade;
        trades[_existingTrade][_direction] = _adjacentTrade;
    }

    // ========================
    // ­ƒƒª Getters
    // ========================

    /// @notice Returns the previous and next trades of a given trade.
    /// @param _trade The trade ID to query.
    /// @return exists True if the trade exists.
    /// @return prev The previous trade ID.
    /// @return next The next trade ID.
    function getTrade(uint256 _trade) public view returns (bool, uint256, uint256) {
        if (!tradeExists(_trade)) {
            return (false, 0, 0);
        }
        return (true, trades[_trade][PREV], trades[_trade][NEXT]);
    }

    /// @notice Returns the previous and next bytes16 trades of a given bytes16 trade.
    /// @param _tradeBytes The trade ID to query.
    /// @return exists True if the trade exists.
    /// @return prev The previous trade ID.
    /// @return next The next trade ID.
    function getTradeBytes(
        bytes16 _tradeBytes
    ) public view returns (bool, bytes16, bytes16) {
        uint256 tradeUint = _toUint(_tradeBytes);
        (bool exists, uint256 prevUint, uint256 nextUint) = getTrade(tradeUint);
        return (exists, _toBytes(prevUint), _toBytes(nextUint));
    }

    /// @notice Returns the adjacent trade in a given direction.
    /// @param _trade The trade ID to query.
    /// @param _direction NEXT for next, PREV for previous.
    /// @return exists True if the trade exists.
    /// @return adjacent The adjacent trade ID.
    function getAdjacent(
        uint256 _trade,
        bool _direction
    ) public view returns (bool, uint256) {
        if (!tradeExists(_trade)) {
            return (false, 0);
        }
        return (true, trades[_trade][_direction]);
    }

    /// @notice Returns the adjacent bytes16 trade in a given direction.
    /// @param _tradeBytes The trade ID to query.
    /// @param _direction NEXT for next, PREV for previous.
    /// @return exists True if the trade exists.
    /// @return adjacent The adjacent trade ID.
    function getAdjacentBytes(
        bytes16 _tradeBytes,
        bool _direction
    ) public view returns (bool, bytes16) {
        uint256 tradeUint = _toUint(_tradeBytes);
        (bool exists, uint256 adjacentUint) = getAdjacent(tradeUint, _direction);
        return (exists, _toBytes(adjacentUint));
    }

    /// @notice Returns the next trade.
    /// @param _trade The trade ID to query.
    /// @return exists True if the trade exists.
    /// @return next The next trade ID.
    function getNext(uint256 _trade) public view returns (bool, uint256) {
        return getAdjacent(_trade, NEXT);
    }

    /// @notice Returns the next bytes16 trade.
    /// @param _tradeBytes The bytes16 trade ID to query.
    /// @return exists True if the trade exists.
    /// @return next The next trade ID.
    function getNextBytes(bytes16 _tradeBytes) public view returns (bool, bytes16) {
        return getAdjacentBytes(_tradeBytes, NEXT);
    }

    /// @notice Returns the previous trade.
    /// @param _trade The trade ID to query.
    /// @return exists True if the trade exists.
    /// @return prev The previous trade ID.
    function getPrev(uint256 _trade) public view returns (bool, uint256) {
        return getAdjacent(_trade, PREV);
    }

    /// @notice Returns the previous bytes16 trade.
    /// @param _tradeBytes The bytes16 trade ID to query.
    /// @return exists True if the trade exists.
    /// @return prev The previous trade ID.
    function getPrevBytes(bytes16 _tradeBytes) public view returns (bool, bytes16) {
        return getAdjacentBytes(_tradeBytes, PREV);
    }

    /// @notice Returns the total number of trades in the list.
    /// @return The size of the list.
    function getTradeBookSize() public view returns (uint256) {
        return size;
    }

    // ========================
    // ­ƒƒª Conversion Getters
    // ========================

    /// @notice Converts bytes16 trade ID to uint256
    /// @param _tradeBytes The bytes16 trade ID
    /// @return The uint256 representation, or 0 if not found
    function getTradeUintFromBytes(
        bytes16 _tradeBytes
    ) public view returns (uint256) {
        return _tradesBytesToUint[_tradeBytes];
    }

    /// @notice Converts uint256 trade ID to bytes16
    /// @param _tradeUint The uint256 trade ID
    /// @return The bytes16 representation, or 0 if not found
    function getTradeBytesFromUint(
        uint256 _tradeUint
    ) public view returns (bytes16) {
        return _tradesUintToBytes[_tradeUint];
    }

    /// @notice Checks if a bytes16 trade ID exists in the mapping
    /// @param _tradeBytes The bytes16 trade ID to check
    /// @return True if the mapping exists
    function tradeBytesMappingExists(
        bytes16 _tradeBytes
    ) public view returns (bool) {
        return _tradesBytesToUint[_tradeBytes] != 0;
    }

    /// @notice Checks if a uint256 trade ID has a bytes16 mapping
    /// @param _tradeUint The uint256 trade ID to check
    /// @return True if the mapping exists
    function tradeUintMappingExists(uint256 _tradeUint) public view returns (bool) {
        return _tradesUintToBytes[_tradeUint] != bytes16(0);
    }
}

/// @title TradeRegistry
/// @notice Registry for trade storage, creation, and lifecycle management
abstract contract TradeRegistry is LinkedList, IErrors {
    /// @notice Mapping of trade uint ID to Trade struct
    mapping(uint256 => Trade) internal _trades;

    /// @notice Monotonically increasing trade counter
    uint256 internal _tradeCount;

    /// @notice Trade repayments
    mapping(uint256 => TradePaymentReceipt[]) internal _tradePayments; // tradeUint => trade payments

    constructor() {
        _tradeCount = 1; // 0 is reserved for HEAD
    }

    // --- Events ---
    event TradeCreated(
        bytes16 indexed tradeBytes,
        uint256 indexed tradeId,
        address indexed companyAccount,
        address sellAsset,
        address buyAsset,
        uint256 sellAssetQuoteAmount, // gross sell asset (pre-FX, pre-fees)
        uint256 buyAssetQuoteValue, // gross buy asset value (mid-market)
        uint256 axiymFee, // buy-asset denominated fee
        uint256 totalFee, // buy-asset denominated total fee
        uint256 initialPayoutSize // buy-asset payout to company
    );
    event TradeExecuted(bytes16 indexed tradeBytes, uint256 indexed tradeId);
    event TradeCancelled(bytes16 indexed tradeBytes, uint256 indexed tradeId);

    /// @notice Creates a new trade and registers it in the linked list
    /// @param tradeBytes_ Trade ID in bytes16 format
    /// @param sellAssetQuoteAmount_ Amount of USDT to sell, this includes all fees.
    /// @param buyAssetQuoteValue_ Amount of USDT to sell, including all fees, at mid-market rate.
    /// @param axiymFee_ Axiym fee charged on the trade, in USD.
    /// @param totalFee_ Total fee charged on the trade, in USD.
    /// @param initialPayoutSize_ The payout size to the company account
    /// @param companyAccount_ The company account address involved
    /// @param sellAsset_ The ERC20 token being sold
    /// @param buyAsset_ The ERC20 token being bought
    /// @return tradeUint The newly created trade identifier
    function _createTrade(
        bytes16 tradeBytes_,
        uint256 sellAssetQuoteAmount_,
        uint256 buyAssetQuoteValue_,
        uint256 axiymFee_,
        uint256 totalFee_,
        uint256 initialPayoutSize_,
        address companyAccount_,
        address sellAsset_,
        address buyAsset_
    ) internal returns (uint256) {
        uint256 tradeUint = _tradeCount;

        // create trade struct in storage
        _trades[tradeUint] = Trade({
            sellAssetQuoteAmount: sellAssetQuoteAmount_,
            buyAssetQuoteValue: buyAssetQuoteValue_,
            axiymFee: axiymFee_,
            totalFee: totalFee_,
            initialPayoutSize: initialPayoutSize_,
            currentPayoutSize: initialPayoutSize_,
            companyAccount: companyAccount_,
            tradePool: address(this),
            sellAsset: sellAsset_,
            buyAsset: buyAsset_,
            createdAt: block.timestamp,
            executedAt: 0,
            cancelledAt: 0,
            status: TradeState.Pending
        });

        // register mapping between uint256 and bytes16 IDs
        _registerTrade(tradeUint, tradeBytes_);

        // increment trade count for next trade
        _tradeCount += 1;

        emit TradeCreated(
            tradeBytes_,
            tradeUint,
            companyAccount_,
            sellAsset_,
            buyAsset_,
            sellAssetQuoteAmount_,
            buyAssetQuoteValue_,
            axiymFee_,
            totalFee_,
            initialPayoutSize_
        );
        return tradeUint;
    }

    /// @notice Updates a trade for a payment
    /// @param tradeUint_ The internal numeric ID
    /// @param tradePayment_ The payment details
    /// @param payoutSize_ The payout sisze
    function _updateRegistry(
        uint256 tradeUint_,
        TradePaymentReceipt memory tradePayment_,
        uint256 payoutSize_
    ) internal {
        Trade storage trade = _trades[tradeUint_];

        if (trade.createdAt == 0) revert TradeDoesNotExist();
        if (trade.status != TradeState.Pending) revert InvalidTradeState();

        // we handle any rounding here
        if (payoutSize_ >= trade.currentPayoutSize) {
            trade.currentPayoutSize = 0;
        } else {
            trade.currentPayoutSize -= payoutSize_;
        }

        if (trade.currentPayoutSize == 0) {
            trade.status = TradeState.Executed;
            trade.executedAt = block.timestamp;
        }

        _tradePayments[tradeUint_].push(tradePayment_);
    }

    function _cancelRegistry(uint256 tradeUint_) internal returns (uint256) {
        Trade storage trade = _trades[tradeUint_];

        if (trade.status != TradeState.Pending) revert InvalidTradeState();

        trade.cancelledAt = block.timestamp;
        trade.status = TradeState.Cancelled;

        return trade.currentPayoutSize;
    }

    /// @notice Returns the full trade struct for a given tradeUint
    /// @param tradeUint_ The internal numeric ID
    /// @return The trade struct
    function getTradeData(uint256 tradeUint_) public view returns (Trade memory) {
        Trade memory trade = _trades[tradeUint_];
        if (trade.createdAt == 0) revert TradeDoesNotExist();
        return trade;
    }

    /// @notice Returns the full trade struct for a given bytes16 ID
    /// @param tradeBytes_ The bytes16 identifier
    /// @return The trade struct
    function getTradeDataBytes(
        bytes16 tradeBytes_
    ) public view returns (Trade memory) {
        uint256 tradeUint = _tradesBytesToUint[tradeBytes_];
        if (tradeUint == 0) revert TradeDoesNotExist();
        return _trades[tradeUint];
    }

    /// @notice Checks if a trade is in Pending state by uint256 ID
    /// @param tradeUint_ The trade ID to check
    /// @return True if the trade is pending
    function isTradePending(uint256 tradeUint_) public view returns (bool) {
        return _trades[tradeUint_].status == TradeState.Pending;
    }

    /// @notice Checks if a trade is in Pending state by bytes16 ID
    /// @param tradeBytes_ The bytes16 trade ID to check
    /// @return True if the trade is pending
    function isTradePendingBytes(bytes16 tradeBytes_) external view returns (bool) {
        uint256 tradeUint = _tradesBytesToUint[tradeBytes_];
        if (tradeUint == 0) return false;
        return isTradePending(tradeUint);
    }

    /// @notice Returns current trade count
    /// @return The total number of trades created
    function tradeCount() external view returns (uint256) {
        return _tradeCount;
    }

    /// @notice Returns all payments made for a specific trade
    /// @param tradeUint_ The internal numeric ID
    /// @return An array of TradePayment structs
    function getTradePayments(
        uint256 tradeUint_
    ) public view returns (TradePaymentReceipt[] memory) {
        if (_trades[tradeUint_].createdAt == 0) revert TradeDoesNotExist();
        return _tradePayments[tradeUint_];
    }

    /// @notice Returns all payments made for a specific trade using bytes16 ID
    /// @param tradeBytes_ The bytes16 identifier
    /// @return An array of TradePayment structs
    function getTradePaymentsBytes(
        bytes16 tradeBytes_
    ) external view returns (TradePaymentReceipt[] memory) {
        uint256 tradeUint = _tradesBytesToUint[tradeBytes_];
        return getTradePayments(tradeUint);
    }
}

/// @title TradeQueue
/// @notice Manages queue-specific operations and state for trades
abstract contract TradeQueue is TradeRegistry, Governable {
    /// @notice Authorization registry
    address internal _authRegistry;

    /// @notice Total amount currently in the queue
    uint256 internal _queueAmountTotal;

    /// @notice Cumulative amount that has ever been queued
    uint256 internal _queueAmountCumulative;

    // --- Events ---
    event TradeAddedToQueue(
        bytes16 indexed tradeBytes,
        uint256 indexed tradeUint,
        uint256 amount
    );
    event TradeRemovedFromQueue(
        bytes16 indexed tradeBytes,
        uint256 indexed tradeUint
    );
    event TradeMoved(
        bytes16 indexed tradeBytes_,
        uint256 indexed tradeUint_,
        bytes16 indexed tradeBytesTarget_,
        uint256 tradeUintTarget_,
        bool direction
    );
    event QueueMoved(
        uint256 indexed tradeId,
        uint256 indexed targetId,
        bool direction
    );
    event AuthRegistryTransferred(
        address indexed oldAuthRegistry,
        address indexed newAuthRegistry
    );

    //--- Modifiers ---
    /// @notice Restricts function access to authorized addresses only
    modifier onlyAuthAddress() {
        if (!IAuthRegistry(_authRegistry).isAuthAddress(msg.sender))
            revert Unauthorized();
        _;
    }

    constructor(address governance_, address authRegistry_) Governable(governance_) {
        _authRegistry = authRegistry_;
    }

    /// @notice Updates the AuthRegistry address
    /// @param newAuthRegistry_ New AuthRegistry address
    function setAuthRegistry(address newAuthRegistry_) external onlyGovernor {
        if (newAuthRegistry_ == address(0)) revert AddressEmpty();
        if (newAuthRegistry_ == _authRegistry) revert AddressExists();

        address oldAuthRegistry = _authRegistry;
        _authRegistry = newAuthRegistry_;

        emit AuthRegistryTransferred(oldAuthRegistry, newAuthRegistry_);
    }

    /// @notice Move a trade in the queue by uint ID
    /// @param tradeUint_ Trade ID to move
    /// @param targetUint_ Target trade ID to move before/after
    /// @param direction_ True for forward, false for backward
    function move(
        uint256 tradeUint_,
        uint256 targetUint_,
        bool direction_
    ) external onlyAuthAddress {
        bool moved = _move(tradeUint_, targetUint_, direction_);
        if (!moved) revert QueueMoveFailed();

        emit QueueMoved(tradeUint_, targetUint_, direction_);
    }

    /// @notice Move a trade in the queue by bytes16 ID
    /// @param tradeBytes_ Trade ID to move
    /// @param targetBytes_ Target trade ID to move before/after
    /// @param direction_ True for forward, false for backward
    function moveBytes(
        bytes16 tradeBytes_,
        bytes16 targetBytes_,
        bool direction_
    ) external onlyAuthAddress {
        bool moved = _moveBytes(tradeBytes_, targetBytes_, direction_);
        if (!moved) revert QueueMoveFailed();

        emit QueueMoved(
            _tradesBytesToUint[tradeBytes_],
            _tradesBytesToUint[targetBytes_],
            direction_
        );
    }

    /// @notice Cancels a trade by removing from queue and updating registry
    /// @param tradeUint_ Trade id
    function cancelTrade(uint256 tradeUint_) external onlyAuthAddress {
        // remove trade from queue
        uint256 status = _remove(tradeUint_);
        if (status == 0) revert QueueRemoveFailed();

        // set cancelled in trade registry
        uint256 currentPayoutSize = _cancelRegistry(tradeUint_);

        // reduce queue total by current payout size
        _queueAmountTotal -= currentPayoutSize;

        // execute post cancel transfers etc.
        Trade storage trade = _trades[tradeUint_];
        _executeCancel(tradeUint_, trade);

        emit TradeCancelled(_tradesUintToBytes[tradeUint_], tradeUint_);
    }

    /// @notice Cancels a trade by removing from queue and updating registry
    /// @param tradeBytes_ Trade id
    function cancelTradeBytes(bytes16 tradeBytes_) external onlyAuthAddress {
        // remove trade from queue
        bytes16 removedBytes = _removeBytes(tradeBytes_);
        if (removedBytes == bytes16(0)) revert QueueRemoveFailed();

        // set cancelled in trade registry
        uint256 currentPayoutSize = _cancelRegistry(
            getTradeUintFromBytes(tradeBytes_)
        );

        // reduce queue total by current payout size
        _queueAmountTotal -= currentPayoutSize;

        // execute post cancel transfers etc.
        Trade storage trade = _trades[_tradesBytesToUint[tradeBytes_]];
        _executeCancel(_tradesBytesToUint[tradeBytes_], trade);

        emit TradeCancelled(tradeBytes_, _tradesBytesToUint[tradeBytes_]);
    }

    /// @notice Adds a trade to the queue (at the tail)
    /// @param tradeUint_ The trade ID to add
    /// @param amount_ The trade amount to track in queue totals
    function _addToQueue(uint256 tradeUint_, uint256 amount_) internal {
        // add to linked list at tail
        _pushTail(tradeUint_);

        // update queue state
        _queueAmountTotal += amount_;
        _queueAmountCumulative += amount_;

        emit TradeAddedToQueue(_tradesUintToBytes[tradeUint_], tradeUint_, amount_);
    }

    /// @notice Removes a trade from the queue
    /// @param tradeUint_ The trade ID to remove
    /// @param trade_ The trade struct from storage
    /// @param amount_ The trade amount to deduct from queue totals
    function _updateQueue(
        uint256 tradeUint_,
        Trade storage trade_,
        uint256 amount_
    ) internal {
        if (amount_ == trade_.currentPayoutSize) {
            _remove(tradeUint_);
            _queueAmountTotal -= amount_;
            emit TradeRemovedFromQueue(_tradesUintToBytes[tradeUint_], tradeUint_);
        } else {
            _queueAmountTotal -= amount_;
        }
    }

    function _executeCancel(
        uint256 tradeUint_,
        Trade storage trade_
    ) internal virtual;

    /// @notice Returns the trade at the head of the queue
    /// @return tradeUint_ The trade ID at the head
    /// @return trade The trade struct
    function getHeadTrade()
        external
        view
        returns (uint256 tradeUint_, Trade memory trade)
    {
        (, uint256 nextTradeId) = getNext(0); // HEAD == 0
        if (nextTradeId == 0) return (0, _getEmptyTrade());
        return (nextTradeId, getTradeData(nextTradeId));
    }

    /// @notice Returns the trade at the tail of the queue
    /// @return tradeUint_ The trade ID at the tail
    /// @return trade The trade struct
    function getTailTrade()
        external
        view
        returns (uint256 tradeUint_, Trade memory trade)
    {
        (, uint256 prevTradeId) = getPrev(0); // HEAD == 0
        if (prevTradeId == 0) return (0, _getEmptyTrade());
        return (prevTradeId, getTradeData(prevTradeId));
    }

    /// @notice Returns all queued trades
    /// @return tradeIds Array of trade IDs
    /// @return trades Array of trade structs
    function getAllQueuedTrades()
        external
        view
        returns (uint256[] memory tradeIds, Trade[] memory trades)
    {
        uint256 listSize = getTradeBookSize();
        tradeIds = new uint256[](listSize);
        trades = new Trade[](listSize);

        (, uint256 current) = getNext(0); // start at head
        for (uint256 i = 0; i < listSize; i++) {
            tradeIds[i] = current;
            trades[i] = getTradeData(current);
            (, current) = getNext(current);
        }
    }

    /// @notice Returns a paginated list of queued trades
    /// @dev Pass nextId as startId_ for subsequent pages. Returns trimmed arrays without assembly.
    /// @param startId_ The trade ID to start from (0 for head)
    /// @param pageSize_ The number of trades to return per page
    /// @return tradeIds Array of trade IDs for this page
    /// @return trades Array of trade structs for this page
    /// @return nextId The next trade ID to use as startId_ for the next page (0 if end of queue)
    function getQueuedTradesPaginated(
        uint256 startId_,
        uint256 pageSize_
    )
        external
        view
        returns (uint256[] memory tradeIds, Trade[] memory trades, uint256 nextId)
    {
        uint256[] memory tempIds = new uint256[](pageSize_);
        Trade[] memory tempTrades = new Trade[](pageSize_);

        (, uint256 current) = getNext(startId_);
        uint256 count;

        while (current != 0 && count < pageSize_) {
            tempIds[count] = current;
            tempTrades[count] = getTradeData(current);
            (, current) = getNext(current);
            count++;
        }

        nextId = current;

        tradeIds = new uint256[](count);
        trades = new Trade[](count);
        for (uint256 i = 0; i < count; i++) {
            tradeIds[i] = tempIds[i];
            trades[i] = tempTrades[i];
        }
    }

    /// @notice Returns an empty trade struct
    /// @return Empty trade struct with default values
    function _getEmptyTrade() internal pure returns (Trade memory) {
        return
            Trade({
                sellAssetQuoteAmount: 0,
                buyAssetQuoteValue: 0,
                axiymFee: 0,
                totalFee: 0,
                initialPayoutSize: 0,
                currentPayoutSize: 0,
                companyAccount: address(0),
                tradePool: address(0),
                sellAsset: address(0),
                buyAsset: address(0),
                createdAt: 0,
                executedAt: 0,
                cancelledAt: 0,
                status: TradeState.Unspecified
            });
    }

    /// @notice Returns total amount currently in queue
    /// @return The total queued amount
    function queueAmountTotal() external view returns (uint256) {
        return _queueAmountTotal;
    }

    /// @notice Returns cumulative amount ever queued
    /// @return The cumulative queued amount
    function queueAmountCumulative() external view returns (uint256) {
        return _queueAmountCumulative;
    }
}

/// @title TradeExecutor
/// @notice Handles execution of queued trades with treasury interaction
abstract contract TradeExecutor is TradeQueue, ReentrancyGuard, Pausable {
    uint256 internal constant MIN_GAS_THRESHOLD = 50_000;
    uint256 internal constant MAX_GAS_THRESHOLD = 10_000_000;

    uint256 internal constant MIN_MAX_TRADES = 1;
    uint256 internal constant MAX_MAX_TRADES = 1000;

    /// @notice The trade pool asset (internal currency, e.g. IUSD)
    IERC20 internal immutable _offAsset;

    /// @notice The treasury asset (external currency, e.g. USDT)
    IERC20 internal immutable _onAsset;

    /// @notice Whether queue execution happens automatically
    bool internal _autoExecution = true;

    /// @notice Whether queue allowed partial execution
    bool internal _partialExecution = false;

    /// @notice Maximum number of trades to execute in one queue run
    uint256 internal _maxTrades = 50;

    /// @notice Gas threshold for stopping queue execution
    uint256 internal _gasThreshold = 150000;

    // --- Events ---
    event AutoExecutionSet(bool newAutoExecution);
    event PartialExecutionSet(bool newPartialExecution);
    event QueueExecuted(uint256 totalExecuted, uint256 remainingBalance);
    event GasThresholdSet(uint256 previousGasThreshold, uint256 newGasThreshold);
    event MaxTradesSet(uint256 previousMaxTrades, uint256 newMaxTrades);

    // --- Constructor ---
    /// @param governance_ Governance address
    /// @param authRegistry_ Auth registry address
    /// @param offAsset_ Address of the internal exchange asset (IUSD)
    /// @param onAsset_ Address of external asset (USDT)
    constructor(
        address governance_,
        address authRegistry_,
        address offAsset_,
        address onAsset_
    ) TradeQueue(governance_, authRegistry_) {
        _offAsset = IERC20(offAsset_);
        _onAsset = IERC20(onAsset_);
    }

    /// @notice Enable or disable auto execution mode
    /// @param newAutoExecution_ True to enable auto execution, false to disable
    function setAutoExecution(bool newAutoExecution_) external onlyGovernor {
        _autoExecution = newAutoExecution_;
        emit AutoExecutionSet(newAutoExecution_);
    }

    /// @notice Enable or disable partial execution mode
    /// @param newPartialExecution_ True to enable partial execution, false to disable
    function setPartialExecution(bool newPartialExecution_) external onlyGovernor {
        _partialExecution = newPartialExecution_;
        emit PartialExecutionSet(newPartialExecution_);
    }

    /// @notice Set gas threshold for queue execution
    /// @dev Must be between 50,000 and 10,000,000 to prevent queue lockout across all supported chains
    /// @param newGasThreshold_ Minimum gas remaining before stopping queue execution
    function setGasThreshold(uint256 newGasThreshold_) external onlyGovernor {
        if (
            newGasThreshold_ < MIN_GAS_THRESHOLD ||
            newGasThreshold_ > MAX_GAS_THRESHOLD
        ) revert InvalidGasThreshold();

        uint256 previous = _gasThreshold;
        _gasThreshold = newGasThreshold_;
        emit GasThresholdSet(previous, newGasThreshold_);
    }

    /// @notice Set max trades to execute in one queue run
    /// @dev Must be between 1 and 1000 to prevent queue lockout across all supported chains
    /// @param newMaxTrades_ Maximum number of trades to execute
    function setMaxTrades(uint256 newMaxTrades_) external onlyGovernor {
        if (newMaxTrades_ < MIN_MAX_TRADES || newMaxTrades_ > MAX_MAX_TRADES)
            revert InvalidMaxTrades();

        uint256 previous = _maxTrades;
        _maxTrades = newMaxTrades_;
        emit MaxTradesSet(previous, newMaxTrades_);
    }

    /// @notice Run execution engine
    function executeQueue() external onlyAuthAddress nonReentrant whenNotPaused {
        if (_partialExecution) {
            _runExecutionEngine(true);
        } else {
            _runExecutionEngine(false);
        }
    }

    /// @notice Run execution engine internal
    function _executeQueue() internal {
        if (_partialExecution) {
            _runExecutionEngine(true);
        } else {
            _runExecutionEngine(false);
        }
    }

    /// @notice Executes execution engine, with partial allowed or not allowed
    function _runExecutionEngine(bool allowPartial) internal {
        uint256 available = _getTreasuryBalance();
        if (available == 0) return;

        uint256 totalExecuted;
        uint256 executedCount;
        uint256 gasLimit = _gasThreshold;

        (, uint256 currentTrade) = getNext(0);

        while (currentTrade != 0 && available > 0) {
            if (gasleft() < gasLimit) break;
            if (_maxTrades > 0 && executedCount >= _maxTrades) break;

            Trade storage trade = _trades[currentTrade];
            (, uint256 nextTrade) = getNext(currentTrade);

            if (trade.status == TradeState.Pending) {
                uint256 paymentAmount = 0;

                if (available >= trade.currentPayoutSize) {
                    // Sufficient funds for full payment
                    paymentAmount = trade.currentPayoutSize;
                } else if (allowPartial) {
                    // Insufficient funds, but partial payments are allowed
                    paymentAmount = available;
                }

                // If we determined a valid payment amount, execute it
                if (paymentAmount > 0) {
                    available -= paymentAmount;
                    totalExecuted += paymentAmount;
                    executedCount++;

                    _executeTrade(currentTrade, trade, paymentAmount);
                }
            }
            currentTrade = nextTrade;
        }

        emit QueueExecuted(totalExecuted, available);
    }

    /// @notice Internal helper to execute a trade with partial/full logic
    /// @param tradeId_ The trade ID
    function executeSingleTrade(
        uint256 tradeId_
    ) external onlyAuthAddress nonReentrant whenNotPaused {
        Trade storage trade = _trades[tradeId_];

        _executeSingleTradeInternal(tradeId_, trade);
    }

    /// @notice Internal helper to execute a trade with partial/full logic
    /// @param tradeBytes_ The trade bytes
    function executeSingleTradeBytes(
        bytes16 tradeBytes_
    ) external onlyAuthAddress nonReentrant whenNotPaused {
        // decode the tradeId from bytes
        Trade storage trade = _trades[_tradesBytesToUint[tradeBytes_]];

        _executeSingleTradeInternal(_tradesBytesToUint[tradeBytes_], trade);
    }

    /// @notice Internal helper to execute a trade with partial/full logic
    /// @param tradeId_ The trade ID
    /// @param trade_ Storage pointer to the trade
    function _executeSingleTradeInternal(
        uint256 tradeId_,
        Trade storage trade_
    ) internal {
        if (trade_.status != TradeState.Pending) revert InvalidStatus();

        uint256 available = _getTreasuryBalance();
        uint256 amount;

        if (available >= trade_.currentPayoutSize) {
            amount = trade_.currentPayoutSize;
        } else if (_partialExecution) {
            amount = available;
        } else {
            revert InsufficientTreasuryBalance();
        }

        _executeTrade(tradeId_, trade_, amount);
    }

    function _getTreasuryBalance() internal view virtual returns (uint256);

    function _executeTrade(
        uint256 tradeUint_,
        Trade storage trade_,
        uint256 amount_
    ) internal virtual;

    /// @notice Returns the auth registry address
    /// @return The auth registry address
    function authRegistry() external view returns (address) {
        return _authRegistry;
    }

    /// @notice Returns whether auto execution is enabled
    /// @return True if auto execution is enabled
    function autoExecution() external view returns (bool) {
        return _autoExecution;
    }

    /// @notice Returns the maximum trades per execution
    /// @return The max trades limit
    function maxTrades() external view returns (uint256) {
        return _maxTrades;
    }

    /// @notice Returns the gas threshold for execution
    /// @return The gas threshold
    function gasThreshold() external view returns (uint256) {
        return _gasThreshold;
    }

    /// @notice Returns the off asset (internal currency)
    /// @return The off asset address
    function offAsset() external view returns (address) {
        return address(_offAsset);
    }

    /// @notice Returns the on asset (external currency)
    /// @return The on asset address
    function onAsset() external view returns (address) {
        return address(_onAsset);
    }

    /// @notice Returns the on partialExecution
    /// @return The on asset address
    function partialExecution() external view returns (bool) {
        return _partialExecution;
    }
}

/// @title OnTradeExchange
/// @notice Implements exchange functionality between an OnTradeExchange and a SegregatedTreasury
/// @dev Orchestrates trade creation, fee collection, and company account management
contract OnTradeExchange is TradeExecutor {
    using SafeToken for IERC20;

    ContractVersion public immutable version = ContractVersion.OnTradeExchange;

    // --- State ---
    /// @notice Tracks if a company account is registered
    mapping(address => bool) internal _companyAccounts;

    /// @notice Maps index to company account address
    mapping(uint256 => address) internal _companyAccountsByIdx;

    /// @notice Tracks company account status (Active/Deactivated)
    mapping(address => CompanyAccountStatus) internal _companyAccountStatuses;

    /// @notice Total number of company accounts
    uint256 internal _companyAccountCount;

    /// @notice Address where Axiym fees are sent (in offAsset/IUSD)
    address internal _feeCompanyAccount;

    /// @notice Segregated Treasury address
    address internal immutable _segregatedTreasury;

    /// @notice Nonce tracking mapping
    mapping(bytes16 => bool) private _usedNonces;

    /// @notice Minimum Trade Size
    uint256 internal _minTradeAmount;

    // --- Events ---
    event FeeCompanyAccountUpdated(
        address indexed previousFeeAccount,
        address indexed newFeeAccount
    );
    event CompanyAccountAdded(address indexed companyAccount);
    event CompanyAccountActivated(address indexed companyAccount);
    event CompanyAccountDeactivated(address indexed companyAccount);
    event TradePayment(
        bytes32 indexed tradeId,
        uint256 indexed tradeUint,
        address indexed companyAccount,
        address asset,
        uint256 grossAmount,
        uint256 clientPayout,
        uint256 axiymFee,
        uint256 providerFee,
        uint256 timestamp
    );
    event MinTradeAmountSet(uint256 previousAmount, uint256 newAmount);

    // --- Modifiers ---
    /// @notice Ensures company account exists and is active
    modifier onlyActiveCompanyAccount(address companyAccount_) {
        if (!_companyAccounts[companyAccount_]) revert NotCompanyAccount();
        if (_companyAccountStatuses[companyAccount_] != CompanyAccountStatus.Active)
            revert InvalidStatus();
        _;
    }

    /// @notice Ensures Axiym fee account is set
    modifier nonZerofeeAccount() {
        if (_feeCompanyAccount == address(0)) revert AddressEmpty();
        _;
    }

    // --- Constructor ---
    /// @notice Deploys OnTradeExchange and creates associated SegregatedTreasury
    /// @param governance_ Address of governance authority
    /// @param owner_ Address of on trade treasury owner
    /// @param authRegistry_ Address of the Auth Registry
    /// @param offAsset_ Address of the internal exchange asset (IUSD)
    /// @param onAsset_ Address of external asset (USDT)
    constructor(
        address governance_,
        address owner_,
        address authRegistry_,
        address offAsset_,
        address onAsset_
    ) TradeExecutor(governance_, authRegistry_, offAsset_, onAsset_) {
        if (offAsset_ == address(0) || onAsset_ == address(0)) revert AddressEmpty();
        if (offAsset_.code.length == 0 || onAsset_.code.length == 0)
            revert NotContract();
        if (offAsset_ == onAsset_) revert AssetsIdentical();

        // create a new SegregatedTreasury
        _segregatedTreasury = address(
            new SegregatedTreasury(address(this), owner_, offAsset_, onAsset_)
        );
    }

    /// @notice Sets the minimum trade amount
    /// @param minTradeAmount_ New minimum trade amount in offAsset units
    function setMinTradeAmount(uint256 minTradeAmount_) external onlyGovernor {
        uint256 previous = _minTradeAmount;
        _minTradeAmount = minTradeAmount_;
        emit MinTradeAmountSet(previous, minTradeAmount_);
    }

    /// @notice Pauses the contract
    function pause() external onlyManager {
        _pause();
        emit Paused(msg.sender);
    }

    /// @notice Unpauses the contract
    function unpause() external onlyManager {
        _unpause();
        emit Unpaused(msg.sender);
    }

    /// @notice Adds a new company account and sets its status to Active
    /// @param companyAccount_ Address of the company account to add
    function addCompanyAccount(address companyAccount_) external onlyAuthorizer {
        if (_companyAccounts[companyAccount_] || companyAccount_ == address(0))
            revert InvalidCompanyAccount();

        _companyAccounts[companyAccount_] = true;
        _companyAccountsByIdx[_companyAccountCount] = companyAccount_;
        _companyAccountStatuses[companyAccount_] = CompanyAccountStatus.Active;
        _companyAccountCount++;
        emit CompanyAccountAdded(companyAccount_);
    }

    /// @notice Activates a company account
    /// @param companyAccount_ Address of the company account to activate
    function activateCompanyAccount(
        address companyAccount_
    ) external onlyAuthorizer {
        if (!_companyAccounts[companyAccount_]) revert NotCompanyAccount();
        if (_companyAccountStatuses[companyAccount_] == CompanyAccountStatus.Active)
            revert InvalidStatus();
        _companyAccountStatuses[companyAccount_] = CompanyAccountStatus.Active;
        emit CompanyAccountActivated(companyAccount_);
    }

    /// @notice Deactivates a company account
    /// @param companyAccount_ Address of the company account to deactivate
    function deactivateCompanyAccount(
        address companyAccount_
    ) external onlyGovernor {
        if (!_companyAccounts[companyAccount_]) revert NotCompanyAccount();
        if (_companyAccountStatuses[companyAccount_] != CompanyAccountStatus.Active)
            revert InvalidStatus();
        _companyAccountStatuses[companyAccount_] = CompanyAccountStatus.Deactivated;
        emit CompanyAccountDeactivated(companyAccount_);
    }

    /// @notice Sets the Axiym fee company account (where IUSD fees are sent)
    /// @param feeCompanyAccount_ New fee company account address
    function setFeeCompanyAccount(address feeCompanyAccount_) external onlyGovernor {
        if (
            _feeCompanyAccount == feeCompanyAccount_ ||
            feeCompanyAccount_ == address(0)
        ) revert InvalidAxiymFeeCompanyAccount();

        address previous = _feeCompanyAccount;
        _feeCompanyAccount = feeCompanyAccount_;
        emit FeeCompanyAccountUpdated(previous, feeCompanyAccount_);
    }

    ///// @notice Executes a trade selling internal currency (IUSD) for treasury asset (USDT)
    ///// @dev Orchestrates: validate ÔåÆ pull funds ÔåÆ create trade ÔåÆ add to queue ÔåÆ execute queue
    ///// @param companyAccount_ Address of the company account initiating the trade
    ///// @param tradeBytes_ Trade ID in bytes16 format
    ///// @param sellAssetQuoteAmount_ Amount of USDT to sell, this includes all fees.
    ///// @param axiymFee_ Axiym fee charged on the trade, in USD.
    ///// @param nonce_ Nonce for authorization signature
    ///// @param signature_ Signature authorizing this trade
    function onTrade(
        address companyAccount_,
        bytes16 tradeBytes_,
        uint256 sellAssetQuoteAmount_,
        uint256 axiymFee_,
        bytes16 nonce_,
        bytes memory signature_
    )
        external
        nonReentrant
        whenNotPaused
        onlyAuthAddress
        onlyActiveCompanyAccount(companyAccount_)
        nonZerofeeAccount
    {
        if (_usedNonces[nonce_]) revert InvalidTradeNonce();
        _usedNonces[nonce_] = true;

        if (sellAssetQuoteAmount_ < _minTradeAmount) revert TradeBelowMinimum();
        if (axiymFee_ > sellAssetQuoteAmount_ / 20) revert FeesExceedValue();

        // pull funds from company account and send fee to fee account
        _pullFundsAndApprove(
            companyAccount_,
            sellAssetQuoteAmount_,
            axiymFee_,
            tradeBytes_,
            nonce_,
            signature_
        );

        // calculate payout size (USD paid at start)
        uint256 payoutSize = sellAssetQuoteAmount_ - axiymFee_;

        // create trade in registry
        uint256 tradeUint = _createTrade(
            tradeBytes_,
            sellAssetQuoteAmount_, // Amount of USD being sold
            sellAssetQuoteAmount_, // Equivalent USDT (i.e. mid-market price is 1)
            axiymFee_, // total axiym fee in USD / USDT (same as 1:1)
            axiymFee_, // total as above as no provider
            payoutSize, // initial payout equals amount for client (total - axiymFee)
            companyAccount_,
            address(_offAsset),
            address(_onAsset)
        );

        // add trade to queue
        _addToQueue(tradeUint, payoutSize);

        // try to execute queue if auto execution is enabled
        if (_autoExecution) {
            _executeQueue();
        }
    }

    function _executeTrade(
        uint256 tradeUint_,
        Trade storage trade_,
        uint256 amount_
    ) internal override whenNotPaused {
        if (!_companyAccounts[trade_.companyAccount]) revert NotCompanyAccount();
        if (
            _companyAccountStatuses[trade_.companyAccount] !=
            CompanyAccountStatus.Active
        ) revert InvalidStatus();

        _updateQueue(tradeUint_, trade_, amount_);

        uint256 axiymFee = (amount_ * trade_.axiymFee) / trade_.initialPayoutSize;
        uint256 providerFee = 0;

        TradePaymentReceipt memory tradePayment = TradePaymentReceipt({
            clientPayout: amount_,
            axiymFee: axiymFee,
            otherFee: providerFee,
            timestamp: block.timestamp
        });

        // capture before _updateRegistry zeroes it on full payment
        uint256 remainingPayout = trade_.currentPayoutSize;

        // update trade registry
        _updateRegistry(tradeUint_, tradePayment, amount_);

        _offAsset.safeForceApprove(_segregatedTreasury, amount_);

        ISegregatedTreasury(_segregatedTreasury).executeTrade(
            tradeUint_,
            amount_,
            remainingPayout
        );

        _onAsset.safeTransfer(trade_.companyAccount, amount_);

        emit TradePayment(
            _tradesUintToBytes[tradeUint_],
            tradeUint_,
            trade_.companyAccount,
            address(_onAsset),
            amount_,
            amount_,
            axiymFee,
            0,
            block.timestamp
        );
    }

    function _getTreasuryBalance() internal view override returns (uint256) {
        return _onAsset.balanceOf(_segregatedTreasury);
    }

    /// @notice Refunds a single trade
    /// @param tradeUint_ The trade ID
    /// @param trade_ The trade struct from storage
    function _executeCancel(
        uint256 tradeUint_,
        Trade storage trade_
    ) internal override whenNotPaused {}

    /// @notice Validates balance, authorizes spender, and pulls funds from a company account
    /// @param companyAccount_ The company account address
    /// @param sellAssetQuoteAmount_ Amount of USDT to sell, this includes all fees.
    /// @param axiymFee_ Axiym fee charged on the trade, in USD.
    /// @param tradeBytes_ TradeBytes
    /// @param nonce_ Nonce used for authorization signature
    /// @param signature_ Signature authorizing the spender
    function _pullFundsAndApprove(
        address companyAccount_,
        uint256 sellAssetQuoteAmount_,
        uint256 axiymFee_,
        bytes16 tradeBytes_,
        bytes16 nonce_,
        bytes memory signature_
    ) internal {
        // verify company account has sufficient balance
        if (_offAsset.balanceOf(companyAccount_) < sellAssetQuoteAmount_)
            revert InsufficientFunds();

        // authorize this contract to spend from company account
        ICompanyAccount(companyAccount_).approveSpender(
            address(_offAsset),
            sellAssetQuoteAmount_,
            tradeBytes_,
            nonce_,
            signature_
        );

        // pull total from company account to this exchange
        _offAsset.safeTransferFrom(
            companyAccount_,
            address(this),
            sellAssetQuoteAmount_
        );

        // safeTransfer fee to Axiym fee account
        if (axiymFee_ > 0) {
            _offAsset.safeTransfer(_feeCompanyAccount, axiymFee_);
        }
    }

    /// @notice Returns the Axiym fee company account address
    /// @return The fee account address
    function feeCompanyAccount() external view returns (address) {
        return _feeCompanyAccount;
    }

    /// @notice Returns total number of company accounts
    /// @return The company account count
    function companyAccountCount() external view returns (uint256) {
        return _companyAccountCount;
    }

    /// @notice Returns company account at given index
    /// @param index_ The index to query
    /// @return The company account address
    function getCompanyAccountByIndex(
        uint256 index_
    ) external view returns (address) {
        return _companyAccountsByIdx[index_];
    }

    /// @notice Returns status of a company account
    /// @param companyAccount_ The company account to query
    /// @return The account status
    function getCompanyAccountStatus(
        address companyAccount_
    ) external view returns (CompanyAccountStatus) {
        return _companyAccountStatuses[companyAccount_];
    }

    /// @notice Checks if address is a registered company account
    /// @param companyAccount_ The address to check
    /// @return True if registered
    function isCompanyAccount(address companyAccount_) external view returns (bool) {
        return _companyAccounts[companyAccount_];
    }

    /// @notice Returns the on trade treasury address
    /// @return The treasury address
    function segregatedTreasury() external view returns (address) {
        return _segregatedTreasury;
    }

    /// @notice Returns the minimum trade amount in offAsset units
    /// @return The minimum trade amount
    function minTradeAmount() external view returns (uint256) {
        return _minTradeAmount;
    }
}
