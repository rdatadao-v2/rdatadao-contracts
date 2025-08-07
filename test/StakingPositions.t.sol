// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../src/StakingPositions.sol";
import "../src/interfaces/IStakingPositions.sol";
import "../src/RDATUpgradeable.sol";
import "../src/vRDAT.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract StakingPositionsTest is Test {
    StakingPositions public staking;
    RDATUpgradeable public rdat;
    vRDAT public vrdat;

    address public admin = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);
    address public treasury = address(0x4);

    uint256 constant INITIAL_BALANCE = 1_000_000 * 10 ** 18;
    uint256 constant STAKE_AMOUNT = 1000 * 10 ** 18;

    event Staked(
        address indexed user, uint256 indexed positionId, uint256 amount, uint256 lockPeriod, uint256 multiplier
    );
    event Unstaked(address indexed user, uint256 indexed positionId, uint256 amount, uint256 vrdatBurned);
    event RewardsClaimed(address indexed user, uint256 indexed positionId, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed positionId, uint256 amountReceived, uint256 penalty);

    function setUp() public {
        vm.startPrank(admin);

        // Deploy RDAT with proxy
        RDATUpgradeable rdatImpl = new RDATUpgradeable();
        bytes memory rdatInitData = abi.encodeCall(
            rdatImpl.initialize,
            (treasury, admin, address(0x100)) // migration contract address
        );
        ERC1967Proxy rdatProxy = new ERC1967Proxy(address(rdatImpl), rdatInitData);
        rdat = RDATUpgradeable(address(rdatProxy));

        // Deploy vRDAT
        vrdat = new vRDAT(admin);

        // Fast forward to bypass initial mint delay
        // No mint delay needed for soul-bound tokens

        // Deploy StakingPositions with proxy
        StakingPositions stakingImpl = new StakingPositions();
        bytes memory stakingInitData = abi.encodeCall(stakingImpl.initialize, (address(rdat), address(vrdat), admin));
        ERC1967Proxy stakingProxy = new ERC1967Proxy(address(stakingImpl), stakingInitData);
        staking = StakingPositions(address(stakingProxy));

        // Setup roles
        // vRDAT minting/burning is now handled by RewardsManager modules
        // RDAT no longer has MINTER_ROLE - all tokens minted at deployment

        // Transfer tokens from treasury to test users (no minting)
        vm.stopPrank();
        vm.startPrank(treasury);
        rdat.transfer(alice, INITIAL_BALANCE);
        rdat.transfer(bob, INITIAL_BALANCE);
        vm.stopPrank();

        // Approve staking contract
        vm.prank(alice);
        rdat.approve(address(staking), type(uint256).max);

        vm.prank(bob);
        rdat.approve(address(staking), type(uint256).max);
    }

    function testStakeCreatesPosition() public {
        vm.startPrank(alice);

        uint256 balanceBefore = rdat.balanceOf(alice);

        vm.expectEmit(true, true, false, true);
        emit Staked(alice, 1, STAKE_AMOUNT, staking.MONTH_1(), 10000);

        uint256 positionId = staking.stake(STAKE_AMOUNT, staking.MONTH_1());

        assertEq(positionId, 1);
        assertEq(staking.ownerOf(positionId), alice);
        assertEq(rdat.balanceOf(alice), balanceBefore - STAKE_AMOUNT);
        assertEq(staking.totalStaked(), STAKE_AMOUNT);

        StakingPositions.Position memory position = staking.getPosition(positionId);
        assertEq(position.amount, STAKE_AMOUNT);
        assertEq(position.lockPeriod, staking.MONTH_1());
        assertEq(position.multiplier, 10000);
        assertEq(position.vrdatMinted, STAKE_AMOUNT);

        vm.stopPrank();
    }

    function testMultipleStakesCreateMultiplePositions() public {
        vm.startPrank(alice);

        // Create first position
        uint256 position1 = staking.stake(STAKE_AMOUNT, staking.MONTH_1());
        assertEq(position1, 1);

        // Warp time to bypass mint delay
        // No mint delay needed for soul-bound tokens

        // Create second position with different lock period
        uint256 position2 = staking.stake(STAKE_AMOUNT * 2, staking.MONTH_3());
        assertEq(position2, 2);

        // Warp time to bypass mint delay
        // No mint delay needed for soul-bound tokens

        // Create third position
        uint256 position3 = staking.stake(STAKE_AMOUNT / 2, staking.MONTH_12());
        assertEq(position3, 3);

        // Verify all positions exist
        assertEq(staking.balanceOf(alice), 3);
        assertEq(staking.ownerOf(position1), alice);
        assertEq(staking.ownerOf(position2), alice);
        assertEq(staking.ownerOf(position3), alice);

        // Verify positions have correct data
        StakingPositions.Position memory pos1 = staking.getPosition(position1);
        assertEq(pos1.amount, STAKE_AMOUNT);
        assertEq(pos1.multiplier, 10000); // 1x

        StakingPositions.Position memory pos2 = staking.getPosition(position2);
        assertEq(pos2.amount, STAKE_AMOUNT * 2);
        assertEq(pos2.multiplier, 15000); // 1.5x

        StakingPositions.Position memory pos3 = staking.getPosition(position3);
        assertEq(pos3.amount, STAKE_AMOUNT / 2);
        assertEq(pos3.multiplier, 40000); // 4x

        // Verify total staked
        assertEq(staking.totalStaked(), STAKE_AMOUNT + STAKE_AMOUNT * 2 + STAKE_AMOUNT / 2);

        // vRDAT minting is now handled by RewardsManager modules
        // StakingPositions no longer mints vRDAT directly
        assertEq(vrdat.balanceOf(alice), 0);

        vm.stopPrank();
    }

    function testGetUserPositions() public {
        vm.startPrank(alice);

        // Create multiple positions
        staking.stake(STAKE_AMOUNT, staking.MONTH_1());

        // No mint delay needed for soul-bound tokens
        staking.stake(STAKE_AMOUNT, staking.MONTH_3());

        // No mint delay needed for soul-bound tokens
        staking.stake(STAKE_AMOUNT, staking.MONTH_6());

        uint256[] memory positions = staking.getUserPositions(alice);
        assertEq(positions.length, 3);
        assertEq(positions[0], 1);
        assertEq(positions[1], 2);
        assertEq(positions[2], 3);

        vm.stopPrank();
    }

    function testUnstakeAfterLockPeriod() public {
        vm.startPrank(alice);

        uint256 positionId = staking.stake(STAKE_AMOUNT, staking.MONTH_1());

        // Get the position to know how much vRDAT was minted
        StakingPositions.Position memory position = staking.getPosition(positionId);
        uint256 vrdatMinted = position.vrdatMinted;

        // Try to unstake before lock period ends
        vm.expectRevert(IStakingPositions.StakeStillLocked.selector);
        staking.unstake(positionId);

        // Fast forward past lock period
        vm.warp(block.timestamp + staking.MONTH_1() + 1);

        vm.expectEmit(true, true, false, true);
        emit Unstaked(alice, positionId, STAKE_AMOUNT, vrdatMinted);

        staking.unstake(positionId);

        // Verify position is burned
        vm.expectRevert();
        staking.ownerOf(positionId);

        // Verify tokens returned (may include rewards if reward rate is set)
        assertGe(rdat.balanceOf(alice), INITIAL_BALANCE);
        assertEq(staking.totalStaked(), 0);

        // vRDAT burning is now handled by RewardsManager modules
        assertEq(vrdat.balanceOf(alice), 0);

        vm.stopPrank();
    }

    function testTransferBlockedDuringLock() public {
        vm.startPrank(alice);

        uint256 positionId = staking.stake(STAKE_AMOUNT, staking.MONTH_1());

        // Try to transfer while locked
        vm.expectRevert(IStakingPositions.TransferWhileLocked.selector);
        staking.transferFrom(alice, bob, positionId);

        vm.stopPrank();
    }

    function testTransferAllowedAfterUnlock() public {
        vm.startPrank(alice);

        uint256 positionId = staking.stake(STAKE_AMOUNT, staking.MONTH_1());

        // Fast forward past lock period
        vm.warp(block.timestamp + staking.MONTH_1() + 1);

        // Transfer should NOT work if vRDAT is still active
        // Users must emergency withdraw first to burn vRDAT
        vm.expectRevert(IStakingPositions.TransferWithActiveRewards.selector);
        staking.transferFrom(alice, bob, positionId);

        // Emergency withdraw to burn vRDAT (enables transfer)
        staking.emergencyWithdraw(positionId);

        vm.stopPrank();
    }

    function testEmergencyWithdraw() public {
        vm.startPrank(alice);

        uint256 positionId = staking.stake(STAKE_AMOUNT, staking.MONTH_12());

        uint256 expectedPenalty = STAKE_AMOUNT / 2; // 50% penalty
        uint256 expectedReturn = STAKE_AMOUNT - expectedPenalty;

        vm.expectEmit(true, true, false, true);
        emit EmergencyWithdraw(alice, positionId, expectedReturn, expectedPenalty);

        staking.emergencyWithdraw(positionId);

        // Verify position is burned
        vm.expectRevert();
        staking.ownerOf(positionId);

        // Verify reduced tokens returned
        assertEq(rdat.balanceOf(alice), INITIAL_BALANCE - STAKE_AMOUNT + expectedReturn);

        // vRDAT burning is now handled by RewardsManager modules
        assertEq(vrdat.balanceOf(alice), 0);

        vm.stopPrank();
    }

    function testRewardCalculation() public {
        vm.startPrank(alice);

        uint256 positionId = staking.stake(STAKE_AMOUNT, staking.MONTH_1());

        // Fast forward 1 day
        vm.warp(block.timestamp + 1 days);

        // In the new architecture, rewards are calculated by RewardsManager
        // StakingPositions always returns 0
        uint256 pendingRewards = staking.calculatePendingRewards(positionId);
        assertEq(pendingRewards, 0);

        vm.stopPrank();
    }

    function testClaimRewards() public {
        vm.startPrank(alice);

        uint256 positionId = staking.stake(STAKE_AMOUNT, staking.MONTH_1());

        // The new architecture requires users to claim rewards directly from RewardsManager
        // StakingPositions no longer handles reward claiming
        vm.expectRevert("Use RewardsManager.claimRewards directly");
        staking.claimRewards(positionId);

        vm.stopPrank();
    }

    function testClaimAllRewards() public {
        vm.startPrank(alice);

        // Create multiple positions
        staking.stake(STAKE_AMOUNT, staking.MONTH_1());
        staking.stake(STAKE_AMOUNT * 2, staking.MONTH_3());
        staking.stake(STAKE_AMOUNT / 2, staking.MONTH_6());

        // The new architecture requires users to claim rewards directly from RewardsManager
        // StakingPositions no longer handles reward claiming
        vm.expectRevert("Use RewardsManager.claimAllRewards directly");
        staking.claimAllRewards();

        vm.stopPrank();
    }

    function testInvalidLockPeriod() public {
        vm.startPrank(alice);

        vm.expectRevert(IStakingPositions.InvalidLockDuration.selector);
        staking.stake(STAKE_AMOUNT, 45 days); // Not a valid lock period

        vm.stopPrank();
    }

    function testZeroAmountStake() public {
        vm.startPrank(alice);

        vm.expectRevert();
        staking.stake(0, 30 days);

        vm.stopPrank();
    }

    function testNonExistentPosition() public {
        vm.expectRevert(IStakingPositions.PositionDoesNotExist.selector);
        staking.getPosition(999);

        vm.expectRevert(IStakingPositions.PositionDoesNotExist.selector);
        staking.unstake(999);

        vm.expectRevert(IStakingPositions.PositionDoesNotExist.selector);
        staking.claimRewards(999);
    }

    function testNotPositionOwner() public {
        vm.startPrank(alice);
        uint256 positionId = staking.stake(STAKE_AMOUNT, staking.MONTH_1());
        vm.stopPrank();

        vm.startPrank(bob);

        vm.expectRevert(IStakingPositions.NotPositionOwner.selector);
        staking.unstake(positionId);

        vm.expectRevert(IStakingPositions.NotPositionOwner.selector);
        staking.claimRewards(positionId);

        vm.expectRevert(IStakingPositions.NotPositionOwner.selector);
        staking.emergencyWithdraw(positionId);

        vm.stopPrank();
    }

    function testPauseUnpause() public {
        vm.prank(admin);
        staking.pause();

        vm.prank(alice);
        vm.expectRevert();
        staking.stake(STAKE_AMOUNT, 30 days);

        vm.prank(admin);
        staking.unpause();

        vm.prank(alice);
        uint256 positionId = staking.stake(STAKE_AMOUNT, 30 days);
        assertEq(positionId, 1);
    }

    function testSetMultipliers() public {
        vm.startPrank(admin);

        staking.setMultipliers(12000, 18000, 25000, 50000);

        assertEq(staking.lockMultipliers(staking.MONTH_1()), 12000);
        assertEq(staking.lockMultipliers(staking.MONTH_3()), 18000);
        assertEq(staking.lockMultipliers(staking.MONTH_6()), 25000);
        assertEq(staking.lockMultipliers(staking.MONTH_12()), 50000);

        vm.stopPrank();
    }

    function testRescueTokens() public {
        // Deploy a mock token using proxy pattern
        RDATUpgradeable mockTokenImpl = new RDATUpgradeable();
        bytes memory mockInitData = abi.encodeCall(
            mockTokenImpl.initialize,
            (treasury, admin, address(0x100)) // migration contract address
        );
        ERC1967Proxy mockTokenProxy = new ERC1967Proxy(address(mockTokenImpl), mockInitData);
        RDATUpgradeable mockToken = RDATUpgradeable(address(mockTokenProxy));

        // Transfer tokens from treasury (no minting)
        vm.startPrank(treasury);
        mockToken.transfer(address(staking), 1000 * 10 ** 18);
        vm.stopPrank();

        uint256 balanceBefore = mockToken.balanceOf(admin);

        vm.prank(admin);
        staking.rescueTokens(address(mockToken), 1000 * 10 ** 18);

        assertEq(mockToken.balanceOf(admin), balanceBefore + 1000 * 10 ** 18);
    }

    function testCannotRescueRDAT() public {
        vm.prank(admin);
        vm.expectRevert("Cannot rescue RDAT");
        staking.rescueTokens(address(rdat), 1000 * 10 ** 18);
    }
}
