// SPDX-License-Identifier: MIT
import "forge-std/console2.sol";

pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../src/StakingPositions.sol";
import "../src/examples/StakingPositionsV2Example.sol";
import "../src/RDATUpgradeable.sol";
import "../src/vRDAT.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title CrossContractUpgradeTest
 * @notice Tests complex upgrade scenarios involving multiple contracts
 * @dev Covers scenarios where RDAT is upgraded while staking positions are active
 */
contract CrossContractUpgradeTest is Test {
    StakingPositions public staking;
    RDATUpgradeable public rdat;
    vRDAT public vrdat;
    ERC1967Proxy public rdatProxy;
    ERC1967Proxy public stakingProxy;

    address public admin = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);
    address public treasury = address(0x5);

    uint256 constant INITIAL_BALANCE = 1_000_000 * 10 ** 18;
    uint256 constant STAKE_AMOUNT = 1000 * 10 ** 18;

    // Track test positions
    uint256 alicePosition1;
    uint256 alicePosition2;
    uint256 bobPosition1;

    function setUp() public {
        vm.startPrank(admin);

        // Deploy RDAT with proxy
        RDATUpgradeable rdatImpl = new RDATUpgradeable();
        bytes memory rdatInitData = abi.encodeCall(rdatImpl.initialize, (treasury, admin, address(0x100)));
        rdatProxy = new ERC1967Proxy(address(rdatImpl), rdatInitData);
        rdat = RDATUpgradeable(address(rdatProxy));

        // Deploy vRDAT
        vrdat = new vRDAT(admin);
        // No mint delay needed for soul-bound tokens

        // Deploy StakingPositions with proxy
        StakingPositions stakingImpl = new StakingPositions();
        bytes memory stakingInitData = abi.encodeCall(stakingImpl.initialize, (address(rdat), address(vrdat), admin));
        stakingProxy = new ERC1967Proxy(address(stakingImpl), stakingInitData);
        staking = StakingPositions(address(stakingProxy));

        // Setup roles (use staking contract address, not proxy separately)
        vrdat.grantRole(vrdat.MINTER_ROLE(), address(staking));
        vrdat.grantRole(vrdat.BURNER_ROLE(), address(staking));
        // RDAT no longer has MINTER_ROLE - all tokens minted at deployment

        // Set very low reward rate for upgrade tests to avoid supply overflow
        staking.setRewardRate(1); // Minimal rewards to avoid NoRewardsToClaim error

        // Transfer tokens from treasury to users (all tokens pre-minted)
        vm.startPrank(treasury);
        rdat.transfer(alice, INITIAL_BALANCE);
        rdat.transfer(bob, INITIAL_BALANCE);
        vm.stopPrank();

        vm.startPrank(admin);

        vm.stopPrank();

        // Users approve staking contract (both proxy and interface addresses)
        console2.log("Staking proxy address:", address(stakingProxy));
        console2.log("Staking interface address:", address(staking));

        vm.prank(alice);
        rdat.approve(address(staking), type(uint256).max);
        console2.log("Alice allowance after approval:", rdat.allowance(alice, address(staking)));

        vm.prank(bob);
        rdat.approve(address(staking), type(uint256).max);
        console2.log("Bob allowance after approval:", rdat.allowance(bob, address(staking)));
    }

    /**
     * @notice Test RDAT upgrade while staking positions are active
     * @dev Critical scenario: ensure staked tokens remain accessible after RDAT upgrade
     */
    function testRDATUpgradeWithActiveStakingPositions() public {
        // Step 1: Create active staking positions
        vm.startPrank(alice);
        alicePosition1 = staking.stake(STAKE_AMOUNT, staking.MONTH_1());
        // No mint delay needed for soul-bound tokens
        alicePosition2 = staking.stake(STAKE_AMOUNT * 2, staking.MONTH_6());
        vm.stopPrank();

        vm.startPrank(bob);
        bobPosition1 = staking.stake(STAKE_AMOUNT * 3, staking.MONTH_12());
        vm.stopPrank();

        // Record pre-upgrade state
        uint256 stakingRDATBalanceBefore = rdat.balanceOf(address(staking));
        uint256 aliceRDATBalanceBefore = rdat.balanceOf(alice);
        uint256 bobRDATBalanceBefore = rdat.balanceOf(bob);
        uint256 totalStakedBefore = staking.totalStaked();

        IStakingPositions.Position memory pos1Before = staking.getPosition(alicePosition1);
        IStakingPositions.Position memory pos2Before = staking.getPosition(alicePosition2);
        IStakingPositions.Position memory pos3Before = staking.getPosition(bobPosition1);

        console2.log("Pre-upgrade staking RDAT balance:", stakingRDATBalanceBefore);
        console2.log("Pre-upgrade total staked:", totalStakedBefore);

        // Step 2: Upgrade RDAT contract
        vm.startPrank(admin);
        RDATUpgradeableV2 newRdatImpl = new RDATUpgradeableV2();
        rdat.upgradeToAndCall(address(newRdatImpl), "");
        vm.stopPrank();

        // Step 3: Verify RDAT upgrade didn't break staking
        assertEq(rdat.balanceOf(address(staking)), stakingRDATBalanceBefore, "Staking contract lost RDAT tokens");
        assertEq(rdat.balanceOf(alice), aliceRDATBalanceBefore, "Alice lost RDAT tokens");
        assertEq(rdat.balanceOf(bob), bobRDATBalanceBefore, "Bob lost RDAT tokens");
        assertEq(staking.totalStaked(), totalStakedBefore, "Total staked amount changed");

        // Verify positions are intact
        IStakingPositions.Position memory pos1After = staking.getPosition(alicePosition1);
        IStakingPositions.Position memory pos2After = staking.getPosition(alicePosition2);
        IStakingPositions.Position memory pos3After = staking.getPosition(bobPosition1);

        assertEq(pos1After.amount, pos1Before.amount, "Position 1 amount changed");
        assertEq(pos2After.amount, pos2Before.amount, "Position 2 amount changed");
        assertEq(pos3After.amount, pos3Before.amount, "Position 3 amount changed");

        // Step 4: Test unstaking after RDAT upgrade (most critical test)
        // Fast forward past Alice's first position lock period (minimal time to avoid huge rewards)
        vm.warp(pos1Before.startTime + pos1Before.lockPeriod + 1);

        uint256 aliceRDATBeforeUnstake = rdat.balanceOf(alice);
        console2.log("Alice balance before unstake:", aliceRDATBeforeUnstake);
        console2.log("Position amount to unstake:", pos1Before.amount);

        // Note: We expect rewards to be minted during unstaking

        vm.prank(alice);
        staking.unstake(alicePosition1);

        uint256 aliceRDATAfterUnstake = rdat.balanceOf(alice);
        console2.log("Alice balance after unstake:", aliceRDATAfterUnstake);

        // Critical test: Verify Alice got her original RDAT tokens back from upgraded contract
        // This proves that RDAT upgrade doesn't break the staking→unstaking flow
        assertTrue(
            aliceRDATAfterUnstake >= aliceRDATBeforeUnstake + pos1Before.amount,
            "Alice didn't receive at least her original stake back from upgraded RDAT contract"
        );

        // Note: In the fixed supply model, rewards are handled by RewardsManager, not StakingPositions
        // StakingPositions returns 0 rewards, so Alice gets exactly her principal back
        assertEq(
            aliceRDATAfterUnstake,
            aliceRDATBeforeUnstake + pos1Before.amount,
            "Unexpected amount returned - should be exactly the principal"
        );

        console2.log("Alice successfully unstaked from upgraded RDAT contract");

        // Step 5: Test that new stakes work with upgraded RDAT
        // No mint delay needed for soul-bound tokens

        vm.startPrank(alice);
        uint256 newPosition = staking.stake(STAKE_AMOUNT / 2, staking.MONTH_3());
        vm.stopPrank();

        assertTrue(newPosition > 0, "Could not create new position with upgraded RDAT");
        console2.log("New staking position created with upgraded RDAT contract");
    }

    /**
     * @notice Simple test: RDAT upgrade preserves staking contract balance
     * @dev Focuses on the core issue without complex reward calculations
     */
    function testSimpleRDATUpgradePreservesStakingBalance() public {
        // Step 1: Create a position (no time advancement)
        vm.startPrank(alice);
        uint256 positionId = staking.stake(STAKE_AMOUNT, staking.MONTH_1());
        vm.stopPrank();

        // Record balances before upgrade
        uint256 stakingBalanceBefore = rdat.balanceOf(address(staking));
        uint256 aliceBalanceBefore = rdat.balanceOf(alice);
        uint256 totalSupplyBefore = rdat.totalSupply();

        // Step 2: Upgrade RDAT
        RDATUpgradeableV2 newImpl = new RDATUpgradeableV2();
        vm.prank(admin);
        rdat.upgradeToAndCall(address(newImpl), "");

        // Step 3: Verify critical balances preserved
        assertEq(rdat.balanceOf(address(staking)), stakingBalanceBefore, "Staking lost tokens during RDAT upgrade");
        assertEq(rdat.balanceOf(alice), aliceBalanceBefore, "Alice lost tokens during RDAT upgrade");
        assertEq(rdat.totalSupply(), totalSupplyBefore, "Total supply changed during RDAT upgrade");

        // Step 4: Verify position still exists and is owned correctly
        assertEq(staking.ownerOf(positionId), alice, "Position ownership lost during RDAT upgrade");

        IStakingPositions.Position memory position = staking.getPosition(positionId);
        assertEq(position.amount, STAKE_AMOUNT, "Position amount corrupted during RDAT upgrade");

        // Step 5: Verify RDAT upgrade worked (new functions available)
        RDATUpgradeableV2 upgradedRDAT = RDATUpgradeableV2(address(rdat));
        assertEq(upgradedRDAT.version(), 2, "RDAT upgrade failed");
        assertEq(upgradedRDAT.newFeature(), "V2 Feature Active", "V2 features not available");

        console2.log("RDAT upgrade preserved all balances and staking positions");
    }

    /**
     * @notice Test both RDAT and StakingPositions upgrades in sequence
     * @dev Tests most complex scenario: upgrade both contracts while positions are active
     */
    function testSequentialUpgradesWithActivePositions() public {
        // Step 1: Create positions
        vm.startPrank(alice);
        alicePosition1 = staking.stake(STAKE_AMOUNT, staking.MONTH_6());
        // No mint delay needed for soul-bound tokens
        alicePosition2 = staking.stake(STAKE_AMOUNT * 2, staking.MONTH_12());
        vm.stopPrank();

        // Record initial state
        uint256 initialStakingBalance = rdat.balanceOf(address(staking));
        // uint256 initialAliceBalance = rdat.balanceOf(alice); // Unused - kept for reference
        IStakingPositions.Position memory pos1Initial = staking.getPosition(alicePosition1);
        IStakingPositions.Position memory pos2Initial = staking.getPosition(alicePosition2);

        // Step 2: First upgrade RDAT
        RDATUpgradeableV2 newRdatImpl = new RDATUpgradeableV2();
        vm.prank(admin);
        rdat.upgradeToAndCall(address(newRdatImpl), "");

        // Verify state after RDAT upgrade
        assertEq(rdat.balanceOf(address(staking)), initialStakingBalance, "RDAT upgrade affected staking balance");

        // Step 3: Then upgrade StakingPositions
        StakingPositionsV2Example newStakingImpl = new StakingPositionsV2Example();
        vm.prank(admin);
        staking.upgradeToAndCall(address(newStakingImpl), abi.encodeCall(StakingPositionsV2Example.initializeV2, ()));
        StakingPositionsV2Example stakingV2 = StakingPositionsV2Example(address(stakingProxy));

        // Step 4: Verify both upgrades work together
        assertEq(rdat.balanceOf(address(stakingV2)), initialStakingBalance, "Staking upgrade affected RDAT balance");
        assertEq(stakingV2.ownerOf(alicePosition1), alice, "Position 1 ownership lost");
        assertEq(stakingV2.ownerOf(alicePosition2), alice, "Position 2 ownership lost");

        // Verify position data preserved through both upgrades
        IStakingPositions.Position memory pos1Final = stakingV2.getPosition(alicePosition1);
        IStakingPositions.Position memory pos2Final = stakingV2.getPosition(alicePosition2);

        assertEq(pos1Final.amount, pos1Initial.amount, "Position 1 amount lost through upgrades");
        assertEq(pos2Final.amount, pos2Initial.amount, "Position 2 amount lost through upgrades");

        // Step 5: Test unstaking with both contracts upgraded (minimal time warp)
        vm.warp(pos1Initial.startTime + pos1Initial.lockPeriod + 1);

        uint256 alicePreUnstakeBalance = rdat.balanceOf(alice);

        vm.startPrank(alice);
        stakingV2.unstake(alicePosition1);
        vm.stopPrank();

        // Note: We expect Alice to get at least her principal back, potentially more with rewards
        assertTrue(
            rdat.balanceOf(alice) >= alicePreUnstakeBalance + pos1Initial.amount,
            "Alice didn't receive at least her original stake back after both upgrades"
        );

        console2.log("Successfully unstaked with both RDAT and StakingPositions upgraded");
    }

    /**
     * @notice Test emergency scenarios during upgrades
     * @dev Ensures upgrade failures don't lock funds
     */
    function testUpgradeFailureRecovery() public {
        // Create position
        vm.startPrank(alice);
        alicePosition1 = staking.stake(STAKE_AMOUNT, staking.MONTH_1());
        vm.stopPrank();

        uint256 stakingBalanceBefore = rdat.balanceOf(address(staking));

        // Attempt bad RDAT upgrade
        BadRDATImplementation badImpl = new BadRDATImplementation();

        // This should fail and revert
        vm.prank(admin);
        vm.expectRevert();
        rdat.upgradeToAndCall(address(badImpl), "");

        // Verify original contract still works
        assertEq(rdat.balanceOf(address(staking)), stakingBalanceBefore, "Bad upgrade affected balances");
        assertEq(staking.ownerOf(alicePosition1), alice, "Position ownership affected by failed upgrade");

        // Test that unstaking still works after failed upgrade
        vm.warp(block.timestamp + staking.MONTH_1() + 1);

        uint256 aliceBalanceBefore = rdat.balanceOf(alice);

        vm.startPrank(alice);
        staking.unstake(alicePosition1);
        vm.stopPrank();

        // Alice should get at least her principal back, possibly with rewards
        assertTrue(
            rdat.balanceOf(alice) >= aliceBalanceBefore + STAKE_AMOUNT,
            "Alice didn't receive at least her original stake back after failed upgrade attempt"
        );

        console2.log("Contract recovered successfully from bad upgrade attempt");
    }

    /**
     * @notice Test paused upgrades
     * @dev Ensures upgrades work even when contracts are paused
     */
    function testPausedContractUpgrade() public {
        // Create position
        vm.startPrank(alice);
        alicePosition1 = staking.stake(STAKE_AMOUNT, staking.MONTH_1());
        vm.stopPrank();

        // Pause both contracts
        vm.startPrank(admin);
        rdat.pause();
        staking.pause();
        vm.stopPrank();

        // Verify paused state
        assertTrue(staking.paused(), "Staking should be paused");
        assertTrue(rdat.paused(), "RDAT should be paused");

        // Upgrade while paused
        RDATUpgradeableV2 newRdatImpl = new RDATUpgradeableV2();
        vm.prank(admin);
        rdat.upgradeToAndCall(address(newRdatImpl), "");

        StakingPositionsV2Example newStakingImpl = new StakingPositionsV2Example();
        vm.prank(admin);
        staking.upgradeToAndCall(address(newStakingImpl), abi.encodeCall(StakingPositionsV2Example.initializeV2, ()));

        // Unpause
        vm.startPrank(admin);
        rdat.unpause();
        staking.unpause();
        vm.stopPrank();

        // Verify functionality after paused upgrade
        StakingPositionsV2Example stakingV2 = StakingPositionsV2Example(address(stakingProxy));
        assertEq(stakingV2.ownerOf(alicePosition1), alice, "Position lost during paused upgrade");

        // Test normal operation after paused upgrade
        vm.warp(block.timestamp + staking.MONTH_1() + 1);

        uint256 aliceBalanceBefore = rdat.balanceOf(alice);

        vm.startPrank(alice);
        stakingV2.unstake(alicePosition1);
        vm.stopPrank();

        assertTrue(
            rdat.balanceOf(alice) >= aliceBalanceBefore + STAKE_AMOUNT,
            "Alice didn't receive at least her original stake back after paused upgrade"
        );

        console2.log("Paused contract upgrade completed successfully");
    }
}

/**
 * @notice Mock V2 implementation for RDAT with new features
 */
contract RDATUpgradeableV2 is RDATUpgradeable {
    uint256 public constant VERSION = 2;

    function version() external pure returns (uint256) {
        return VERSION;
    }

    // New function in V2
    function newFeature() external pure returns (string memory) {
        return "V2 Feature Active";
    }
}

/**
 * @notice Bad implementation that should fail upgrades
 */
contract BadRDATImplementation {
    // Missing required functions - this will cause upgrade to fail
    function initialize() external pure {
        revert("Bad implementation");
    }
}
