// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./ifaces/IERC20.sol";
import "./ifaces/ISharedGrants.sol";

/// ☠️ THE FOLLOWING CODE IS NOT BATTLE TESTED! USE IT AT YOUR OWN RISK ☠️

/// @author NaviNavu - https://github.com/NaviNavu
/// @notice This contract allows users to create Grants into which other users can deposit any amount of authorized 
/// ERC20 tokens that can then be claimed by a given beneficiary account when a defined timestamp is reached.
/// Users are given the option to instantly recover their token deposits during the grant period. 
/// At the end of the grant period, further deposits into the Grant are disabled and the Grant tokens are unlocked 
/// for the beneficiary account.
contract SharedGrants is ISharedGrants {
    struct GrantData {
        uint256 id;
        uint32 unlockTimestamp;
        address owner;
        address recipient;
        string name;
        GrantStatus status;
    }

    address public s_owner;
    uint256 s_grantIDsCounter;

    /// @notice Holds the Grants Data.
    /// @dev s_grants[grantID] => GrantData
    mapping(uint256 => GrantData) public s_grants;

    /// @notice Holds all Grants token balances.
    /// @dev s_grantBalances[grantID][tokenAddress] => amount
    mapping(uint256 => mapping(address => uint256)) public s_grantBalances;

    /// @notice Holds all the Users deposits.
    /// @dev s_userDeposits[userAddress][grantID][tokenAddress] => amount
    mapping(address => mapping(uint256 => mapping(address => uint256))) public s_userDeposits;
    
    /// @notice Holds all allowed ERC20 token addresses.
    /// @dev s_allowedGrantTokens[tokenAddress] => bool
    mapping(address => bool) public s_allowedERC20Tokens;
    

    constructor () {
        s_owner = msg.sender;
    }


     //////////////////////////
    /// EXTERNAL FUNCTIONS ///_______________________________________________________


    function allowERC20Token(address _tokenAddress, bool _allowed) external virtual override onlyContractOwner() {
        _allowERC20Token(_tokenAddress, _allowed);
        emit ERC20TokenAllowed(_tokenAddress);
    }


    /// @notice See ISharedGrants.sol
    function createGrant(string calldata _name, address _recipient) external override {
        uint256 grantID = _createGrant(_name, _recipient);
        emit GrantCreated(grantID, _recipient);
    }


    /// @notice See ISharedGrants.sol
    function openGrant(uint256 _grantID, uint32 _unlockTimestamp) external virtual override {
        _openGrant(_grantID, _unlockTimestamp);
        emit GrantOpened(_grantID, _unlockTimestamp);
    }


    /// @notice See ISharedGrants.sol
    function createAndOpenGrant(string calldata _name, address _recipient, uint32 _unlockTimestamp) external virtual override {
        uint256 grantID = _createGrant(_name, _recipient);
        _openGrant(grantID, _unlockTimestamp);
        emit GrantCreatedAndOpened(grantID, _name, _recipient, _unlockTimestamp);
    }


    /// @notice See ISharedGrants.sol
    function depositIntoGrant(
        uint256 _grantID,
        address _from,
        address _tokenAddress,
        uint256 _tokenAmount
    ) external virtual override {
        _depositIntoGrant(_grantID, _from, _tokenAddress, _tokenAmount);
        emit Deposit(_grantID, _from, _tokenAddress, _tokenAmount);
        require(IERC20(_tokenAddress).transferFrom(_from, address(this), _tokenAmount));
    }


    /// @notice See ISharedGrants.sol
    function claimTokenAsRecipient(
        uint256 _grantID,
        address _tokenAddress,
        uint256 _tokenAmount
    ) external virtual override {
        _claimTokenAsRecipient(msg.sender, _grantID, _tokenAddress, _tokenAmount);
        emit TokenClaimed(_grantID, _tokenAddress, _tokenAmount);
        require(IERC20(_tokenAddress).transfer(msg.sender, _tokenAmount));
    }


    /// @notice See ISharedGrants.sol
    function claimTokenAsDepositor(
        uint256 _grantID,
        address _tokenAddress,
        uint256 _tokenAmount
    ) external virtual override {
        _claimTokenAsDepositor(msg.sender, _grantID, _tokenAddress, _tokenAmount);
        emit TokenClaimed(_grantID, _tokenAddress, _tokenAmount);
        require(IERC20(_tokenAddress).transfer(msg.sender, _tokenAmount));
    }


    /// @notice See ISharedGrants.sol
    function updateContractOwner(address _newOwner) external override onlyContractOwner() {
        s_owner = _newOwner;
    }


     //////////////////////////
    /// INTERNAL FUNCTIONS ///_______________________________________________________

    function _allowERC20Token(address _tokenAddress, bool _allowed) internal virtual {
        if (_tokenAddress.code.length == 0) revert NotAContract(_tokenAddress);
        s_allowedERC20Tokens[_tokenAddress] = _allowed;
    }


    function _createGrant(string calldata _name, address _recipient) internal virtual returns (uint256) {
        if (_recipient == address(0) || _recipient == address(this)) 
            revert InvalidRecipient(_recipient);

        uint256 grantID;

        unchecked {
            grantID = ++s_grantIDsCounter;
        }

        s_grants[grantID] = GrantData({
            id: grantID,
            unlockTimestamp: 0,
            recipient: _recipient,
            owner: msg.sender,
            name: _name,
            status: GrantStatus.INACTIVE
        });

        return grantID;
    }


    function _openGrant(uint256 _grantID, uint32 _unlockTimestamp) internal virtual {
        if (_unlockTimestamp == 0 || _unlockTimestamp <= block.timestamp) 
            revert InvalidUnlockTimestamp(_unlockTimestamp);

        GrantData storage grant = s_grants[_grantID];
        
        if (grant.id == 0)
            revert UnknownGrant(_grantID);
        else if (grant.owner != msg.sender)
            revert NotGrantOwner(msg.sender);
        else if (grant.status == GrantStatus.ACTIVE)
            revert GrantIsAlreadyOpen(_grantID);
       
        grant.unlockTimestamp = _unlockTimestamp;
        grant.status = GrantStatus.ACTIVE;
    }


    function _depositIntoGrant(
        uint256 _grantID,
        address _from,
        address _tokenAddress,
        uint256 _tokenAmount
    ) internal virtual {
        if (!s_allowedERC20Tokens[_tokenAddress]) 
            revert TokenContractNotAllowed(_tokenAddress);
        
        GrantData storage grant = s_grants[_grantID];
        
        if (grant.id == 0)
            revert UnknownGrant(_grantID);
        else if (grant.status != GrantStatus.ACTIVE)
            revert GrantIsNotOpen(_grantID);
        else if (block.timestamp >= grant.unlockTimestamp)
            revert CannotDepositAfterUnlock(_grantID);
        
        s_grantBalances[_grantID][_tokenAddress] += _tokenAmount;
        s_userDeposits[_from][_grantID][_tokenAddress] += _tokenAmount;
    }


    function _claimTokenAsRecipient(
        address _operator,
        uint256 _grantID,
        address _tokenAddress,
        uint256 _tokenAmount
    ) internal virtual {
        GrantData storage grant = s_grants[_grantID];
        
        if (_operator != grant.recipient)
            revert NotGrantRecipient(_operator);
        else if (grant.status != GrantStatus.ACTIVE || block.timestamp < grant.unlockTimestamp)
            revert GrantIsNotClaimableByRecipient(_grantID, grant.unlockTimestamp);

        uint256 grantTokenAmount = s_grantBalances[_grantID][_tokenAddress];

        if (_tokenAmount > grantTokenAmount || _tokenAmount == 0) 
            revert InvalidTokenAmount(_tokenAddress, _tokenAmount, grantTokenAmount);
        
        unchecked {
            s_grantBalances[_grantID][_tokenAddress] -= _tokenAmount;
        }
    }


    function _claimTokenAsDepositor(
        address _operator,
        uint256 _grantID,
        address _tokenAddress,
        uint256 _tokenAmount
    ) internal virtual {
        GrantData storage grant = s_grants[_grantID];

        if (grant.id == 0)
            revert UnknownGrant(_grantID);
        else if (block.timestamp >= grant.unlockTimestamp)
            revert CannotWithdrawAfterUnlock(_grantID);
        
        uint256 userTokenDeposit = s_userDeposits[_operator][_grantID][_tokenAddress];

        if (_tokenAmount > userTokenDeposit || _tokenAmount == 0) 
            revert InvalidTokenAmount(_tokenAddress, _tokenAmount, userTokenDeposit);
        
        unchecked {
            s_grantBalances[_grantID][_tokenAddress] -= _tokenAmount;
            s_userDeposits[_operator][_grantID][_tokenAddress] -= _tokenAmount;
        }
    }


     /////////////////////////
    /// ACCESS MODIFIERS  ///_______________________________________________________

    modifier onlyContractOwner() {
        if (msg.sender != s_owner) revert NotContractOwner(msg.sender);
        _;
    }
}