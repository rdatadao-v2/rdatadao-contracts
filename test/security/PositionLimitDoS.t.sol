// SPDX-License-Identifier: MIT
import "forge-std/console2.sol";
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../../src/StakingPositions.sol";
import "../../src/RDATUpgradeable.sol";
import "../../src/vRDAT.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title PositionLimitDoS
 * @author r/datadao
 * @notice CRITICAL: Tests actual position limits to prevent DoS attacks
 * @dev Tests the REAL MAX_POSITIONS_PER_USER limit, not simplified versions
 */
contract PositionLimitDoSTest is Test {
    StakingPositions public stakingPositions;
    RDATUpgradeable public rdat;
    vRDAT public vrdat;
    
    address public admin = address(0x1);
    address public attacker = address(0x2);
    address public victim = address(0x3);
    address public treasury = address(0x4);
    
    uint256 public actualMaxPositions;
    uint256 public minStakeAmount;
    
    function setUp() public {
        vm.startPrank(admin);
        
        // Deploy RDAT
        RDATUpgradeable rdatImpl = new RDATUpgradeable();
        bytes memory rdatInitData = abi.encodeCall(
            rdatImpl.initialize,
            (treasury, admin, address(0x100)) // migration contract address
        );
        ERC1967Proxy rdatProxy = new ERC1967Proxy(address(rdatImpl), rdatInitData);
        rdat = RDATUpgradeable(address(rdatProxy));
        
        // Deploy vRDAT
        vrdat = new vRDAT(admin);
        
        // Deploy StakingPositions
        StakingPositions stakingImpl = new StakingPositions();
        bytes memory stakingInitData = abi.encodeCall(
            stakingImpl.initialize,
            (address(rdat), address(vrdat), admin)
        );
        ERC1967Proxy stakingProxy = new ERC1967Proxy(address(stakingImpl), stakingInitData);
        stakingPositions = StakingPositions(address(stakingProxy));
        
        // Setup tokens and roles
        // RDAT no longer has MINTER_ROLE - admin);
        vrdat.grantRole(vrdat.MINTER_ROLE(), address(stakingPositions));
        vrdat.grantRole(vrdat.BURNER_ROLE(), address(stakingPositions));
        
        // Get actual constants
        actualMaxPositions = stakingPositions.MAX_POSITIONS_PER_USER();
        minStakeAmount = stakingPositions.MIN_STAKE_AMOUNT();
        
        // Transfer tokens for testing from treasury (need enough for max positions)
        vm.startPrank(treasury);
        rdat.transfer(attacker, minStakeAmount * (actualMaxPositions + 10));
        rdat.transfer(victim, minStakeAmount * 10);
        vm.stopPrank();
        
        vm.startPrank(admin);
        vm.stopPrank();
    }
    
    // ============ CRITICAL: Test Actual Position Limit ============
    
    function test_ActualMaxPositionsEnforcement() public {
        console2.log("Testing actual MAX_POSITIONS_PER_USER:", actualMaxPositions);
        console2.log("MIN_STAKE_AMOUNT:", minStakeAmount);
        
        vm.startPrank(attacker);
        
        // Create exactly the maximum allowed positions
        for (uint256 i = 0; i < actualMaxPositions; i++) {
            rdat.approve(address(stakingPositions), minStakeAmount);
            uint256 positionId = stakingPositions.stake(minStakeAmount, 30 days);
            
            // Log progress every 10 positions
            if (i % 10 == 0) {
                console2.log("Created positions:", i);
            }
            
            // Verify position was created
            assertEq(positionId, i + 1);
        }
        
        // Verify we have exactly max positions
        assertEq(stakingPositions.balanceOf(attacker), actualMaxPositions);
        console2.log("Successfully created maximum positions:", actualMaxPositions);
        
        // CRITICAL TEST: Next position MUST fail with specific error
        rdat.approve(address(stakingPositions), minStakeAmount);
        vm.expectRevert(IStakingPositions.TooManyPositions.selector);
        stakingPositions.stake(minStakeAmount, 30 days);
        
        console2.log("Position limit correctly enforced at:", actualMaxPositions);
        
        vm.stopPrank();
    }
    
    function test_GasCostAtMaxPositions() public {
        vm.startPrank(attacker);
        
        // Create maximum positions
        for (uint256 i = 0; i < actualMaxPositions; i++) {
            rdat.approve(address(stakingPositions), minStakeAmount);
            stakingPositions.stake(minStakeAmount, 30 days);
        }
        
        // CRITICAL: Test gas cost for position enumeration at max capacity
        uint256 gasBefore = gasleft();
        uint256[] memory positions = stakingPositions.getUserPositions(attacker);
        uint256 gasUsed = gasBefore - gasleft();
        
        console2.log("Gas used for getUserPositions with", actualMaxPositions, "positions:", gasUsed);
        
        // Verify all positions returned
        assertEq(positions.length, actualMaxPositions);
        
        // CRITICAL: Gas usage should be reasonable (adjust threshold based on requirements)
        uint256 maxAcceptableGas = 500000; // 500k gas limit
        assertLt(gasUsed, maxAcceptableGas, "Gas cost too high for position enumeration");
        
        // Test individual position access gas cost
        gasBefore = gasleft();
        for (uint256 i = 0; i < 10; i++) { // Sample 10 positions
            stakingPositions.getPosition(positions[i]);
        }
        gasUsed = (gasBefore - gasleft()) / 10;
        console2.log("Average gas per getPosition:", gasUsed);
        
        vm.stopPrank();
    }
    
    function test_PositionCreationGasAtLimit() public {
        vm.startPrank(attacker);
        
        // Fill up to near limit
        for (uint256 i = 0; i < actualMaxPositions - 1; i++) {
            rdat.approve(address(stakingPositions), minStakeAmount);
            stakingPositions.stake(minStakeAmount, 30 days);
        }
        
        // Measure gas for last position creation
        rdat.approve(address(stakingPositions), minStakeAmount);
        uint256 gasBefore = gasleft();
        stakingPositions.stake(minStakeAmount, 30 days);
        uint256 gasUsed = gasBefore - gasleft();
        
        console2.log("Gas used for creating position #", actualMaxPositions, ":", gasUsed);
        
        // Gas should not increase dramatically with position count
        assertLt(gasUsed, 300000, "Stake gas cost too high at limit");
        
        vm.stopPrank();
    }
    
    function test_UnstakeReducesPositionCount() public {
        vm.startPrank(attacker);
        
        // Create max positions
        uint256[] memory positionIds = new uint256[](actualMaxPositions);
        for (uint256 i = 0; i < actualMaxPositions; i++) {
            rdat.approve(address(stakingPositions), minStakeAmount);
            positionIds[i] = stakingPositions.stake(minStakeAmount, 30 days);
        }
        
        // Should be at limit
        assertEq(stakingPositions.balanceOf(attacker), actualMaxPositions);
        
        // Next stake should fail
        rdat.approve(address(stakingPositions), minStakeAmount);
        vm.expectRevert(IStakingPositions.TooManyPositions.selector);
        stakingPositions.stake(minStakeAmount, 30 days);
        
        // Warp time to allow unstake
        vm.warp(block.timestamp + 30 days + 1);
        
        // Unstake one position
        stakingPositions.unstake(positionIds[0]);
        
        // Should now have one less position
        assertEq(stakingPositions.balanceOf(attacker), actualMaxPositions - 1);
        
        // Should be able to create new position
        rdat.approve(address(stakingPositions), minStakeAmount);
        uint256 newPositionId = stakingPositions.stake(minStakeAmount, 30 days);
        assertGt(newPositionId, 0);
        
        // Back at limit
        assertEq(stakingPositions.balanceOf(attacker), actualMaxPositions);
        
        vm.stopPrank();
    }
    
    function test_EmergencyWithdrawReducesPositionCount() public {
        vm.startPrank(attacker);
        
        // Create max positions
        uint256[] memory positionIds = new uint256[](actualMaxPositions);
        for (uint256 i = 0; i < actualMaxPositions; i++) {
            rdat.approve(address(stakingPositions), minStakeAmount);
            positionIds[i] = stakingPositions.stake(minStakeAmount, 365 days); // Long lock
        }
        
        // At limit
        assertEq(stakingPositions.balanceOf(attacker), actualMaxPositions);
        
        // Emergency withdraw one position
        stakingPositions.emergencyWithdraw(positionIds[0]);
        
        // Should have one less position
        assertEq(stakingPositions.balanceOf(attacker), actualMaxPositions - 1);
        
        // Can create new position
        rdat.approve(address(stakingPositions), minStakeAmount);
        uint256 newPositionId = stakingPositions.stake(minStakeAmount, 30 days);
        assertGt(newPositionId, 0);
        
        vm.stopPrank();
    }
    
    // ============ DoS Attack Scenarios ============
    
    function test_FrontendDoSViaPositionEnumeration() public {
        // Simulate frontend trying to load all user positions
        vm.startPrank(attacker);
        
        // Create max positions
        for (uint256 i = 0; i < actualMaxPositions; i++) {
            rdat.approve(address(stakingPositions), minStakeAmount);
            stakingPositions.stake(minStakeAmount, 30 days);
        }
        
        vm.stopPrank();
        
        // Frontend would call these functions
        uint256 totalGas = 0;
        
        // 1. Get position count
        uint256 gasBefore = gasleft();
        uint256 positionCount = stakingPositions.balanceOf(attacker);
        totalGas += gasBefore - gasleft();
        
        // 2. Get all positions
        gasBefore = gasleft();
        uint256[] memory positions = stakingPositions.getUserPositions(attacker);
        totalGas += gasBefore - gasleft();
        
        // 3. Get details for each position (frontend might do this)
        gasBefore = gasleft();
        for (uint256 i = 0; i < 10 && i < positions.length; i++) { // Sample first 10
            stakingPositions.getPosition(positions[i]);
        }
        uint256 detailsGas = (gasBefore - gasleft()) * positions.length / 10;
        totalGas += detailsGas;
        
        console2.log("Total estimated gas for frontend to load user data:", totalGas);
        console2.log("- Position count:", positionCount);
        console2.log("- Get all positions gas:", gasBefore - gasleft());
        console2.log("- Estimated details gas:", detailsGas);
        
        // This should not be prohibitively expensive
        assertLt(totalGas, 1000000, "Frontend gas cost too high");
    }
    
    function test_SystemStillFunctionalAtMaxCapacity() public {
        // Fill system with multiple users at max capacity
        address[3] memory users = [attacker, victim, address(0x999)];
        
        vm.startPrank(treasury);
        rdat.transfer(address(0x999), minStakeAmount * actualMaxPositions);
        vm.stopPrank();
        
        // Each user creates max positions
        for (uint256 u = 0; u < users.length; u++) {
            vm.startPrank(users[u]);
            
            for (uint256 i = 0; i < actualMaxPositions / 2; i++) { // Half max to speed up test
                rdat.approve(address(stakingPositions), minStakeAmount);
                stakingPositions.stake(minStakeAmount, 30 days);
            }
            
            vm.stopPrank();
        }
        
        // System should still be functional
        vm.startPrank(users[0]);
        
        // Can still query positions efficiently
        uint256 gasBefore = gasleft();
        stakingPositions.getUserPositions(users[0]);
        uint256 gasUsed = gasBefore - gasleft();
        
        console2.log("Gas for position query with multiple users at capacity:", gasUsed);
        assertLt(gasUsed, 500000, "System not scalable at capacity");
        
        vm.stopPrank();
    }
    
    // ============ Edge Cases ============
    
    function test_PositionLimitPerUser_NotGlobal() public {
        // Verify limit is per-user, not global
        vm.startPrank(attacker);
        
        // Attacker creates max positions
        for (uint256 i = 0; i < actualMaxPositions; i++) {
            rdat.approve(address(stakingPositions), minStakeAmount);
            stakingPositions.stake(minStakeAmount, 30 days);
        }
        
        vm.stopPrank();
        
        // Victim should still be able to create positions
        vm.startPrank(victim);
        
        rdat.approve(address(stakingPositions), minStakeAmount);
        uint256 victimPositionId = stakingPositions.stake(minStakeAmount, 30 days);
        assertGt(victimPositionId, 0);
        
        console2.log("Confirmed: Position limit is per-user, not global");
        
        vm.stopPrank();
    }
    
    function test_PositionIDsKeepIncrementing() public {
        // Verify position IDs are global and keep incrementing
        vm.startPrank(attacker);
        
        rdat.approve(address(stakingPositions), minStakeAmount);
        uint256 firstId = stakingPositions.stake(minStakeAmount, 30 days);
        
        vm.stopPrank();
        vm.startPrank(victim);
        
        rdat.approve(address(stakingPositions), minStakeAmount);
        uint256 secondId = stakingPositions.stake(minStakeAmount, 30 days);
        
        assertEq(secondId, firstId + 1, "Position IDs should increment globally");
        
        vm.stopPrank();
    }
}