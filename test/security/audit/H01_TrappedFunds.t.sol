// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../../../src/StakingPositions.sol";
import "../../../src/RDATUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title H01_TrappedFunds Test
 * @notice Tests for HIGH severity issue H-01: Penalty and Revenue Funds Trapped in StakingPositions
 * @dev Verifies that penalty funds and revenue rewards can be properly recovered/distributed
 */
contract H01_TrappedFundsTest is Test {
    StakingPositions public stakingPositions;
    RDATUpgradeable public rdatToken;

    address public admin = address(0x1000);
    address public treasury = address(0x2000);
    address public revenueCollector = address(0x3000);
    address public user1 = address(0x4000);
    address public user2 = address(0x5000);

    uint256 public constant INITIAL_BALANCE = 10000 * 1e18;
    uint256 public constant STAKE_AMOUNT = 1000 * 1e18;

    function setUp() public {
        // Deploy RDAT token
        RDATUpgradeable implementation = new RDATUpgradeable();
        bytes memory initData = abi.encodeWithSelector(
            RDATUpgradeable.initialize.selector,
            treasury,
            admin,
            address(1) // migration bridge (dummy address for testing)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        rdatToken = RDATUpgradeable(address(proxy));

        // Deploy StakingPositions
        StakingPositions stakingImpl = new StakingPositions();
        bytes memory stakingInitData = abi.encodeWithSelector(
            StakingPositions.initialize.selector,
            address(rdatToken),
            address(0x9000), // vRDAT token (dummy address for testing)
            admin
        );
        ERC1967Proxy stakingProxy = new ERC1967Proxy(address(stakingImpl), stakingInitData);
        stakingPositions = StakingPositions(address(stakingProxy));

        // Setup roles
        vm.startPrank(admin);
        stakingPositions.grantRole(stakingPositions.REVENUE_COLLECTOR_ROLE(), revenueCollector);
        vm.stopPrank();

        // Setup test tokens
        vm.startPrank(treasury);
        rdatToken.transfer(user1, INITIAL_BALANCE);
        rdatToken.transfer(user2, INITIAL_BALANCE);
        rdatToken.transfer(revenueCollector, INITIAL_BALANCE);
        vm.stopPrank();
    }

    /**
     * @notice Test that demonstrates the trapped penalty funds issue
     * @dev This test should FAIL with current implementation, PASS after fix
     */
    function test_PenaltyFundsTrapped() public {
        // User stakes tokens
        vm.startPrank(user1);
        rdatToken.approve(address(stakingPositions), STAKE_AMOUNT);
        uint256 positionId = stakingPositions.stake(STAKE_AMOUNT, 90 days);
        vm.stopPrank();

        // Verify initial balance (should have the staked amount)
        uint256 contractBalanceBefore = rdatToken.balanceOf(address(stakingPositions));
        assertEq(contractBalanceBefore, STAKE_AMOUNT, "Initial balance incorrect");

        // User performs emergency withdrawal (50% penalty)
        vm.startPrank(user1);
        stakingPositions.emergencyWithdraw(positionId);
        vm.stopPrank();

        // Calculate penalty amount (50% of staked amount)
        uint256 penaltyAmount = STAKE_AMOUNT / 2;
        uint256 contractBalanceAfter = rdatToken.balanceOf(address(stakingPositions));

        // Verify penalty is trapped in contract (balance should be the penalty amount)
        assertEq(contractBalanceAfter, penaltyAmount, "Penalty not trapped in contract");

        // Test that rescueTokens still cannot be used for RDAT
        vm.startPrank(admin);
        vm.expectRevert("Cannot rescue RDAT");
        stakingPositions.rescueTokens(address(rdatToken), penaltyAmount);
        vm.stopPrank();

        // Test the new withdrawPenalties function (our fix)
        uint256 treasuryBalanceBefore = rdatToken.balanceOf(treasury);

        // Grant TREASURY_ROLE to treasury address
        vm.startPrank(admin);
        stakingPositions.grantRole(stakingPositions.TREASURY_ROLE(), treasury);
        vm.stopPrank();

        // Treasury withdraws penalties
        vm.startPrank(treasury);
        stakingPositions.withdrawPenalties(treasury);
        vm.stopPrank();

        // Verify penalties transferred to treasury
        uint256 treasuryBalanceAfter = rdatToken.balanceOf(treasury);
        assertEq(treasuryBalanceAfter - treasuryBalanceBefore, penaltyAmount, "Penalties not transferred to treasury");

        // Verify contract balance is now 0
        assertEq(rdatToken.balanceOf(address(stakingPositions)), 0, "Contract should have 0 balance after withdrawal");
    }

    /**
     * @notice Test that demonstrates the trapped revenue rewards issue
     * @dev Revenue deposited via notifyRewardAmount cannot be distributed
     */
    function test_RevenueRewardsTrapped() public {
        uint256 rewardAmount = 500 * 1e18;

        // Revenue collector deposits rewards
        vm.startPrank(revenueCollector);
        rdatToken.approve(address(stakingPositions), rewardAmount);
        stakingPositions.notifyRewardAmount(rewardAmount);
        vm.stopPrank();

        // Verify rewards are in contract
        assertEq(rdatToken.balanceOf(address(stakingPositions)), rewardAmount, "Rewards not in contract");

        // User stakes to be eligible for rewards
        vm.startPrank(user1);
        rdatToken.approve(address(stakingPositions), STAKE_AMOUNT);
        uint256 positionId = stakingPositions.stake(STAKE_AMOUNT, 30 days);
        vm.stopPrank();

        // Fast forward time
        vm.warp(block.timestamp + 30 days);

        // Try to claim rewards - should revert with current implementation
        vm.startPrank(user1);
        vm.expectRevert("Use RewardsManager.claimRewards directly");
        stakingPositions.claimRewards(positionId);
        vm.stopPrank();

        // Verify funds are still trapped
        assertTrue(rdatToken.balanceOf(address(stakingPositions)) >= rewardAmount, "Rewards should be trapped");

        // TODO: After fix, implement proper reward distribution test
    }

    /**
     * @notice Test the proposed fix: withdrawPenalties function
     * @dev This test is for the PROPOSED SOLUTION
     */
    function test_ProposedFix_WithdrawPenalties() public {
        // This test will be uncommented after implementing the fix
        /*
        // Setup: User stakes and emergency withdraws
        vm.startPrank(user1);
        rdatToken.approve(address(stakingPositions), STAKE_AMOUNT);
        uint256 positionId = stakingPositions.stake(STAKE_AMOUNT, 90 days);
        stakingPositions.emergencyWithdraw(positionId);
        vm.stopPrank();
        
        uint256 penaltyAmount = STAKE_AMOUNT / 2;
        uint256 treasuryBalanceBefore = rdatToken.balanceOf(treasury);
        
        // Treasury withdraws penalties
        vm.startPrank(treasury);
        stakingPositions.withdrawPenalties(penaltyAmount);
        vm.stopPrank();
        
        // Verify penalties transferred to treasury
        assertEq(
            rdatToken.balanceOf(treasury) - treasuryBalanceBefore,
            penaltyAmount,
            "Penalties not transferred to treasury"
        );
        
        // Verify non-treasury cannot withdraw
        vm.startPrank(user1);
        vm.expectRevert("Unauthorized");
        stakingPositions.withdrawPenalties(penaltyAmount);
        vm.stopPrank();
        */
    }

    /**
     * @notice Test cumulative penalty tracking
     * @dev Ensures multiple penalties are properly accumulated
     */
    function test_MultiplePenaltiesAccumulation() public {
        // Multiple users stake
        vm.startPrank(user1);
        rdatToken.approve(address(stakingPositions), STAKE_AMOUNT);
        uint256 position1 = stakingPositions.stake(STAKE_AMOUNT, 30 days);
        vm.stopPrank();

        vm.startPrank(user2);
        rdatToken.approve(address(stakingPositions), STAKE_AMOUNT);
        uint256 position2 = stakingPositions.stake(STAKE_AMOUNT, 90 days);
        vm.stopPrank();

        // Both perform emergency withdrawals
        vm.prank(user1);
        stakingPositions.emergencyWithdraw(position1);

        vm.prank(user2);
        stakingPositions.emergencyWithdraw(position2);

        // Total penalties should be accumulated
        uint256 totalPenalties = STAKE_AMOUNT; // 50% of 2 * STAKE_AMOUNT
        assertEq(rdatToken.balanceOf(address(stakingPositions)), totalPenalties, "Penalties not properly accumulated");

        // TODO: After fix, verify all penalties can be withdrawn at once
    }
}
