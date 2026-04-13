// SPDX-License-Identifier: AGPL-3.0-or-later AND GPL-3.0-only AND MIT
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

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        if (to == address(0)) revert SafeToken__ZeroAddress();
        if (value == 0) revert SafeToken__ZeroAmount();
        uint256 balanceBefore = token.balanceOf(to);
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transfer.selector, to, value)
        );
        if (!success)
            revert SafeToken__CallFailed(address(token), token.transfer.selector);
        if (data.length > 0 && !abi.decode(data, (bool))) {
            _requireBalanceDelta(token, to, balanceBefore, value);
        }
    }

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
        if (data.length > 0 && !abi.decode(data, (bool))) {
            if (balanceAfter <= balanceBefore) {
                revert SafeToken__TransferFailed(address(token), to, value);
            }
        }
        received = balanceAfter - balanceBefore;
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
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
        if (data.length > 0 && !abi.decode(data, (bool))) {
            _requireBalanceDelta(token, to, balanceBefore, value);
        }
    }

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

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        if (spender == address(0)) revert SafeToken__ZeroAddress();
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

    function safeForceApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        if (spender == address(0)) revert SafeToken__ZeroAddress();
        uint256 currentAllowance = token.allowance(address(this), spender);
        if (currentAllowance != 0) {
            (bool zeroSuccess, ) = address(token).call(
                abi.encodeWithSelector(token.approve.selector, spender, 0)
            );
            if (!zeroSuccess)
                revert SafeToken__CallFailed(address(token), token.approve.selector);
        }
        if (value == 0) return;
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.approve.selector, spender, value)
        );
        if (!success)
            revert SafeToken__CallFailed(address(token), token.approve.selector);
        if (data.length > 0 && !abi.decode(data, (bool))) {
            revert SafeToken__ApproveFailed(address(token), spender, value);
        }
    }

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
    uint256 clientPayout;
    uint256 axiymFee;
    uint256 otherFee;
    uint256 timestamp;
}

struct Trade {
    uint256 sellAssetQuoteAmount;
    uint256 buyAssetQuoteValue;
    uint256 axiymFee;
    uint256 totalFee;
    uint256 initialPayoutSize;
    uint256 currentPayoutSize;
    address companyAccount;
    address tradePool;
    address sellAsset;
    address buyAsset;
    uint256 createdAt;
    uint256 executedAt;
    uint256 cancelledAt;
    TradeState status;
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

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }
        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        _status = NOT_ENTERED;
    }

    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == ENTERED;
    }
}

contract SegregatedTreasury is
    Pausable,
    ReentrancyGuard,
    IErrors,
    ISegregatedTreasury
{
    using SafeToken for IERC20;

    ContractVersion public immutable version = ContractVersion.SegregatedTreasury;
    address internal immutable _onTradeExchange;
    IERC20 internal immutable _offAsset;
    IERC20 internal immutable _onAsset;
    mapping(address => bool) public _owners;
    uint256 internal _ownerCount;
    address internal _receiveAddress;

    event OwnerChanged(address indexed previousOwner, address indexed newOwner);
    event ReceiveAddressChanged(
        address indexed previousAddress,
        address indexed newAddress
    );
    event TradePayment(uint256 indexed tradeUint, uint256 amount);
    event TreasuryWithdraw(address receiveAddress, address onAsset, uint256 amount);

    modifier onlyOwner() {
        if (!_owners[msg.sender]) revert NotOwner();
        _;
    }

    modifier onlyOnTradeExchange() {
        if (msg.sender != _onTradeExchange) revert NotOnTradeExchange();
        _;
    }

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

    function pause() external onlyOwner {
        _pause();
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        _unpause();
        emit Unpaused(msg.sender);
    }

    function addOwner(address owner_) external onlyOwner {
        if (owner_ == address(0)) revert AddressEmpty();
        if (_owners[owner_]) revert OwnerExists();
        _owners[owner_] = true;
        _ownerCount++;
        emit OwnerChanged(address(0), owner_);
    }

    function removeOwner(address owner_) external onlyOwner {
        if (!_owners[owner_]) revert NotOwner();
        if (_ownerCount == 1) revert CannotRemoveLastOwner();
        _owners[owner_] = false;
        _ownerCount--;
        emit OwnerChanged(owner_, address(0));
    }

    function setReceiveAddress(address receiveAddress_) external onlyOwner {
        if (receiveAddress_ == address(0)) revert AddressEmpty();
        if (receiveAddress_ == _receiveAddress) revert AddressExists();
        address previousAddress = _receiveAddress;
        _receiveAddress = receiveAddress_;
        emit ReceiveAddressChanged(previousAddress, receiveAddress_);
    }

    function withdraw(uint256 amount_) external onlyOwner nonReentrant {
        if (amount_ == 0) revert ZeroAmount();
        if (_receiveAddress == address(0)) revert AddressEmpty();
        uint256 bal = _onAsset.balanceOf(address(this));
        if (bal < amount_) revert InsufficientTreasuryBalance();
        _onAsset.safeTransfer(_receiveAddress, amount_);
        emit TreasuryWithdraw(_receiveAddress, address(_onAsset), amount_);
    }

    function executeTrade(
        uint256 tradeId_,
        uint256 offAmount_,
        uint256 onAmount_
    ) external onlyOnTradeExchange whenNotPaused nonReentrant {
        if (offAmount_ == 0 || onAmount_ == 0) revert ZeroAmount();
        _offAsset.safeTransferFrom(msg.sender, address(this), offAmount_);
        _onAsset.safeTransfer(msg.sender, onAmount_);
        emit TradePayment(tradeId_, offAmount_);
    }

    function onTradeExchange() external view returns (address) {
        return _onTradeExchange;
    }

    function offAsset() external view returns (address) {
        return address(_offAsset);
    }

    function onAsset() external view returns (address) {
        return address(_onAsset);
    }

    function receiveAddress() external view returns (address) {
        return _receiveAddress;
    }

    function isOwner(address account_) external view returns (bool) {
        return _owners[account_];
    }
}
