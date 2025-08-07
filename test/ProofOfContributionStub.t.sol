// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../src/ProofOfContributionStub.sol";

contract ProofOfContributionStubTest is Test {
    ProofOfContributionStub public poc;
    
    address public admin = address(0x1);
    address public dlp = address(0x2);
    address public contributor = address(0x3);
    address public validator = address(0x4);
    
    function setUp() public {
        vm.prank(admin);
        poc = new ProofOfContributionStub(admin, dlp);
    }
    
    function test_Deployment() public view {
        assertEq(poc.dlpAddress(), dlp);
        assertEq(poc.getCurrentEpoch(), 1);
        assertTrue(poc.isActive());
    }
    
    function test_RecordContribution() public {
        // Grant integration role
        vm.prank(admin);
        poc.grantIntegrationRole(address(this));
        
        // Record contribution
        bool success = poc.recordContribution(contributor, 85, keccak256("data1"));
        assertTrue(success);
        
        // Check state
        assertEq(poc.contributionCount(contributor), 1);
        assertEq(poc.totalScore(contributor), 85);
    }
    
    function test_ValidatorManagement() public {
        vm.startPrank(admin);
        
        // Add validator
        poc.addValidator(validator);
        assertTrue(poc.isValidator(validator));
        
        // Remove validator
        poc.removeValidator(validator);
        assertFalse(poc.isValidator(validator));
        
        vm.stopPrank();
    }
    
    function test_StubViewFunctions() public view {
        // Test all view functions work
        poc.contributions(contributor, 0);
        poc.pendingRewards(contributor);
        poc.getEpochScore(contributor, 1);
        poc.getEpochTotalScore(1);
        poc.hasContributedInEpoch(contributor, 1);
    }
}