// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.7;

import "./utils/SharedTestData.sol";
import "./utils/ERC20Token.sol";
import "src/SharedGrants.sol";
import "src/ifaces/ISharedGrants.sol";


contract SharedGrantsTest is SharedTestData {
    address internal erc20_addr;
    address internal grant_addr;

    function setUp() public {
        vm.startPrank(DEPLOYER);

        /// Deploys the ERC20 contract as DEPLOYER and get deploy address
        erc20_addr = address(new ERC20Token());
        // Deploy a Grant contract as DEPLOYER and get deploy address
        grant_addr = address(new SharedGrants());
        // Mints DEFAULT_OWNER_1_BALANCE token amount to ERC20_OWNER_1 as DEPLOYER
        ERC20Token(erc20_addr).mint(ERC20_OWNER_1, DEFAULT_OWNER_1_BALANCE);
      
        vm.stopPrank();
    }

    function test_deployerIsOwner() public {
        address owner = SharedGrants(grant_addr).s_owner();
        assertEq(owner, DEPLOYER);
    }

    function test_updateContractOwner() public {
        vm.prank(DEPLOYER);
        SharedGrants(grant_addr).updateContractOwner(DEFAULT_EOA);
        
        address owner = SharedGrants(grant_addr).s_owner();
        assertEq(owner, DEFAULT_EOA);
    }

    function test_allowERC20Token() public {
        vm.expectEmit(true, false, false, false);
        emit ERC20TokenAllowed(erc20_addr);

        vm.prank(DEPLOYER);
        SharedGrants(grant_addr).allowERC20Token(erc20_addr, true);

        assertTrue(SharedGrants(grant_addr).s_allowedERC20Tokens(erc20_addr));
    }

    function test_createGrant() public {
        vm.expectEmit(true, true, false, false);
        emit GrantCreated(1, GRANT_RECIPIENT);

        vm.prank(DEFAULT_EOA);
        SharedGrants(grant_addr).createGrant("TEST NAME", GRANT_RECIPIENT);

        (
            uint256 id, 
            uint32 unlockTimestamp,
            address owner,
            address recipient,
            string memory name,
            SharedGrants.GrantStatus status
        ) = SharedGrants(grant_addr).s_grants(1);

        assertEq(id, 1);
        assertEq(unlockTimestamp, uint32(0));
        assertEq(recipient, GRANT_RECIPIENT);
        assertEq(name, "TEST NAME");
        assertEq(owner, DEFAULT_EOA);
        assertEq(uint256(status), uint256(ISharedGrants.GrantStatus.INACTIVE));
    }

    function test_openGrant() public {
        uint256 unlockTime = block.timestamp + 10 days;
        
        vm.expectEmit(true, true, false, false);
        emit GrantOpened(1, uint32(unlockTime));

        vm.startPrank(DEFAULT_EOA);
        SharedGrants(grant_addr).createGrant("TEST NAME", GRANT_RECIPIENT);
        SharedGrants(grant_addr).openGrant(1, uint32(unlockTime));
        vm.stopPrank();

        ( , uint32 unlockTimestamp, , , ,ISharedGrants.GrantStatus status) = SharedGrants(grant_addr).s_grants(1);

        assertEq(uint256(status), uint256(ISharedGrants.GrantStatus.ACTIVE));
        assertEq(uint256(unlockTimestamp), unlockTime);
    }

    function test_createAndOpenGrant() public {
        uint256 unlockTime = block.timestamp + 10 days;
        
        vm.expectEmit(true, true, true, true);
        emit GrantCreatedAndOpened(1, "TEST NAME", GRANT_RECIPIENT, uint32(unlockTime));

        vm.startPrank(DEFAULT_EOA);
        SharedGrants(grant_addr).createAndOpenGrant("TEST NAME", GRANT_RECIPIENT, uint32(unlockTime));
        vm.stopPrank();

        (
            uint256 id, 
            uint32 unlockTimestamp,
            address owner,
            address recipient,
            string memory name,
            ISharedGrants.GrantStatus status
        ) = SharedGrants(grant_addr).s_grants(1);

        assertEq(id, 1);
        assertEq(recipient, GRANT_RECIPIENT);
        assertEq(owner, DEFAULT_EOA);
        assertEq(name, "TEST NAME");
        assertEq(uint256(status), uint256(ISharedGrants.GrantStatus.ACTIVE));
        assertEq(uint256(unlockTimestamp), unlockTime);
    }

    function test_depositIntoGrant() public {
        uint256 amountToTransfer = 5;
        uint256 unlockTime = block.timestamp + 10 days;

        vm.prank(DEPLOYER);
        SharedGrants(grant_addr).allowERC20Token(erc20_addr, true);

        vm.startPrank(DEFAULT_EOA);
        SharedGrants(grant_addr).createGrant("TEST NAME", GRANT_RECIPIENT);
        SharedGrants(grant_addr).openGrant(1, uint32(unlockTime));
        vm.stopPrank();

        vm.prank(ERC20_OWNER_1);
        ERC20Token(erc20_addr).approve(grant_addr, amountToTransfer);

        vm.expectEmit(true, true, true, true);
        emit Deposit(1, ERC20_OWNER_1, erc20_addr, amountToTransfer);

        vm.prank(ERC20_OWNER_1);
        SharedGrants(grant_addr).depositIntoGrant(1, ERC20_OWNER_1, erc20_addr, amountToTransfer);

        uint256 grantTokenAmount = SharedGrants(grant_addr).s_grantBalances(1, erc20_addr);
        uint256 userDepositTokenAmount = SharedGrants(grant_addr).s_userDeposits(ERC20_OWNER_1, 1, erc20_addr);

        assertEq(grantTokenAmount, amountToTransfer);
        assertEq(userDepositTokenAmount, amountToTransfer);
    }

    function test_claimTokenAsRecipient() public {
        uint256 amountToTransfer = 5;
        uint256 unlockTime = block.timestamp + 10 days;

        vm.startPrank(DEPLOYER);
        SharedGrants(grant_addr).allowERC20Token(erc20_addr, true);
        SharedGrants(grant_addr).createGrant("TEST NAME", GRANT_RECIPIENT);
        SharedGrants(grant_addr).openGrant(1, uint32(unlockTime));
        vm.stopPrank();

        vm.startPrank(ERC20_OWNER_1);
        ERC20Token(erc20_addr).approve(grant_addr, amountToTransfer);
        SharedGrants(grant_addr).depositIntoGrant(1, ERC20_OWNER_1, erc20_addr, amountToTransfer);
        vm.stopPrank();

        vm.expectEmit(true, true, true, false);
        emit TokenClaimed(1, erc20_addr, amountToTransfer);
        
        vm.warp(unlockTime);
        vm.prank(GRANT_RECIPIENT);
        SharedGrants(grant_addr).claimTokenAsRecipient(1, erc20_addr, amountToTransfer);

        uint256 grantRecipientBalance = ERC20Token(erc20_addr).balanceOf(GRANT_RECIPIENT);
        uint256 grantTokenAmount = SharedGrants(grant_addr).s_grantBalances(1, erc20_addr);
        uint256 userDepositTokenAmount = SharedGrants(grant_addr).s_userDeposits(ERC20_OWNER_1, 1, erc20_addr);

        assertEq(grantRecipientBalance, amountToTransfer);
        assertEq(grantTokenAmount, 0);
        assertEq(userDepositTokenAmount, amountToTransfer); // Keeps history of user deposit
    }

    function test_claimTokenAsDepositor() public {
        uint256 amountToTransfer = 5;
        uint256 unlockTime = block.timestamp + 10 days;

        vm.prank(DEPLOYER);
        SharedGrants(grant_addr).allowERC20Token(erc20_addr, true);
       
        vm.startPrank(DEFAULT_EOA);
        SharedGrants(grant_addr).createGrant("TEST NAME", GRANT_RECIPIENT);
        SharedGrants(grant_addr).openGrant(1, uint32(unlockTime));
        vm.stopPrank();

        vm.startPrank(ERC20_OWNER_1);
        ERC20Token(erc20_addr).approve(grant_addr, amountToTransfer);
        SharedGrants(grant_addr).depositIntoGrant(1, ERC20_OWNER_1, erc20_addr, amountToTransfer);
        vm.stopPrank();

        vm.expectEmit(true, true, true, false);
        emit TokenClaimed(1, erc20_addr, amountToTransfer);

        vm.prank(ERC20_OWNER_1);
        SharedGrants(grant_addr).claimTokenAsDepositor(1, erc20_addr, amountToTransfer);

        uint256 grantTokenAmount = SharedGrants(grant_addr).s_grantBalances(1, erc20_addr);
        uint256 userDepositTokenAmount = SharedGrants(grant_addr).s_userDeposits(ERC20_OWNER_1, 1, erc20_addr);

        assertEq(grantTokenAmount, 0);
        assertEq(userDepositTokenAmount, 0); // Do not keep history of user deposit
    }
}