// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Staking} from "../../src/Staking.sol";
import {RDATUpgradeable} from "../../src/RDATUpgradeable.sol";
import {vRDAT} from "../../src/vRDAT.sol";
import {IStaking} from "../../src/interfaces/IStaking.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract StakingTest is Test {
    Staking public staking;
    RDATUpgradeable public rdatImplementation;
    RDATUpgradeable public rdat;
    vRDAT public vrdat;
    
    address public admin;
    address public treasury;
    address public user1;
    address public user2;
    address public user3;
    
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    uint256 public constant INITIAL_BALANCE = 100_000 * 10**18;
    
    event Staked(address indexed user, uint256 amount, uint256 lockPeriod, uint256 multiplier);
    event Unstaked(address indexed user, uint256 amount, uint256 vrdatBurned);
    event RewardsClaimed(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount, uint256 penalty);
    
    function setUp() public {
        admin = makeAddr("admin");
        treasury = makeAddr("treasury");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        
        // Deploy RDAT with proxy
        vm.startPrank(admin);
        
        rdatImplementation = new RDATUpgradeable();
        bytes memory initData = abi.encodeWithSelector(
            RDATUpgradeable.initialize.selector,
            treasury,
            admin
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(rdatImplementation),
            initData
        );
        
        rdat = RDATUpgradeable(address(proxy));
        
        // Deploy vRDAT
        vrdat = new vRDAT(admin);
        
        // Deploy Staking
        staking = new Staking(
            address(rdat),
            address(vrdat),
            admin
        );
        
        // Grant roles
        rdat.grantRole(MINTER_ROLE, address(staking)); // Staking can mint rewards
        vrdat.grantRole(MINTER_ROLE, address(staking)); // Staking can mint vRDAT
        vrdat.grantRole(BURNER_ROLE, address(staking)); // Staking can burn vRDAT
        
        vm.stopPrank();
        
        // Give users some RDAT using deal to avoid transfer
        deal(address(rdat), user1, INITIAL_BALANCE);
        deal(address(rdat), user2, INITIAL_BALANCE);
        deal(address(rdat), user3, INITIAL_BALANCE);
        
        // Reduce treasury balance accordingly
        deal(address(rdat), treasury, rdat.balanceOf(treasury) - 3 * INITIAL_BALANCE);
        
        // Approve staking contract
        vm.prank(user1);
        IERC20(address(rdat)).approve(address(staking), type(uint256).max);
        
        vm.prank(user2);
        IERC20(address(rdat)).approve(address(staking), type(uint256).max);
        
        vm.prank(user3);
        IERC20(address(rdat)).approve(address(staking), type(uint256).max);
    }
    
    function test_InitialState() public {
        assertEq(staking.totalStaked(), 0);
        assertEq(staking.totalRewardsDistributed(), 0);
        assertEq(staking.rewardRate(), 100);
        
        assertEq(staking.lockMultipliers(staking.MONTH_1()), 10000);
        assertEq(staking.lockMultipliers(staking.MONTH_3()), 15000);
        assertEq(staking.lockMultipliers(staking.MONTH_6()), 20000);
        assertEq(staking.lockMultipliers(staking.MONTH_12()), 40000);
        
        assertEq(staking.rdatToken(), address(rdat));
        assertEq(staking.vrdatToken(), address(vrdat));
    }
    
    function test_StakeMonth1() public {
        uint256 stakeAmount = 1000 * 10**18;
        
        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit Staked(user1, stakeAmount, staking.MONTH_1(), 10000);
        staking.stake(stakeAmount, staking.MONTH_1());
        
        // Check balances
        assertEq(rdat.balanceOf(user1), INITIAL_BALANCE - stakeAmount);
        assertEq(rdat.balanceOf(address(staking)), stakeAmount);
        assertEq(vrdat.balanceOf(user1), stakeAmount); // 1:1 vRDAT minted
        
        // Check stake info
        IStaking.StakeInfo memory info = staking.stakes(user1);
        assertEq(info.amount, stakeAmount);
        assertEq(info.lockPeriod, staking.MONTH_1());
        assertEq(info.multiplier, 10000);
        assertEq(info.vrdatMinted, stakeAmount);
        
        // Check global state
        assertEq(staking.totalStaked(), stakeAmount);
    }
    
    function test_StakeMultipleLockPeriods() public {
        uint256 stakeAmount = 1000 * 10**18;
        
        // Test all lock periods
        vm.prank(user1);
        staking.stake(stakeAmount, staking.MONTH_3());
        assertEq(staking.stakes(user1).multiplier, 15000);
        
        // User2 stakes for 6 months
        vm.prank(user2);
        staking.stake(stakeAmount, staking.MONTH_6());
        assertEq(staking.stakes(user2).multiplier, 20000);
        
        // User3 stakes for 12 months
        vm.prank(user3);
        staking.stake(stakeAmount, staking.MONTH_12());
        assertEq(staking.stakes(user3).multiplier, 40000);
    }
    
    function test_StakeZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert(IStaking.ZeroAmount.selector);
        staking.stake(0, staking.MONTH_1());
    }
    
    function test_StakeInvalidLockPeriod() public {
        vm.prank(user1);
        vm.expectRevert(IStaking.InvalidLockDuration.selector);
        staking.stake(1000 * 10**18, 45 days); // Not a valid period
    }
    
    function test_StakeExceedsMaxPerUser() public {
        uint256 maxStake = staking.MAX_STAKE_PER_USER();
        
        vm.prank(user1);
        vm.expectRevert(IStaking.ExceedsMaxStakePerUser.selector);
        staking.stake(maxStake + 1, staking.MONTH_1());
    }
    
    function test_AddToExistingStake() public {
        uint256 stakeAmount = 1000 * 10**18;
        
        // Initial stake
        vm.prank(user1);
        staking.stake(stakeAmount, staking.MONTH_3());
        
        // Add more to existing stake
        vm.prank(user1);
        staking.stake(stakeAmount, staking.MONTH_1()); // Lock period ignored, uses existing
        
        IStaking.StakeInfo memory info = staking.stakes(user1);
        assertEq(info.amount, stakeAmount * 2);
        assertEq(info.lockPeriod, staking.MONTH_3()); // Kept original lock period
        assertEq(info.vrdatMinted, stakeAmount * 2);
    }
    
    function test_CannotAddToExpiredStake() public {
        uint256 stakeAmount = 1000 * 10**18;
        
        // Initial stake
        vm.prank(user1);
        staking.stake(stakeAmount, staking.MONTH_1());
        
        // Fast forward past lock period
        vm.warp(block.timestamp + staking.MONTH_1() + 1);
        
        // Try to add more
        vm.prank(user1);
        vm.expectRevert("Existing stake expired");
        staking.stake(stakeAmount, staking.MONTH_1());
    }
    
    function test_UnstakeAfterLockPeriod() public {
        uint256 stakeAmount = 1000 * 10**18;
        
        // Stake
        vm.prank(user1);
        staking.stake(stakeAmount, staking.MONTH_1());
        
        // Fast forward past lock period
        vm.warp(block.timestamp + staking.MONTH_1() + 1);
        
        // Unstake
        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit Unstaked(user1, stakeAmount, stakeAmount);
        staking.unstake();
        
        // Check balances
        assertEq(rdat.balanceOf(user1), INITIAL_BALANCE); // Got back original amount
        assertEq(vrdat.balanceOf(user1), 0); // vRDAT burned
        assertEq(staking.totalStaked(), 0);
        
        // Check stake cleared
        IStaking.StakeInfo memory info = staking.stakes(user1);
        assertEq(info.amount, 0);
    }
    
    function test_CannotUnstakeBeforeLockPeriod() public {
        uint256 stakeAmount = 1000 * 10**18;
        
        // Stake
        vm.prank(user1);
        staking.stake(stakeAmount, staking.MONTH_1());
        
        // Try to unstake immediately
        vm.prank(user1);
        vm.expectRevert(IStaking.StakeStillLocked.selector);
        staking.unstake();
    }
    
    function test_CannotUnstakeWithoutStake() public {
        vm.prank(user1);
        vm.expectRevert(IStaking.InsufficientBalance.selector);
        staking.unstake();
    }
    
    function test_CalculateRewards() public {
        uint256 stakeAmount = 1000 * 10**18;
        
        // Stake with 1.5x multiplier (3 months)
        vm.prank(user1);
        staking.stake(stakeAmount, staking.MONTH_3());
        
        // Fast forward 1 day
        vm.warp(block.timestamp + 1 days);
        
        // Calculate expected rewards
        // rate = 100 (0.01% with PRECISION)
        // time = 86400 seconds (1 day)
        // multiplier = 15000 (1.5x with PRECISION)
        // rewards = 1000e18 * 100 * 86400 * 15000 / (10000 * 10000)
        uint256 expectedRewards = (stakeAmount * 100 * 86400 * 15000) / (10000 * 10000);
        
        uint256 pendingRewards = staking.calculatePendingRewards(user1);
        assertEq(pendingRewards, expectedRewards);
    }
    
    function test_ClaimRewards() public {
        uint256 stakeAmount = 1000 * 10**18;
        
        // Stake
        vm.prank(user1);
        staking.stake(stakeAmount, staking.MONTH_1());
        
        uint256 balanceBefore = rdat.balanceOf(user1);
        
        // Fast forward to accumulate rewards
        vm.warp(block.timestamp + 7 days);
        
        uint256 expectedRewards = staking.calculatePendingRewards(user1);
        
        // Claim rewards
        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit RewardsClaimed(user1, expectedRewards);
        staking.claimRewards();
        
        // Check balance increased by rewards
        assertEq(rdat.balanceOf(user1), balanceBefore + expectedRewards);
        assertEq(staking.totalRewardsDistributed(), expectedRewards);
        
        // Check cannot claim again immediately
        vm.prank(user1);
        vm.expectRevert(IStaking.NoRewardsToClaim.selector);
        staking.claimRewards();
    }
    
    function test_EmergencyWithdraw() public {
        uint256 stakeAmount = 1000 * 10**18;
        
        // Stake for 12 months
        vm.prank(user1);
        staking.stake(stakeAmount, staking.MONTH_12());
        
        // Emergency withdraw immediately
        uint256 penalty = (stakeAmount * staking.EMERGENCY_WITHDRAW_PENALTY()) / 100;
        uint256 expectedWithdraw = stakeAmount - penalty;
        
        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit EmergencyWithdraw(user1, expectedWithdraw, penalty);
        staking.emergencyWithdraw();
        
        // Check user got 50% back
        assertEq(rdat.balanceOf(user1), INITIAL_BALANCE - penalty);
        
        // Check penalty stayed in contract
        assertEq(rdat.balanceOf(address(staking)), penalty);
        
        // Check vRDAT burned
        assertEq(vrdat.balanceOf(user1), 0);
        
        // Check stake cleared
        IStaking.StakeInfo memory info = staking.stakes(user1);
        assertEq(info.amount, 0);
    }
    
    function test_CanUnstake() public {
        assertFalse(staking.canUnstake(user1)); // No stake
        
        // Stake
        vm.prank(user1);
        staking.stake(1000 * 10**18, staking.MONTH_1());
        
        assertFalse(staking.canUnstake(user1)); // Still locked
        
        // Fast forward
        vm.warp(block.timestamp + staking.MONTH_1() + 1);
        
        assertTrue(staking.canUnstake(user1)); // Can unstake now
    }
    
    function test_GetStakeEndTime() public {
        assertEq(staking.getStakeEndTime(user1), 0); // No stake
        
        uint256 stakeTime = block.timestamp;
        
        // Stake
        vm.prank(user1);
        staking.stake(1000 * 10**18, staking.MONTH_1());
        
        assertEq(staking.getStakeEndTime(user1), stakeTime + staking.MONTH_1());
    }
    
    function test_SetRewardRate() public {
        uint256 newRate = 200;
        
        vm.prank(admin);
        staking.setRewardRate(newRate);
        
        assertEq(staking.rewardRate(), newRate);
    }
    
    function test_SetRewardRateUnauthorized() public {
        vm.prank(user1);
        vm.expectRevert();
        staking.setRewardRate(200);
    }
    
    function test_SetMultipliers() public {
        vm.prank(admin);
        staking.setMultipliers(12000, 18000, 25000, 50000);
        
        assertEq(staking.lockMultipliers(staking.MONTH_1()), 12000);
        assertEq(staking.lockMultipliers(staking.MONTH_3()), 18000);
        assertEq(staking.lockMultipliers(staking.MONTH_6()), 25000);
        assertEq(staking.lockMultipliers(staking.MONTH_12()), 50000);
    }
    
    function test_SetMultipliersInvalid() public {
        vm.prank(admin);
        vm.expectRevert(IStaking.InvalidMultiplier.selector);
        staking.setMultipliers(0, 18000, 25000, 50000); // Zero multiplier
    }
    
    function test_PauseUnpause() public {
        // Pause
        vm.prank(admin);
        staking.pause();
        
        // Cannot stake when paused
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        staking.stake(1000 * 10**18, staking.MONTH_1());
        
        // Unpause
        vm.prank(admin);
        staking.unpause();
        
        // Can stake again
        vm.prank(user1);
        staking.stake(1000 * 10**18, staking.MONTH_1());
    }
    
    function test_RescueTokens() public {
        // Deploy a mock token
        MockERC20 mockToken = new MockERC20();
        mockToken.mint(address(staking), 1000 * 10**18);
        
        uint256 adminBalanceBefore = mockToken.balanceOf(admin);
        
        // Rescue tokens
        vm.prank(admin);
        staking.rescueTokens(address(mockToken), 1000 * 10**18);
        
        assertEq(mockToken.balanceOf(admin), adminBalanceBefore + 1000 * 10**18);
        assertEq(mockToken.balanceOf(address(staking)), 0);
    }
    
    function test_CannotRescueRDAT() public {
        vm.prank(admin);
        vm.expectRevert("Cannot rescue RDAT");
        staking.rescueTokens(address(rdat), 1000);
    }
    
    function test_MultipleUsersStaking() public {
        uint256 stakeAmount = 1000 * 10**18;
        
        // Multiple users stake
        vm.prank(user1);
        staking.stake(stakeAmount, staking.MONTH_1());
        
        vm.prank(user2);
        staking.stake(stakeAmount * 2, staking.MONTH_3());
        
        vm.prank(user3);
        staking.stake(stakeAmount * 3, staking.MONTH_12());
        
        // Check total staked
        assertEq(staking.totalStaked(), stakeAmount * 6);
        
        // Check individual stakes
        assertEq(staking.stakes(user1).amount, stakeAmount);
        assertEq(staking.stakes(user2).amount, stakeAmount * 2);
        assertEq(staking.stakes(user3).amount, stakeAmount * 3);
        
        // Check multipliers
        assertEq(staking.stakes(user1).multiplier, 10000);
        assertEq(staking.stakes(user2).multiplier, 15000);
        assertEq(staking.stakes(user3).multiplier, 40000);
    }
    
    function test_RewardsWithDifferentMultipliers() public {
        uint256 stakeAmount = 1000 * 10**18;
        
        // Two users stake same amount, different lock periods
        vm.prank(user1);
        staking.stake(stakeAmount, staking.MONTH_1()); // 1x multiplier
        
        vm.prank(user2);
        staking.stake(stakeAmount, staking.MONTH_12()); // 4x multiplier
        
        // Fast forward
        vm.warp(block.timestamp + 1 days);
        
        uint256 rewards1 = staking.calculatePendingRewards(user1);
        uint256 rewards2 = staking.calculatePendingRewards(user2);
        
        // User2 should have 4x rewards
        assertEq(rewards2, rewards1 * 4);
    }
}

// Mock ERC20 for testing rescue function
contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}