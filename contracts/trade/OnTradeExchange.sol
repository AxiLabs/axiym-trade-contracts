// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.24;

import {TradeExecutor} from "./TradeExecutor.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ContractVersion} from "../enums/ContractVersion.sol";
import {CompanyAccountStatus} from "../enums/CompanyAccountStatus.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICompanyAccount} from "../interfaces/ICompanyAccount.sol";
import {Trade} from "../trade/structs/Trade.sol";
import {ISegregatedTreasury} from "./interfaces/ISegregatedTreasury.sol";
import {SegregatedTreasury} from "./SegregatedTreasury.sol";
import {TradePaymentReceipt} from "./structs/TradePaymentReceipt.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title OnTradeExchange
/// @notice Implements exchange functionality between an OnTradeExchange and a SegregatedTreasury
/// @dev Orchestrates trade creation, fee collection, and company account management
contract OnTradeExchange is TradeExecutor, Pausable {
    using SafeERC20 for IERC20;

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
    /// @param companyAccounts_ List of company account addresses to register and activate
    /// @param feeCompanyAccount_ Account to receive Axiym fees (in offAsset)
    constructor(
        address governance_,
        address owner_,
        address authRegistry_,
        address offAsset_,
        address onAsset_,
        address[] memory companyAccounts_,
        address feeCompanyAccount_
    ) TradeExecutor(governance_, authRegistry_, offAsset_, onAsset_) {
        // create a new SegregatedTreasury
        _segregatedTreasury = address(
            new SegregatedTreasury(address(this), owner_, offAsset_, onAsset_)
        );

        // initialize fee account and company accounts
        _setup(feeCompanyAccount_, companyAccounts_);
    }

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Pause Controls
    // ════════════════════════════════════════════════════════════════════════════

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
    // 🟦 Setup
    // ════════════════════════════════════════════════════════════════════════════

    /// @notice Internal setup function to initialize fee account and company accounts
    /// @param feeCompanyAccount_ The address of the fee company account
    /// @param companyAccounts_ List of company account addresses to register and activate
    function _setup(
        address feeCompanyAccount_,
        address[] memory companyAccounts_
    ) internal {
        // setup fee company account
        _feeCompanyAccount = feeCompanyAccount_;
        emit FeeCompanyAccountUpdated(address(0), feeCompanyAccount_);

        // setup company accounts
        for (uint256 i = 0; i < companyAccounts_.length; i++) {
            address companyAccount = companyAccounts_[i];
            if (companyAccount == address(0)) revert InvalidCompanyAccount();

            _companyAccounts[companyAccount] = true;
            _companyAccountsByIdx[i] = companyAccount;
            _companyAccountStatuses[companyAccount] = CompanyAccountStatus.Active;
            _companyAccountCount++;

            emit CompanyAccountAdded(companyAccount);
        }
    }

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Company Account Management
    // ════════════════════════════════════════════════════════════════════════════

    /// @notice Adds a new company account and sets its status to Active
    /// @param companyAccount_ Address of the company account to add
    function addCompanyAccount(address companyAccount_) external onlyAuthorizer {
        if (_companyAccounts[companyAccount_]) revert InvalidCompanyAccount();
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
        if (_feeCompanyAccount == feeCompanyAccount_)
            revert InvalidAxiymFeeCompanyAccount();

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
        if (sellAssetQuoteAmount_ == 0) revert ZeroAmount();
        if (axiymFee_ > sellAssetQuoteAmount_) revert FeesExceedValue();

        // pull funds from company account and send fee to fee account
        _pullFundsAndApprove(
            companyAccount_,
            sellAssetQuoteAmount_,
            axiymFee_,
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

    /// @notice Executes a single trade
    /// @param tradeUint_ The trade ID
    /// @param trade_ The trade struct from storage
    /// @param amount_ The trade struct from storage
    function _executeTrade(
        uint256 tradeUint_,
        Trade storage trade_,
        uint256 amount_
    ) internal override whenNotPaused {
        // if complete payment, we can remove from queue.
        _updateQueue(tradeUint_, trade_, amount_);

        // approve treasury to take offAsset
        SafeERC20.forceApprove(_offAsset, _segregatedTreasury, amount_);

        // execute trade in treasury (swap assets)
        ISegregatedTreasury(_segregatedTreasury).executeTrade(tradeUint_, amount_);

        // calculate fee for receipt (already paid but for reference)
        uint256 axiymFee = (amount_ * trade_.axiymFee) / trade_.initialPayoutSize;

        // provide fee does not exist for on-ramp
        uint256 providerFee = 0;

        // create trade payment recipt
        TradePaymentReceipt memory tradePayment = TradePaymentReceipt({
            clientPayout: amount_,
            axiymFee: axiymFee,
            otherFee: providerFee,
            timestamp: block.timestamp
        });

        // update trade registry
        _updateRegistry(tradeUint_, tradePayment, amount_);

        // ensure company account still exists and is active
        if (!_companyAccounts[trade_.companyAccount]) revert NotCompanyAccount();
        if (
            _companyAccountStatuses[trade_.companyAccount] !=
            CompanyAccountStatus.Active
        ) revert InvalidStatus();

        // safeTransfer onAsset payout to company account
        _onAsset.safeTransfer(trade_.companyAccount, amount_);

        emit TradePayment(
            _tradesUintToBytes[tradeUint_], // trade ID (bytes32 form, external reference)
            tradeUint_, // trade ID (uint form, internal reference)
            trade_.companyAccount, // company account receiving the payout
            address(_onAsset), // asset used for this payment
            amount_, // gross amount processed for this payment
            amount_, // net amount paid to the company (no fees deducted)
            axiymFee, // Axiym fee charged for this payment slice (already paid elsewhere)
            0, // provider fee (not applicable for on-trade)
            block.timestamp // timestamp of execution
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
    /// @param nonce_ Nonce used for authorization signature
    /// @param signature_ Signature authorizing the spender
    function _pullFundsAndApprove(
        address companyAccount_,
        uint256 sellAssetQuoteAmount_,
        uint256 axiymFee_,
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
        _offAsset.safeTransfer(_feeCompanyAccount, axiymFee_);
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
}
