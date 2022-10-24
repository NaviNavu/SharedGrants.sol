// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

interface ISharedGrants {
    enum GrantStatus { INACTIVE, ACTIVE }

    error NotContractOwner(address operator);
    error NotGrantOwner(address operator);
    error NotGrantRecipient(address operator);
    error InvalidRecipient(address recipient);
    error InvalidUnlockTimestamp(uint32 unlockTimestamp);
    error UnknownGrant(uint256 grantID);
    error GrantIsNotOpen(uint256 grantID);
    error GrantIsAlreadyOpen(uint256 grantID);
    error GrantIsNotClaimableByRecipient(uint256 grantID, uint32 unlockTimestamp); 
    error CannotDepositAfterUnlock(uint256 grantID);
    error CannotWithdrawAfterUnlock(uint256 grantID);
    error InvalidTokenAmount(address tokenAddress, uint256 requestedTokenAmount, uint256 availableTokenAmount);
    error NotAContract(address target);
    error TokenContractNotAllowed(address tokenAddress);

    event ERC20TokenAllowed(address indexed tokenAddress);
    event GrantCreated(uint256 indexed grantID, address indexed recipient);
    event GrantOpened(uint256 indexed grantID, uint32 indexed unlockTimestamp);
    event GrantCreatedAndOpened(uint256 indexed grantID, string indexed name, address indexed recipient, uint32 unlockTimestamp);
    event Deposit(uint256 indexed grantID, address indexed from, address indexed tokenAddress, uint256 tokenAmount);
    event TokenClaimed(uint256 indexed grantID, address indexed tokenAddress, uint256 indexed tokenAmount);


    /// @notice Allows or disallows an ERC20 token to be deposited into Grants. If an ERC20 allowance is revoked, it is 
    /// still possible to withdraw it from the Grants where the ERC20 is already deposited.
    /// @param tokenAddress The ERC20 token contract to be allowed.
    /// @param allowed A boolean representing the allowance.
    /// @dev MUST revert if:
    ///     - the operator is not the contract owner
    ///     - the address provided has no code
    function allowERC20Token(address tokenAddress, bool allowed) external;


    /// @notice Creates a new Grant with an INACTIVE status and a non-defined unlock time.
    /// @param name The Grant name.
    /// @param recipient The Grant recipient.
    /// @dev MUST revert if:
    ///     - the recipient is address 0 or this contract
    function createGrant(string calldata name, address recipient) external;


    /// @notice Opens a Grant ID for user deposists. The operator must provide an unlock timestamp.
    /// @param grantID The Grant ID to open.
    /// @param unlockTimestamp The unlock time at which the Grant recipient will be able to claim the deposited tokens.
    /// @dev MUST revert if:
    ///     - the operator is not the grant ID owner
    ///     - the unlock timestamp is zero or inferior or equal to block.timestamp
    ///     - the Grant ID is unknown
    ///     - the Grant is already open for deposits (has ACTIVE status)
    function openGrant(uint256 grantID, uint32 unlockTimestamp) external;


    /// @notice Creates a new Grant and sets its status open for deposits.
    /// @param name The Grant name.
    /// @param recipient The Grant recipient. The recipient will be able to claim all tokens deposited into the grant
    /// when the unlock time is reached.
    /// @param unlockTimestamp The unlock time at which the Grant recipient will be able to claim the deposited tokens.
    /// @dev MUST revert if:
    ///     - the recipient is address 0 or this contract
    ///     - the unlock timestamp is zero or inferior or equal to block.timestamp
    function createAndOpenGrant(string calldata name, address recipient, uint32 unlockTimestamp) external;


    /// @notice Deposits an allowed ERC20 token amount into a Grant.
    /// The users can claim back their deposits if the Grant is canceled.
    /// When the Grant unlocks for the Grant recipient to claim its granted tokens,
    /// the deposits are disabled.
    /// @param grantID The Grant ID to deposit tokens to.
    /// @param from The depositor address.
    /// @param tokenAddress The ERC20 token contract address.
    /// @param tokenAmount The ERC20 token amount to deposit into the Grant.
    /// @dev MUST revert if:
    ///     - the ERC20 token is not allowed to be deposited into Grants
    ///     - the Grant status is different than ACTIVE
    ///     - the Grant status is ACTIVE but the unlock timestamp has been reached
    function depositIntoGrant(uint256 grantID, address from, address tokenAddress, uint256 tokenAmount) external;


    /// @notice Claims Grant tokens as Grant recipient when unlock time is reached.
    /// @param grantID The Grant ID to claim tokens from.
    /// @param tokenAddress The ERC20 token contract address.
    /// @param tokenAmount The ERC20 token amount to claim.
    /// @dev MUST revert if:
    ///     - the operator is not the Grant recipient
    ///     - the Grant status is different than ACTIVE
    ///     - the Grant unlock timestamp has not been reached
    ///     - the requested token amount to claim is above the Grant token balance
    function claimTokenAsRecipient(uint256 grantID, address tokenAddress, uint256 tokenAmount) external;


    /// @notice Claims back deposited Grant tokens as depositor when the Grant ID has been canceled.
    /// @param grantID The Grant ID to claim back tokens from.
    /// @param tokenAddress The ERC20 token contract address.
    /// @param tokenAmount The ERC20 token amount to claim.
    /// @dev MUST revert if:
    ///     - the Grant unlock timestamp has been reached
    ///     - the requested token amount to claim is above the user deposit balance
    function claimTokenAsDepositor(uint256 grantID, address tokenAddress, uint256 tokenAmount) external;


    /// @notice Updates the contract ownership.
    /// @param newOwner The new contract owner.
    /// @dev MUST revert if: The operator is not the actual contract owner
    function updateContractOwner(address newOwner) external;
}