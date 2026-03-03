// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.24;

import {ContractVersion} from "../enums/ContractVersion.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IErrors} from "../interfaces/IErrors.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {TradeState} from "../trade/enums/TradeState.sol";
import {Trade} from "../trade/structs/Trade.sol";
import {ISegregatedTreasury} from "./interfaces/ISegregatedTreasury.sol";
import {IOnTradeExchange} from "./interfaces/IOnTradeExchange.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title SegregatedTreasury
/// @notice Treasury contract that holds external assets and facilitates asset swaps with OnTradeExchange
/// @dev Created and managed by OnTradeExchange, executes trades by swapping offAsset for onAsset
contract SegregatedTreasury is
    Pausable,
    ReentrancyGuard,
    IErrors,
    ISegregatedTreasury
{
    using SafeERC20 for IERC20;

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
    address internal _owner;

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
        if (msg.sender != _owner) revert NotOwner();
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
        _owner = owner_;
        _offAsset = IERC20(offAsset_);
        _onAsset = IERC20(onAsset_);
    }

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Pause Controls
    // ════════════════════════════════════════════════════════════════════════════

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

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Owner Management
    // ════════════════════════════════════════════════════════════════════════════

    /// @notice Updates the treasury owner
    /// @param owner_ Address of the new treasury owner
    function setOwner(address owner_) external onlyOwner {
        if (owner_ == address(0)) revert AddressEmpty();
        if (owner_ == _owner) revert OwnerExists();

        address previousOwner = _owner;
        _owner = owner_;

        emit OwnerChanged(previousOwner, owner_);
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
        if (_receiveAddress == address(0)) revert AddressEmpty();

        uint256 bal = _onAsset.balanceOf(address(this));
        if (bal < amount_) revert InsufficientTreasuryBalance();
        _onAsset.safeTransfer(_receiveAddress, amount_);

        emit TreasuryWithdraw(_receiveAddress, address(_onAsset), amount_);
    }

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Trade Execution
    // ════════════════════════════════════════════════════════════════════════════

    /// @notice Executes a trade by swapping offAsset for onAsset approval
    /// @dev Called by OnTradeExchange during trade execution
    /// @param tradeUint_ The trade ID to execute
    /// @param amount_ The amount to swap
    function executeTrade(
        uint256 tradeUint_,
        uint256 amount_
    ) external onlyOnTradeExchange whenNotPaused nonReentrant {
        // verify trade exists and is in pending state, and amount not greater than registered payout
        Trade memory trade = IOnTradeExchange(_onTradeExchange).getTradeData(
            tradeUint_
        );
        if (trade.status != TradeState.Pending) revert InvalidPayoutStatus();
        if (trade.currentPayoutSize < amount_) revert AmountExceedsCurrentPayout();

        // Check enough USDT
        uint256 bal = _onAsset.balanceOf(address(this));
        if (bal < amount_) revert InsufficientTreasuryBalance();

        // pull offAsset (IUSD) from exchange into treasury
        _offAsset.safeTransferFrom(_onTradeExchange, address(this), amount_);

        // Transfer USDT
        _onAsset.safeTransfer(_onTradeExchange, amount_);

        emit TradePayment(tradeUint_, amount_);
    }

    // ════════════════════════════════════════════════════════════════════════════
    // 🟦 Getters
    // ════════════════════════════════════════════════════════════════════════════

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

    /// @notice Returns the current owner of the treasury
    /// @return The owner address
    function owner() external view returns (address) {
        return _owner;
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
