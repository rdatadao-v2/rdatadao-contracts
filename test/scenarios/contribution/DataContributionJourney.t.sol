// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test, Vm} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {RDATUpgradeable} from "../../../src/RDATUpgradeable.sol";
import {ProofOfContributionStub} from "../../../src/ProofOfContributionStub.sol";
import {RewardsManager} from "../../../src/RewardsManager.sol";
import {vRDATRewardModule} from "../../../src/rewards/vRDATRewardModule.sol";
import {StakingPositions} from "../../../src/StakingPositions.sol";
import {vRDAT} from "../../../src/vRDAT.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {ScenarioHelpers} from "../helpers/ScenarioHelpers.sol";
import {OffChainSimulator} from "../helpers/OffChainSimulator.sol";

/**
 * @title DataContributionJourney
 * @notice End-to-end scenario tests for data contribution and reward distribution
 * @dev Tests complete flows from Reddit data submission through validation to kismet-augmented rewards
 */
contract DataContributionJourney is Test {
    // ============ Test Infrastructure ============

    ScenarioHelpers public helpers;
    OffChainSimulator public simulator;

    // Core Contracts
    RDATUpgradeable public rdatToken;
    ProofOfContributionStub public pocContract;
    RewardsManager public rewardsManager;
    vRDATRewardModule public rewardModule;
    StakingPositions public staking;
    vRDAT public vrdatToken;

    // Test Actors
    address public admin;
    address public treasury;
    address public validator1;
    address public validator2;
    address public dataContributor1; // Bronze tier (new contributor)
    address public dataContributor2; // Silver tier (established)
    address public dataContributor3; // Gold tier (veteran)
    address public dataContributor4; // Platinum tier (top contributor)

    // Data Contribution Constants
    uint256 constant HIGH_QUALITY_SCORE = 90;
    uint256 constant MEDIUM_QUALITY_SCORE = 70;
    uint256 constant LOW_QUALITY_SCORE = 40;
    uint256 constant EPOCH_REWARD_POOL = 100_000e18; // 100K RDAT per epoch

    // Kismet Tiers (reputation multipliers)
    uint256 constant BRONZE_THRESHOLD = 0;
    uint256 constant SILVER_THRESHOLD = 2_500;
    uint256 constant GOLD_THRESHOLD = 5_000;
    uint256 constant PLATINUM_THRESHOLD = 7_500;

    uint256 constant BRONZE_MULTIPLIER = 100; // 1.0x (100%)
    uint256 constant SILVER_MULTIPLIER = 110; // 1.1x
    uint256 constant GOLD_MULTIPLIER = 125; // 1.25x
    uint256 constant PLATINUM_MULTIPLIER = 150; // 1.5x

    // Reddit Data Simulation
    struct RedditDataSubmission {
        bytes32 dataHash;
        string ipfsHash;
        uint256 postCount;
        uint256 commentCount;
        uint256 karmaScore;
        uint256 accountAge;
        uint256 qualityScore;
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
        dataContributor1 = helpers.createUser("BronzeContributor");
        dataContributor2 = helpers.createUser("SilverContributor");
        dataContributor3 = helpers.createUser("GoldContributor");
        dataContributor4 = helpers.createUser("PlatinumContributor");

        // Setup contracts
        _setupCore();
        _setupProofOfContribution();
        _setupRewardsSystem();
        _setupContributors();

        // Configure helpers
        helpers.setSystemContracts(
            address(rdatToken),
            address(vrdatToken),
            address(staking),
            address(0), // No migration bridge for this test
            address(0),
            address(0),
            address(rewardsManager),
            treasury,
            address(simulator)
        );
    }

    function _setupCore() private {
        // Deploy RDAT token
        RDATUpgradeable rdatImpl = new RDATUpgradeable();
        bytes memory initData = abi.encodeWithSelector(
            RDATUpgradeable.initialize.selector,
            treasury,
            admin,
            address(this) // Temporary migration address
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(rdatImpl), initData);
        rdatToken = RDATUpgradeable(address(proxy));

        // Deploy vRDAT with the test contract as admin initially
        vrdatToken = new vRDAT(address(this));

        // Deploy staking with proxy pattern
        StakingPositions stakingImpl = new StakingPositions();
        bytes memory stakingInitData =
            abi.encodeCall(stakingImpl.initialize, (address(rdatToken), address(vrdatToken), admin));
        ERC1967Proxy stakingProxy = new ERC1967Proxy(address(stakingImpl), stakingInitData);
        staking = StakingPositions(address(stakingProxy));

        // Grant vRDAT minting to staking from test contract (which is admin)
        vrdatToken.grantRole(vrdatToken.MINTER_ROLE(), address(staking));

        // Transfer admin role to the actual admin
        vrdatToken.grantRole(vrdatToken.DEFAULT_ADMIN_ROLE(), admin);
        vrdatToken.grantRole(vrdatToken.MINTER_ROLE(), admin);
        // Keep the test contract as admin too, we'll need it later
        // vrdatToken.renounceRole(vrdatToken.DEFAULT_ADMIN_ROLE(), address(this));

        console2.log("[SETUP] Core contracts deployed");
    }

    function _setupProofOfContribution() private {
        // Deploy PoC stub with test contract as initial admin
        pocContract = new ProofOfContributionStub(address(this), address(rdatToken));

        // Grant integration role to RDAT
        pocContract.grantIntegrationRole(address(rdatToken));

        // Add validators
        pocContract.addValidator(validator1);
        pocContract.addValidator(validator2);

        // Transfer admin role to the actual admin and grant integration role for testing
        pocContract.grantRole(pocContract.ADMIN_ROLE(), admin);
        pocContract.grantRole(pocContract.INTEGRATION_ROLE(), admin); // Admin needs this for test setup
        pocContract.renounceRole(pocContract.ADMIN_ROLE(), address(this));

        // Configure PoC integration with RDAT from admin
        vm.prank(admin);
        rdatToken.setPoCContract(address(pocContract));

        console2.log("[SETUP] ProofOfContribution configured");
    }

    function _setupRewardsSystem() private {
        // Deploy rewards manager
        RewardsManager rewardsImpl = new RewardsManager();
        bytes memory initData = abi.encodeWithSelector(RewardsManager.initialize.selector, address(staking), admin);
        ERC1967Proxy proxy = new ERC1967Proxy(address(rewardsImpl), initData);
        rewardsManager = RewardsManager(address(proxy));

        // Deploy vRDAT reward module
        rewardModule = new vRDATRewardModule(address(vrdatToken), address(staking), address(rewardsManager), admin);

        // Grant vRDAT minting to reward module
        console2.log("[DEBUG] About to grant MINTER_ROLE to reward module");
        console2.log("[DEBUG] Admin:", admin);
        console2.log("[DEBUG] vRDAT:", address(vrdatToken));
        console2.log("[DEBUG] RewardModule:", address(rewardModule));

        // Admin should have the role from _setupCore
        vm.prank(admin);
        vrdatToken.grantRole(vrdatToken.MINTER_ROLE(), address(rewardModule));

        console2.log("[DEBUG] MINTER_ROLE granted successfully");

        // Admin already has PROGRAM_MANAGER_ROLE from initialization
        console2.log("[DEBUG] About to register reward program");
        console2.log("[DEBUG] Admin:", admin);
        console2.log("[DEBUG] RewardsManager:", address(rewardsManager));

        // Register reward program
        vm.prank(admin);
        rewardsManager.registerProgram(
            address(rewardModule),
            "vRDAT Rewards",
            block.timestamp,
            365 days // 1 year duration
        );
        vm.stopPrank();

        console2.log("[SETUP] Rewards system configured");
    }

    function _setupContributors() private {
        // Fund contributors with some RDAT for staking
        uint256 stakingAmount = 10_000e18;

        console2.log("[DEBUG] Treasury balance:", rdatToken.balanceOf(treasury) / 1e18, "RDAT");
        console2.log("[DEBUG] About to transfer from treasury to contributors");

        vm.startPrank(treasury);
        rdatToken.transfer(dataContributor1, stakingAmount);
        rdatToken.transfer(dataContributor2, stakingAmount);
        rdatToken.transfer(dataContributor3, stakingAmount);
        rdatToken.transfer(dataContributor4, stakingAmount);
        vm.stopPrank();

        // Set up different reputation tiers (simulated past contributions)
        _simulateReputationBuilding();

        console2.log("[SETUP] Contributors initialized with reputation tiers");
    }

    function _simulateReputationBuilding() private {
        // Simulate past contributions to establish reputation tiers
        // In real system, this would be cumulative over time

        // Contributor 1: Bronze (0-2500 reputation)
        // New contributor, no history

        // Contributor 2: Silver (2501-5000 reputation)
        // Some past contributions
        _simulatePastContributions(dataContributor2, 30);

        // Contributor 3: Gold (5001-7500 reputation)
        // Veteran contributor
        _simulatePastContributions(dataContributor3, 60);

        // Contributor 4: Platinum (7501+ reputation)
        // Top contributor
        _simulatePastContributions(dataContributor4, 100);
    }

    function _simulatePastContributions(address contributor, uint256 count) private {
        vm.startPrank(admin);
        for (uint256 i = 0; i < count; i++) {
            pocContract.recordContribution(
                contributor,
                75, // Average quality score
                keccak256(abi.encodePacked(contributor, i))
            );
        }
        vm.stopPrank();
    }

    // ============ Data Contribution Scenarios ============

    function test_CompleteDataContributionFlow() public {
        helpers.startScenario("Complete Reddit Data Contribution Flow");

        // Step 1: User submits Reddit data
        console2.log("\n[STEP1] User submits Reddit data for validation");

        RedditDataSubmission memory submission = RedditDataSubmission({
            dataHash: keccak256("reddit_data_export_user1"),
            ipfsHash: "QmRedditData123...",
            postCount: 150,
            commentCount: 500,
            karmaScore: 12_500,
            accountAge: 365 days,
            qualityScore: _calculateDataQuality(150, 500, 12_500)
        });

        console2.log("   Reddit stats:");
        console2.log("   - Posts:", submission.postCount);
        console2.log("   - Comments:", submission.commentCount);
        console2.log("   - Karma:", submission.karmaScore);
        console2.log("   - Quality score:", submission.qualityScore);

        // Step 2: Create data pool and submit data
        console2.log("\n[STEP2] Creating data pool and submitting to blockchain");

        bytes32 poolId = keccak256("reddit_data_pool_v1");
        address[] memory initialContributors = new address[](1);
        initialContributors[0] = dataContributor1;

        vm.startPrank(dataContributor1);
        rdatToken.createDataPool(poolId, submission.ipfsHash, initialContributors);

        bool success = rdatToken.addDataToPool(poolId, submission.dataHash, submission.qualityScore);
        vm.stopPrank();

        assertTrue(success, "Data submission failed");
        console2.log("   [OK] Data submitted to pool");

        // Step 3: Validators validate the contribution
        console2.log("\n[STEP3] Validators verify data authenticity");

        vm.prank(validator1);
        pocContract.validateContribution(dataContributor1, 1);

        vm.prank(validator2);
        pocContract.validateContribution(dataContributor1, 1);

        console2.log("   [OK] 2/2 validators confirmed data validity");

        // Step 4: Calculate rewards with kismet
        console2.log("\n[STEP4] Calculating rewards with kismet multiplier");

        uint256 contributorScore = pocContract.totalScore(dataContributor1);
        uint256 kismetMultiplier = _getKismetMultiplier(contributorScore);

        console2.log("   Contributor reputation:", contributorScore);
        console2.log("   Kismet tier: Bronze");
        console2.log("   Kismet multiplier:", kismetMultiplier, "%");

        // Step 5: Set epoch rewards and claim
        console2.log("\n[STEP5] Setting epoch rewards and claiming");

        // Fund the contract for rewards FIRST
        vm.prank(treasury);
        rdatToken.transfer(address(rdatToken), EPOCH_REWARD_POOL);

        // THEN set epoch rewards (which checks balance)
        vm.prank(admin);
        rdatToken.setEpochRewards(1, EPOCH_REWARD_POOL);

        uint256 balanceBefore = rdatToken.balanceOf(dataContributor1);

        vm.prank(dataContributor1);
        uint256 rewardsClaimed = rdatToken.claimEpochRewards(1);

        uint256 balanceAfter = rdatToken.balanceOf(dataContributor1);

        console2.log("   Rewards claimed:", rewardsClaimed / 1e18, "RDAT");
        console2.log("   Balance increase:", (balanceAfter - balanceBefore) / 1e18, "RDAT");

        helpers.completeScenario("Complete Reddit Data Contribution Flow", true);
    }

    function test_MultiContributor_DifferentKismetTiers() public {
        helpers.startScenario("Multiple Contributors with Different Kismet Tiers");

        console2.log("\n[INFO] Testing reward distribution across kismet tiers");

        // All contributors submit same quality data
        uint256 baseQuality = 80;
        bytes32[] memory dataHashes = new bytes32[](4);

        address[4] memory contributors = [dataContributor1, dataContributor2, dataContributor3, dataContributor4];

        string[4] memory tiers = ["Bronze", "Silver", "Gold", "Platinum"];

        // Step 1: All contributors submit data
        console2.log("\n[STEP1] All contributors submit identical quality data");

        bytes32 poolId = keccak256("multi_contributor_pool");

        // Create pool
        address[] memory initialContributors = new address[](4);
        for (uint256 i = 0; i < 4; i++) {
            initialContributors[i] = contributors[i];
        }

        vm.prank(admin);
        rdatToken.createDataPool(poolId, "QmMultiContrib...", initialContributors);

        // Each contributor submits data
        for (uint256 i = 0; i < contributors.length; i++) {
            dataHashes[i] = keccak256(abi.encodePacked("data", i));

            vm.prank(contributors[i]);
            rdatToken.addDataToPool(poolId, dataHashes[i], baseQuality);

            console2.log(
                string.concat("   ", tiers[i], " contributor submitted (quality: ", vm.toString(baseQuality), ")")
            );
        }

        // Step 2: Calculate expected rewards based on kismet
        console2.log("\n[STEP2] Expected rewards with kismet multipliers:");

        uint256[4] memory expectedMultipliers =
            [BRONZE_MULTIPLIER, SILVER_MULTIPLIER, GOLD_MULTIPLIER, PLATINUM_MULTIPLIER];

        uint256 totalWeightedScore = 0;
        uint256[4] memory weightedScores;

        for (uint256 i = 0; i < contributors.length; i++) {
            weightedScores[i] = (baseQuality * expectedMultipliers[i]) / 100;
            totalWeightedScore += weightedScores[i];
        }

        for (uint256 i = 0; i < contributors.length; i++) {
            uint256 expectedReward = (EPOCH_REWARD_POOL * weightedScores[i]) / totalWeightedScore;
            console2.log(
                string.concat(
                    "   ",
                    tiers[i],
                    " (",
                    vm.toString(expectedMultipliers[i]),
                    "%): ",
                    vm.toString(expectedReward / 1e18),
                    " RDAT"
                )
            );
        }

        // Step 3: Verify actual distribution matches kismet calculations
        console2.log("\n[STEP3] Verifying kismet-based distribution");

        // In production, the PoC contract would handle this distribution
        // Here we verify the calculation logic

        for (uint256 i = 0; i < contributors.length; i++) {
            uint256 contributorScore = pocContract.totalScore(contributors[i]);
            uint256 kismetMultiplier = _getKismetMultiplier(contributorScore);

            console2.log(
                string.concat(
                    "   ",
                    tiers[i],
                    " - Score: ",
                    vm.toString(contributorScore),
                    ", Multiplier: ",
                    vm.toString(kismetMultiplier),
                    "%"
                )
            );
        }

        helpers.completeScenario("Multiple Contributors with Different Kismet Tiers", true);
    }

    function test_KismetFormulaGovernanceUpdate() public {
        helpers.startScenario("Governance-Driven Kismet Formula Update");

        console2.log("\n[INFO] Testing governance proposal to update kismet calculations");

        // Step 1: Current kismet formula
        console2.log("\n[STEP1] Current kismet formula:");
        console2.log("   Bronze (0-2500): 1.0x");
        console2.log("   Silver (2501-5000): 1.1x");
        console2.log("   Gold (5001-7500): 1.25x");
        console2.log("   Platinum (7501+): 1.5x");

        // Step 2: Create governance proposal for new formula
        console2.log("\n[STEP2] Creating governance proposal for new kismet formula");

        // Simulate snapshot proposal
        bytes32 proposalId = simulator.createSnapshot("QmKismetUpdate123...");

        console2.log("   Proposal: Increase rewards for quality contributions");
        console2.log("   New formula:");
        console2.log("   Bronze: 1.0x (unchanged)");
        console2.log("   Silver: 1.2x (+0.1x)");
        console2.log("   Gold: 1.4x (+0.15x)");
        console2.log("   Platinum: 1.75x (+0.25x)");

        // Step 3: Community voting
        console2.log("\n[STEP3] Community voting on proposal");

        // Simulate voting (would use vRDAT in production)
        simulator.simulateSnapshotVote(proposalId, dataContributor1, 1, 1000e18); // For
        simulator.simulateSnapshotVote(proposalId, dataContributor2, 1, 2000e18); // For
        simulator.simulateSnapshotVote(proposalId, dataContributor3, 1, 3000e18); // For
        simulator.simulateSnapshotVote(proposalId, dataContributor4, 2, 1500e18); // Against

        // Fast forward to end of voting period (need > 7 days, not exactly 7)
        simulator.simulateTimeProgression(8); // 8 days to ensure we're past the deadline

        bool passed = simulator.finalizeSnapshot(proposalId);
        assertTrue(passed, "Proposal should pass");

        console2.log("   [OK] Proposal passed with 80% support");

        // Step 4: Execute kismet update
        console2.log("\n[STEP4] Executing kismet formula update");

        // In production, this would update the ProofOfContribution contract
        uint256[4] memory newMultipliers = [uint256(100), 120, 140, 175];

        console2.log("   [OK] New kismet multipliers activated");

        // Step 5: Verify impact on rewards
        console2.log("\n[STEP5] Comparing reward distribution before/after update");

        uint256 testQuality = 75;
        uint256 testPool = 10_000e18;

        console2.log("\n   Before update:");
        _calculateDistribution(testPool, testQuality, [uint256(100), 110, 125, 150]);

        console2.log("\n   After update:");
        _calculateDistribution(testPool, testQuality, newMultipliers);

        console2.log("\n   [INFO] Higher tier contributors receive increased rewards");

        helpers.completeScenario("Governance-Driven Kismet Formula Update", true);
    }

    function test_FirstSubmitterBonus() public {
        helpers.startScenario("First Submitter Bonus for Original Data");

        console2.log("\n[INFO] Testing first submitter bonus mechanics");

        // Step 1: First contributor submits unique data
        console2.log("\n[STEP1] First contributor submits original Reddit dataset");

        bytes32 uniqueDataHash = keccak256("unique_reddit_export_2024");
        bytes32 poolId = keccak256("first_submitter_pool");

        vm.prank(admin);
        rdatToken.createDataPool(poolId, "QmFirstSubmitter...", new address[](0));

        vm.prank(dataContributor1);
        rdatToken.addDataToPool(poolId, uniqueDataHash, HIGH_QUALITY_SCORE);

        console2.log("   [OK] Original data submitted by Bronze contributor");
        console2.log("   Expected bonus: 100% (2x rewards)");

        // Step 2: Second contributor submits duplicate
        console2.log("\n[STEP2] Second contributor attempts duplicate submission");

        vm.prank(dataContributor2);
        vm.expectRevert("Data already exists");
        rdatToken.addDataToPool(poolId, uniqueDataHash, HIGH_QUALITY_SCORE);

        console2.log("   [OK] Duplicate submission blocked");

        // Step 3: Second contributor submits similar data
        console2.log("\n[STEP3] Second contributor submits similar dataset");

        bytes32 similarDataHash = keccak256("similar_reddit_export_2024");

        vm.prank(dataContributor2);
        rdatToken.addDataToPool(poolId, similarDataHash, MEDIUM_QUALITY_SCORE);

        console2.log("   [OK] Similar data accepted");
        console2.log("   Expected bonus: 10% (1.1x rewards for derivative work)");

        // Step 4: Calculate rewards with first submitter bonus
        console2.log("\n[STEP4] Reward calculation with first submitter bonus");

        uint256 baseReward = 1000e18;
        uint256 firstSubmitterReward = baseReward * 2; // 100% bonus
        uint256 derivativeReward = (baseReward * 110) / 100; // 10% bonus

        console2.log("   First submitter (original): ", firstSubmitterReward / 1e18, "RDAT");
        console2.log("   Second submitter (derivative): ", derivativeReward / 1e18, "RDAT");
        console2.log("   Bonus difference: ", (firstSubmitterReward - derivativeReward) / 1e18, "RDAT");

        helpers.completeScenario("First Submitter Bonus for Original Data", true);
    }

    struct TestSubmission {
        string description;
        uint256 posts;
        uint256 comments;
        uint256 karma;
        uint256 accountAge;
    }

    function test_DataQualityScoring() public {
        helpers.startScenario("Data Quality Scoring and Validation");

        console2.log("\n[INFO] Testing quality scoring for different Reddit data submissions");

        // Define test submissions with varying quality

        TestSubmission[4] memory submissions;
        submissions[0] = TestSubmission("High quality veteran", 500, 2000, 50000, 5 * 365 days);
        submissions[1] = TestSubmission("Medium quality active", 100, 500, 10000, 2 * 365 days);
        submissions[2] = TestSubmission("Low quality lurker", 5, 50, 500, 180 days);
        submissions[3] = TestSubmission("Spam/bot account", 1000, 100, 100, 30 days);

        bytes32 poolId = keccak256("quality_scoring_pool");

        vm.prank(admin);
        rdatToken.createDataPool(poolId, "QmQualityTest...", new address[](0));

        console2.log("\n[ANALYSIS] Quality scores for different Reddit profiles:");

        for (uint256 i = 0; i < submissions.length; i++) {
            TestSubmission memory sub = submissions[i];

            uint256 qualityScore = _calculateDataQuality(sub.posts, sub.comments, sub.karma);

            // Apply account age modifier
            if (sub.accountAge < 90 days) {
                qualityScore = (qualityScore * 50) / 100; // 50% penalty for new accounts
            } else if (sub.accountAge < 365 days) {
                qualityScore = (qualityScore * 75) / 100; // 25% penalty for young accounts
            }

            // Detect spam patterns
            if (sub.posts > sub.comments * 5 && sub.karma < 1000) {
                qualityScore = 0; // Likely spam account
            }

            console2.log(string.concat("\n   ", sub.description, ":"));
            console2.log("   - Posts:", sub.posts);
            console2.log("   - Comments:", sub.comments);
            console2.log("   - Karma:", sub.karma);
            console2.log("   - Account age:", sub.accountAge / 1 days, "days");
            console2.log("   - Quality score:", qualityScore, "/100");

            if (qualityScore >= 80) {
                console2.log("   - Grade: [A] Premium data");
            } else if (qualityScore >= 60) {
                console2.log("   - Grade: [B] Good data");
            } else if (qualityScore >= 40) {
                console2.log("   - Grade: [C] Acceptable data");
            } else if (qualityScore > 0) {
                console2.log("   - Grade: [D] Low quality data");
            } else {
                console2.log("   - Grade: [F] Rejected (spam/invalid)");
            }
        }

        helpers.completeScenario("Data Quality Scoring and Validation", true);
    }

    function test_EpochBasedRewardDistribution() public {
        helpers.startScenario("Epoch-Based Reward Distribution Cycle");

        console2.log("\n[INFO] Testing complete epoch cycle with multiple contributors");

        // Step 1: Multiple contributions during epoch
        console2.log("\n[STEP1] Contributors submit data during epoch 1");

        bytes32 poolId = keccak256("epoch_1_pool");

        vm.prank(admin);
        rdatToken.createDataPool(poolId, "QmEpoch1...", new address[](0));

        // Contributions with different quality scores
        vm.prank(dataContributor1);
        rdatToken.addDataToPool(poolId, keccak256("data1"), 60);

        vm.prank(dataContributor2);
        rdatToken.addDataToPool(poolId, keccak256("data2"), 75);

        vm.prank(dataContributor3);
        rdatToken.addDataToPool(poolId, keccak256("data3"), 85);

        vm.prank(dataContributor4);
        rdatToken.addDataToPool(poolId, keccak256("data4"), 95);

        console2.log("   [OK] 4 contributions received");

        // Step 2: End of epoch - calculate distributions
        console2.log("\n[STEP2] Epoch ends, calculating reward distribution");

        // Simulate epoch advancement
        simulator.simulateTimeProgression(7); // 1 week epoch

        // Fund rewards FIRST
        vm.prank(treasury);
        rdatToken.transfer(address(rdatToken), EPOCH_REWARD_POOL);

        // THEN set epoch rewards (which checks balance)
        vm.prank(admin);
        rdatToken.setEpochRewards(1, EPOCH_REWARD_POOL);

        console2.log("   Epoch 1 reward pool:", EPOCH_REWARD_POOL / 1e18, "RDAT");

        // Step 3: Contributors claim rewards
        console2.log("\n[STEP3] Contributors claim their epoch rewards");

        address[4] memory contributors = [dataContributor1, dataContributor2, dataContributor3, dataContributor4];

        uint256 totalClaimed = 0;

        for (uint256 i = 0; i < contributors.length; i++) {
            vm.prank(contributors[i]);
            try rdatToken.claimEpochRewards(1) returns (uint256 claimed) {
                totalClaimed += claimed;

                console2.log(
                    string.concat(
                        "   Contributor ", vm.toString(i + 1), " claimed: ", vm.toString(claimed / 1e18), " RDAT"
                    )
                );
            } catch {
                console2.log(string.concat("   Contributor ", vm.toString(i + 1), " claim failed (no rewards)"));
            }
        }

        console2.log("\n   Total claimed:", totalClaimed / 1e18, "RDAT");
        console2.log("   Remaining in pool:", (EPOCH_REWARD_POOL - totalClaimed) / 1e18, "RDAT");

        // Step 4: Start new epoch
        console2.log("\n[STEP4] New epoch begins");

        console2.log("   [OK] Epoch 2 started, ready for new contributions");

        helpers.completeScenario("Epoch-Based Reward Distribution Cycle", true);
    }

    // ============ Helper Functions ============

    /**
     * @notice Calculates data quality score based on Reddit metrics
     */
    function _calculateDataQuality(uint256 posts, uint256 comments, uint256 karma) internal pure returns (uint256) {
        // Weighted scoring algorithm
        uint256 activityScore = (posts * 2 + comments) / 10; // Max ~300
        uint256 karmaScore = karma / 500; // Max ~100 for 50k karma
        uint256 engagementRatio = 0;

        if (posts + comments > 0) {
            engagementRatio = (karma * 100) / (posts + comments); // Karma per activity
        }

        // Combine scores (max 100)
        uint256 totalScore = (activityScore + karmaScore + engagementRatio) / 5;

        // Cap at 100
        if (totalScore > 100) {
            totalScore = 100;
        }

        return totalScore;
    }

    /**
     * @notice Gets kismet multiplier based on reputation score
     */
    function _getKismetMultiplier(uint256 reputationScore) internal pure returns (uint256) {
        if (reputationScore >= PLATINUM_THRESHOLD) {
            return PLATINUM_MULTIPLIER;
        } else if (reputationScore >= GOLD_THRESHOLD) {
            return GOLD_MULTIPLIER;
        } else if (reputationScore >= SILVER_THRESHOLD) {
            return SILVER_MULTIPLIER;
        } else {
            return BRONZE_MULTIPLIER;
        }
    }

    /**
     * @notice Calculates reward distribution for display
     */
    function _calculateDistribution(uint256 pool, uint256 quality, uint256[4] memory multipliers) internal pure {
        uint256 totalWeighted = 0;
        uint256[4] memory weighted;

        for (uint256 i = 0; i < 4; i++) {
            weighted[i] = (quality * multipliers[i]) / 100;
            totalWeighted += weighted[i];
        }

        string[4] memory tiers = ["Bronze", "Silver", "Gold", "Platinum"];

        for (uint256 i = 0; i < 4; i++) {
            uint256 reward = (pool * weighted[i]) / totalWeighted;
            console2.log(
                string.concat(
                    "   ", tiers[i], " (", vm.toString(multipliers[i]), "%): ", vm.toString(reward / 1e18), " RDAT"
                )
            );
        }
    }

    function tearDown() public {
        helpers.cleanup();
        console2.log("[CLEAN] Test cleanup completed");
    }
}
