// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {MockRDAT} from "../../src/mocks/MockRDAT.sol";

contract MockRDATTest is Test {
    MockRDAT public mockRDAT;
    address public owner;
    address public admin;
    address public user1;
    address public user2;
    address public blockedUser;
    
    // Base mainnet RDAT constants for verification
    address constant BASE_MAINNET_RDAT = 0x4498cd8Ba045E00673402353f5a4347562707e7D;
    uint256 constant TOTAL_SUPPLY = 30_000_000 * 10**18; // 30 million tokens
    
    function setUp() public {
        owner = makeAddr("owner");
        admin = makeAddr("admin");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        blockedUser = makeAddr("blockedUser");
        
        // Deploy mock RDAT with owner
        vm.prank(owner);
        mockRDAT = new MockRDAT(owner);
    }
    
    function test_InitialState() public {
        // Verify it matches Base mainnet RDAT properties
        assertEq(mockRDAT.name(), "RData");
        assertEq(mockRDAT.symbol(), "RDAT");
        assertEq(mockRDAT.decimals(), 18);
        assertEq(mockRDAT.totalSupply(), TOTAL_SUPPLY);
        assertEq(mockRDAT.balanceOf(owner), TOTAL_SUPPLY);
        assertEq(mockRDAT.owner(), owner);
        assertEq(mockRDAT.admin(), address(0)); // Admin not set initially
        assertFalse(mockRDAT.mintBlocked());
    }
    
    function test_Transfer() public {
        uint256 amount = 1000 * 10**18;
        
        // Transfer tokens from owner
        vm.prank(owner);
        assertTrue(mockRDAT.transfer(user1, amount));
        assertEq(mockRDAT.balanceOf(user1), amount);
        assertEq(mockRDAT.balanceOf(owner), TOTAL_SUPPLY - amount);
    }
    
    function test_Approve_TransferFrom() public {
        uint256 amount = 1000 * 10**18;
        
        // Owner approves user1 to spend tokens
        vm.prank(owner);
        assertTrue(mockRDAT.approve(user1, amount));
        assertEq(mockRDAT.allowance(owner, user1), amount);
        
        // User1 transfers tokens from owner to user2
        vm.prank(user1);
        assertTrue(mockRDAT.transferFrom(owner, user2, amount));
        
        assertEq(mockRDAT.balanceOf(user2), amount);
        assertEq(mockRDAT.balanceOf(owner), TOTAL_SUPPLY - amount);
        assertEq(mockRDAT.allowance(owner, user1), 0);
    }
    
    function test_AdminFunctions() public {
        // Owner sets admin
        vm.prank(owner);
        mockRDAT.changeAdmin(admin);
        assertEq(mockRDAT.admin(), admin);
        
        // Transfer some tokens to blockedUser
        vm.prank(owner);
        mockRDAT.transfer(blockedUser, 1000 * 10**18);
        
        // Admin blocks an address
        vm.prank(admin);
        mockRDAT.blockAddress(blockedUser);
        assertEq(mockRDAT.blockListLength(), 1);
        assertEq(mockRDAT.blockListAt(0), blockedUser);
        
        // Blocked user cannot transfer
        vm.prank(blockedUser);
        vm.expectRevert(abi.encodeWithSelector(MockRDAT.UnauthorizedUserAction.selector, blockedUser));
        mockRDAT.transfer(user1, 100 * 10**18);
        
        // Admin unblocks the address
        vm.prank(admin);
        mockRDAT.unblockAddress(blockedUser);
        assertEq(mockRDAT.blockListLength(), 0);
        
        // Now blocked user can transfer
        vm.prank(blockedUser);
        assertTrue(mockRDAT.transfer(user1, 100 * 10**18));
    }
    
    function test_MintBlocking() public {
        // Owner can mint before blocking
        vm.prank(owner);
        mockRDAT.mint(user1, 1000 * 10**18);
        assertEq(mockRDAT.balanceOf(user1), 1000 * 10**18);
        
        // Owner blocks minting
        vm.prank(owner);
        mockRDAT.blockMint();
        assertTrue(mockRDAT.mintBlocked());
        
        // Owner cannot mint after blocking
        vm.prank(owner);
        vm.expectRevert(MockRDAT.EnforceMintBlocked.selector);
        mockRDAT.mint(user2, 1000 * 10**18);
    }
    
    function test_OnlyOwnerFunctions() public {
        // Non-owner cannot mint
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), user1));
        mockRDAT.mint(user2, 1000 * 10**18);
        
        // Non-owner cannot change admin
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), user1));
        mockRDAT.changeAdmin(admin);
        
        // Non-owner cannot block minting
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), user1));
        mockRDAT.blockMint();
    }
    
    function test_OnlyAdminFunctions() public {
        // Set admin first
        vm.prank(owner);
        mockRDAT.changeAdmin(admin);
        
        // Non-admin cannot block addresses
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(MockRDAT.UnauthorizedAdminAction.selector, user1));
        mockRDAT.blockAddress(user2);
        
        // Non-admin cannot unblock addresses
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(MockRDAT.UnauthorizedAdminAction.selector, user1));
        mockRDAT.unblockAddress(user2);
    }
    
    function test_Permit() public {
        uint256 privateKey = 0xBEEF;
        address permitOwner = vm.addr(privateKey);
        uint256 amount = 1000 * 10**18;
        uint256 deadline = block.timestamp + 1 hours;
        
        // Give permitOwner some tokens
        vm.prank(owner);
        mockRDAT.transfer(permitOwner, amount);
        
        // Create permit signature
        bytes32 permitHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                mockRDAT.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        permitOwner,
                        user1,
                        amount,
                        mockRDAT.nonces(permitOwner),
                        deadline
                    )
                )
            )
        );
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, permitHash);
        
        // Execute permit
        mockRDAT.permit(permitOwner, user1, amount, deadline, v, r, s);
        
        assertEq(mockRDAT.allowance(permitOwner, user1), amount);
    }
    
    function test_Votes() public {
        // Owner delegates to themselves
        vm.prank(owner);
        mockRDAT.delegate(owner);
        
        assertEq(mockRDAT.getVotes(owner), TOTAL_SUPPLY);
        
        // Transfer some tokens
        vm.prank(owner);
        mockRDAT.transfer(user1, 1000 * 10**18);
        
        // Check votes updated
        assertEq(mockRDAT.getVotes(owner), TOTAL_SUPPLY - 1000 * 10**18);
        
        // User1 delegates to user2
        vm.prank(user1);
        mockRDAT.delegate(user2);
        
        assertEq(mockRDAT.getVotes(user2), 1000 * 10**18);
    }
    
    function test_MigrationScenario() public {
        // Simulate a migration scenario
        uint256 migrationAmount = 100_000 * 10**18;
        
        // 1. Owner distributes tokens to users (simulating existing holders)
        vm.startPrank(owner);
        mockRDAT.transfer(user1, migrationAmount);
        mockRDAT.transfer(user2, migrationAmount * 2);
        vm.stopPrank();
        
        // 2. Users would approve migration contract (not deployed in this test)
        address migrationContract = makeAddr("migration");
        
        vm.prank(user1);
        mockRDAT.approve(migrationContract, migrationAmount);
        
        vm.prank(user2);
        mockRDAT.approve(migrationContract, migrationAmount * 2);
        
        // 3. Verify approvals are set correctly
        assertEq(mockRDAT.allowance(user1, migrationContract), migrationAmount);
        assertEq(mockRDAT.allowance(user2, migrationContract), migrationAmount * 2);
        
        console2.log("Migration scenario setup complete");
        console2.log("User1 balance:", mockRDAT.balanceOf(user1));
        console2.log("User2 balance:", mockRDAT.balanceOf(user2));
        console2.log("User1 allowance:", mockRDAT.allowance(user1, migrationContract));
        console2.log("User2 allowance:", mockRDAT.allowance(user2, migrationContract));
    }
    
    function testFuzz_Transfer(address to, uint256 amount) public {
        // Skip invalid addresses
        vm.assume(to != address(0));
        vm.assume(to != owner);
        
        // Bound amount to owner's balance
        amount = bound(amount, 0, mockRDAT.balanceOf(owner));
        
        uint256 ownerBalanceBefore = mockRDAT.balanceOf(owner);
        uint256 toBalanceBefore = mockRDAT.balanceOf(to);
        
        // Transfer
        vm.prank(owner);
        assertTrue(mockRDAT.transfer(to, amount));
        
        // Verify balances
        assertEq(mockRDAT.balanceOf(owner), ownerBalanceBefore - amount);
        assertEq(mockRDAT.balanceOf(to), toBalanceBefore + amount);
    }
}