// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.24;

import {TradeExecutor} from "./TradeExecutor.sol";
import {ContractVersion} from "../enums/ContractVersion.sol";
import {CompanyAccountStatus} from "../enums/CompanyAccountStatus.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICompanyAccount} from "../interfaces/ICompanyAccount.sol";
import {Trade} from "../trade/structs/Trade.sol";
import {ISegregatedTreasury} from "./interfaces/ISegregatedTreasury.sol";
import {SegregatedTreasury} from "./SegregatedTreasury.sol";
import {TradePaymentReceipt} from "./structs/TradePaymentReceipt.sol";
import {SafeToken} from "../libraries/SafeToken.sol";

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

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Governor / Manager Functions
    // ════════════════════════════════════════════════════════════════════════════

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

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Company Account Management
    // ════════════════════════════════════════════════════════════════════════════

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

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Axiym Fee Account Management
    // ════════════════════════════════════════════════════════════════════════════

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

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 OnTrade Function (Main Entry Point)
    // ════════════════════════════════════════════════════════════════════════════

    ///// @notice Executes a trade selling internal currency (IUSD) for treasury asset (USDT)
    ///// @dev Orchestrates: validate → pull funds → create trade → add to queue → execute queue
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

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Trade Execution
    // ════════════════════════════════════════════════════════════════════════════

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

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Trade Cancellation
    // ════════════════════════════════════════════════════════════════════════════

    /// @notice Refunds a single trade
    /// @param tradeUint_ The trade ID
    /// @param trade_ The trade struct from storage
    function _executeCancel(
        uint256 tradeUint_,
        Trade storage trade_
    ) internal override whenNotPaused {}

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Helper Functions
    // ════════════════════════════════════════════════════════════════════════════

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

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Getters
    // ════════════════════════════════════════════════════════════════════════════

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
