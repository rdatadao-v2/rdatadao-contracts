// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test, Vm} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {BaseMigrationBridge} from "../src/BaseMigrationBridge.sol";
import {MockRDAT} from "../src/mocks/MockRDAT.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BaseMigrationBridgeTest is Test {
    BaseMigrationBridge public bridge;
    MockRDAT public v1Token;
    
    address public admin = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    
    uint256 public constant INITIAL_BALANCE = 10_000e18;
    
    event MigrationInitiated(
        bytes32 indexed requestId,
        address indexed user,
        uint256 amount,
        bytes32 burnTxHash
    );
    event TokensBurned(address indexed user, uint256 amount, bytes32 indexed burnTxHash);
    
    function setUp() public {
        // Deploy V1 token
        v1Token = new MockRDAT(admin);
        
        // Deploy bridge
        bridge = new BaseMigrationBridge(address(v1Token), admin);
        
        // Setup test users
        vm.startPrank(admin);
        v1Token.mint(user1, INITIAL_BALANCE);
        v1Token.mint(user2, INITIAL_BALANCE);
        vm.stopPrank();
    }
    
    function test_InitialState() public view {
        assertEq(address(bridge.v1Token()), address(v1Token));
        assertEq(bridge.totalBurned(), 0);
        assertEq(bridge.userBurnedAmounts(user1), 0);
        assertTrue(bridge.hasRole(bridge.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(bridge.hasRole(bridge.PAUSER_ROLE(), admin));
        assertFalse(bridge.paused());
    }
    
    function test_InitiateMigration() public {
        uint256 migrationAmount = 1000e18;
        
        // Approve bridge
        vm.startPrank(user1);
        v1Token.approve(address(bridge), migrationAmount);
        
        // Check initial state
        uint256 initialBalance = v1Token.balanceOf(user1);
        
        // Initiate migration
        bridge.initiateMigration(migrationAmount);
        vm.stopPrank();
        
        // Verify state changes
        assertEq(v1Token.balanceOf(user1), initialBalance - migrationAmount);
        assertEq(v1Token.balanceOf(address(bridge)), migrationAmount);
        assertEq(bridge.totalBurned(), migrationAmount);
        assertEq(bridge.userBurnedAmounts(user1), migrationAmount);
    }
    
    function test_InitiateMigrationMultipleUsers() public {
        uint256 amount1 = 1000e18;
        uint256 amount2 = 2000e18;
        
        // User 1 migration
        vm.startPrank(user1);
        v1Token.approve(address(bridge), amount1);
        bridge.initiateMigration(amount1);
        vm.stopPrank();
        
        // User 2 migration
        vm.startPrank(user2);
        v1Token.approve(address(bridge), amount2);
        bridge.initiateMigration(amount2);
        vm.stopPrank();
        
        // Verify totals
        assertEq(bridge.totalBurned(), amount1 + amount2);
        assertEq(bridge.userBurnedAmounts(user1), amount1);
        assertEq(bridge.userBurnedAmounts(user2), amount2);
    }
    
    function test_InitiateMigrationMultipleTimes() public {
        uint256 amount1 = 1000e18;
        uint256 amount2 = 500e18;
        
        vm.startPrank(user1);
        v1Token.approve(address(bridge), amount1 + amount2);
        
        // First migration
        bridge.initiateMigration(amount1);
        assertEq(bridge.userBurnedAmounts(user1), amount1);
        
        // Second migration
        bridge.initiateMigration(amount2);
        assertEq(bridge.userBurnedAmounts(user1), amount1 + amount2);
        
        vm.stopPrank();
    }
    
    function test_RevertInitiateMigrationZeroAmount() public {
        vm.startPrank(user1);
        vm.expectRevert(BaseMigrationBridge.ZeroAmount.selector);
        bridge.initiateMigration(0);
        vm.stopPrank();
    }
    
    function test_RevertInitiateMigrationInsufficientBalance() public {
        vm.startPrank(user1);
        v1Token.approve(address(bridge), type(uint256).max);
        
        vm.expectRevert(BaseMigrationBridge.InsufficientBalance.selector);
        bridge.initiateMigration(INITIAL_BALANCE + 1);
        vm.stopPrank();
    }
    
    function test_RevertInitiateMigrationAfterDeadline() public {
        // Warp past deadline
        vm.warp(block.timestamp + 366 days);
        
        vm.startPrank(user1);
        v1Token.approve(address(bridge), 1000e18);
        
        vm.expectRevert(BaseMigrationBridge.MigrationDeadlinePassed.selector);
        bridge.initiateMigration(1000e18);
        vm.stopPrank();
    }
    
    function test_PauseUnpause() public {
        // Pause
        vm.prank(admin);
        bridge.pause();
        assertTrue(bridge.paused());
        
        // Cannot migrate when paused
        vm.startPrank(user1);
        v1Token.approve(address(bridge), 1000e18);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        bridge.initiateMigration(1000e18);
        vm.stopPrank();
        
        // Unpause
        vm.prank(admin);
        bridge.unpause();
        assertFalse(bridge.paused());
        
        // Can migrate again
        vm.startPrank(user1);
        bridge.initiateMigration(1000e18);
        vm.stopPrank();
    }
    
    function test_RescueTokensAfterDeadline() public {
        // Send some tokens to bridge
        vm.startPrank(user1);
        v1Token.approve(address(bridge), 1000e18);
        bridge.initiateMigration(1000e18);
        vm.stopPrank();
        
        // Also send some other tokens by mistake
        MockRDAT otherToken = new MockRDAT(admin);
        vm.prank(admin);
        otherToken.mint(address(bridge), 500e18);
        
        // Cannot rescue before deadline
        vm.prank(admin);
        vm.expectRevert("Migration still active");
        bridge.rescueTokens(address(v1Token), admin, 100e18);
        
        // Warp past deadline
        vm.warp(block.timestamp + 366 days);
        
        // Now can rescue
        vm.startPrank(admin);
        
        // Rescue V1 tokens
        uint256 v1Balance = v1Token.balanceOf(address(bridge));
        uint256 adminBalanceBefore = v1Token.balanceOf(admin);
        bridge.rescueTokens(address(v1Token), admin, v1Balance);
        assertEq(v1Token.balanceOf(admin), adminBalanceBefore + v1Balance);
        
        // Rescue other tokens
        uint256 otherBalanceBefore = otherToken.balanceOf(admin);
        bridge.rescueTokens(address(otherToken), admin, 500e18);
        assertEq(otherToken.balanceOf(admin), otherBalanceBefore + 500e18);
        
        vm.stopPrank();
    }
    
    function test_GetUserMigrationInfo() public {
        uint256 migrationAmount = 1000e18;
        
        // Before migration
        (uint256 burned, uint256 remaining) = bridge.getUserMigrationInfo(user1);
        assertEq(burned, 0);
        assertEq(remaining, INITIAL_BALANCE);
        
        // After migration
        vm.startPrank(user1);
        v1Token.approve(address(bridge), migrationAmount);
        bridge.initiateMigration(migrationAmount);
        vm.stopPrank();
        
        (burned, remaining) = bridge.getUserMigrationInfo(user1);
        assertEq(burned, migrationAmount);
        assertEq(remaining, INITIAL_BALANCE - migrationAmount);
    }
    
    function test_MigrationDeadlineHelpers() public {
        // Check not expired
        assertFalse(bridge.isMigrationExpired());
        assertGt(bridge.timeUntilDeadline(), 0);
        
        // Warp to near deadline
        vm.warp(block.timestamp + 364 days);
        assertFalse(bridge.isMigrationExpired());
        assertLt(bridge.timeUntilDeadline(), 2 days);
        
        // Warp past deadline
        vm.warp(block.timestamp + 2 days);
        assertTrue(bridge.isMigrationExpired());
        assertEq(bridge.timeUntilDeadline(), 0);
    }
    
    function test_BurnTxHashUniqueness() public {
        uint256 amount = 1000e18;
        
        vm.startPrank(user1);
        v1Token.approve(address(bridge), amount * 2);
        
        // Record events to check burn hashes
        vm.recordLogs();
        
        // First migration
        bridge.initiateMigration(amount);
        
        // Second migration (same amount, should have different hash)
        bridge.initiateMigration(amount);
        
        Vm.Log[] memory logs = vm.getRecordedLogs();
        vm.stopPrank();
        
        // Extract burn hashes from events
        bytes32 hash1;
        bytes32 hash2;
        uint256 foundCount = 0;
        
        // Find TokensBurned events
        for (uint i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("TokensBurned(address,uint256,bytes32)")) {
                if (foundCount == 0) {
                    hash1 = logs[i].topics[2]; // burnTxHash is indexed
                } else if (foundCount == 1) {
                    hash2 = logs[i].topics[2];
                }
                foundCount++;
            }
        }
        
        // Verify hashes are different
        assertTrue(hash1 != bytes32(0), "First hash should not be zero");
        assertTrue(hash2 != bytes32(0), "Second hash should not be zero");
        assertTrue(hash1 != hash2, "Burn hashes should be unique");
    }
    
    function test_RevertVanaSideFunctions() public {
        // All Vana-side functions should revert
        vm.expectRevert("Not implemented on Base");
        bridge.submitValidation(user1, 1000e18, bytes32(0), 1);
        
        vm.expectRevert("Not implemented on Base");
        bridge.challengeMigration(bytes32(0));
        
        vm.expectRevert("Not implemented on Base");
        bridge.executeMigration(bytes32(0));
        
        vm.expectRevert("Not implemented on Base");
        bridge.addValidator(user1);
        
        vm.expectRevert("Not implemented on Base");
        bridge.removeValidator(user1);
        
        vm.expectRevert("Not implemented on Base");
        bridge.calculateBonus(1000e18);
    }
}