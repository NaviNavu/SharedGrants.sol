// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "forge-std/Test.sol";

contract SharedTestData is Test {
    address internal DEPLOYER = vm.addr(1);
    address internal ERC20_OWNER_1 = vm.addr(2);
    address internal GRANT_RECIPIENT = vm.addr(3);
    address internal DEFAULT_EOA = vm.addr(4);
    uint256 internal DEFAULT_OWNER_1_BALANCE = 10;

    event ERC20TokenAllowed(address indexed tokenAddress);
    event GrantCreated(uint256 indexed grantID, address indexed recipient);
    event GrantOpened(uint256 indexed grantID, uint32 indexed unlockTimestamp);
    event GrantCreatedAndOpened(uint256 indexed grantID, string indexed name, address indexed recipient, uint32 unlockTimestamp);
    event Deposit(uint256 indexed grantID, address indexed from,  address indexed tokenAddress, uint256 tokenAmount);
    event TokenClaimed(uint256 indexed grantID, address indexed tokenAddress, uint256 indexed tokenAmount);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}