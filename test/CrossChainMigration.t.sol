// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test, Vm} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {BaseMigrationBridge} from "../src/BaseMigrationBridge.sol";
import {VanaMigrationBridge} from "../src/VanaMigrationBridge.sol";
import {MockRDAT} from "../src/mocks/MockRDAT.sol";
import {RDATUpgradeable} from "../src/RDATUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title CrossChainMigrationTest
 * @notice Simulates the complete cross-chain migration flow from Base to Vana
 * @dev In real deployment, validators would monitor Base events and submit to Vana
 */
contract CrossChainMigrationTest is Test {
    // Base chain contracts
    BaseMigrationBridge public baseBridge;
    MockRDAT public v1Token;
    
    // Vana chain contracts
    VanaMigrationBridge public vanaBridge;
    RDATUpgradeable public v2Token;
    
    // Actors
    address public admin = address(0x1);
    address public treasury = address(0x2);
    address public validator1 = address(0x11);
    address public validator2 = address(0x12);
    address public validator3 = address(0x13);
    address public user1 = address(0x21);
    address public user2 = address(0x22);
    
    // Constants
    uint256 public constant V1_SUPPLY = 30_000_000e18;
    uint256 public constant MIGRATION_ALLOCATION = 30_000_000e18;
    
    // Events from Base
    event TokensBurned(address indexed user, uint256 amount, bytes32 indexed burnTxHash);
    
    function setUp() public {
        // Setup Base chain
        _setupBaseChain();
        
        // Setup Vana chain
        _setupVanaChain();
    }
    
    function _setupBaseChain() private {
        // Deploy V1 token
        v1Token = new MockRDAT(admin);
        
        // Deploy Base bridge
        baseBridge = new BaseMigrationBridge(address(v1Token), admin);
        
        // Distribute V1 tokens to users
        vm.startPrank(admin);
        v1Token.mint(user1, 10_000e18);
        v1Token.mint(user2, 20_000e18);
        vm.stopPrank();
    }
    
    function _setupVanaChain() private {
        // Deploy V2 token
        RDATUpgradeable rdatImpl = new RDATUpgradeable();
        bytes memory initData = abi.encodeWithSelector(
            RDATUpgradeable.initialize.selector,
            treasury,
            admin,
            address(this) // Temporary migration address
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(rdatImpl), initData);
        v2Token = RDATUpgradeable(address(proxy));
        
        // Deploy Vana bridge with validators
        address[] memory validators = new address[](3);
        validators[0] = validator1;
        validators[1] = validator2;
        validators[2] = validator3;
        
        vanaBridge = new VanaMigrationBridge(
            address(v2Token),
            admin,
            validators
        );
        
        // Transfer migration allocation to Vana bridge
        v2Token.transfer(address(vanaBridge), MIGRATION_ALLOCATION);
    }
    
    function test_CompleteUserMigrationFlow() public {
        uint256 migrationAmount = 5_000e18;
        
        console2.log("=== Starting Cross-Chain Migration Test ===");
        console2.log("User1 balance on Base:", v1Token.balanceOf(user1));
        
        // Step 1: User initiates migration on Base
        console2.log("\n1. User initiates migration on Base");
        
        vm.startPrank(user1);
        v1Token.approve(address(baseBridge), migrationAmount);
        
        // Capture the burn event
        vm.recordLogs();
        baseBridge.initiateMigration(migrationAmount);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        vm.stopPrank();
        
        // Extract burn details from event
        bytes32 burnTxHash;
        for (uint i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("TokensBurned(address,uint256,bytes32)")) {
                burnTxHash = logs[i].topics[2];
                break;
            }
        }
        
        console2.log("Burn TX Hash:", vm.toString(burnTxHash));
        console2.log("V1 tokens burned:", migrationAmount);
        console2.log("User1 remaining V1 balance:", v1Token.balanceOf(user1));
        
        // Step 2: Validators observe the burn and submit to Vana
        console2.log("\n2. Validators submit observations to Vana");
        
        // Validator 1 submits
        vm.prank(validator1);
        vanaBridge.submitValidation(user1, migrationAmount, burnTxHash, block.number);
        console2.log("Validator 1 submitted");
        
        // Validator 2 submits (reaches consensus)
        vm.prank(validator2);
        vanaBridge.submitValidation(user1, migrationAmount, burnTxHash, block.number);
        console2.log("Validator 2 submitted - consensus reached");
        
        // Step 3: Wait for challenge period
        console2.log("\n3. Waiting for challenge period (6 hours)");
        vm.warp(block.timestamp + 7 hours);
        
        // Step 4: Execute migration
        console2.log("\n4. Executing migration on Vana");
        
        uint256 bonus = vanaBridge.calculateBonus(migrationAmount);
        console2.log("Migration bonus (5%):", bonus);
        
        bytes32 requestId = keccak256(abi.encodePacked(user1, migrationAmount, burnTxHash));
        vanaBridge.executeMigration(requestId);
        
        // Step 5: Verify results
        console2.log("\n5. Migration Complete!");
        console2.log("User1 V2 balance:", v2Token.balanceOf(user1));
        console2.log("Expected (amount + bonus):", migrationAmount + bonus);
        
        assertEq(v2Token.balanceOf(user1), migrationAmount + bonus);
        assertEq(vanaBridge.totalMigrated(), migrationAmount);
        assertEq(vanaBridge.userMigrations(user1), migrationAmount);
    }
    
    function test_MultipleMigrationsWithDailyLimit() public {
        console2.log("=== Testing Daily Limit Enforcement ===");
        
        // Give user1 more tokens for this test
        vm.prank(admin);
        v1Token.mint(user1, 350_000e18);
        
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 200_000e18;  // Most of daily limit
        amounts[1] = 100_000e18;  // Would exceed limit with bonus
        amounts[2] = 50_000e18;   // Next day migration
        
        bytes32[] memory burnHashes = new bytes32[](3);
        
        // Initiate all migrations on Base
        vm.startPrank(user1);
        v1Token.approve(address(baseBridge), 350_000e18);
        
        for (uint i = 0; i < 3; i++) {
            vm.recordLogs();
            baseBridge.initiateMigration(amounts[i]);
            Vm.Log[] memory logs = vm.getRecordedLogs();
            
            // Extract burn hash
            for (uint j = 0; j < logs.length; j++) {
                if (logs[j].topics[0] == keccak256("TokensBurned(address,uint256,bytes32)")) {
                    burnHashes[i] = logs[j].topics[2];
                    break;
                }
            }
        }
        vm.stopPrank();
        
        console2.log("Daily limit:", vanaBridge.DAILY_LIMIT());
        
        // Process first migration
        console2.log("\n1. First migration (200,000 RDAT)");
        _processValidation(user1, amounts[0], burnHashes[0]);
        console2.log("Daily migrated:", vanaBridge.dailyMigrated());
        
        // Try second migration - should fail
        console2.log("\n2. Second migration (100,000 RDAT) - should exceed limit");
        _submitValidations(user1, amounts[1], burnHashes[1]);
        
        // Wait for challenge period
        vm.warp(block.timestamp + 7 hours);
        
        bytes32 requestId2 = keccak256(abi.encodePacked(user1, amounts[1], burnHashes[1]));
        vm.expectRevert(VanaMigrationBridge.DailyLimitExceeded.selector);
        vanaBridge.executeMigration(requestId2);
        
        // Warp to next day
        console2.log("\n3. Warping to next day");
        vm.warp(block.timestamp + 1 days);
        
        // Now second migration should work
        vanaBridge.executeMigration(requestId2);
        console2.log("Second migration executed successfully");
        
        // Process third migration
        console2.log("\n4. Third migration (50,000 RDAT)");
        _processValidation(user1, amounts[2], burnHashes[2]);
        
        console2.log("\nFinal V2 balance:", v2Token.balanceOf(user1));
        console2.log("Total migrated:", vanaBridge.totalMigrated());
    }
    
    function test_ChallengedMigration() public {
        uint256 amount = 10_000e18;
        
        console2.log("=== Testing Challenged Migration ===");
        
        // User initiates migration
        vm.startPrank(user1);
        v1Token.approve(address(baseBridge), amount);
        
        vm.recordLogs();
        baseBridge.initiateMigration(amount);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        vm.stopPrank();
        
        bytes32 burnTxHash;
        for (uint i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("TokensBurned(address,uint256,bytes32)")) {
                burnTxHash = logs[i].topics[2];
                break;
            }
        }
        
        // Two validators approve
        console2.log("\n1. Two validators approve migration");
        vm.prank(validator1);
        vanaBridge.submitValidation(user1, amount, burnTxHash, block.number);
        
        vm.prank(validator2);
        vanaBridge.submitValidation(user1, amount, burnTxHash, block.number);
        
        // Third validator challenges
        console2.log("\n2. Third validator challenges migration");
        bytes32 requestId = keccak256(abi.encodePacked(user1, amount, burnTxHash));
        
        vm.prank(validator3);
        vanaBridge.challengeMigration(requestId);
        
        // Try to execute - should fail
        console2.log("\n3. Attempting to execute challenged migration");
        vm.warp(block.timestamp + 7 hours);
        
        vm.expectRevert(VanaMigrationBridge.NotChallenged.selector);
        vanaBridge.executeMigration(requestId);
        
        console2.log("Migration blocked due to challenge");
        assertEq(v2Token.balanceOf(user1), 0);
    }
    
    function test_MigrationBonusDecay() public {
        uint256 amount = 10_000e18;
        
        console2.log("=== Testing Migration Bonus Decay ===");
        
        // Test bonus at different time periods
        uint256[] memory weeksPassed = new uint256[](4);
        weeksPassed[0] = 1;  // Week 1-2: 5%
        weeksPassed[1] = 3;  // Week 3-4: 3%
        weeksPassed[2] = 5;  // Week 5-8: 1%
        weeksPassed[3] = 9;  // After week 8: 0%
        
        for (uint i = 0; i < weeksPassed.length; i++) {
            // Warp to specific week
            vm.warp(vanaBridge.deploymentTime() + weeksPassed[i] * 1 weeks);
            
            uint256 bonus = vanaBridge.calculateBonus(amount);
            uint256 bonusPercent = (bonus * 100) / amount;
            
            console2.log(
                string.concat(
                    "Week ", 
                    vm.toString(weeksPassed[i]), 
                    " bonus: ", 
                    vm.toString(bonusPercent), 
                    "%"
                )
            );
        }
    }
    
    // Helper functions
    
    function _submitValidations(address user, uint256 amount, bytes32 burnTxHash) private {
        vm.prank(validator1);
        vanaBridge.submitValidation(user, amount, burnTxHash, block.number);
        
        vm.prank(validator2);
        vanaBridge.submitValidation(user, amount, burnTxHash, block.number);
    }
    
    function _processValidation(address user, uint256 amount, bytes32 burnTxHash) private {
        _submitValidations(user, amount, burnTxHash);
        
        // Wait for challenge period
        vm.warp(block.timestamp + 7 hours);
        
        // Execute
        bytes32 requestId = keccak256(abi.encodePacked(user, amount, burnTxHash));
        vanaBridge.executeMigration(requestId);
    }
}