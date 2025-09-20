// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../../../src/VanaMigrationBridge.sol";
import "../../../src/interfaces/IMigrationBridge.sol";
import "../../../src/RDATUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title H02_MigrationChallenge Test
 * @notice Tests for HIGH severity issue H-02: Single Validator Can Block Migrations
 * @dev Verifies that challenge mechanism has proper safeguards
 */
contract H02_MigrationChallengeTest is Test {
    VanaMigrationBridge public bridge;
    RDATUpgradeable public rdatToken;

    address public admin = address(0x1000);
    address public treasury = address(0x2000);
    address public validator1 = address(0x3000);
    address public validator2 = address(0x4000);
    address public validator3 = address(0x5000);
    address public user = address(0x6000);
    address public maliciousValidator = address(0x7000);

    uint256 public constant MIGRATION_AMOUNT = 1000 * 1e18;
    bytes32 public constant BURN_TX_HASH = keccak256("burn_tx_1");
    uint256 public constant BURN_BLOCK = 12345;

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

        // Deploy bridge with initial validators
        address[] memory initialValidators = new address[](3);
        initialValidators[0] = validator1;
        initialValidators[1] = validator2;
        initialValidators[2] = validator3;

        bridge = new VanaMigrationBridge(address(rdatToken), admin, initialValidators);

        // Add malicious validator
        vm.startPrank(admin);
        bridge.addValidator(maliciousValidator);
        vm.stopPrank();

        // Transfer tokens to bridge for distribution
        vm.startPrank(treasury);
        rdatToken.transfer(address(bridge), 30_000_000 * 1e18);
        vm.stopPrank();
    }

    /**
     * @notice Test that challenges can only be submitted within the challenge period
     * @dev This should PASS with the fix implemented
     */
    function test_ChallengeOnlyWithinPeriod() public {
        // Validator submits migration validation
        vm.prank(validator1);
        bridge.submitValidation(user, MIGRATION_AMOUNT, BURN_TX_HASH, BURN_BLOCK);

        bytes32 requestId = keccak256(abi.encodePacked(user, MIGRATION_AMOUNT, BURN_TX_HASH));

        // Fast forward past challenge period (6 hours)
        vm.warp(block.timestamp + 7 hours);

        // Malicious validator tries to challenge after period
        vm.prank(maliciousValidator);
        vm.expectRevert("Challenge period ended");
        bridge.challengeMigration(requestId);
    }

    /**
     * @notice Test admin override of malicious challenges
     * @dev Admin can override after review period
     */
    function test_AdminOverrideChallenge() public {
        // Setup: Create and validate migration
        vm.prank(validator1);
        bridge.submitValidation(user, MIGRATION_AMOUNT, BURN_TX_HASH, BURN_BLOCK);

        vm.prank(validator2);
        bridge.submitValidation(user, MIGRATION_AMOUNT, BURN_TX_HASH, BURN_BLOCK);

        bytes32 requestId = keccak256(abi.encodePacked(user, MIGRATION_AMOUNT, BURN_TX_HASH));

        // Malicious validator challenges within period
        vm.prank(maliciousValidator);
        bridge.challengeMigration(requestId);

        // User cannot execute challenged migration
        vm.prank(user);
        vm.expectRevert(); // Should revert due to challenge
        bridge.executeMigration(requestId);

        // Admin cannot override immediately
        vm.prank(admin);
        vm.expectRevert("Review period not ended");
        bridge.overrideChallenge(requestId);

        // Fast forward past review period (7 days)
        vm.warp(block.timestamp + 8 days);

        // Admin can now override
        vm.prank(admin);
        bridge.overrideChallenge(requestId);

        // User can now execute migration
        uint256 balanceBefore = rdatToken.balanceOf(user);
        vm.prank(user);
        bridge.executeMigration(requestId);

        // Verify tokens received
        assertTrue(rdatToken.balanceOf(user) > balanceBefore, "User should receive tokens");
    }

    /**
     * @notice Test that non-admin cannot override challenges
     * @dev Only admin should have override capability
     */
    function test_OnlyAdminCanOverride() public {
        // Setup migration and challenge
        vm.prank(validator1);
        bridge.submitValidation(user, MIGRATION_AMOUNT, BURN_TX_HASH, BURN_BLOCK);

        vm.prank(validator2);
        bridge.submitValidation(user, MIGRATION_AMOUNT, BURN_TX_HASH, BURN_BLOCK);

        bytes32 requestId = keccak256(abi.encodePacked(user, MIGRATION_AMOUNT, BURN_TX_HASH));

        vm.prank(maliciousValidator);
        bridge.challengeMigration(requestId);

        // Fast forward past review period
        vm.warp(block.timestamp + 8 days);

        // Regular user cannot override
        vm.prank(user);
        vm.expectRevert(); // Should revert due to missing role
        bridge.overrideChallenge(requestId);

        // Validator cannot override
        vm.prank(validator1);
        vm.expectRevert(); // Should revert due to missing role
        bridge.overrideChallenge(requestId);
    }

    /**
     * @notice Test legitimate challenge scenario
     * @dev Challenges should still work for actual fraudulent migrations
     */
    function test_LegitimateChallenge() public {
        // Setup suspicious migration
        bytes32 suspiciousHash = keccak256("suspicious");

        vm.prank(validator1);
        bridge.submitValidation(user, MIGRATION_AMOUNT * 100, suspiciousHash, BURN_BLOCK);

        bytes32 requestId = keccak256(abi.encodePacked(user, MIGRATION_AMOUNT * 100, suspiciousHash));

        // Another validator challenges suspicious activity
        vm.prank(validator2);
        bridge.challengeMigration(requestId);

        // Migration should remain blocked
        vm.warp(block.timestamp + 30 days);
        vm.prank(user);
        vm.expectRevert();
        bridge.executeMigration(requestId);

        // Admin reviews and decides not to override (no action taken)
        // Migration remains blocked as intended
    }

    /**
     * @notice Test challenge timestamp tracking
     * @dev Ensures challenge timestamps are properly recorded
     */
    function test_ChallengeTimestampTracking() public {
        // Create multiple migrations
        bytes32 hash1 = keccak256("tx1");
        bytes32 hash2 = keccak256("tx2");

        vm.prank(validator1);
        bridge.submitValidation(user, 100 * 1e18, hash1, BURN_BLOCK);

        vm.prank(validator1);
        bridge.submitValidation(user, 200 * 1e18, hash2, BURN_BLOCK + 1);

        bytes32 requestId1 = keccak256(abi.encodePacked(user, uint256(100 * 1e18), hash1));
        bytes32 requestId2 = keccak256(abi.encodePacked(user, uint256(200 * 1e18), hash2));

        // Challenge first migration
        uint256 challengeTime1 = block.timestamp;
        vm.prank(maliciousValidator);
        bridge.challengeMigration(requestId1);

        // Wait and challenge second migration
        vm.warp(block.timestamp + 1 hours);
        uint256 challengeTime2 = block.timestamp;
        vm.prank(maliciousValidator);
        bridge.challengeMigration(requestId2);

        // Admin can override first after its review period
        vm.warp(challengeTime1 + 7 days + 1);
        vm.prank(admin);
        bridge.overrideChallenge(requestId1);

        // But cannot override second yet
        vm.prank(admin);
        vm.expectRevert("Review period not ended");
        bridge.overrideChallenge(requestId2);

        // Wait for second review period
        vm.warp(challengeTime2 + 7 days + 1);
        vm.prank(admin);
        bridge.overrideChallenge(requestId2);
    }
}
