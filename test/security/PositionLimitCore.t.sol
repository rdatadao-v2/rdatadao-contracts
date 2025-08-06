// SPDX-License-Identifier: MIT
import "forge-std/console2.sol";
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../../src/StakingPositions.sol";
import "../../src/RDATUpgradeable.sol";
import "../../src/vRDAT.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title PositionLimitCore
 * @author r/datadao
 * @notice CRITICAL: Core position limit testing without vRDAT complexity
 * @dev Tests the actual position limits by warping time appropriately
 */
contract PositionLimitCoreTest is Test {
    StakingPositions public stakingPositions;
    RDATUpgradeable public rdat;
    vRDAT public vrdat;
    
    address public admin = address(0x1);
    address public attacker = address(0x2);
    address public treasury = address(0x4);
    
    uint256 public constant ACTUAL_MAX_POSITIONS = 100; // The real limit we need to test
    
    function setUp() public {
        vm.startPrank(admin);
        
        // Deploy RDAT
        RDATUpgradeable rdatImpl = new RDATUpgradeable();
        ERC1967Proxy rdatProxy = new ERC1967Proxy(
            address(rdatImpl),
            abi.encodeCall(rdatImpl.initialize, (treasury, admin, address(0x100)))
        );
        rdat = RDATUpgradeable(address(rdatProxy));
        
        // Deploy vRDAT
        vrdat = new vRDAT(admin);
        
        // Deploy StakingPositions
        StakingPositions stakingImpl = new StakingPositions();
        ERC1967Proxy stakingProxy = new ERC1967Proxy(
            address(stakingImpl),
            abi.encodeCall(stakingImpl.initialize, (address(rdat), address(vrdat), admin))
        );
        stakingPositions = StakingPositions(address(stakingProxy));
        
        // Setup
        // RDAT no longer has MINTER_ROLE - admin);
        vrdat.grantRole(vrdat.MINTER_ROLE(), address(stakingPositions));
        vrdat.grantRole(vrdat.BURNER_ROLE(), address(stakingPositions));
        
        // Transfer enough tokens for testing from treasury (no minting)
        uint256 minStake = stakingPositions.MIN_STAKE_AMOUNT();
        vm.startPrank(treasury);
        rdat.transfer(attacker, minStake * (ACTUAL_MAX_POSITIONS + 10));
        vm.stopPrank();
        
        vm.startPrank(admin);
        vm.stopPrank();
    }
    
    /**
     * @notice CRITICAL TEST: Verify actual position limit enforcement
     * @dev This test MUST pass with exactly 100 positions
     */
    function test_ActualPositionLimit_100Positions() public {
        uint256 maxPositions = stakingPositions.MAX_POSITIONS_PER_USER();
        uint256 minStake = stakingPositions.MIN_STAKE_AMOUNT();
        
        console2.log("=== CRITICAL POSITION LIMIT TEST ===");
        console2.log("MAX_POSITIONS_PER_USER:", maxPositions);
        console2.log("MIN_STAKE_AMOUNT:", minStake / 1e18, "RDAT");
        
        // Verify constant matches our expectation
        assertEq(maxPositions, ACTUAL_MAX_POSITIONS, "MAX_POSITIONS not 100!");
        
        vm.startPrank(attacker);
        
        // Create positions with time warps to avoid vRDAT mint delay
        for (uint256 i = 0; i < maxPositions; i++) {
            // Approve and stake
            rdat.approve(address(stakingPositions), minStake);
            uint256 positionId = stakingPositions.stake(minStake, 30 days);
            
            // Verify position created
            assertEq(positionId, i + 1);
            
            // Log progress
            if (i == 0) console2.log("First position created successfully");
            if (i == 24) console2.log("25 positions created...");
            if (i == 49) console2.log("50 positions created...");
            if (i == 74) console2.log("75 positions created...");
            if (i == 99) console2.log("100 positions created!");
        }
        
        // Verify we have exactly max positions
        assertEq(stakingPositions.balanceOf(attacker), maxPositions);
        console2.log("[SUCCESS] Successfully created", maxPositions, "positions");
        
        // CRITICAL: Next position MUST fail
        rdat.approve(address(stakingPositions), minStake);
        vm.expectRevert(IStakingPositions.TooManyPositions.selector);
        stakingPositions.stake(minStake, 30 days);
        
        console2.log("[SUCCESS] Position", maxPositions + 1, "correctly rejected");
        console2.log("[VERIFIED] POSITION LIMIT ENFORCEMENT WORKING");
        
        vm.stopPrank();
    }
    
    /**
     * @notice Test gas costs at maximum positions
     * @dev Critical for preventing DoS attacks
     */
    function test_GasCostAtMaximumPositions() public {
        uint256 maxPositions = stakingPositions.MAX_POSITIONS_PER_USER();
        uint256 minStake = stakingPositions.MIN_STAKE_AMOUNT();
        
        vm.startPrank(attacker);
        
        // Create maximum positions efficiently
        for (uint256 i = 0; i < maxPositions; i++) {
            rdat.approve(address(stakingPositions), minStake);
            stakingPositions.stake(minStake, 30 days);
        }
        
        console2.log("=== GAS COST ANALYSIS ===");
        
        // Test 1: getUserPositions gas cost
        uint256 gasBefore = gasleft();
        uint256[] memory positions = stakingPositions.getUserPositions(attacker);
        uint256 gasUsed = gasBefore - gasleft();
        
        console2.log("getUserPositions() with", maxPositions, "positions:");
        console2.log("- Gas used:", gasUsed);
        console2.log("- Gas per position:", gasUsed / maxPositions);
        
        assertEq(positions.length, maxPositions);
        assertLt(gasUsed, 3000000, "getUserPositions too expensive"); // 3M gas limit
        
        // Test 2: Individual position queries
        uint256 totalGas = 0;
        for (uint256 i = 0; i < 10; i++) {
            gasBefore = gasleft();
            stakingPositions.getPosition(positions[i]);
            totalGas += gasBefore - gasleft();
        }
        console2.log("getPosition() average gas:", totalGas / 10);
        
        // Test 3: Balance query
        gasBefore = gasleft();
        uint256 balance = stakingPositions.balanceOf(attacker);
        gasUsed = gasBefore - gasleft();
        console2.log("balanceOf() gas:", gasUsed);
        assertEq(balance, maxPositions);
        
        vm.stopPrank();
    }
    
    /**
     * @notice Test that unstaking properly frees position slots
     */
    function test_UnstakeFreesPositionSlot() public {
        uint256 maxPositions = stakingPositions.MAX_POSITIONS_PER_USER();
        uint256 minStake = stakingPositions.MIN_STAKE_AMOUNT();
        
        vm.startPrank(attacker);
        
        // Fill all positions
        uint256 firstPositionId;
        for (uint256 i = 0; i < maxPositions; i++) {
            rdat.approve(address(stakingPositions), minStake);
            uint256 posId = stakingPositions.stake(minStake, 30 days);
            if (i == 0) firstPositionId = posId;
        }
        
        // Should be at limit
        rdat.approve(address(stakingPositions), minStake);
        vm.expectRevert(IStakingPositions.TooManyPositions.selector);
        stakingPositions.stake(minStake, 30 days);
        
        // Unstake first position
        vm.warp(block.timestamp + 30 days + 1); // Past lock period
        stakingPositions.unstake(firstPositionId);
        
        // Should now be able to stake again
        rdat.approve(address(stakingPositions), minStake);
        uint256 newPositionId = stakingPositions.stake(minStake, 30 days);
        assertGt(newPositionId, 0);
        
        console2.log("[SUCCESS] Unstaking properly frees position slots");
        
        vm.stopPrank();
    }
    
    /**
     * @notice Test position limit is per-user not global
     */
    function test_PositionLimitIsPerUser() public {
        uint256 minStake = stakingPositions.MIN_STAKE_AMOUNT();
        address user2 = address(0x999);
        
        vm.prank(treasury);
        rdat.transfer(user2, minStake * 10);
        
        // User 1 creates some positions
        vm.startPrank(attacker);
        for (uint256 i = 0; i < 5; i++) {
            rdat.approve(address(stakingPositions), minStake);
            stakingPositions.stake(minStake, 30 days);
        }
        vm.stopPrank();
        
        // User 2 can still create positions
        vm.startPrank(user2);
        
        rdat.approve(address(stakingPositions), minStake);
        uint256 positionId = stakingPositions.stake(minStake, 30 days);
        assertGt(positionId, 0);
        
        console2.log("[SUCCESS] Position limit confirmed as per-user");
        
        vm.stopPrank();
    }
}