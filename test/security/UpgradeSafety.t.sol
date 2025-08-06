// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../../src/StakingPositions.sol";
import "../../src/RDATUpgradeable.sol";
import "../../src/vRDAT.sol";
import "../../src/RewardsManager.sol";
import "../../src/rewards/RDATRewardModule.sol";
import "../../src/EmergencyPause.sol";
import "../../src/examples/StakingPositionsV2Example.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title UpgradeSafety
 * @author r/datadao
 * @notice Security tests for upgrade scenarios with active positions
 * @dev Tests state preservation, storage collisions, and upgrade atomicity
 */
contract UpgradeSafetyTest is Test {
    StakingPositions public stakingV1;
    RDATUpgradeable public rdat;
    vRDAT public vrdat;
    RewardsManager public rewardsManager;
    
    ERC1967Proxy public stakingProxy;
    ERC1967Proxy public rdatProxy;
    ERC1967Proxy public rewardsProxy;
    
    address public admin = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);
    address public treasury = address(0x4);
    
    uint256 constant STAKE_AMOUNT = 1000e18;
    
    // Position tracking
    uint256 alicePosition1;
    uint256 alicePosition2;
    uint256 bobPosition1;
    
    function setUp() public {
        vm.startPrank(admin);
        
        // Deploy RDAT
        RDATUpgradeable rdatImpl = new RDATUpgradeable();
        bytes memory rdatInitData = abi.encodeCall(
            rdatImpl.initialize,
            (treasury, admin, address(0x100)) // migration contract address
        );
        rdatProxy = new ERC1967Proxy(address(rdatImpl), rdatInitData);
        rdat = RDATUpgradeable(address(rdatProxy));
        
        // Deploy vRDAT
        vrdat = new vRDAT(admin);
        // No mint delay needed for soul-bound tokens
        
        // Deploy StakingPositions V1
        StakingPositions stakingImpl = new StakingPositions();
        bytes memory stakingInitData = abi.encodeCall(
            stakingImpl.initialize,
            (address(rdat), address(vrdat), admin)
        );
        stakingProxy = new ERC1967Proxy(address(stakingImpl), stakingInitData);
        stakingV1 = StakingPositions(address(stakingProxy));
        
        // Deploy RewardsManager
        RewardsManager rewardsManagerImpl = new RewardsManager();
        bytes memory rewardsInitData = abi.encodeCall(
            rewardsManagerImpl.initialize,
            (address(stakingV1), admin)
        );
        rewardsProxy = new ERC1967Proxy(address(rewardsManagerImpl), rewardsInitData);
        rewardsManager = RewardsManager(address(rewardsProxy));
        
        // Configure
        stakingV1.setRewardsManager(address(rewardsManager));
        vrdat.grantRole(vrdat.MINTER_ROLE(), address(stakingV1));
        
        // Mint tokens
        // RDAT no longer has MINTER_ROLE - admin);
        rdat.mint(alice, STAKE_AMOUNT * 10);
        rdat.mint(bob, STAKE_AMOUNT * 10);
        
        vm.stopPrank();
        
        // Create active positions
        _createActivePositions();
    }
    
    function _createActivePositions() internal {
        // Alice stakes
        vm.startPrank(alice);
        rdat.approve(address(stakingV1), STAKE_AMOUNT * 3);
        alicePosition1 = stakingV1.stake(STAKE_AMOUNT, 30 days);
        alicePosition2 = stakingV1.stake(STAKE_AMOUNT * 2, 365 days);
        vm.stopPrank();
        
        // Bob stakes
        vm.startPrank(bob);
        rdat.approve(address(stakingV1), STAKE_AMOUNT);
        bobPosition1 = stakingV1.stake(STAKE_AMOUNT, 90 days);
        vm.stopPrank();
        
        // Fast forward to accumulate rewards
        vm.warp(block.timestamp + 7 days);
    }
    
    // ============ State Preservation Tests ============
    
    function test_UpgradePreservesPositions() public {
        // Record state before upgrade
        IStakingPositions.Position memory alicePos1Before = stakingV1.getPosition(alicePosition1);
        IStakingPositions.Position memory alicePos2Before = stakingV1.getPosition(alicePosition2);
        IStakingPositions.Position memory bobPos1Before = stakingV1.getPosition(bobPosition1);
        uint256 totalStakedBefore = stakingV1.totalStaked();
        
        // Deploy V2 implementation
        StakingPositionsV2Example stakingV2Impl = new StakingPositionsV2Example();
        
        // Upgrade
        vm.prank(admin);
        stakingV1.upgradeToAndCall(address(stakingV2Impl), "");
        
        StakingPositionsV2Example stakingV2 = StakingPositionsV2Example(address(stakingProxy));
        
        // Verify all positions preserved
        IStakingPositions.Position memory alicePos1After = stakingV2.getPosition(alicePosition1);
        IStakingPositions.Position memory alicePos2After = stakingV2.getPosition(alicePosition2);
        IStakingPositions.Position memory bobPos1After = stakingV2.getPosition(bobPosition1);
        
        // Check position data integrity
        assertEq(alicePos1After.amount, alicePos1Before.amount);
        assertEq(alicePos1After.startTime, alicePos1Before.startTime);
        assertEq(alicePos1After.lockPeriod, alicePos1Before.lockPeriod);
        assertEq(alicePos1After.vrdatMinted, alicePos1Before.vrdatMinted);
        
        assertEq(alicePos2After.amount, alicePos2Before.amount);
        assertEq(bobPos1After.amount, bobPos1Before.amount);
        
        // Check global state
        assertEq(stakingV2.totalStaked(), totalStakedBefore);
        
        // Verify NFT ownership preserved
        assertEq(stakingV2.ownerOf(alicePosition1), alice);
        assertEq(stakingV2.ownerOf(alicePosition2), alice);
        assertEq(stakingV2.ownerOf(bobPosition1), bob);
    }
    
    function test_UpgradeWithPendingRewards() public {
        // Calculate pending rewards before upgrade
        uint256 aliceRewardsBefore = stakingV1.calculatePendingRewards(alicePosition1);
        assertGt(aliceRewardsBefore, 0);
        
        // Upgrade
        StakingPositionsV2Example stakingV2Impl = new StakingPositionsV2Example();
        vm.prank(admin);
        stakingV1.upgradeToAndCall(address(stakingV2Impl), "");
        
        StakingPositionsV2Example stakingV2 = StakingPositionsV2Example(address(stakingProxy));
        
        // Rewards should still be claimable
        uint256 aliceRewardsAfter = stakingV2.calculatePendingRewards(alicePosition1);
        assertGe(aliceRewardsAfter, aliceRewardsBefore); // May have accumulated more
        
        // Claim should work
        vm.prank(alice);
        uint256 balanceBefore = rdat.balanceOf(alice);
        stakingV2.claimRewards(alicePosition1);
        uint256 balanceAfter = rdat.balanceOf(alice);
        
        assertGt(balanceAfter, balanceBefore);
    }
    
    // ============ Storage Collision Tests ============
    
    function test_StorageGapProtection() public {
        // Deploy a malicious V2 with different storage layout
        MaliciousStakingV2 maliciousImpl = new MaliciousStakingV2();
        
        // Try to upgrade
        vm.prank(admin);
        stakingV1.upgradeToAndCall(address(maliciousImpl), "");
        
        MaliciousStakingV2 maliciousStaking = MaliciousStakingV2(address(stakingProxy));
        
        // Original storage should be intact despite new variables
        assertEq(maliciousStaking.totalStaked(), stakingV1.totalStaked());
        
        // New functionality should not corrupt old data
        maliciousStaking.setMaliciousData(0xDEADBEEF);
        
        // Old positions should still be valid
        IStakingPositions.Position memory position = maliciousStaking.getPosition(alicePosition1);
        assertEq(position.amount, STAKE_AMOUNT);
    }
    
    // ============ Upgrade During Active Operations ============
    
    function test_UpgradeDuringActiveStaking() public {
        // Start a stake transaction
        vm.startPrank(alice);
        rdat.approve(address(stakingV1), STAKE_AMOUNT);
        
        // Someone else triggers upgrade in same block
        vm.stopPrank();
        vm.prank(admin);
        StakingPositionsV2Example stakingV2Impl = new StakingPositionsV2Example();
        stakingV1.upgradeToAndCall(address(stakingV2Impl), "");
        
        // Complete the stake on V2
        vm.prank(alice);
        uint256 newPosition = StakingPositionsV2Example(address(stakingProxy)).stake(STAKE_AMOUNT, 30 days);
        
        // Should work correctly
        assertGt(newPosition, 0);
        assertEq(StakingPositionsV2Example(address(stakingProxy)).ownerOf(newPosition), alice);
    }
    
    function test_RewardsManagerCompatibilityAfterUpgrade() public {
        // Deploy reward module
        EmergencyPause emergencyPause = new EmergencyPause(admin);
        RDATRewardModule rdatModule = new RDATRewardModule(
            address(rdat),
            address(stakingV1),
            address(rewardsManager),
            admin,
            1e24,
            1e18
        );
        
        vm.startPrank(admin);
        rdat.mint(address(rdatModule), 1e24);
        rewardsManager.registerProgram(address(rdatModule), "RDAT", 0, 0);
        vm.stopPrank();
        
        // Upgrade staking contract
        StakingPositionsV2Example stakingV2Impl = new StakingPositionsV2Example();
        vm.prank(admin);
        stakingV1.upgradeToAndCall(address(stakingV2Impl), "");
        
        // RewardsManager should still work with upgraded contract
        vm.warp(block.timestamp + 1 days);
        
        (uint256[] memory amounts, address[] memory tokens) = rewardsManager.calculateRewards(alice, alicePosition1);
        assertGt(amounts.length, 0);
        assertGt(amounts[0], 0);
        
        // Claiming should work
        vm.prank(alice);
        IRewardsManager.ClaimInfo[] memory claims = rewardsManager.claimRewards(alicePosition1);
        assertGt(claims.length, 0);
    }
    
    // ============ Emergency Scenarios During Upgrade ============
    
    function test_EmergencyPauseDuringUpgrade() public {
        // Pause before upgrade
        vm.prank(admin);
        stakingV1.pause();
        
        // Upgrade while paused
        StakingPositionsV2Example stakingV2Impl = new StakingPositionsV2Example();
        vm.prank(admin);
        stakingV1.upgradeToAndCall(address(stakingV2Impl), "");
        
        StakingPositionsV2Example stakingV2 = StakingPositionsV2Example(address(stakingProxy));
        
        // Should still be paused
        vm.expectRevert("Pausable: paused");
        vm.prank(alice);
        stakingV2.stake(STAKE_AMOUNT, 30 days);
        
        // Unpause should work
        vm.prank(admin);
        stakingV2.unpause();
        
        // Now staking should work
        vm.prank(alice);
        rdat.approve(address(stakingV2), STAKE_AMOUNT);
        uint256 newPosition = stakingV2.stake(STAKE_AMOUNT, 30 days);
        assertGt(newPosition, 0);
    }
    
    function test_MultipleUpgrades() public {
        // First upgrade
        StakingPositionsV2Example v2Impl = new StakingPositionsV2Example();
        vm.prank(admin);
        stakingV1.upgradeToAndCall(address(v2Impl), "");
        
        StakingPositionsV2Example stakingV2 = StakingPositionsV2Example(address(stakingProxy));
        
        // Use V2 features
        vm.prank(alice);
        rdat.approve(address(stakingV2), STAKE_AMOUNT);
        stakingV2.stakeWithReferral(STAKE_AMOUNT, 30 days, bob);
        
        // Second upgrade back to V1 (simulating rollback)
        StakingPositions v1Impl = new StakingPositions();
        vm.prank(admin);
        stakingV2.upgradeToAndCall(address(v1Impl), "");
        
        // Should still have all positions
        StakingPositions rolledBack = StakingPositions(address(stakingProxy));
        assertEq(rolledBack.totalStaked(), stakingV1.totalStaked() + STAKE_AMOUNT);
        
        // Original positions should be intact
        IStakingPositions.Position memory position = rolledBack.getPosition(alicePosition1);
        assertEq(position.amount, STAKE_AMOUNT);
    }
}

// Malicious implementation for testing
contract MaliciousStakingV2 is StakingPositions {
    // Add new storage variables without respecting gap
    uint256 public maliciousData;
    mapping(address => uint256) public exploitTracking;
    
    function setMaliciousData(uint256 data) external {
        maliciousData = data;
    }
    
    // Try to manipulate positions
    function corruptPosition(uint256 positionId) external {
        // This should not affect the actual position data due to storage layout
        exploitTracking[msg.sender] = positionId;
    }
}