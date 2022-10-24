// SPDX-License-Identifier: UNLICENCED
pragma solidity ^0.8.7;

import "src/SharedGrants.sol";
import "src/ifaces/ISharedGrants.sol";
import "./utils/SharedTestData.sol";
import "./utils/ERC20Token.sol";

contract SharedGrantsRevertTests is SharedTestData {
    address internal erc20_addr;
    address internal grant_addr;
    ERC20Token internal erc20_contract;
    SharedGrants internal grant_contract;
    
    function setUp() public {
        vm.startPrank(DEPLOYER);
        /// Deploys the ERC20 contract and get address
        erc20_addr = address(new ERC20Token());
        // Deploy a Grant Contract and get address
        grant_addr = address(new SharedGrants());
        // Mints DEFAULT_OWNER_1_BALANCE token amount to ERC20_OWNER_1
        ERC20Token(erc20_addr).mint(ERC20_OWNER_1, DEFAULT_OWNER_1_BALANCE);
        vm.stopPrank();
    }

    function test_updateOwner_RevertNotContractOwner() public {
        vm.expectRevert(
            abi.encodeWithSelector(ISharedGrants.NotContractOwner.selector, DEFAULT_EOA)
        );

        vm.prank(DEFAULT_EOA);
        SharedGrants(grant_addr).updateContractOwner(DEFAULT_EOA);
    }

    function test_allowERC20Token_RevertNotContractOwner() public {
        vm.expectRevert(
            abi.encodeWithSelector(ISharedGrants.NotContractOwner.selector, DEFAULT_EOA)
        );

        vm.prank(DEFAULT_EOA);
        SharedGrants(grant_addr).allowERC20Token(erc20_addr, true);
    }

    function test_allowERC20Token_RevertNotAContract() public {
        vm.expectRevert(
            abi.encodeWithSelector(ISharedGrants.NotAContract.selector, DEFAULT_EOA)
        );

        vm.prank(DEPLOYER);
        SharedGrants(grant_addr).allowERC20Token(DEFAULT_EOA, true);
    }

    function test_createGrant_RevertInvalidRecipient() public {
        vm.expectRevert(
            abi.encodeWithSelector(ISharedGrants.InvalidRecipient.selector, address(0))
        );

        vm.prank(DEFAULT_EOA);
        SharedGrants(grant_addr).createGrant("TEST NAME", address(0));

        vm.expectRevert(
            abi.encodeWithSelector(ISharedGrants.InvalidRecipient.selector, grant_addr)
        );

        vm.prank(DEFAULT_EOA);
        SharedGrants(grant_addr).createGrant("TEST NAME", grant_addr);
    }

    function test_openGrant_RevertNotGrantOwner() public {
        uint256 unlockTimestamp = block.timestamp + 10 days;

        vm.prank(DEFAULT_EOA);
        SharedGrants(grant_addr).createGrant("TEST NAME", GRANT_RECIPIENT);

        vm.expectRevert(
            abi.encodeWithSelector(ISharedGrants.NotGrantOwner.selector, ERC20_OWNER_1)
        );

        vm.prank(ERC20_OWNER_1);
        SharedGrants(grant_addr).openGrant(1, uint32(unlockTimestamp));
    }

    function test_openGrant_RevertInvalidUnlockTimestamp() public {
        vm.warp(block.timestamp + 10 days);

        uint256 unlockTimestampInPast = block.timestamp - 1 days;
        
        vm.prank(DEFAULT_EOA);
        SharedGrants(grant_addr).createGrant("TEST NAME", GRANT_RECIPIENT);

        vm.expectRevert(
            abi.encodeWithSelector(ISharedGrants.InvalidUnlockTimestamp.selector, uint32(unlockTimestampInPast))
        );

        vm.prank(DEFAULT_EOA);
        SharedGrants(grant_addr).openGrant(1, uint32(unlockTimestampInPast));

        vm.expectRevert(
            abi.encodeWithSelector(ISharedGrants.InvalidUnlockTimestamp.selector, uint32(0))
        );

        vm.prank(DEFAULT_EOA);
        SharedGrants(grant_addr).openGrant(1, uint32(0));
    }

    function test_depositIntoGrant_RevertTokenContractNotAllowed() public {
        uint256 unlockTimestamp = block.timestamp + 10 days;
        uint256 amountToTransfer = 5;
        
        vm.startPrank(DEFAULT_EOA);
        SharedGrants(grant_addr).createGrant("TEST NAME", GRANT_RECIPIENT);
        SharedGrants(grant_addr).openGrant(1, uint32(unlockTimestamp));
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(ISharedGrants.TokenContractNotAllowed.selector, erc20_addr)
        );

        vm.prank(ERC20_OWNER_1);
        SharedGrants(grant_addr).depositIntoGrant(1, ERC20_OWNER_1, erc20_addr, amountToTransfer);
    }

    function test_depositIntoGrant_RevertUnknownGrant() public {
        uint256 unlockTimestamp = block.timestamp + 10 days;
        uint256 amountToTransfer = 5;

        vm.prank(DEPLOYER);
        SharedGrants(grant_addr).allowERC20Token(erc20_addr, true);

        vm.startPrank(DEFAULT_EOA);
        SharedGrants(grant_addr).createGrant("TEST NAME", GRANT_RECIPIENT);
        SharedGrants(grant_addr).openGrant(1, uint32(unlockTimestamp));
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(ISharedGrants.UnknownGrant.selector, 1000)
        );

        vm.prank(ERC20_OWNER_1);
        SharedGrants(grant_addr).depositIntoGrant(1000, ERC20_OWNER_1, erc20_addr, amountToTransfer);
    }

    function test_depositIntoGrant_RevertGrantIsNotOpen() public {
        uint256 amountToTransfer = 5;
        vm.prank(DEPLOYER);
        SharedGrants(grant_addr).allowERC20Token(erc20_addr, true);

        vm.prank(DEFAULT_EOA);
        SharedGrants(grant_addr).createGrant("TEST NAME", GRANT_RECIPIENT);

        vm.expectRevert(
            abi.encodeWithSelector(ISharedGrants.GrantIsNotOpen.selector, 1)
        );

        vm.prank(ERC20_OWNER_1);
        SharedGrants(grant_addr).depositIntoGrant(1, ERC20_OWNER_1, erc20_addr, amountToTransfer);
    }

    function test_depositIntoGrant_RevertCannotDepositAfterUnlock() public {
        uint256 unlockTimestamp = block.timestamp + 10 days;
        uint256 amountToTransfer = 5;
        
        vm.prank(DEPLOYER);
        SharedGrants(grant_addr).allowERC20Token(erc20_addr, true);

        vm.startPrank(DEFAULT_EOA);
        SharedGrants(grant_addr).createGrant("TEST NAME", GRANT_RECIPIENT);
        SharedGrants(grant_addr).openGrant(1, uint32(unlockTimestamp));
        vm.stopPrank();
        
        vm.expectRevert(
            abi.encodeWithSelector(ISharedGrants.CannotDepositAfterUnlock.selector, 1)
        );

        vm.warp(unlockTimestamp);
        vm.prank(ERC20_OWNER_1);
        SharedGrants(grant_addr).depositIntoGrant(1, ERC20_OWNER_1, erc20_addr, amountToTransfer);
    }

    function test_claimTokenAsRecipient_NotGrantRecipient() public {
        uint256 unlockTimestamp = block.timestamp + 10 days;
        uint256 amountToTransfer = 5;

        vm.prank(DEPLOYER);
        SharedGrants(grant_addr).allowERC20Token(erc20_addr, true);

        vm.startPrank(DEFAULT_EOA);
        SharedGrants(grant_addr).createGrant("TEST NAME", GRANT_RECIPIENT);
        SharedGrants(grant_addr).openGrant(1, uint32(unlockTimestamp));
        vm.stopPrank();

        vm.startPrank(ERC20_OWNER_1);
        ERC20Token(erc20_addr).approve(grant_addr, amountToTransfer);
        SharedGrants(grant_addr).depositIntoGrant(1, ERC20_OWNER_1, erc20_addr, amountToTransfer);
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(ISharedGrants.NotGrantRecipient.selector, DEFAULT_EOA)
        );

        vm.warp(unlockTimestamp);
        vm.prank(DEFAULT_EOA);
        SharedGrants(grant_addr).claimTokenAsRecipient(1, erc20_addr, amountToTransfer);
    }

    function test_claimTokenAsRecipient_RevertGrantNotClaimableByRecipient() public {
        uint256 unlockTimestamp = block.timestamp + 10 days;
        uint256 amountToTransfer = 5;

        vm.prank(DEPLOYER);
        SharedGrants(grant_addr).allowERC20Token(erc20_addr, true);

        vm.startPrank(DEFAULT_EOA);
        SharedGrants(grant_addr).createGrant("TEST NAME", GRANT_RECIPIENT);
        SharedGrants(grant_addr).openGrant(1, uint32(unlockTimestamp));
        vm.stopPrank();

        vm.startPrank(ERC20_OWNER_1);
        ERC20Token(erc20_addr).approve(grant_addr, amountToTransfer);
        SharedGrants(grant_addr).depositIntoGrant(1, ERC20_OWNER_1, erc20_addr, amountToTransfer);
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(ISharedGrants.GrantIsNotClaimableByRecipient.selector, 1, bytes32(unlockTimestamp))
        );
        
        vm.prank(GRANT_RECIPIENT);
        SharedGrants(grant_addr).claimTokenAsRecipient(1, erc20_addr, amountToTransfer);
    }

    function test_claimTokenAsRecipient_RevertInvalidTokenAmount() public {
        uint256 unlockTimestamp = block.timestamp + 10 days;
        uint256 amountToTransfer = 5;
        uint256 invalidAmountToWithdraw = 1000;

        vm.prank(DEPLOYER);
        SharedGrants(grant_addr).allowERC20Token(erc20_addr, true);

        vm.startPrank(DEFAULT_EOA);
        SharedGrants(grant_addr).createGrant("TEST NAME", GRANT_RECIPIENT);
        SharedGrants(grant_addr).openGrant(1, uint32(unlockTimestamp));
        vm.stopPrank();

        vm.startPrank(ERC20_OWNER_1);
        ERC20Token(erc20_addr).approve(grant_addr, amountToTransfer);
        SharedGrants(grant_addr).depositIntoGrant(1, ERC20_OWNER_1, erc20_addr, amountToTransfer);
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(ISharedGrants.InvalidTokenAmount.selector, erc20_addr, invalidAmountToWithdraw, amountToTransfer)
        );
        
        vm.warp(unlockTimestamp);
        vm.prank(GRANT_RECIPIENT);
        SharedGrants(grant_addr).claimTokenAsRecipient(1, erc20_addr, invalidAmountToWithdraw);
    }

    function test_claimTokenAsDepositor_RevertCannotWithdrawAfterUnlock() public {
        uint256 unlockTimestamp = block.timestamp + 10 days;
        uint256 wrongUnlockTimestamp = block.timestamp + 11 days;
        uint256 amountToTransfer = 5;
        uint256 amountToWithdraw = amountToTransfer;

        vm.prank(DEPLOYER);
        SharedGrants(grant_addr).allowERC20Token(erc20_addr, true);

        vm.startPrank(DEFAULT_EOA);
        SharedGrants(grant_addr).createGrant("TEST NAME", GRANT_RECIPIENT);
        SharedGrants(grant_addr).openGrant(1, uint32(unlockTimestamp));
        vm.stopPrank();

        vm.startPrank(ERC20_OWNER_1);
        ERC20Token(erc20_addr).approve(grant_addr, amountToTransfer);
        SharedGrants(grant_addr).depositIntoGrant(1, ERC20_OWNER_1, erc20_addr, amountToTransfer);
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(ISharedGrants.CannotWithdrawAfterUnlock.selector, 1)
        );

        vm.warp(wrongUnlockTimestamp);
        vm.startPrank(ERC20_OWNER_1);
        SharedGrants(grant_addr).claimTokenAsDepositor(1, erc20_addr, amountToWithdraw);
    }

    function test_claimTokenAsDepositor_RevertInvalidTokenAmount() public {
        uint256 unlockTimestamp = block.timestamp + 10 days;
        uint256 amountToTransfer = 5;
        uint256 invalidAmountToWithdraw = 1000;

        vm.prank(DEPLOYER);
        SharedGrants(grant_addr).allowERC20Token(erc20_addr, true);

        vm.startPrank(DEFAULT_EOA);
        SharedGrants(grant_addr).createGrant("TEST NAME", GRANT_RECIPIENT);
        SharedGrants(grant_addr).openGrant(1, uint32(unlockTimestamp));
        vm.stopPrank();

        vm.startPrank(ERC20_OWNER_1);
        ERC20Token(erc20_addr).approve(grant_addr, amountToTransfer);
        SharedGrants(grant_addr).depositIntoGrant(1, ERC20_OWNER_1, erc20_addr, amountToTransfer);
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(ISharedGrants.InvalidTokenAmount.selector, erc20_addr, invalidAmountToWithdraw, amountToTransfer)
        );
        
        vm.startPrank(ERC20_OWNER_1);
        SharedGrants(grant_addr).claimTokenAsDepositor(1, erc20_addr, invalidAmountToWithdraw);
    }
}