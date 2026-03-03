// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.24;

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

    error Initialized();
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
}
