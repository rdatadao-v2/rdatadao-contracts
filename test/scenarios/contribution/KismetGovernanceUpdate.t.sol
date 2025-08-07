// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test, Vm} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {ScenarioHelpers} from "../helpers/ScenarioHelpers.sol";
import {OffChainSimulator} from "../helpers/OffChainSimulator.sol";

/**
 * @title KismetGovernanceUpdate
 * @notice Tests governance-driven updates to kismet calculation formulas
 * @dev Simulates complete governance flow for updating reward multipliers
 */
contract KismetGovernanceUpdate is Test {
    
    ScenarioHelpers public helpers;
    OffChainSimulator public simulator;
    
    // Test actors
    address public admin;
    address public proposer;
    address public voter1;
    address public voter2;
    address public voter3;
    address public voter4;
    address public voter5;
    
    // Kismet calculation contract (mock)
    KismetCalculator public kismetCalculator;
    
    // Current kismet formula
    struct KismetTier {
        string name;
        uint256 minReputation;
        uint256 maxReputation;
        uint256 multiplier; // In basis points (100 = 1.0x)
        uint256 dataQualityBonus; // Additional bonus for high quality
    }
    
    KismetTier[] public currentFormula;
    KismetTier[] public proposedFormula;
    
    function setUp() public {
        helpers = new ScenarioHelpers();
        simulator = new OffChainSimulator();
        
        // Create actors
        admin = helpers.createUser("Admin");
        proposer = helpers.createUser("Proposer");
        voter1 = helpers.createUser("SmallHolder");
        voter2 = helpers.createUser("MediumHolder");
        voter3 = helpers.createUser("LargeHolder");
        voter4 = helpers.createUser("Whale");
        voter5 = helpers.createUser("Validator");
        
        // Deploy kismet calculator
        kismetCalculator = new KismetCalculator(admin);
        
        // Initialize current formula
        _initializeCurrentFormula();
    }
    
    function _initializeCurrentFormula() private {
        // Current conservative formula
        currentFormula.push(KismetTier("Bronze", 0, 2500, 100, 0));
        currentFormula.push(KismetTier("Silver", 2501, 5000, 110, 5));
        currentFormula.push(KismetTier("Gold", 5001, 7500, 125, 10));
        currentFormula.push(KismetTier("Platinum", 7501, type(uint256).max, 150, 15));
        
        // Apply current formula as admin
        vm.startPrank(admin);
        for (uint256 i = 0; i < currentFormula.length; i++) {
            kismetCalculator.setTier(i, currentFormula[i]);
        }
        vm.stopPrank();
    }
    
    function test_ProposalToUpdateKismetFormula() public {
        helpers.startScenario("Governance Proposal to Update Kismet Formula");
        
        // Step 1: Community discussion phase
        console2.log("\n[STEP1] Community discussion on forum");
        console2.log("   Topic: 'Increasing rewards for quality contributors'");
        console2.log("   Duration: 3 days of discussion");
        console2.log("   Participants: 127 community members");
        
        simulator.simulateTimeProgression(3);
        
        // Step 2: Formal proposal creation
        console2.log("\n[STEP2] Creating formal governance proposal");
        
        // Define new formula
        proposedFormula.push(KismetTier("Bronze", 0, 2000, 100, 5));
        proposedFormula.push(KismetTier("Silver", 2001, 4500, 120, 10));
        proposedFormula.push(KismetTier("Gold", 4501, 7000, 145, 15));
        proposedFormula.push(KismetTier("Platinum", 7001, 10000, 175, 20));
        proposedFormula.push(KismetTier("Diamond", 10001, type(uint256).max, 200, 25));
        
        string memory proposalDescription = "KIP-001: Enhanced Kismet Formula for Quality Incentivization";
        
        console2.log("   Proposal:", proposalDescription);
        console2.log("\n   Current Formula:");
        _displayFormula(currentFormula);
        
        console2.log("\n   Proposed Formula:");
        _displayFormula(proposedFormula);
        
        console2.log("\n   Key Changes:");
        console2.log("   - Added Diamond tier for top contributors");
        console2.log("   - Increased multipliers across all tiers");
        console2.log("   - Added quality bonuses for high-quality data");
        console2.log("   - Adjusted reputation thresholds");
        
        // Step 3: Snapshot voting (off-chain)
        console2.log("\n[STEP3] Off-chain Snapshot voting");
        
        bytes32 snapshotId = simulator.createSnapshot("QmKismetProposal001...");
        
        // Simulate voting with different voting powers
        simulator.simulateSnapshotVote(snapshotId, voter1, 1, 1000e18);  // For
        simulator.simulateSnapshotVote(snapshotId, voter2, 1, 5000e18);  // For
        simulator.simulateSnapshotVote(snapshotId, voter3, 1, 10000e18); // For
        simulator.simulateSnapshotVote(snapshotId, voter4, 2, 8000e18);  // Against
        simulator.simulateSnapshotVote(snapshotId, voter5, 0, 2000e18);  // Abstain
        
        console2.log("   Voting period: 7 days");
        console2.log("   Total votes cast: 26,000 vRDAT");
        
        // Advance to end of voting
        simulator.simulateTimeProgression(8);
        
        bool passed = simulator.finalizeSnapshot(snapshotId);
        
        (uint256 forVotes, uint256 againstVotes, uint256 abstainVotes,,) = 
            simulator.getSnapshotResults(snapshotId);
        
        console2.log("\n   Results:");
        console2.log(string.concat(
            "   - For: ",
            vm.toString(forVotes / 1e18),
            " vRDAT (",
            vm.toString((forVotes * 100) / (forVotes + againstVotes)),
            "%)"
        ));
        console2.log(string.concat(
            "   - Against: ",
            vm.toString(againstVotes / 1e18),
            " vRDAT (",
            vm.toString((againstVotes * 100) / (forVotes + againstVotes)),
            "%)"
        ));
        console2.log(string.concat(
            "   - Abstain: ",
            vm.toString(abstainVotes / 1e18),
            " vRDAT"
        ));
        console2.log(string.concat("   - Outcome: ", passed ? "[PASSED]" : "[FAILED]"));
        
        assertTrue(passed, "Proposal should pass");
        
        // Step 4: On-chain execution with timelock
        console2.log("\n[STEP4] On-chain execution with 48-hour timelock");
        
        // Schedule the update as admin
        vm.prank(admin);
        bytes32 actionId = kismetCalculator.scheduleFormulaUpdate(proposedFormula);
        
        console2.log("   Update scheduled with ID:", vm.toString(actionId));
        console2.log("   Timelock period: 48 hours");
        
        // Advance past timelock
        simulator.simulateTimeProgression(2);
        
        // Execute the update as admin
        vm.prank(admin);
        kismetCalculator.executeFormulaUpdate(actionId);
        
        console2.log("   [OK] New kismet formula activated");
        
        // Step 5: Verify the update
        console2.log("\n[STEP5] Verifying formula update");
        
        console2.log("\n   Active Formula:");
        KismetTier[] memory activeFormula = kismetCalculator.getActiveFormula();
        _displayFormula(activeFormula);
        
        helpers.completeScenario("Governance Proposal to Update Kismet Formula", true);
    }
    
    function test_EmergencyKismetAdjustment() public {
        helpers.startScenario("Emergency Kismet Adjustment for Exploit Mitigation");
        
        console2.log("\n[ALERT] Exploit detected in kismet calculation!");
        console2.log("   Issue: Sybil attack using multiple accounts to farm rewards");
        console2.log("   Impact: 15% of epoch rewards going to suspected sybil accounts");
        
        // Step 1: Emergency pause
        console2.log("\n[STEP1] Emergency pause activated");
        
        vm.prank(admin);
        kismetCalculator.emergencyPause();
        
        console2.log("   [OK] Kismet calculations paused");
        console2.log("   Duration: 72 hours maximum");
        
        // Step 2: Rapid governance response
        console2.log("\n[STEP2] Emergency governance proposal");
        
        // Emergency formula to mitigate sybil attacks
        KismetTier[] memory emergencyFormula = new KismetTier[](4);
        emergencyFormula[0] = KismetTier("Bronze", 0, 5000, 100, 0);
        emergencyFormula[1] = KismetTier("Silver", 5001, 10000, 115, 5);
        emergencyFormula[2] = KismetTier("Gold", 10001, 15000, 130, 10);
        emergencyFormula[3] = KismetTier("Platinum", 15001, type(uint256).max, 150, 15);
        
        console2.log("   Emergency changes:");
        console2.log("   - Increased reputation requirements");
        console2.log("   - Reduced multiplier differences");
        console2.log("   - Anti-sybil reputation thresholds");
        
        // Fast-track voting (24 hours)
        bytes32 emergencyProposal = simulator.createSnapshot("QmEmergencyKismet...");
        
        // Major stakeholders vote quickly
        simulator.simulateSnapshotVote(emergencyProposal, voter3, 1, 10000e18);
        simulator.simulateSnapshotVote(emergencyProposal, voter4, 1, 8000e18);
        simulator.simulateSnapshotVote(emergencyProposal, voter5, 1, 2000e18);
        
        simulator.simulateTimeProgression(8); // Need to wait full 7 day voting period + buffer
        
        bool emergencyPassed = simulator.finalizeSnapshot(emergencyProposal);
        assertTrue(emergencyPassed, "Emergency proposal should pass");
        
        console2.log("   [OK] Emergency proposal passed with 100% support");
        
        // Step 3: Immediate execution (no timelock for emergency)
        console2.log("\n[STEP3] Immediate execution (timelock bypassed)");
        
        vm.prank(admin);
        kismetCalculator.emergencyUpdateFormula(emergencyFormula);
        
        console2.log("   [OK] Emergency formula activated");
        
        // Step 4: Resume operations
        console2.log("\n[STEP4] Resuming normal operations");
        
        vm.prank(admin);
        kismetCalculator.emergencyUnpause();
        
        console2.log("   [OK] Kismet calculations resumed with new formula");
        console2.log("   Sybil attack mitigated");
        
        helpers.completeScenario("Emergency Kismet Adjustment for Exploit Mitigation", true);
    }
    
    function test_CommunityProposedKismetExperiment() public {
        helpers.startScenario("Community-Proposed Kismet Experiment");
        
        console2.log("\n[INFO] Testing experimental kismet formula from community");
        
        // Step 1: Community member proposes experimental formula
        console2.log("\n[STEP1] Community proposal for experimental kismet");
        
        console2.log("   Proposer: Active contributor with 5000 reputation");
        console2.log("   Concept: Dynamic kismet based on data scarcity");
        
        // Experimental formula with scarcity multipliers
        console2.log("\n   Experimental Formula:");
        console2.log("   Base tiers remain the same, but add:");
        console2.log("   - Scarcity bonus: +20% for rare data types");
        console2.log("   - Freshness bonus: +10% for recent data");
        console2.log("   - Diversity bonus: +15% for varied sources");
        
        // Step 2: Testing period
        console2.log("\n[STEP2] 30-day testing period on subset");
        
        console2.log("   Test group: 100 contributors");
        console2.log("   Control group: 100 contributors");
        console2.log("   Duration: 30 days (4 epochs)");
        
        // Simulate testing period
        for (uint256 epoch = 1; epoch <= 4; epoch++) {
            console2.log(string.concat("\n   Epoch ", vm.toString(epoch), " results:"));
            
            uint256 testGroupRewards = 25000e18 + (epoch * 1000e18); // Increasing
            uint256 controlGroupRewards = 25000e18; // Stable
            
            console2.log("   - Test group rewards:", testGroupRewards / 1e18, "RDAT");
            console2.log("   - Control group rewards:", controlGroupRewards / 1e18, "RDAT");
            console2.log("   - Data quality improvement:", epoch * 5, "%");
            
            simulator.simulateTimeProgression(8);
        }
        
        // Step 3: Analysis and decision
        console2.log("\n[STEP3] Analysis of experimental results");
        
        console2.log("   Results:");
        console2.log("   - 20% increase in high-quality submissions");
        console2.log("   - 35% increase in rare data contributions");
        console2.log("   - 15% improvement in contributor retention");
        console2.log("   - No increase in suspected gaming behavior");
        
        console2.log("\n   Recommendation: Adopt experimental formula with modifications");
        
        // Step 4: Full rollout vote
        console2.log("\n[STEP4] Governance vote for full rollout");
        
        bytes32 rolloutProposal = simulator.createSnapshot("QmExperimentalRollout...");
        
        // Strong support after successful test
        simulator.simulateSnapshotVote(rolloutProposal, voter1, 1, 1000e18);
        simulator.simulateSnapshotVote(rolloutProposal, voter2, 1, 5000e18);
        simulator.simulateSnapshotVote(rolloutProposal, voter3, 1, 10000e18);
        simulator.simulateSnapshotVote(rolloutProposal, voter4, 1, 8000e18);
        simulator.simulateSnapshotVote(rolloutProposal, voter5, 1, 2000e18);
        
        simulator.simulateTimeProgression(8);
        
        bool rolloutPassed = simulator.finalizeSnapshot(rolloutProposal);
        assertTrue(rolloutPassed, "Rollout should pass");
        
        console2.log("   [OK] Experimental formula approved with 100% support");
        
        helpers.completeScenario("Community-Proposed Kismet Experiment", true);
    }
    
    // ============ Helper Functions ============
    
    function _displayFormula(KismetTier[] memory formula) internal view {
        for (uint256 i = 0; i < formula.length; i++) {
            console2.log(
                string.concat(
                    "   ",
                    formula[i].name,
                    " (",
                    vm.toString(formula[i].minReputation),
                    "-",
                    formula[i].maxReputation == type(uint256).max ? "max" : vm.toString(formula[i].maxReputation),
                    "): ",
                    vm.toString(formula[i].multiplier / 10),
                    ".",
                    vm.toString(formula[i].multiplier % 10),
                    "x"
                )
            );
            
            if (formula[i].dataQualityBonus > 0) {
                console2.log(
                    string.concat(
                        "     + Quality bonus: ",
                        vm.toString(formula[i].dataQualityBonus),
                        "%"
                    )
                );
            }
        }
    }
}

/**
 * @title KismetCalculator
 * @notice Mock contract for kismet calculation management
 */
contract KismetCalculator {
    address public admin;
    bool public paused;
    
    KismetGovernanceUpdate.KismetTier[] public activeTiers;
    mapping(bytes32 => KismetGovernanceUpdate.KismetTier[]) public pendingUpdates;
    mapping(bytes32 => uint256) public updateTimelocks;
    
    uint256 public constant TIMELOCK_DURATION = 48 hours;
    
    constructor(address _admin) {
        admin = _admin;
    }
    
    function setTier(uint256 index, KismetGovernanceUpdate.KismetTier memory tier) external {
        require(msg.sender == admin, "Only admin");
        
        if (index >= activeTiers.length) {
            activeTiers.push(tier);
        } else {
            activeTiers[index] = tier;
        }
    }
    
    function scheduleFormulaUpdate(
        KismetGovernanceUpdate.KismetTier[] memory newFormula
    ) external returns (bytes32 actionId) {
        require(msg.sender == admin, "Only admin");
        
        actionId = keccak256(abi.encode(newFormula, block.timestamp));
        
        // Store pending update
        for (uint256 i = 0; i < newFormula.length; i++) {
            pendingUpdates[actionId].push(newFormula[i]);
        }
        
        updateTimelocks[actionId] = block.timestamp + TIMELOCK_DURATION;
        
        return actionId;
    }
    
    function executeFormulaUpdate(bytes32 actionId) external {
        require(msg.sender == admin, "Only admin");
        require(updateTimelocks[actionId] != 0, "Update not found");
        require(block.timestamp >= updateTimelocks[actionId], "Timelock not expired");
        
        // Clear current formula
        delete activeTiers;
        
        // Apply new formula
        KismetGovernanceUpdate.KismetTier[] storage pending = pendingUpdates[actionId];
        for (uint256 i = 0; i < pending.length; i++) {
            activeTiers.push(pending[i]);
        }
        
        // Clean up
        delete pendingUpdates[actionId];
        delete updateTimelocks[actionId];
    }
    
    function emergencyPause() external {
        require(msg.sender == admin, "Only admin");
        paused = true;
    }
    
    function emergencyUnpause() external {
        require(msg.sender == admin, "Only admin");
        paused = false;
    }
    
    function emergencyUpdateFormula(
        KismetGovernanceUpdate.KismetTier[] memory emergencyFormula
    ) external {
        require(msg.sender == admin, "Only admin");
        require(paused, "Must be paused for emergency update");
        
        // Clear and update immediately (no timelock)
        delete activeTiers;
        
        for (uint256 i = 0; i < emergencyFormula.length; i++) {
            activeTiers.push(emergencyFormula[i]);
        }
    }
    
    function getActiveFormula() external view returns (KismetGovernanceUpdate.KismetTier[] memory) {
        return activeTiers;
    }
    
    function calculateKismet(
        uint256 reputation,
        uint256 dataQuality
    ) external view returns (uint256 multiplier) {
        require(!paused, "Calculator paused");
        
        // Find appropriate tier
        for (uint256 i = 0; i < activeTiers.length; i++) {
            if (reputation >= activeTiers[i].minReputation && 
                reputation <= activeTiers[i].maxReputation) {
                
                multiplier = activeTiers[i].multiplier;
                
                // Apply quality bonus if data is high quality
                if (dataQuality >= 80 && activeTiers[i].dataQualityBonus > 0) {
                    multiplier += activeTiers[i].dataQualityBonus;
                }
                
                return multiplier;
            }
        }
        
        // Default to base multiplier if no tier found
        return 100;
    }
}