// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../src/ProofOfContribution.sol";
import "../src/EmergencyPause.sol";
import "../src/mocks/MockRDAT.sol";

contract ProofOfContributionTest is Test {
    ProofOfContribution public poc;
    EmergencyPause public emergencyPause;
    
    address public admin = address(0x1);
    address public validator1 = address(0x2);
    address public validator2 = address(0x3);
    address public validator3 = address(0x4);
    address public contributor1 = address(0x5);
    address public contributor2 = address(0x6);
    address public dlpAddress = address(0x7);
    
    // Events
    event ContributionRecorded(address indexed contributor, uint256 score, bytes32 dataHash);
    event ValidatorAdded(address indexed validator);
    event ValidatorRemoved(address indexed validator);
    event RewardsDistributed(address indexed contributor, uint256 amount);
    event EpochAdvanced(uint256 indexed newEpoch, uint256 epochScore);
    event ContributionValidated(address indexed contributor, uint256 indexed contributionId, address validator);

    function setUp() public {
        vm.startPrank(admin);
        
        // Deploy emergency pause
        emergencyPause = new EmergencyPause(admin);
        
        // Deploy ProofOfContribution with initial validators
        address[] memory validators = new address[](2);
        validators[0] = validator1;
        validators[1] = validator2;
        
        poc = new ProofOfContribution(
            dlpAddress,
            address(emergencyPause),
            validators
        );
        
        vm.stopPrank();
    }

    // ========== BASIC FUNCTIONALITY TESTS ==========

    function test_InitialState() public view {
        assertEq(poc.dlpAddress(), dlpAddress);
        assertEq(poc.currentEpoch(), 1);
        assertTrue(poc.isActive());
        assertTrue(poc.isValidator(validator1));
        assertTrue(poc.isValidator(validator2));
        assertEq(poc.getValidatorCount(), 2);
    }

    function test_RecordContribution() public {
        bytes32 dataHash = keccak256("test data");
        uint256 score = 75;
        
        vm.expectEmit(true, false, false, true);
        emit ContributionRecorded(contributor1, score, dataHash);
        
        poc.recordContribution(contributor1, score, dataHash);
        
        assertEq(poc.contributionCount(contributor1), 1);
        
        IProofOfContribution.Contribution memory contrib = poc.contributions(contributor1, 0);
        assertEq(contrib.score, score);
        assertEq(contrib.dataHash, dataHash);
        assertFalse(contrib.validated);
        assertEq(contrib.timestamp, block.timestamp);
    }

    function test_RecordContribution_InvalidScore() public {
        bytes32 dataHash = keccak256("test data");
        
        vm.expectRevert(ProofOfContribution.InvalidScore.selector);
        poc.recordContribution(contributor1, 101, dataHash);
    }

    function test_RecordContribution_InvalidContributor() public {
        bytes32 dataHash = keccak256("test data");
        
        vm.expectRevert(ProofOfContribution.InvalidContribution.selector);
        poc.recordContribution(address(0), 50, dataHash);
    }

    function test_RecordContribution_InvalidDataHash() public {
        vm.expectRevert(ProofOfContribution.InvalidContribution.selector);
        poc.recordContribution(contributor1, 50, bytes32(0));
    }

    // ========== VALIDATION TESTS ==========

    function test_ValidateContribution() public {
        // Record contribution
        bytes32 dataHash = keccak256("test data");
        uint256 score = 80;
        poc.recordContribution(contributor1, score, dataHash);
        
        // Validate as validator1
        vm.prank(validator1);
        vm.expectEmit(true, true, false, true);
        emit ContributionValidated(contributor1, 0, validator1);
        poc.validateContribution(contributor1, 0);
        
        // With 2 validators, need both to validate
        IProofOfContribution.Contribution memory contrib = poc.contributions(contributor1, 0);
        assertFalse(contrib.validated);
        
        // Validate as validator2
        vm.prank(validator2);
        poc.validateContribution(contributor1, 0);
        
        // Now should be validated
        contrib = poc.contributions(contributor1, 0);
        assertTrue(contrib.validated);
        assertEq(poc.totalScore(contributor1), score);
        assertEq(poc.getEpochScore(contributor1, 1), score);
    }

    function test_ValidateContribution_NotValidator() public {
        poc.recordContribution(contributor1, 50, keccak256("test"));
        
        vm.prank(contributor2);
        vm.expectRevert(ProofOfContribution.NotValidator.selector);
        poc.validateContribution(contributor1, 0);
    }

    function test_ValidateContribution_AlreadyValidated() public {
        poc.recordContribution(contributor1, 50, keccak256("test"));
        
        vm.startPrank(validator1);
        poc.validateContribution(contributor1, 0);
        
        vm.expectRevert(ProofOfContribution.AlreadyValidated.selector);
        poc.validateContribution(contributor1, 0);
        vm.stopPrank();
    }

    function test_ValidateContribution_InvalidId() public {
        vm.prank(validator1);
        vm.expectRevert(ProofOfContribution.InvalidContribution.selector);
        poc.validateContribution(contributor1, 0);
    }

    function test_ValidateContribution_WindowExpired() public {
        poc.recordContribution(contributor1, 50, keccak256("test"));
        
        // Move past validation window
        vm.warp(block.timestamp + 7 hours);
        
        vm.prank(validator1);
        vm.expectRevert(ProofOfContribution.ValidationWindowExpired.selector);
        poc.validateContribution(contributor1, 0);
    }

    // ========== VALIDATOR MANAGEMENT TESTS ==========

    function test_AddValidator() public {
        vm.startPrank(admin);
        
        vm.expectEmit(true, false, false, false);
        emit ValidatorAdded(validator3);
        
        poc.addValidator(validator3);
        
        assertTrue(poc.isValidator(validator3));
        assertEq(poc.getValidatorCount(), 3);
        
        vm.stopPrank();
    }

    function test_AddValidator_NotAdmin() public {
        vm.prank(contributor1);
        vm.expectRevert();
        poc.addValidator(validator3);
    }

    function test_RemoveValidator() public {
        // First add a third validator
        vm.prank(admin);
        poc.addValidator(validator3);
        
        // Now remove validator2
        vm.prank(admin);
        
        vm.expectEmit(true, false, false, false);
        emit ValidatorRemoved(validator2);
        
        poc.removeValidator(validator2);
        
        assertFalse(poc.isValidator(validator2));
        assertEq(poc.getValidatorCount(), 2);
    }

    function test_RemoveValidator_BelowMinimum() public {
        vm.startPrank(admin);
        
        // Try to remove when only 2 validators
        vm.expectRevert("Cannot go below minimum validators");
        poc.removeValidator(validator1);
        
        vm.stopPrank();
    }

    // ========== EPOCH TESTS ==========

    function test_EpochAdvancement() public {
        // Record contributions in epoch 1
        poc.recordContribution(contributor1, 60, keccak256("data1"));
        poc.recordContribution(contributor2, 40, keccak256("data2"));
        
        // Validate contributions
        vm.startPrank(validator1);
        poc.validateContribution(contributor1, 0);
        poc.validateContribution(contributor2, 0);
        vm.stopPrank();
        
        vm.startPrank(validator2);
        poc.validateContribution(contributor1, 0);
        poc.validateContribution(contributor2, 0);
        vm.stopPrank();
        
        // Check epoch 1 state
        (uint256 epoch, , , uint256 epochScore) = poc.getCurrentEpochInfo();
        assertEq(epoch, 1);
        assertEq(epochScore, 100);
        
        // Advance time and epoch
        vm.warp(block.timestamp + 1 days + 1);
        
        vm.expectEmit(true, false, false, true);
        emit EpochAdvanced(2, 100);
        
        poc.advanceEpoch();
        
        // Check new epoch state
        (epoch, , , epochScore) = poc.getCurrentEpochInfo();
        assertEq(epoch, 2);
        assertEq(epochScore, 0);
        assertEq(poc.epochTotalScores(1), 100);
    }

    function test_EpochAdvancement_NotFinished() public {
        vm.expectRevert(ProofOfContribution.EpochNotFinished.selector);
        poc.advanceEpoch();
    }

    function test_AutoEpochAdvancement() public {
        // Record contribution in epoch 1
        poc.recordContribution(contributor1, 50, keccak256("data1"));
        
        // Move to next epoch
        vm.warp(block.timestamp + 1 days + 1);
        
        // Recording new contribution should auto-advance epoch
        poc.recordContribution(contributor2, 30, keccak256("data2"));
        
        assertEq(poc.currentEpoch(), 2);
    }

    // ========== REWARDS TESTS ==========

    function test_RewardCalculation() public {
        // Set reward pool for epoch 1
        vm.prank(admin);
        poc.setEpochRewardPool(1, 1000 ether);
        
        // Record and validate contributions
        poc.recordContribution(contributor1, 60, keccak256("data1"));
        poc.recordContribution(contributor2, 40, keccak256("data2"));
        
        vm.startPrank(validator1);
        poc.validateContribution(contributor1, 0);
        poc.validateContribution(contributor2, 0);
        vm.stopPrank();
        
        vm.startPrank(validator2);
        poc.validateContribution(contributor1, 0);
        poc.validateContribution(contributor2, 0);
        vm.stopPrank();
        
        // Advance epoch
        vm.warp(block.timestamp + 1 days + 1);
        poc.advanceEpoch();
        
        // Check pending rewards
        assertEq(poc.pendingRewards(contributor1), 600 ether); // 60% of 1000
        assertEq(poc.pendingRewards(contributor2), 400 ether); // 40% of 1000
    }

    function test_ClaimRewards() public {
        // Setup rewards
        vm.prank(admin);
        poc.setEpochRewardPool(1, 1000 ether);
        
        // Record and validate contribution
        poc.recordContribution(contributor1, 100, keccak256("data1"));
        
        vm.prank(validator1);
        poc.validateContribution(contributor1, 0);
        vm.prank(validator2);
        poc.validateContribution(contributor1, 0);
        
        // Advance epoch
        vm.warp(block.timestamp + 1 days + 1);
        poc.advanceEpoch();
        
        // Claim rewards
        vm.expectEmit(true, false, false, true);
        emit RewardsDistributed(contributor1, 1000 ether);
        
        uint256 claimed = poc.claimRewards(contributor1);
        assertEq(claimed, 1000 ether);
        assertEq(poc.pendingRewards(contributor1), 0);
    }

    function test_ClaimRewards_NoPending() public {
        vm.expectRevert(ProofOfContribution.NoRewardsToClaim.selector);
        poc.claimRewards(contributor1);
    }

    // ========== EMERGENCY TESTS ==========

    function test_EmergencyPause() public {
        vm.prank(admin);
        poc.pause();
        
        assertTrue(poc.paused());
        
        // Should not be able to record contributions
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        poc.recordContribution(contributor1, 50, keccak256("test"));
    }

    function test_Unpause() public {
        vm.startPrank(admin);
        poc.pause();
        poc.unpause();
        vm.stopPrank();
        
        assertFalse(poc.paused());
        
        // Should be able to record contributions again
        poc.recordContribution(contributor1, 50, keccak256("test"));
    }

    function test_Deactivate() public {
        vm.prank(admin);
        poc.deactivate();
        
        assertFalse(poc.isActive());
        
        vm.expectRevert(ProofOfContribution.ContractNotActive.selector);
        poc.recordContribution(contributor1, 50, keccak256("test"));
    }

    // ========== INTEGRATION TESTS ==========

    function test_FullContributionFlow() public {
        // Set reward pools for multiple epochs
        vm.startPrank(admin);
        poc.setEpochRewardPool(1, 1000 ether);
        poc.setEpochRewardPool(2, 2000 ether);
        vm.stopPrank();
        
        // Epoch 1 contributions
        poc.recordContribution(contributor1, 70, keccak256("data1"));
        poc.recordContribution(contributor2, 30, keccak256("data2"));
        
        // Validate
        vm.startPrank(validator1);
        poc.validateContribution(contributor1, 0);
        poc.validateContribution(contributor2, 0);
        vm.stopPrank();
        
        vm.startPrank(validator2);
        poc.validateContribution(contributor1, 0);
        poc.validateContribution(contributor2, 0);
        vm.stopPrank();
        
        // Move to epoch 2
        vm.warp(block.timestamp + 1 days + 1);
        
        // Epoch 2 contributions
        poc.recordContribution(contributor1, 40, keccak256("data3"));
        poc.recordContribution(contributor2, 60, keccak256("data4"));
        
        // Validate
        vm.startPrank(validator1);
        poc.validateContribution(contributor1, 1);
        poc.validateContribution(contributor2, 1);
        vm.stopPrank();
        
        vm.startPrank(validator2);
        poc.validateContribution(contributor1, 1);
        poc.validateContribution(contributor2, 1);
        vm.stopPrank();
        
        // Move to epoch 3
        vm.warp(block.timestamp + 1 days + 1);
        poc.advanceEpoch();
        
        // Check total scores
        assertEq(poc.totalScore(contributor1), 110); // 70 + 40
        assertEq(poc.totalScore(contributor2), 90);  // 30 + 60
        
        // Check pending rewards
        assertEq(poc.pendingRewards(contributor1), 1500 ether); // 700 + 800
        assertEq(poc.pendingRewards(contributor2), 1500 ether); // 300 + 1200
        
        // Claim rewards
        uint256 claimed1 = poc.claimRewards(contributor1);
        uint256 claimed2 = poc.claimRewards(contributor2);
        
        assertEq(claimed1, 1500 ether);
        assertEq(claimed2, 1500 ether);
    }

    function test_MultiValidatorConsensus() public {
        // Add third validator
        vm.prank(admin);
        poc.addValidator(validator3);
        
        // Record contribution
        poc.recordContribution(contributor1, 100, keccak256("data"));
        
        // First validation - not enough
        vm.prank(validator1);
        poc.validateContribution(contributor1, 0);
        
        IProofOfContribution.Contribution memory contrib = poc.contributions(contributor1, 0);
        assertFalse(contrib.validated);
        
        // Second validation - now validated (2 out of 3)
        vm.prank(validator2);
        poc.validateContribution(contributor1, 0);
        
        contrib = poc.contributions(contributor1, 0);
        assertTrue(contrib.validated);
        assertEq(poc.totalScore(contributor1), 100);
    }
}