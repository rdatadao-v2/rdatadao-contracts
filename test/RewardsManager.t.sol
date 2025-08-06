// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../src/RewardsManager.sol";
import "../src/RDATUpgradeable.sol";
import "../src/vRDAT.sol";
import "../src/StakingPositions.sol";
import "../src/rewards/vRDATRewardModule.sol";
import "../src/rewards/RDATRewardModule.sol";
import "../src/EmergencyPause.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract RewardsManagerTest is Test {
    RewardsManager public rewardsManager;
    RewardsManager public rewardsManagerImpl;
    RDATUpgradeable public rdat;
    vRDAT public vrdat;
    StakingPositions public stakingPositions;
    vRDATRewardModule public vrdatModule;
    RDATRewardModule public rdatModule;
    EmergencyPause public emergencyPause;
    
    ERC1967Proxy public rewardsProxy;
    ERC1967Proxy public stakingProxy;
    ERC1967Proxy public rdatProxy;
    
    address public admin = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);
    address public charlie = address(0x4);
    address public treasury = address(0x5);
    address public pauser = address(0x6);
    address public upgrader = address(0x7);
    
    uint256 constant INITIAL_BALANCE = 10_000_000 * 10**18;
    uint256 constant STAKE_AMOUNT = 1000 * 10**18;
    uint256 constant REWARD_ALLOCATION = 1_000_000 * 10**18;
    
    event ProgramRegistered(
        uint256 indexed programId,
        address indexed rewardModule,
        address indexed rewardToken,
        string name
    );
    
    event ProgramStatusUpdated(uint256 indexed programId, bool active);
    event EmergencyPauseTriggered(uint256 indexed programId);
    event EmergencyPauseLifted(uint256 indexed programId);
    event StakeNotified(address indexed user, uint256 indexed stakeId, uint256 amount, uint256 lockPeriod);
    event UnstakeNotified(address indexed user, uint256 indexed stakeId, bool emergency);
    event RewardsClaimed(address indexed user, uint256 indexed stakeId, IRewardsManager.ClaimInfo[] claims);
    event RevenueDistributed(uint256 indexed programId, uint256 amount);
    
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
        
        // Deploy EmergencyPause
        emergencyPause = new EmergencyPause(admin);
        
        // Deploy StakingPositions
        StakingPositions stakingImpl = new StakingPositions();
        bytes memory stakingInitData = abi.encodeCall(
            stakingImpl.initialize,
            (address(rdat), address(vrdat), admin)
        );
        stakingProxy = new ERC1967Proxy(address(stakingImpl), stakingInitData);
        stakingPositions = StakingPositions(address(stakingProxy));
        
        // Deploy RewardsManager
        rewardsManagerImpl = new RewardsManager();
        bytes memory rewardsInitData = abi.encodeCall(
            rewardsManagerImpl.initialize,
            (address(stakingPositions), admin)
        );
        rewardsProxy = new ERC1967Proxy(address(rewardsManagerImpl), rewardsInitData);
        rewardsManager = RewardsManager(address(rewardsProxy));
        
        // Set up reward modules
        vrdatModule = new vRDATRewardModule(
            address(vrdat),
            address(stakingPositions),
            address(emergencyPause),
            admin
        );
        
        rdatModule = new RDATRewardModule(
            address(rdat),
            address(stakingPositions),
            address(rewardsManager),
            admin,
            REWARD_ALLOCATION,
            1e18 // 1 RDAT per second base rate
        );
        
        // Configure connections
        // Note: StakingPositions doesn't have setRewardsManager in current implementation
        vrdat.grantRole(vrdat.MINTER_ROLE(), address(vrdatModule));
        vrdat.grantRole(vrdat.BURNER_ROLE(), address(vrdatModule));
        vrdatModule.updateRewardsManager(address(rewardsManager));
        
        // Set up roles
        rewardsManager.grantRole(rewardsManager.PAUSER_ROLE(), pauser);
        rewardsManager.grantRole(rewardsManager.UPGRADER_ROLE(), upgrader);
        
        // Allocate RDAT to users (from treasury, no minting)
        // RDAT no longer has MINTER_ROLE - all tokens minted at deployment
        vm.startPrank(treasury);
        rdat.transfer(alice, INITIAL_BALANCE);
        rdat.transfer(bob, INITIAL_BALANCE);
        rdat.transfer(charlie, INITIAL_BALANCE);
        rdat.transfer(address(rdatModule), REWARD_ALLOCATION);
        vm.stopPrank();
        
        vm.startPrank(admin);
        vm.stopPrank();
    }
    
    // ============ Program Management Tests ============
    
    function test_RegisterProgram() public {
        vm.startPrank(admin);
        
        vm.expectEmit(true, true, true, true);
        emit ProgramRegistered(0, address(vrdatModule), address(vrdat), "vRDAT Governance Rewards");
        
        uint256 programId = rewardsManager.registerProgram(
            address(vrdatModule),
            "vRDAT Governance Rewards",
            0, // immediate start
            0  // perpetual
        );
        
        assertEq(programId, 0);
        
        IRewardsManager.RewardProgram memory program = rewardsManager.getProgram(programId);
        assertEq(program.rewardModule, address(vrdatModule));
        assertEq(program.rewardToken, address(vrdat));
        assertEq(program.name, "vRDAT Governance Rewards");
        assertEq(program.startTime, block.timestamp);
        assertEq(program.endTime, 0);
        assertTrue(program.active);
        assertFalse(program.emergency);
        
        vm.stopPrank();
    }
    
    function test_RegisterProgram_InvalidModule() public {
        vm.startPrank(admin);
        
        vm.expectRevert(IRewardsManager.InvalidModule.selector);
        rewardsManager.registerProgram(
            address(0),
            "Invalid Module",
            0,
            0
        );
        
        vm.stopPrank();
    }
    
    function test_RegisterProgram_WithStartTimeAndDuration() public {
        vm.startPrank(admin);
        
        uint256 futureStart = block.timestamp + 1 days;
        uint256 duration = 30 days;
        
        uint256 programId = rewardsManager.registerProgram(
            address(rdatModule),
            "RDAT Staking Rewards",
            futureStart,
            duration
        );
        
        IRewardsManager.RewardProgram memory program = rewardsManager.getProgram(programId);
        assertEq(program.startTime, futureStart);
        assertEq(program.endTime, futureStart + duration);
        
        vm.stopPrank();
    }
    
    function test_UpdateProgramStatus() public {
        vm.startPrank(admin);
        
        uint256 programId = rewardsManager.registerProgram(
            address(vrdatModule),
            "vRDAT Rewards",
            0,
            0
        );
        
        vm.expectEmit(true, false, false, true);
        emit ProgramStatusUpdated(programId, false);
        
        rewardsManager.updateProgramStatus(programId, false);
        
        IRewardsManager.RewardProgram memory program = rewardsManager.getProgram(programId);
        assertFalse(program.active);
        
        vm.stopPrank();
    }
    
    function test_UpdateProgramStatus_Unauthorized() public {
        vm.prank(admin);
        uint256 programId = rewardsManager.registerProgram(
            address(vrdatModule),
            "vRDAT Rewards",
            0,
            0
        );
        
        vm.prank(alice);
        vm.expectRevert();
        rewardsManager.updateProgramStatus(programId, false);
    }
    
    function test_EmergencyPauseProgram() public {
        vm.prank(admin);
        uint256 programId = rewardsManager.registerProgram(
            address(vrdatModule),
            "vRDAT Rewards",
            0,
            0
        );
        
        vm.prank(pauser);
        vm.expectEmit(true, false, false, false);
        emit EmergencyPauseTriggered(programId);
        
        rewardsManager.emergencyPauseProgram(programId);
        
        IRewardsManager.RewardProgram memory program = rewardsManager.getProgram(programId);
        assertTrue(program.emergency);
    }
    
    function test_EmergencyUnpauseProgram() public {
        vm.prank(admin);
        uint256 programId = rewardsManager.registerProgram(
            address(vrdatModule),
            "vRDAT Rewards",
            0,
            0
        );
        
        vm.startPrank(pauser);
        rewardsManager.emergencyPauseProgram(programId);
        
        vm.expectEmit(true, false, false, false);
        emit EmergencyPauseLifted(programId);
        
        rewardsManager.emergencyUnpauseProgram(programId);
        vm.stopPrank();
        
        IRewardsManager.RewardProgram memory program = rewardsManager.getProgram(programId);
        assertFalse(program.emergency);
    }
    
    // ============ Staking Integration Tests ============
    
    function test_NotifyStake() public {
        vm.prank(admin);
        uint256 programId = rewardsManager.registerProgram(
            address(vrdatModule),
            "vRDAT Rewards",
            0,
            0
        );
        
        vm.startPrank(alice);
        rdat.approve(address(stakingPositions), STAKE_AMOUNT);
        
        vm.expectEmit(true, true, false, true);
        emit StakeNotified(alice, 1, STAKE_AMOUNT, stakingPositions.MONTH_1());
        
        uint256 positionId = stakingPositions.stake(STAKE_AMOUNT, stakingPositions.MONTH_1());
        vm.stopPrank();
        
        // Verify vRDAT was minted
        assertEq(vrdat.balanceOf(alice), STAKE_AMOUNT);
    }
    
    function test_NotifyStake_OnlyStakingManager() public {
        vm.prank(alice);
        vm.expectRevert(IRewardsManager.NotStakingManager.selector);
        rewardsManager.notifyStake(alice, 1, STAKE_AMOUNT, 30 days);
    }
    
    function test_NotifyStake_WhenPaused() public {
        vm.prank(admin);
        uint256 programId = rewardsManager.registerProgram(
            address(vrdatModule),
            "vRDAT Rewards",
            0,
            0
        );
        
        vm.prank(pauser);
        rewardsManager.pause();
        
        vm.startPrank(alice);
        rdat.approve(address(stakingPositions), STAKE_AMOUNT);
        
        vm.expectRevert();
        stakingPositions.stake(STAKE_AMOUNT, stakingPositions.MONTH_1());
        vm.stopPrank();
    }
    
    function test_NotifyUnstake() public {
        // Setup: Register program and stake
        vm.prank(admin);
        uint256 programId = rewardsManager.registerProgram(
            address(vrdatModule),
            "vRDAT Rewards",
            0,
            0
        );
        
        vm.startPrank(alice);
        rdat.approve(address(stakingPositions), STAKE_AMOUNT);
        uint256 positionId = stakingPositions.stake(STAKE_AMOUNT, stakingPositions.MONTH_1());
        
        // Fast forward to allow unstake
        vm.warp(block.timestamp + stakingPositions.MONTH_1() + 1);
        
        vm.expectEmit(true, true, false, true);
        emit UnstakeNotified(alice, positionId, false);
        
        stakingPositions.unstake(positionId);
        vm.stopPrank();
        
        // Verify vRDAT was burned
        assertEq(vrdat.balanceOf(alice), 0);
    }
    
    function test_NotifyUnstake_Emergency() public {
        // Setup: Register program and stake
        vm.prank(admin);
        uint256 programId = rewardsManager.registerProgram(
            address(vrdatModule),
            "vRDAT Rewards",
            0,
            0
        );
        
        vm.startPrank(alice);
        rdat.approve(address(stakingPositions), STAKE_AMOUNT);
        uint256 positionId = stakingPositions.stake(STAKE_AMOUNT, stakingPositions.MONTH_1());
        
        vm.expectEmit(true, true, false, true);
        emit UnstakeNotified(alice, positionId, true);
        
        stakingPositions.emergencyWithdraw(positionId);
        vm.stopPrank();
        
        // Verify vRDAT was burned (emergency)
        assertEq(vrdat.balanceOf(alice), 0);
    }
    
    // ============ Reward Claiming Tests ============
    
    function test_ClaimRewards_SingleProgram() public {
        // Setup: Register RDAT rewards program
        vm.prank(admin);
        uint256 programId = rewardsManager.registerProgram(
            address(rdatModule),
            "RDAT Staking Rewards",
            0,
            0
        );
        
        // Stake
        vm.startPrank(alice);
        rdat.approve(address(stakingPositions), STAKE_AMOUNT);
        uint256 positionId = stakingPositions.stake(STAKE_AMOUNT, stakingPositions.MONTH_1());
        
        // Fast forward to accumulate rewards
        vm.warp(block.timestamp + 7 days);
        
        // Check pending rewards
        (uint256[] memory amounts, address[] memory tokens) = rewardsManager.calculateRewards(alice, positionId);
        assertEq(amounts.length, 1);
        assertEq(tokens.length, 1);
        assertEq(tokens[0], address(rdat));
        assertGt(amounts[0], 0);
        
        uint256 balanceBefore = rdat.balanceOf(alice);
        
        // Claim rewards
        IRewardsManager.ClaimInfo[] memory claims = rewardsManager.claimRewards(positionId);
        
        assertEq(claims.length, 1);
        assertEq(claims[0].programId, programId);
        assertEq(claims[0].token, address(rdat));
        assertGt(claims[0].amount, 0);
        
        assertEq(rdat.balanceOf(alice), balanceBefore + claims[0].amount);
        
        vm.stopPrank();
    }
    
    function test_ClaimRewards_MultiplePrograms() public {
        // Register both programs
        vm.startPrank(admin);
        uint256 vrdatProgramId = rewardsManager.registerProgram(
            address(vrdatModule),
            "vRDAT Governance Rewards",
            0,
            0
        );
        
        uint256 rdatProgramId = rewardsManager.registerProgram(
            address(rdatModule),
            "RDAT Staking Rewards",
            0,
            0
        );
        vm.stopPrank();
        
        // Stake
        vm.startPrank(alice);
        rdat.approve(address(stakingPositions), STAKE_AMOUNT);
        uint256 positionId = stakingPositions.stake(STAKE_AMOUNT, stakingPositions.MONTH_1());
        
        // Fast forward
        vm.warp(block.timestamp + 7 days);
        
        // Check pending rewards (should be 2)
        (uint256[] memory amounts, address[] memory tokens) = rewardsManager.calculateRewards(alice, positionId);
        assertEq(amounts.length, 2);
        assertEq(tokens.length, 2);
        
        // Note: vRDAT rewards are immediate, RDAT rewards accumulate over time
        assertGt(amounts[1], 0); // RDAT rewards
        
        vm.stopPrank();
    }
    
    function test_ClaimAllRewards() public {
        // Setup programs
        vm.prank(admin);
        rewardsManager.registerProgram(address(rdatModule), "RDAT Rewards", 0, 0);
        
        // Create multiple positions
        vm.startPrank(alice);
        rdat.approve(address(stakingPositions), STAKE_AMOUNT * 3);
        
        uint256 position1 = stakingPositions.stake(STAKE_AMOUNT, stakingPositions.MONTH_1());
        uint256 position2 = stakingPositions.stake(STAKE_AMOUNT, stakingPositions.MONTH_3());
        uint256 position3 = stakingPositions.stake(STAKE_AMOUNT, stakingPositions.MONTH_6());
        
        // Fast forward
        vm.warp(block.timestamp + 7 days);
        
        uint256 balanceBefore = rdat.balanceOf(alice);
        
        // Claim all rewards
        IRewardsManager.ClaimInfo[] memory claims = rewardsManager.claimAllRewards();
        
        // Should have claims for all 3 positions
        assertGt(claims.length, 0);
        
        uint256 totalClaimed = 0;
        for (uint256 i = 0; i < claims.length; i++) {
            totalClaimed += claims[i].amount;
        }
        
        assertEq(rdat.balanceOf(alice), balanceBefore + totalClaimed);
        
        vm.stopPrank();
    }
    
    function test_ClaimRewardsFor() public {
        // Setup
        vm.prank(admin);
        rewardsManager.registerProgram(address(rdatModule), "RDAT Rewards", 0, 0);
        
        // Alice stakes
        vm.startPrank(alice);
        rdat.approve(address(stakingPositions), STAKE_AMOUNT);
        uint256 positionId = stakingPositions.stake(STAKE_AMOUNT, stakingPositions.MONTH_1());
        vm.stopPrank();
        
        // Fast forward
        vm.warp(block.timestamp + 7 days);
        
        uint256 aliceBalanceBefore = rdat.balanceOf(alice);
        
        // Admin claims on behalf of Alice
        vm.prank(admin);
        IRewardsManager.ClaimInfo[] memory claims = rewardsManager.claimRewardsFor(alice, positionId);
        
        assertGt(claims.length, 0);
        assertEq(rdat.balanceOf(alice), aliceBalanceBefore + claims[0].amount);
    }
    
    function test_ClaimRewardsFor_Unauthorized() public {
        // Setup
        vm.prank(admin);
        rewardsManager.registerProgram(address(rdatModule), "RDAT Rewards", 0, 0);
        
        // Alice stakes
        vm.startPrank(alice);
        rdat.approve(address(stakingPositions), STAKE_AMOUNT);
        uint256 positionId = stakingPositions.stake(STAKE_AMOUNT, stakingPositions.MONTH_1());
        vm.stopPrank();
        
        // Bob tries to claim for Alice (should fail)
        vm.prank(bob);
        vm.expectRevert();
        rewardsManager.claimRewardsFor(alice, positionId);
    }
    
    // ============ Revenue Distribution Tests ============
    
    function test_NotifyRevenueReward() public {
        // Setup RDAT rewards program
        vm.prank(admin);
        uint256 programId = rewardsManager.registerProgram(
            address(rdatModule),
            "RDAT Staking Rewards",
            0,
            0
        );
        
        // Create some stakes
        vm.startPrank(alice);
        rdat.approve(address(stakingPositions), STAKE_AMOUNT);
        stakingPositions.stake(STAKE_AMOUNT, stakingPositions.MONTH_1());
        vm.stopPrank();
        
        vm.startPrank(bob);
        rdat.approve(address(stakingPositions), STAKE_AMOUNT);
        stakingPositions.stake(STAKE_AMOUNT, stakingPositions.MONTH_1());
        vm.stopPrank();
        
        // Notify revenue (as if from RevenueCollector)
        uint256 revenueAmount = 100_000 * 10**18;
        
        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit RevenueDistributed(programId, revenueAmount);
        
        rewardsManager.notifyRevenueReward(revenueAmount);
        
        // Verify allocation increased in module
        assertEq(rdatModule.totalAllocated(), REWARD_ALLOCATION + revenueAmount);
    }
    
    function test_NotifyRevenueReward_NoProgramMatch() public {
        // Register program with different name
        vm.prank(admin);
        rewardsManager.registerProgram(
            address(rdatModule),
            "Different Name",
            0,
            0
        );
        
        // Notify revenue should not match
        vm.prank(admin);
        rewardsManager.notifyRevenueReward(100_000 * 10**18);
        
        // Allocation should not increase
        assertEq(rdatModule.totalAllocated(), REWARD_ALLOCATION);
    }
    
    // ============ View Function Tests ============
    
    function test_GetProgram() public {
        vm.prank(admin);
        uint256 programId = rewardsManager.registerProgram(
            address(vrdatModule),
            "Test Program",
            block.timestamp + 1 days,
            30 days
        );
        
        IRewardsManager.RewardProgram memory program = rewardsManager.getProgram(programId);
        assertEq(program.name, "Test Program");
        assertEq(program.rewardModule, address(vrdatModule));
    }
    
    function test_GetProgramCount() public {
        assertEq(rewardsManager.getProgramCount(), 0);
        
        vm.startPrank(admin);
        rewardsManager.registerProgram(address(vrdatModule), "Program 1", 0, 0);
        rewardsManager.registerProgram(address(rdatModule), "Program 2", 0, 0);
        vm.stopPrank();
        
        assertEq(rewardsManager.getProgramCount(), 2);
    }
    
    function test_GetActivePrograms() public {
        vm.startPrank(admin);
        uint256 id1 = rewardsManager.registerProgram(address(vrdatModule), "Active 1", 0, 0);
        uint256 id2 = rewardsManager.registerProgram(address(rdatModule), "Active 2", 0, 0);
        uint256 id3 = rewardsManager.registerProgram(address(vrdatModule), "Inactive", 0, 0);
        
        rewardsManager.updateProgramStatus(id3, false);
        vm.stopPrank();
        
        uint256[] memory activePrograms = rewardsManager.getActivePrograms();
        assertEq(activePrograms.length, 2);
        assertEq(activePrograms[0], id1);
        assertEq(activePrograms[1], id2);
    }
    
    function test_GetUserClaimablePrograms() public {
        // Setup programs
        vm.startPrank(admin);
        uint256 id1 = rewardsManager.registerProgram(address(rdatModule), "RDAT Rewards", 0, 0);
        uint256 id2 = rewardsManager.registerProgram(address(vrdatModule), "vRDAT Rewards", 0, 0);
        vm.stopPrank();
        
        // Stake
        vm.startPrank(alice);
        rdat.approve(address(stakingPositions), STAKE_AMOUNT);
        uint256 positionId = stakingPositions.stake(STAKE_AMOUNT, stakingPositions.MONTH_1());
        vm.stopPrank();
        
        // Fast forward to accumulate rewards
        vm.warp(block.timestamp + 7 days);
        
        uint256[] memory claimablePrograms = rewardsManager.getUserClaimablePrograms(alice, positionId);
        assertGt(claimablePrograms.length, 0);
    }
    
    function test_CalculateAllRewards() public {
        // Setup
        vm.prank(admin);
        rewardsManager.registerProgram(address(rdatModule), "RDAT Rewards", 0, 0);
        
        // Create multiple positions
        vm.startPrank(alice);
        rdat.approve(address(stakingPositions), STAKE_AMOUNT * 2);
        stakingPositions.stake(STAKE_AMOUNT, stakingPositions.MONTH_1());
        stakingPositions.stake(STAKE_AMOUNT, stakingPositions.MONTH_3());
        vm.stopPrank();
        
        // Fast forward
        vm.warp(block.timestamp + 7 days);
        
        (uint256[] memory amounts, address[] memory tokens) = rewardsManager.calculateAllRewards(alice);
        assertEq(amounts.length, 1);
        assertEq(tokens.length, 1);
        assertGt(amounts[0], 0);
    }
    
    // ============ Access Control Tests ============
    
    function test_SetStakingManager() public {
        address newStakingManager = address(0x999);
        
        vm.prank(admin);
        rewardsManager.setStakingManager(newStakingManager);
        
        assertEq(rewardsManager.stakingManager(), newStakingManager);
    }
    
    function test_SetStakingManager_Unauthorized() public {
        vm.prank(alice);
        vm.expectRevert();
        rewardsManager.setStakingManager(address(0x999));
    }
    
    function test_SetStakingManager_ZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(IRewardsManager.ZeroAddress.selector);
        rewardsManager.setStakingManager(address(0));
    }
    
    function test_Pause() public {
        vm.prank(pauser);
        rewardsManager.pause();
        
        // Try to claim rewards while paused
        vm.prank(alice);
        vm.expectRevert();
        rewardsManager.claimRewards(1);
    }
    
    function test_Unpause() public {
        vm.startPrank(pauser);
        rewardsManager.pause();
        rewardsManager.unpause();
        vm.stopPrank();
        
        // Should be able to claim now
        vm.prank(alice);
        rewardsManager.claimRewards(1); // Won't revert
    }
    
    // ============ Upgrade Tests ============
    
    function test_UpgradeToNewImplementation() public {
        // Deploy new implementation
        RewardsManager newImpl = new RewardsManager();
        
        vm.prank(upgrader);
        rewardsManager.upgradeToAndCall(address(newImpl), "");
        
        // Verify upgrade worked
        assertEq(rewardsManager.stakingManager(), address(stakingPositions));
    }
    
    function test_UpgradeToNewImplementation_Unauthorized() public {
        RewardsManager newImpl = new RewardsManager();
        
        vm.prank(alice);
        vm.expectRevert();
        rewardsManager.upgradeToAndCall(address(newImpl), "");
    }
    
    // ============ Edge Case Tests ============
    
    function test_ClaimRewards_NonExistentPosition() public {
        vm.prank(alice);
        IRewardsManager.ClaimInfo[] memory claims = rewardsManager.claimRewards(999);
        assertEq(claims.length, 0);
    }
    
    function test_RegisterProgram_InvalidToken() public {
        // Create a mock module that returns address(0) for token
        MockInvalidModule invalidModule = new MockInvalidModule();
        
        vm.prank(admin);
        vm.expectRevert(IRewardsManager.InvalidToken.selector);
        rewardsManager.registerProgram(
            address(invalidModule),
            "Invalid",
            0,
            0
        );
    }
    
    function test_MultipleFailingModules() public {
        // Register multiple programs
        vm.startPrank(admin);
        rewardsManager.registerProgram(address(vrdatModule), "vRDAT", 0, 0);
        rewardsManager.registerProgram(address(rdatModule), "RDAT", 0, 0);
        vm.stopPrank();
        
        // Make one module fail by revoking role
        vm.prank(admin);
        vrdatModule.revokeRole(vrdatModule.REWARDS_MANAGER_ROLE(), address(rewardsManager));
        
        // Stake should still work (one module fails, other continues)
        vm.startPrank(alice);
        rdat.approve(address(stakingPositions), STAKE_AMOUNT);
        uint256 positionId = stakingPositions.stake(STAKE_AMOUNT, stakingPositions.MONTH_1());
        vm.stopPrank();
        
        // Should still be able to claim from working module
        vm.warp(block.timestamp + 7 days);
        
        vm.prank(alice);
        IRewardsManager.ClaimInfo[] memory claims = rewardsManager.claimRewards(positionId);
        assertGt(claims.length, 0);
    }
}

// Mock module for testing
contract MockInvalidModule is IRewardModule {
    function onStake(address, uint256, uint256, uint256) external {}
    function onUnstake(address, uint256, uint256, bool) external {}
    function calculateRewards(address, uint256) external view returns (uint256) { return 0; }
    function claimRewards(address, uint256) external returns (uint256) { return 0; }
    function getModuleInfo() external view returns (ModuleInfo memory) {
        return ModuleInfo({
            name: "Invalid",
            version: "1.0.0",
            rewardToken: address(0), // Invalid token
            isActive: true,
            supportsHistory: false,
            totalAllocated: 0,
            totalDistributed: 0
        });
    }
    function isActive() external view returns (bool) { return true; }
    function rewardToken() external view returns (address) { return address(0); }
    function totalAllocated() external view returns (uint256) { return 0; }
    function totalDistributed() external view returns (uint256) { return 0; }
    function remainingAllocation() external view returns (uint256) { return 0; }
    function emergencyWithdraw(address, uint256) external {}
}