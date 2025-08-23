// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test, Vm} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {VanaMigrationBridge} from "../src/VanaMigrationBridge.sol";
import {RDATUpgradeable} from "../src/RDATUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMigrationBridge} from "../src/interfaces/IMigrationBridge.sol";

contract VanaMigrationBridgeTest is Test {
    VanaMigrationBridge public bridge;
    RDATUpgradeable public rdatImpl;
    RDATUpgradeable public rdat;

    address public admin = address(0x1);
    address public treasury = address(0x2);
    address public validator1 = address(0x11);
    address public validator2 = address(0x12);
    address public validator3 = address(0x13);
    address public user1 = address(0x21);
    address public user2 = address(0x22);

    uint256 public constant MIGRATION_ALLOCATION = 30_000_000e18;

    // Events
    event MigrationValidated(bytes32 indexed requestId, address indexed validator);
    event MigrationExecuted(bytes32 indexed requestId, address indexed user, uint256 amount, uint256 bonus);
    event MigrationChallenged(bytes32 indexed requestId, address indexed challenger);
    event ValidatorAdded(address indexed validator);
    event ValidatorRemoved(address indexed validator);

    function setUp() public {
        // Deploy RDAT V2 token
        rdatImpl = new RDATUpgradeable();
        bytes memory initData = abi.encodeWithSelector(
            RDATUpgradeable.initialize.selector,
            treasury,
            admin,
            address(this) // Temporary migration address
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(rdatImpl), initData);
        rdat = RDATUpgradeable(address(proxy));

        // Deploy bridge with initial validators
        address[] memory validators = new address[](3);
        validators[0] = validator1;
        validators[1] = validator2;
        validators[2] = validator3;

        bridge = new VanaMigrationBridge(address(rdat), admin, validators);

        // Transfer migration allocation to bridge
        rdat.transfer(address(bridge), MIGRATION_ALLOCATION);
    }

    function test_InitialState() public view {
        assertEq(address(bridge.v2Token()), address(rdat));
        assertEq(bridge.validatorCount(), 3);
        assertTrue(bridge.validators(validator1));
        assertTrue(bridge.validators(validator2));
        assertTrue(bridge.validators(validator3));
        assertEq(bridge.totalMigrated(), 0);
        assertEq(bridge.DAILY_LIMIT(), 300_000e18);
        assertFalse(bridge.paused());
    }

    function test_SubmitValidationSingle() public {
        uint256 amount = 1000e18;
        bytes32 burnTxHash = keccak256("burn1");
        uint256 burnBlock = 12345;

        // First validator submits
        vm.prank(validator1);
        bridge.submitValidation(user1, amount, burnTxHash, burnBlock);

        // Check request created
        bytes32 requestId = keccak256(abi.encodePacked(user1, amount, burnTxHash));
        IMigrationBridge.MigrationRequest memory request = bridge.migrationRequests(requestId);

        assertEq(request.user, user1);
        assertEq(request.amount, amount);
        assertEq(request.burnTxHash, burnTxHash);
        assertEq(request.burnBlockNumber, burnBlock);
        assertEq(request.validatorApprovals, 1);
        assertFalse(request.executed);
        assertFalse(request.challenged);

        // Check validator recorded
        assertTrue(bridge.hasValidated(requestId, validator1));
        assertFalse(bridge.hasValidated(requestId, validator2));
    }

    function test_SubmitValidationConsensus() public {
        uint256 amount = 1000e18;
        bytes32 burnTxHash = keccak256("burn1");
        uint256 burnBlock = 12345;
        bytes32 requestId = keccak256(abi.encodePacked(user1, amount, burnTxHash));

        // First validator
        vm.prank(validator1);
        bridge.submitValidation(user1, amount, burnTxHash, burnBlock);

        // Second validator - reaches consensus but challenge period active
        vm.prank(validator2);
        bridge.submitValidation(user1, amount, burnTxHash, burnBlock);

        // Check not executed yet (challenge period)
        IMigrationBridge.MigrationRequest memory request = bridge.migrationRequests(requestId);
        assertEq(request.validatorApprovals, 2);
        assertFalse(request.executed);

        // Warp past challenge period
        vm.warp(block.timestamp + 7 hours);

        // Third validator triggers auto-execution
        uint256 userBalanceBefore = rdat.balanceOf(user1);

        vm.prank(validator3);
        bridge.submitValidation(user1, amount, burnTxHash, burnBlock);

        // Check executed
        request = bridge.migrationRequests(requestId);
        assertTrue(request.executed);

        // Check user received base amount (bonus would be in vesting if configured)
        assertEq(rdat.balanceOf(user1), userBalanceBefore + amount);
    }

    function test_CalculateBonus() public {
        uint256 amount = 10_000e18;
        uint256 deployTime = bridge.deploymentTime();

        // Week 1-2: 5% bonus
        assertEq(bridge.calculateBonus(amount), 500e18);

        // Week 3-4: 3% bonus
        vm.warp(deployTime + 3 weeks);
        assertEq(bridge.calculateBonus(amount), 300e18);

        // Week 5-8: 1% bonus
        vm.warp(deployTime + 5 weeks);
        assertEq(bridge.calculateBonus(amount), 100e18);

        // After week 8: no bonus
        vm.warp(deployTime + 9 weeks);
        assertEq(bridge.calculateBonus(amount), 0);
    }

    function test_ChallengeMigration() public {
        uint256 amount = 1000e18;
        bytes32 burnTxHash = keccak256("burn1");
        bytes32 requestId = keccak256(abi.encodePacked(user1, amount, burnTxHash));

        // Two validators approve
        vm.prank(validator1);
        bridge.submitValidation(user1, amount, burnTxHash, 12345);

        vm.prank(validator2);
        bridge.submitValidation(user1, amount, burnTxHash, 12345);

        // Third validator challenges
        vm.expectEmit(true, false, false, true);
        emit MigrationChallenged(requestId, validator3);

        vm.prank(validator3);
        bridge.challengeMigration(requestId);

        // Check challenged
        IMigrationBridge.MigrationRequest memory request = bridge.migrationRequests(requestId);
        assertTrue(request.challenged);

        // Cannot execute challenged migration
        vm.warp(block.timestamp + 7 hours);
        vm.expectRevert(VanaMigrationBridge.MigrationIsChallenged.selector);
        bridge.executeMigration(requestId);
    }

    function test_ExecuteMigrationManually() public {
        uint256 amount = 1000e18;
        bytes32 burnTxHash = keccak256("burn1");
        bytes32 requestId = keccak256(abi.encodePacked(user1, amount, burnTxHash));

        // Get consensus
        vm.prank(validator1);
        bridge.submitValidation(user1, amount, burnTxHash, 12345);

        vm.prank(validator2);
        bridge.submitValidation(user1, amount, burnTxHash, 12345);

        // Cannot execute during challenge period
        vm.expectRevert(VanaMigrationBridge.ChallengePeriodActive.selector);
        bridge.executeMigration(requestId);

        // Warp past challenge period
        vm.warp(block.timestamp + 7 hours);

        // Now can execute
        uint256 userBalanceBefore = rdat.balanceOf(user1);
        uint256 bonus = bridge.calculateBonus(amount);

        vm.expectEmit(true, true, false, true);
        emit MigrationExecuted(requestId, user1, amount, bonus);

        bridge.executeMigration(requestId);

        // Verify transfer (only base amount, bonus would be in vesting)
        assertEq(rdat.balanceOf(user1), userBalanceBefore + amount);
        assertEq(bridge.totalMigrated(), amount);
        assertEq(bridge.userMigrations(user1), amount);
    }

    function test_DailyLimit() public {
        uint256 dailyLimit = bridge.DAILY_LIMIT();
        uint256 amount = dailyLimit / 2 + 1000e18; // Just over half the daily limit

        // First migration
        bytes32 burnTx1 = keccak256("burn1");
        vm.prank(validator1);
        bridge.submitValidation(user1, amount, burnTx1, 12345);
        vm.prank(validator2);
        bridge.submitValidation(user1, amount, burnTx1, 12345);

        vm.warp(block.timestamp + 7 hours);
        bridge.executeMigration(keccak256(abi.encodePacked(user1, amount, burnTx1)));

        // Second migration - should exceed daily limit
        bytes32 burnTx2 = keccak256("burn2");
        vm.prank(validator1);
        bridge.submitValidation(user2, amount, burnTx2, 12346);
        vm.prank(validator2);
        bridge.submitValidation(user2, amount, burnTx2, 12346);

        vm.warp(block.timestamp + 7 hours);

        vm.expectRevert(VanaMigrationBridge.DailyLimitExceeded.selector);
        bridge.executeMigration(keccak256(abi.encodePacked(user2, amount, burnTx2)));

        // Warp to next day
        vm.warp(block.timestamp + 1 days);

        // Now should work
        bridge.executeMigration(keccak256(abi.encodePacked(user2, amount, burnTx2)));
        assertEq(bridge.dailyMigrated(), amount); // Only base amount counts for daily limit
    }

    function test_ValidatorManagement() public {
        address newValidator = address(0x99);

        // Add validator
        vm.expectEmit(true, false, false, false);
        emit ValidatorAdded(newValidator);

        vm.prank(admin);
        bridge.addValidator(newValidator);

        assertTrue(bridge.validators(newValidator));
        assertEq(bridge.validatorCount(), 4);

        // Remove validator
        vm.expectEmit(true, false, false, false);
        emit ValidatorRemoved(validator3);

        vm.prank(admin);
        bridge.removeValidator(validator3);

        assertFalse(bridge.validators(validator3));
        assertEq(bridge.validatorCount(), 3);
    }

    function test_RevertRemoveBelowMinimum() public {
        // Remove one validator (ok)
        vm.prank(admin);
        bridge.removeValidator(validator3);

        // Try to remove another (would go below minimum)
        vm.prank(admin);
        vm.expectRevert(VanaMigrationBridge.InsufficientValidators.selector);
        bridge.removeValidator(validator2);
    }

    function test_RevertDuplicateValidation() public {
        uint256 amount = 1000e18;
        bytes32 burnTxHash = keccak256("burn1");

        vm.startPrank(validator1);
        bridge.submitValidation(user1, amount, burnTxHash, 12345);

        // Try to validate again
        vm.expectRevert(VanaMigrationBridge.AlreadyValidated.selector);
        bridge.submitValidation(user1, amount, burnTxHash, 12345);
        vm.stopPrank();
    }

    function test_RevertProcessedBurnHash() public {
        uint256 amount = 1000e18;
        bytes32 burnTxHash = keccak256("burn1");

        // Process a migration
        vm.prank(validator1);
        bridge.submitValidation(user1, amount, burnTxHash, 12345);
        vm.prank(validator2);
        bridge.submitValidation(user1, amount, burnTxHash, 12345);

        vm.warp(block.timestamp + 7 hours);
        bridge.executeMigration(keccak256(abi.encodePacked(user1, amount, burnTxHash)));

        // Try to use same burn hash
        vm.prank(validator1);
        vm.expectRevert(VanaMigrationBridge.AlreadyProcessed.selector);
        bridge.submitValidation(user2, amount, burnTxHash, 12345);
    }

    function test_UpdateDailyLimit() public {
        uint256 newLimit = 500_000e18;

        vm.prank(admin);
        bridge.updateDailyLimit(newLimit);

        assertEq(bridge.DAILY_LIMIT(), newLimit);
    }

    function test_PauseUnpause() public {
        // Pause
        vm.prank(admin);
        bridge.pause();
        assertTrue(bridge.paused());

        // Cannot submit validation when paused
        vm.prank(validator1);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        bridge.submitValidation(user1, 1000e18, keccak256("burn"), 12345);

        // Unpause
        vm.prank(admin);
        bridge.unpause();
        assertFalse(bridge.paused());
    }

    function test_ReturnUnclaimedTokensAfterDeadline() public {
        // Cannot return before deadline
        vm.prank(admin);
        vm.expectRevert("Migration still active");
        bridge.returnUnclaimedTokens(treasury);

        // Warp past deadline
        vm.warp(block.timestamp + 366 days);

        // Return unclaimed tokens
        uint256 bridgeBalance = rdat.balanceOf(address(bridge));
        uint256 treasuryBalanceBefore = rdat.balanceOf(treasury);

        vm.prank(admin);
        bridge.returnUnclaimedTokens(treasury);

        assertEq(rdat.balanceOf(address(bridge)), 0);
        assertEq(rdat.balanceOf(treasury), treasuryBalanceBefore + bridgeBalance);
    }

    function test_RevertBaseSideFunctions() public {
        vm.expectRevert("Use submitValidation on Vana");
        bridge.initiateMigration(1000e18);
    }
}
