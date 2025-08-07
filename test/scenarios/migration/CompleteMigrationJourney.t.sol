// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {Vm} from "forge-std/Vm.sol";

import {RDATUpgradeable} from "../../../src/RDATUpgradeable.sol";
import {VanaMigrationBridge} from "../../../src/VanaMigrationBridge.sol";
import {BaseMigrationBridge} from "../../../src/BaseMigrationBridge.sol";
import {MockRDAT} from "../../../src/mocks/MockRDAT.sol";
import {StakingPositions} from "../../../src/StakingPositions.sol";
import {vRDAT} from "../../../src/vRDAT.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {ScenarioHelpers} from "../helpers/ScenarioHelpers.sol";
import {OffChainSimulator} from "../helpers/OffChainSimulator.sol";

/**
 * @title CompleteMigrationJourney
 * @notice End-to-end migration scenario tests covering the full user experience
 * @dev Tests complete flows from V1 token holder to V2 staker with realistic timing
 */
contract CompleteMigrationJourney is Test {
    
    // ============ Test Infrastructure ============
    
    ScenarioHelpers public helpers;
    OffChainSimulator public simulator;
    
    // Base Chain Contracts
    BaseMigrationBridge public baseBridge;
    MockRDAT public v1Token;
    
    // Vana Chain Contracts
    RDATUpgradeable public v2Token;
    VanaMigrationBridge public vanaBridge;
    StakingPositions public staking;
    vRDAT public vrdatToken;
    
    // Test Actors
    address public admin;
    address public treasury;
    address public validator1;
    address public validator2;
    address public validator3;
    address public alice; // Small holder (1K RDAT)
    address public bob;   // Medium holder (10K RDAT)  
    address public carol; // Large holder (100K RDAT)
    
    // Test Constants
    uint256 constant SMALL_AMOUNT = 1_000e18;
    uint256 constant MEDIUM_AMOUNT = 10_000e18;
    uint256 constant LARGE_AMOUNT = 100_000e18;
    
    // Test Structs
    struct BonusTest {
        uint256 week;
        uint256 expectedPercent;
    }
    
    function setUp() public {
        // Initialize test infrastructure
        helpers = new ScenarioHelpers();
        simulator = new OffChainSimulator();
        
        // Create test actors
        admin = helpers.createUser("Admin");
        treasury = helpers.createUser("Treasury");
        validator1 = helpers.createUser("Validator1");
        validator2 = helpers.createUser("Validator2");
        validator3 = helpers.createUser("Validator3");
        alice = helpers.createUser("Alice");
        bob = helpers.createUser("Bob");
        carol = helpers.createUser("Carol");
        
        // Setup blockchain infrastructure
        _setupBaseChain();
        _setupVanaChain();
        _setupValidators();
        _setupUsers();
        
        // Configure helpers with system contracts
        helpers.setSystemContracts(
            address(v2Token),
            address(vrdatToken),
            address(staking),
            address(vanaBridge),
            address(baseBridge),
            address(v1Token),
            address(0), // rewards manager
            treasury,
            address(simulator)
        );
    }
    
    function _setupBaseChain() private {
        // Deploy V1 token (simulating existing Base deployment)
        v1Token = new MockRDAT(admin);
        
        // Deploy Base migration bridge
        baseBridge = new BaseMigrationBridge(address(v1Token), admin);
        
        console2.log("[POWER] Base chain setup complete");
    }
    
    function _setupVanaChain() private {
        // Deploy V2 token with proxy
        RDATUpgradeable rdatImpl = new RDATUpgradeable();
        bytes memory initData = abi.encodeWithSelector(
            RDATUpgradeable.initialize.selector,
            treasury,
            admin,
            address(this) // Temporary migration address
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(rdatImpl), initData);
        v2Token = RDATUpgradeable(address(proxy));
        
        // Deploy vRDAT governance token
        vrdatToken = new vRDAT(admin);
        
        // Deploy staking contract with proxy
        StakingPositions stakingImpl = new StakingPositions();
        bytes memory stakingInitData = abi.encodeCall(
            stakingImpl.initialize,
            (address(v2Token), address(vrdatToken), admin)
        );
        ERC1967Proxy stakingProxy = new ERC1967Proxy(
            address(stakingImpl),
            stakingInitData
        );
        staking = StakingPositions(address(stakingProxy));
        
        // Grant minting role to staking contract
        vm.prank(admin);
        vrdatToken.grantRole(keccak256("MINTER_ROLE"), address(staking));
        
        // Deploy Vana migration bridge with validators
        address[] memory validators = new address[](3);
        validators[0] = validator1;
        validators[1] = validator2;
        validators[2] = validator3;
        
        vanaBridge = new VanaMigrationBridge(
            address(v2Token),
            admin,
            validators
        );
        
        // Transfer migration allocation to bridge from treasury
        uint256 migrationAllocation = 30_000_000e18;
        vm.prank(treasury);
        v2Token.transfer(address(vanaBridge), migrationAllocation);
        
        console2.log("[CRYSTAL] Vana chain setup complete");
    }
    
    function _setupValidators() private {
        // Add validators to simulator
        simulator.addValidator(validator1);
        simulator.addValidator(validator2);
        simulator.addValidator(validator3);
        
        console2.log("[USERS] Validator network initialized");
    }
    
    function _setupUsers() private {
        // Fund users with V1 tokens - mint directly from the v1Token owner
        vm.startPrank(admin);
        v1Token.mint(alice, SMALL_AMOUNT);
        v1Token.mint(bob, MEDIUM_AMOUNT);
        v1Token.mint(carol, LARGE_AMOUNT);
        vm.stopPrank();
        
        // Give users ETH for gas
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(carol, 10 ether);
        
        console2.log("[MONEY] Users funded with V1 tokens");
    }
    
    // ============ Happy Path Scenarios ============
    
    function test_HappyPath_SmallMigration() public {
        helpers.startScenario("Small Migration (1K RDAT)");
        
        uint256 migrationAmount = SMALL_AMOUNT;
        
        // Execute complete migration journey
        _executeMigrationJourney(alice, migrationAmount);
        
        // Verify results
        assertEq(v2Token.balanceOf(alice), migrationAmount, "Alice should have migrated tokens");
        assertEq(vanaBridge.userMigrations(alice), migrationAmount, "Migration recorded");
        
        // Calculate and verify bonus (should be 5% in first 2 weeks)
        uint256 expectedBonus = (migrationAmount * 5) / 100;
        uint256 actualBonus = vanaBridge.calculateBonus(migrationAmount);
        assertEq(actualBonus, expectedBonus, "Bonus calculation incorrect");
        
        helpers.completeScenario("Small Migration (1K RDAT)", true);
    }
    
    function test_HappyPath_LargeMigration() public {
        helpers.startScenario("Large Migration (100K RDAT)");
        
        uint256 migrationAmount = LARGE_AMOUNT;
        
        // Large migration should work within daily limit
        assertTrue(migrationAmount <= vanaBridge.DAILY_LIMIT(), "Amount within daily limit");
        
        _executeMigrationJourney(carol, migrationAmount);
        
        // Verify results
        assertEq(v2Token.balanceOf(carol), migrationAmount, "Carol should have migrated tokens");
        assertEq(vanaBridge.totalMigrated(), migrationAmount, "Total migration updated");
        
        helpers.completeScenario("Large Migration (100K RDAT)", true);
    }
    
    function test_HappyPath_MaxDailyLimit() public {
        helpers.startScenario("Maximum Daily Limit Migration");
        
        uint256 dailyLimit = vanaBridge.DAILY_LIMIT(); // 300K RDAT
        
        // Fund a user with exactly the daily limit
        address whale = helpers.createUser("Whale");
        vm.prank(admin);
        v1Token.mint(whale, dailyLimit);
        vm.deal(whale, 10 ether);
        
        _executeMigrationJourney(whale, dailyLimit);
        
        // Verify daily limit tracking
        assertEq(vanaBridge.dailyMigrated(), dailyLimit, "Daily limit reached");
        assertEq(vanaBridge.totalMigrated(), dailyLimit, "Total migration correct");
        
        helpers.completeScenario("Maximum Daily Limit Migration", true);
    }
    
    function test_BonusDecay_WeekByWeek() public {
        helpers.startScenario("Migration Bonus Decay Over Time");
        
        uint256 testAmount = 10_000e18;
        uint256 deploymentTime = vanaBridge.deploymentTime();
        
        // Test bonus at different time periods
        BonusTest[4] memory tests = [
            BonusTest({week: 1, expectedPercent: 5}),  // Week 1-2: 5%
            BonusTest({week: 3, expectedPercent: 3}),  // Week 3-4: 3%
            BonusTest({week: 6, expectedPercent: 1}),  // Week 5-8: 1%
            BonusTest({week: 10, expectedPercent: 0})  // After week 8: 0%
        ];
        
        for (uint256 i = 0; i < tests.length; i++) {
            // Warp to specific week
            vm.warp(deploymentTime + tests[i].week * 1 weeks);
            
            uint256 bonus = vanaBridge.calculateBonus(testAmount);
            uint256 expectedBonus = (testAmount * tests[i].expectedPercent) / 100;
            
            assertEq(bonus, expectedBonus, 
                string.concat("Week ", vm.toString(tests[i].week), " bonus incorrect"));
            
            console2.log(string.concat("Week ", vm.toString(tests[i].week), " bonus: ", vm.toString(tests[i].expectedPercent), "%"));
        }
        
        helpers.completeScenario("Migration Bonus Decay Over Time", true);
    }
    
    function test_MigrationWithImmediateStaking() public {
        helpers.startScenario("Migration followed by Immediate Staking");
        
        uint256 migrationAmount = MEDIUM_AMOUNT;
        uint256 stakingAmount = migrationAmount / 2; // Stake half
        uint256 stakingPeriod = 90 days;
        
        // Step 1: Complete migration
        _executeMigrationJourney(bob, migrationAmount);
        
        console2.log("\n[CYCLE] Transitioning to staking phase...");
        
        // Step 2: Immediately stake some tokens
        vm.startPrank(bob);
        v2Token.approve(address(staking), stakingAmount);
        uint256 positionId = staking.stake(stakingAmount, stakingPeriod);
        vm.stopPrank();
        
        // Step 3: Verify staking results
        assertEq(staking.ownerOf(positionId), bob, "Bob should own the position");
        assertEq(v2Token.balanceOf(address(staking)), stakingAmount, "Tokens staked");
        // Note: vRDAT minting is handled by RewardsManager, not tested here
        
        // Check remaining balance
        uint256 expectedRemaining = migrationAmount - stakingAmount;
        assertEq(v2Token.balanceOf(bob), expectedRemaining, "Remaining balance correct");
        
        console2.log("[OK] Migration + Staking complete:");
        console2.log(string.concat("   - Migrated: ", vm.toString(migrationAmount / 1e18), " RDAT"));
        console2.log(string.concat("   - Staked: ", vm.toString(stakingAmount / 1e18), " RDAT"));
        console2.log(string.concat("   - vRDAT earned: ", vm.toString(vrdatToken.balanceOf(bob) / 1e18)));
        console2.log(string.concat("   - Remaining: ", vm.toString(expectedRemaining / 1e18), " RDAT"));
        
        helpers.completeScenario("Migration followed by Immediate Staking", true);
    }
    
    // ============ Multi-User Scenarios ============
    
    function test_MultiUser_ConcurrentMigrations() public {
        helpers.startScenario("Concurrent Multi-User Migration");
        
        // All three users migrate on the same day
        console2.log("\n[USERS] Processing concurrent migrations...");
        
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = SMALL_AMOUNT;   // Alice: 1K
        amounts[1] = MEDIUM_AMOUNT;  // Bob: 10K  
        amounts[2] = 80_000e18;      // Carol: 80K (within remaining daily limit)
        
        address[] memory users = new address[](3);
        users[0] = alice;
        users[1] = bob;
        users[2] = carol;
        
        // Execute all migrations
        uint256 totalMigrated = 0;
        for (uint256 i = 0; i < users.length; i++) {
            console2.log(string.concat("\n", vm.toString(i + 1), ". Processing migration for user"));
            _executeMigrationJourney(users[i], amounts[i]);
            totalMigrated += amounts[i];
            
            // Verify individual migration
            assertEq(v2Token.balanceOf(users[i]), amounts[i], "Individual migration failed");
        }
        
        // Verify system state
        assertEq(vanaBridge.totalMigrated(), totalMigrated, "Total migration incorrect");
        assertTrue(vanaBridge.dailyMigrated() <= vanaBridge.DAILY_LIMIT(), "Daily limit respected");
        
        console2.log("\n[CHART] Migration Summary:");
        console2.log(string.concat("   - Total migrated: ", vm.toString(totalMigrated / 1e18), " RDAT"));
        console2.log(string.concat("   - Daily limit used: ", vm.toString((vanaBridge.dailyMigrated() * 100) / vanaBridge.DAILY_LIMIT()), "%"));
        
        helpers.completeScenario("Concurrent Multi-User Migration", true);
    }
    
    function test_MultiDay_MigrationSpread() public {
        helpers.startScenario("Multi-Day Migration Distribution");
        
        // Note: Each migration journey includes a 1-day time progression for challenge period
        // So migrations naturally spread across days
        
        // Migration 1: Alice migrates (includes 1 day progression)
        console2.log("\n[DATE] Alice Migration:");
        _executeMigrationJourney(alice, SMALL_AMOUNT);
        uint256 aliceDay = vanaBridge.dailyMigrated();
        
        // Migration 2: Bob migrates (includes another 1 day progression, so different day)
        console2.log("\n[DATE] Bob Migration (after time progression):");
        _executeMigrationJourney(bob, MEDIUM_AMOUNT);
        uint256 bobDay = vanaBridge.dailyMigrated();
        
        // Each migration happens on a different day due to challenge period
        assertEq(bobDay, MEDIUM_AMOUNT, "Bob's migration on new day");
        
        // Migration 3: Carol migrates (another day due to time progression)
        console2.log("\n[DATE] Carol Migration:");
        _executeMigrationJourney(carol, LARGE_AMOUNT);
        assertEq(vanaBridge.dailyMigrated(), LARGE_AMOUNT, "Carol's migration amount");
        
        // Verify overall totals
        uint256 expectedTotal = SMALL_AMOUNT + MEDIUM_AMOUNT + LARGE_AMOUNT;
        assertEq(vanaBridge.totalMigrated(), expectedTotal, "Multi-day total incorrect");
        
        helpers.completeScenario("Multi-Day Migration Distribution", true);
    }
    
    // ============ Helper Functions ============
    
    /**
     * @notice Executes a complete migration journey for a user
     * @param user The user performing the migration
     * @param amount The amount to migrate
     * @return requestId The migration request ID
     */
    function _executeMigrationJourney(address user, uint256 amount) internal returns (bytes32 requestId) {
        string memory userName = _getUserName(user);
        
        console2.log(string.concat("\n[BRIDGE] Starting migration journey for ", userName));
        console2.log(string.concat("   Amount: ", vm.toString(amount / 1e18), " RDAT"));
        
        // Step 1: User initiates migration on Base
        console2.log("[STEP1] Initiating migration on Base...");
        
        vm.startPrank(user);
        v1Token.approve(address(baseBridge), amount);
        
        // Capture the burn transaction hash
        vm.recordLogs();
        baseBridge.initiateMigration(amount);
        
        // Extract burn hash from events
        bytes32 burnTxHash = _extractBurnHash(vm.getRecordedLogs());
        vm.stopPrank();
        
        console2.log("   [OK] V1 tokens burned, hash:", vm.toString(burnTxHash));
        
        // Step 2: Simulate validator network processing
        console2.log("[STEP2] Validator network processing...");
        
        requestId = simulator.simulateValidatorNetwork(user, amount, burnTxHash, block.number);
        assertTrue(simulator.hasConsensus(requestId), "Consensus not reached");
        
        console2.log("   [OK] Validator consensus reached");
        
        // Step 3: Wait for challenge period
        console2.log("[STEP3] Waiting for challenge period...");
        simulator.simulateTimeProgression(1); // Fast forward past challenge period
        
        assertTrue(simulator.canExecuteMigration(requestId), "Cannot execute migration");
        console2.log("   [OK] Challenge period passed");
        
        // Step 4: Validators submit validations to Vana bridge
        console2.log("[STEP4] Validators submitting validations to Vana bridge...");
        
        // At least 2 validators need to submit validations
        vm.prank(validator1);
        vanaBridge.submitValidation(user, amount, burnTxHash, block.number - 1);
        
        vm.prank(validator2);
        vanaBridge.submitValidation(user, amount, burnTxHash, block.number - 1);
        
        console2.log("   [OK] Validators submitted confirmations");
        
        // Step 5: Wait for challenge period to pass on Vana chain
        console2.log("[STEP5] Waiting for Vana challenge period...");
        vm.warp(block.timestamp + 7 hours); // Challenge period is 6 hours, add buffer
        
        // Step 6: Execute migration on Vana
        console2.log("[STEP6] Executing migration on Vana...");
        
        // Calculate the request ID the same way the bridge does
        requestId = keccak256(abi.encodePacked(user, amount, burnTxHash));
        
        uint256 balanceBefore = v2Token.balanceOf(user);
        vanaBridge.executeMigration(requestId);
        uint256 balanceAfter = v2Token.balanceOf(user);
        
        assertEq(balanceAfter - balanceBefore, amount, "Migration amount incorrect");
        console2.log("   [OK] Migration executed successfully");
        
        // Step 5: Verify final state
        uint256 bonus = vanaBridge.calculateBonus(amount);
        console2.log("[STEP5] Migration complete!");
        console2.log(string.concat("   - Base amount received: ", vm.toString(amount / 1e18), " RDAT"));
        console2.log(string.concat("   - Migration bonus: ", vm.toString(bonus / 1e18), " RDAT (vesting)"));
        console2.log(string.concat("   - Total user balance: ", vm.toString(v2Token.balanceOf(user) / 1e18), " RDAT"));
        
        return requestId;
    }
    
    /**
     * @notice Extracts the burn transaction hash from Base bridge events
     */
    function _extractBurnHash(Vm.Log[] memory logs) internal pure returns (bytes32) {
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("TokensBurned(address,uint256,bytes32)")) {
                return logs[i].topics[2];
            }
        }
        revert("Burn hash not found in logs");
    }
    
    /**
     * @notice Gets user name for logging
     */
    function _getUserName(address user) internal view returns (string memory) {
        if (user == alice) return "Alice";
        if (user == bob) return "Bob";
        if (user == carol) return "Carol";
        return vm.toString(user);
    }
    
    // ============ Invariant Tests ============
    
    function test_Invariant_TotalSupplyConserved() public {
        helpers.startScenario("Total Supply Conservation Invariant");
        
        // Record initial state
        uint256 initialV1Supply = v1Token.totalSupply();
        uint256 initialV2Supply = v2Token.totalSupply();
        
        // Execute multiple migrations
        _executeMigrationJourney(alice, SMALL_AMOUNT);
        _executeMigrationJourney(bob, MEDIUM_AMOUNT);
        
        // Verify supply conservation
        uint256 finalV1Supply = v1Token.totalSupply();
        uint256 finalV2Supply = v2Token.totalSupply();
        
        // V1 tokens should be locked in the bridge (not actually burned in this implementation)
        uint256 tokensInBridge = v1Token.balanceOf(address(baseBridge));
        assertEq(tokensInBridge, SMALL_AMOUNT + MEDIUM_AMOUNT, "V1 tokens not locked in bridge");
        
        // V2 total supply should remain constant (tokens transferred from bridge)
        assertEq(finalV2Supply, initialV2Supply, "V2 total supply changed");
        
        // Bridge balance should decrease
        uint256 expectedBridgeBalance = 30_000_000e18 - vanaBridge.totalMigrated();
        assertEq(v2Token.balanceOf(address(vanaBridge)), expectedBridgeBalance, "Bridge balance incorrect");
        
        helpers.completeScenario("Total Supply Conservation Invariant", true);
    }
    
    function tearDown() public {
        helpers.cleanup();
        console2.log("[CLEAN] Test cleanup completed");
    }
}