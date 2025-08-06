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
import "../src/interfaces/IStakingPositions.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// Simple mock that tracks positions for reward module queries
contract MockStakingPositions {
    mapping(uint256 => IStakingPositions.Position) private _positions;
    mapping(address => uint256[]) private _userPositions;
    
    function mockStake(address user, uint256 positionId, uint256 amount, uint256 lockPeriod) external {
        _positions[positionId] = IStakingPositions.Position({
            amount: amount,
            startTime: block.timestamp,
            lockPeriod: lockPeriod,
            multiplier: 10000,
            vrdatMinted: amount,
            lastRewardTime: block.timestamp,
            rewardsClaimed: 0
        });
        _userPositions[user].push(positionId);
    }
    
    function getPosition(uint256 positionId) external view returns (IStakingPositions.Position memory) {
        return _positions[positionId];
    }
    
    function getUserPositions(address user) external view returns (uint256[] memory) {
        return _userPositions[user];
    }
}

contract RewardsManagerBasicTest is Test {
    RewardsManager public rewardsManager;
    RewardsManager public rewardsManagerImpl;
    RDATUpgradeable public rdat;
    vRDAT public vrdat;
    MockStakingPositions public stakingPositions;
    vRDATRewardModule public vrdatModule;
    RDATRewardModule public rdatModule;
    EmergencyPause public emergencyPause;
    
    ERC1967Proxy public rewardsProxy;
    ERC1967Proxy public rdatProxy;
    
    address public admin = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);
    address public treasury = address(0x5);
    
    uint256 constant INITIAL_BALANCE = 10_000_000 * 10**18;
    uint256 constant STAKE_AMOUNT = 1000 * 10**18;
    uint256 constant REWARD_ALLOCATION = 1_000_000 * 10**18;
    
    event ProgramRegistered(
        uint256 indexed programId,
        address indexed rewardModule,
        address indexed rewardToken,
        string name
    );
    
    event StakeNotified(address indexed user, uint256 indexed stakeId, uint256 amount, uint256 lockPeriod);
    event UnstakeNotified(address indexed user, uint256 indexed stakeId, bool emergency);
    event RewardsClaimed(address indexed user, uint256 indexed stakeId, IRewardsManager.ClaimInfo[] claims);
    
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
        
        // Deploy Mock StakingPositions
        stakingPositions = new MockStakingPositions();
        
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
        vrdat.grantRole(vrdat.MINTER_ROLE(), address(vrdatModule));
        vrdat.grantRole(vrdat.BURNER_ROLE(), address(vrdatModule));
        vrdatModule.updateRewardsManager(address(rewardsManager));
        
        // Allocate tokens (from treasury, no minting)
        // RDAT no longer has MINTER_ROLE - all tokens minted at deployment
        vm.startPrank(treasury);
        rdat.transfer(alice, INITIAL_BALANCE);
        rdat.transfer(bob, INITIAL_BALANCE);
        rdat.transfer(address(rdatModule), REWARD_ALLOCATION);
        vm.stopPrank();
        
        vm.startPrank(admin);
        
        vm.stopPrank();
    }
    
    // ============ Basic Tests ============
    
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
        assertEq(rewardsManager.getProgramCount(), 1);
        
        IRewardsManager.RewardProgram memory program = rewardsManager.getProgram(programId);
        assertEq(program.rewardModule, address(vrdatModule));
        assertEq(program.rewardToken, address(vrdat));
        assertEq(program.name, "vRDAT Governance Rewards");
        assertTrue(program.active);
        
        vm.stopPrank();
    }
    
    function test_RegisterMultiplePrograms() public {
        vm.startPrank(admin);
        
        uint256 id1 = rewardsManager.registerProgram(
            address(vrdatModule),
            "vRDAT Rewards",
            0,
            0
        );
        
        uint256 id2 = rewardsManager.registerProgram(
            address(rdatModule),
            "RDAT Staking Rewards",
            0,
            0
        );
        
        assertEq(id1, 0);
        assertEq(id2, 1);
        assertEq(rewardsManager.getProgramCount(), 2);
        
        vm.stopPrank();
    }
    
    function test_NotifyStake() public {
        // Register program first
        vm.prank(admin);
        rewardsManager.registerProgram(address(vrdatModule), "vRDAT", 0, 0);
        
        // Mock the stake position first
        stakingPositions.mockStake(alice, 1, STAKE_AMOUNT, 30 days);
        
        // Notify stake
        vm.expectEmit(true, true, false, true);
        emit StakeNotified(alice, 1, STAKE_AMOUNT, 30 days);
        
        vm.prank(address(stakingPositions));
        rewardsManager.notifyStake(alice, 1, STAKE_AMOUNT, 30 days);
        
        // Verify vRDAT was minted (through module)
        // vRDAT module uses 10000/10000 = 1x multiplier for 30 days (MONTH_1)
        uint256 expectedVRDAT = (STAKE_AMOUNT * 10000) / 10000;
        assertEq(vrdat.balanceOf(alice), expectedVRDAT);
    }
    
    function test_NotifyUnstake() public {
        // Setup
        vm.prank(admin);
        rewardsManager.registerProgram(address(vrdatModule), "vRDAT", 0, 0);
        
        // Stake first
        // Mock the stake position first
        stakingPositions.mockStake(alice, 1, STAKE_AMOUNT, 30 days);
        
        vm.prank(address(stakingPositions));
        rewardsManager.notifyStake(alice, 1, STAKE_AMOUNT, 30 days);
        
        // Unstake
        vm.expectEmit(true, true, false, true);
        emit UnstakeNotified(alice, 1, false);
        
        vm.prank(address(stakingPositions));
        rewardsManager.notifyUnstake(alice, 1, false);
        
        // vRDAT is NOT burned on normal unstake (only on emergency)
        // For 30 days stake, multiplier is 10000 (1x), so vRDAT = STAKE_AMOUNT
        uint256 expectedVRDAT = STAKE_AMOUNT;
        assertEq(vrdat.balanceOf(alice), expectedVRDAT);
    }
    
    function test_ClaimRewards_NoPrograms() public {
        vm.prank(alice);
        IRewardsManager.ClaimInfo[] memory claims = rewardsManager.claimRewards(1);
        assertEq(claims.length, 0);
    }
    
    function test_ClaimRewards_WithRDATProgram() public {
        // Setup
        vm.prank(admin);
        rewardsManager.registerProgram(
            address(rdatModule),
            "RDAT Staking Rewards",
            0,
            0
        );
        
        // Create a stake
        uint256 positionId = 1;
        stakingPositions.mockStake(alice, positionId, STAKE_AMOUNT, 30 days);
        vm.prank(address(stakingPositions));
        rewardsManager.notifyStake(alice, positionId, STAKE_AMOUNT, 30 days);
        
        // Fast forward to accumulate rewards
        vm.warp(block.timestamp + 1 days);
        
        // Check pending rewards
        (uint256[] memory amounts, address[] memory tokens) = rewardsManager.calculateRewards(alice, positionId);
        assertEq(amounts.length, 1);
        assertEq(tokens[0], address(rdat));
        assertGt(amounts[0], 0);
        
        // RDATRewardModule: rate=1e18, RATE_PRECISION=1e27
        // For 1000 RDAT staked with 1x multiplier for 1 day:
        // (1000e18 * 1e18 * 86400 * 10000) / (1e27 * 10000)
        // = (1000 * 1 * 86400 * 10000) / (1e9 * 10000)
        // = 86400 * 1e12 = 86.4e15 = 0.0864e18
        uint256 expectedReward = 86400 * 1e12;
        assertEq(amounts[0], expectedReward);
        
        // Claim
        uint256 balanceBefore = rdat.balanceOf(alice);
        
        vm.prank(alice);
        IRewardsManager.ClaimInfo[] memory claims = rewardsManager.claimRewards(positionId);
        
        assertEq(claims.length, 1);
        assertEq(claims[0].token, address(rdat));
        assertEq(claims[0].amount, expectedReward);
        assertEq(claims[0].programId, 0);
        assertEq(rdat.balanceOf(alice), balanceBefore + expectedReward);
    }
    
    function test_ProgramLifecycle() public {
        vm.startPrank(admin);
        
        // Register
        uint256 programId = rewardsManager.registerProgram(
            address(vrdatModule),
            "Test Program",
            0,
            0
        );
        
        // Verify active
        IRewardsManager.RewardProgram memory program = rewardsManager.getProgram(programId);
        assertTrue(program.active);
        
        // Deactivate
        rewardsManager.updateProgramStatus(programId, false);
        program = rewardsManager.getProgram(programId);
        assertFalse(program.active);
        
        // Emergency pause
        rewardsManager.emergencyPauseProgram(programId);
        program = rewardsManager.getProgram(programId);
        assertTrue(program.emergency);
        
        // Unpause
        rewardsManager.emergencyUnpauseProgram(programId);
        program = rewardsManager.getProgram(programId);
        assertFalse(program.emergency);
        
        vm.stopPrank();
    }
    
    function test_GetActivePrograms() public {
        vm.startPrank(admin);
        
        // Register 3 programs
        uint256 id1 = rewardsManager.registerProgram(address(vrdatModule), "Active 1", 0, 0);
        uint256 id2 = rewardsManager.registerProgram(address(rdatModule), "Active 2", 0, 0);
        uint256 id3 = rewardsManager.registerProgram(address(vrdatModule), "Inactive", 0, 0);
        
        // Deactivate one
        rewardsManager.updateProgramStatus(id3, false);
        
        uint256[] memory activePrograms = rewardsManager.getActivePrograms();
        assertEq(activePrograms.length, 2);
        assertEq(activePrograms[0], id1);
        assertEq(activePrograms[1], id2);
        
        vm.stopPrank();
    }
    
    function test_CalculateAllRewards() public {
        // Setup programs
        vm.prank(admin);
        rewardsManager.registerProgram(address(rdatModule), "RDAT", 0, 0);
        
        // Create multiple positions
        stakingPositions.mockStake(alice, 1, STAKE_AMOUNT, 30 days);
        vm.prank(address(stakingPositions));
        rewardsManager.notifyStake(alice, 1, STAKE_AMOUNT, 30 days);
        
        stakingPositions.mockStake(alice, 2, STAKE_AMOUNT * 2, 90 days);
        vm.prank(address(stakingPositions));
        rewardsManager.notifyStake(alice, 2, STAKE_AMOUNT * 2, 90 days);
        
        // Fast forward
        vm.warp(block.timestamp + 7 days);
        
        (uint256[] memory amounts, address[] memory tokens) = rewardsManager.calculateAllRewards(alice);
        assertEq(amounts.length, 1);
        assertEq(tokens[0], address(rdat));
        
        // Should be sum of both positions
        // Position 1: (1000e18 * 1e18 * 604800 * 10000) / (1e27 * 10000) = 604800e12
        // Position 2: (2000e18 * 1e18 * 604800 * 15000) / (1e27 * 10000) = 1814400e12
        uint256 position1Reward = 604800 * 1e12;
        uint256 position2Reward = 1814400 * 1e12;
        uint256 expectedTotal = position1Reward + position2Reward;
        assertEq(amounts[0], expectedTotal);
    }
    
    function test_ClaimAllRewards() public {
        // Setup
        vm.prank(admin);
        rewardsManager.registerProgram(address(rdatModule), "RDAT", 0, 0);
        
        // Create positions
        stakingPositions.mockStake(alice, 1, STAKE_AMOUNT, 30 days);
        vm.prank(address(stakingPositions));
        rewardsManager.notifyStake(alice, 1, STAKE_AMOUNT, 30 days);
        
        stakingPositions.mockStake(alice, 2, STAKE_AMOUNT, 90 days);
        vm.prank(address(stakingPositions));
        rewardsManager.notifyStake(alice, 2, STAKE_AMOUNT, 90 days);
        
        // Fast forward
        vm.warp(block.timestamp + 3 days);
        
        uint256 balanceBefore = rdat.balanceOf(alice);
        
        vm.prank(alice);
        IRewardsManager.ClaimInfo[] memory claims = rewardsManager.claimAllRewards();
        
        assertGt(claims.length, 0);
        
        uint256 totalClaimed = 0;
        for (uint256 i = 0; i < claims.length; i++) {
            totalClaimed += claims[i].amount;
        }
        
        assertEq(rdat.balanceOf(alice), balanceBefore + totalClaimed);
    }
    
    function test_NotifyRevenueReward() public {
        // Setup RDAT program with specific name
        vm.prank(admin);
        rewardsManager.registerProgram(
            address(rdatModule),
            "RDAT Staking Rewards", // Must match exactly
            0,
            0
        );
        
        uint256 revenueAmount = 50_000 * 10**18;
        uint256 allocationBefore = rdatModule.totalAllocated();
        
        // Notify revenue
        vm.prank(admin);
        rewardsManager.notifyRevenueReward(revenueAmount);
        
        // Verify allocation increased
        assertEq(rdatModule.totalAllocated(), allocationBefore + revenueAmount);
    }
    
    function test_AccessControl() public {
        // Try to register program as non-admin
        vm.prank(alice);
        vm.expectRevert();
        rewardsManager.registerProgram(address(vrdatModule), "Test", 0, 0);
        
        // Try to notify stake as non-staking manager
        vm.prank(alice);
        vm.expectRevert(IRewardsManager.NotStakingManager.selector);
        rewardsManager.notifyStake(alice, 1, 1000, 30 days);
        
        // Try to set staking manager as non-admin
        vm.prank(alice);
        vm.expectRevert();
        rewardsManager.setStakingManager(address(0x999));
    }
    
    function test_InvalidProgramOperations() public {
        // Try to get non-existent program
        IRewardsManager.RewardProgram memory program = rewardsManager.getProgram(999);
        assertEq(program.rewardModule, address(0));
        
        // Try to update non-existent program
        vm.prank(admin);
        vm.expectRevert(IRewardsManager.ProgramNotFound.selector);
        rewardsManager.updateProgramStatus(999, false);
    }
    
    function test_ProgramWithFutureStart() public {
        vm.prank(admin);
        
        uint256 futureTime = block.timestamp + 7 days;
        uint256 programId = rewardsManager.registerProgram(
            address(rdatModule),
            "Future Program",
            futureTime,
            30 days
        );
        
        IRewardsManager.RewardProgram memory program = rewardsManager.getProgram(programId);
        assertEq(program.startTime, futureTime);
        assertEq(program.endTime, futureTime + 30 days);
        
        // Program should not be in active list yet
        uint256[] memory activePrograms = rewardsManager.getActivePrograms();
        assertEq(activePrograms.length, 0);
        
        // Fast forward past start time
        vm.warp(futureTime + 1);
        
        activePrograms = rewardsManager.getActivePrograms();
        assertEq(activePrograms.length, 1);
        assertEq(activePrograms[0], programId);
    }
}