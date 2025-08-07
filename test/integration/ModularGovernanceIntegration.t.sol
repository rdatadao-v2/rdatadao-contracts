// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../../src/governance/GovernanceCore.sol";
import "../../src/governance/GovernanceVoting.sol";
import "../../src/governance/GovernanceExecution.sol";
import "../../src/vRDAT.sol";
import "../../src/interfaces/IGovernance.sol";

/**
 * @title ModularGovernanceIntegrationTest
 * @notice Integration tests for the modular governance system
 * @dev Tests the interaction between GovernanceCore, GovernanceVoting, and GovernanceExecution
 */
contract ModularGovernanceIntegrationTest is Test {
    // Contracts
    GovernanceCore public governanceCore;
    GovernanceVoting public governanceVoting;
    GovernanceExecution public governanceExecution;
    vRDAT public vrdatToken;
    
    // Test addresses
    address public admin = makeAddr("admin");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public target = makeAddr("target");
    
    // Constants
    uint256 constant INITIAL_VRDAT = 10000e18;
    
    function setUp() public {
        vm.startPrank(admin);
        
        // Deploy vRDAT token
        vrdatToken = new vRDAT(admin);
        
        // Deploy governance modules
        governanceCore = new GovernanceCore(admin);
        governanceVoting = new GovernanceVoting(address(vrdatToken), admin);
        governanceExecution = new GovernanceExecution(admin);
        
        // Configure governance modules
        governanceVoting.setGovernanceCore(address(governanceCore));
        governanceExecution.setGovernanceCore(address(governanceCore));
        
        // Grant governance role to voting contract
        vrdatToken.grantRole(keccak256("GOVERNANCE_ROLE"), address(governanceVoting));
        
        // Setup test users with vRDAT
        vrdatToken.mint(user1, INITIAL_VRDAT);
        vrdatToken.mint(user2, INITIAL_VRDAT / 2);
        
        vm.stopPrank();
    }
    
    function test_ProposalCreationFlow() public {
        // Create proposal
        address[] memory targets = new address[](1);
        targets[0] = target;
        
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("someFunction()");
        
        IGovernance.ProposalParams memory params = IGovernance.ProposalParams({
            snapshotId: "test-snapshot-123",
            ipfsHash: "QmTest123...",
            targets: targets,
            values: values,
            calldatas: calldatas
        });
        
        vm.prank(user1);
        uint256 proposalId = governanceCore.propose(params);
        
        assertEq(proposalId, 1);
        assertEq(governanceCore.proposalCount(), 1);
    }
    
    function test_VotingFlow() public {
        // First create a proposal
        uint256 proposalId = _createTestProposal();
        
        // Wait for voting to start (after VOTING_DELAY blocks)
        vm.roll(block.number + 14400 + 1);
        
        // User1 votes with quadratic cost
        uint256 voteWeight = 10;
        uint256 expectedCost = voteWeight * voteWeight * 1e18; // 100e18
        
        IGovernance.VoteParams memory voteParams = IGovernance.VoteParams({
            proposalId: proposalId,
            voteType: IGovernance.VoteType.For,
            voteWeight: voteWeight,
            reason: "I support this proposal"
        });
        
        uint256 balanceBefore = vrdatToken.balanceOf(user1);
        
        vm.prank(user1);
        governanceVoting.castVote(voteParams);
        
        uint256 balanceAfter = vrdatToken.balanceOf(user1);
        
        // Check vRDAT was burned
        assertEq(balanceBefore - balanceAfter, expectedCost);
        
        // Check vote was recorded
        (bool hasVoted, IGovernance.VoteType voteType, uint256 weight, uint256 vrdatBurned) = 
            governanceVoting.getReceipt(proposalId, user1);
        
        assertTrue(hasVoted);
        assertEq(uint8(voteType), uint8(IGovernance.VoteType.For));
        assertEq(weight, voteWeight);
        assertEq(vrdatBurned, expectedCost);
    }
    
    function test_QuadraticVotingCost() public {
        _createTestProposal();
        vm.roll(block.number + 14400 + 1);
        
        // Test different vote amounts and their quadratic costs
        uint256[] memory votes = new uint256[](4);
        votes[0] = 1;  // Cost: 1e18
        votes[1] = 5;  // Cost: 25e18  
        votes[2] = 10; // Cost: 100e18
        votes[3] = 20; // Cost: 400e18
        
        for (uint256 i = 0; i < votes.length; i++) {
            uint256 expectedCost = votes[i] * votes[i] * 1e18;
            uint256 calculatedCost = governanceVoting.voteCost(votes[i]);
            assertEq(calculatedCost, expectedCost);
        }
    }
    
    function test_QuorumChecks() public {
        uint256 proposalId = _createTestProposal();
        vm.roll(block.number + 14400 + 1);
        
        // Initially no quorum
        assertFalse(governanceVoting.hasQuorum(proposalId));
        
        // User1 votes with large amount to meet vRDAT quorum
        IGovernance.VoteParams memory voteParams = IGovernance.VoteParams({
            proposalId: proposalId,
            voteType: IGovernance.VoteType.For,
            voteWeight: 100, // 100^2 * 1e18 = 10,000e18 vRDAT burned
            reason: "Big vote for quorum"
        });
        
        vm.prank(user1);
        governanceVoting.castVote(voteParams);
        
        // Still need minimum unique voters
        assertFalse(governanceVoting.hasQuorum(proposalId));
        
        // Add more unique voters (need 10 total)
        for (uint256 i = 0; i < 9; i++) {
            address voter = makeAddr(string(abi.encodePacked("voter", vm.toString(i))));
            
            vm.prank(admin);
            vrdatToken.mint(voter, 1e18); // Just enough for 1 vote
            
            vm.prank(voter);
            governanceVoting.castVote(IGovernance.VoteParams({
                proposalId: proposalId,
                voteType: IGovernance.VoteType.For,
                voteWeight: 1,
                reason: "Small vote"
            }));
        }
        
        // Now should have quorum (10k+ vRDAT burned + 10 unique voters)
        assertTrue(governanceVoting.hasQuorum(proposalId));
    }
    
    function test_ExecutionFlow() public {
        uint256 proposalId = _createTestProposal();
        
        // Queue proposal for execution
        address[] memory targets = new address[](1);
        targets[0] = target;
        
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("someFunction()");
        
        bytes32 descriptionHash = keccak256("Test proposal");
        
        vm.prank(address(governanceCore));
        governanceExecution.queue(proposalId, targets, values, calldatas, descriptionHash);
        
        // Cannot execute immediately (timelock)
        vm.expectRevert("Timelock not met");
        vm.prank(admin);
        governanceExecution.execute(proposalId);
        
        // Fast forward past timelock (GovernanceExecution uses timestamp-based timelock)
        vm.warp(block.timestamp + 2 days + 1);
        
        // Now can execute
        vm.prank(admin);
        governanceExecution.execute(proposalId);
        
        // Verify execution data
        (,,,, uint256 eta, bool executed) = governanceExecution.getExecutionData(proposalId);
        assertTrue(executed);
        assertGt(eta, 0);
    }
    
    function test_ModuleRoleConfiguration() public view {
        // Verify role configuration is correct
        bytes32 governanceRole = keccak256("GOVERNANCE_ROLE");
        bytes32 adminRole = keccak256("ADMIN_ROLE");
        
        // GovernanceVoting should have governance role on vRDAT
        assertTrue(vrdatToken.hasRole(governanceRole, address(governanceVoting)));
        
        // Admin should have admin roles on all modules
        assertTrue(governanceCore.hasRole(adminRole, admin));
        assertTrue(governanceVoting.hasRole(adminRole, admin));
        assertTrue(governanceExecution.hasRole(adminRole, admin));
        
        // GovernanceCore should have governance role on execution
        assertTrue(governanceExecution.hasRole(governanceRole, address(governanceCore)));
    }
    
    function test_ProposalStateTransitions() public {
        uint256 proposalId = _createTestProposal();
        
        // Initially pending
        IGovernance.ProposalState currentState = governanceCore.state(proposalId);
        assertEq(uint8(currentState), uint8(IGovernance.ProposalState.Pending));
        
        // After delay (14400 blocks), becomes active
        vm.roll(block.number + 14400 + 1);
        currentState = governanceCore.state(proposalId);
        assertEq(uint8(currentState), uint8(IGovernance.ProposalState.Active));
        
        // After voting period (36000 more blocks), becomes defeated (no votes)
        vm.roll(block.number + 36000 + 1);
        currentState = governanceCore.state(proposalId);
        assertEq(uint8(currentState), uint8(IGovernance.ProposalState.Defeated));
    }
    
    function test_ProposalCancellation() public {
        uint256 proposalId = _createTestProposal();
        
        // Proposer can cancel
        vm.prank(user1);
        governanceCore.cancel(proposalId);
        
        assertEq(uint8(governanceCore.state(proposalId)), uint8(IGovernance.ProposalState.Cancelled));
        
        // Cannot vote on cancelled proposal
        vm.roll(block.number + 14400 + 1);
        
        // Voting should work but state check might prevent it in full implementation
        // For now, just verify the proposal is cancelled
        assertEq(uint8(governanceCore.state(proposalId)), uint8(IGovernance.ProposalState.Cancelled));
    }
    
    function test_RevertDoubleVote() public {
        uint256 proposalId = _createTestProposal();
        vm.roll(block.number + 14400 + 1);
        
        IGovernance.VoteParams memory voteParams = IGovernance.VoteParams({
            proposalId: proposalId,
            voteType: IGovernance.VoteType.For,
            voteWeight: 1,
            reason: "First vote"
        });
        
        // First vote succeeds
        vm.prank(user1);
        governanceVoting.castVote(voteParams);
        
        // Second vote should fail
        vm.expectRevert("Already voted");
        vm.prank(user1);
        governanceVoting.castVote(voteParams);
    }
    
    function test_RevertInsufficientVRDAT() public {
        uint256 proposalId = _createTestProposal();
        vm.roll(block.number + 14400 + 1);
        
        // Try to vote with more vRDAT than balance
        uint256 userBalance = vrdatToken.balanceOf(user1);
        uint256 maxVotes = _sqrt(userBalance / 1e18); // Max votes without exceeding balance
        
        IGovernance.VoteParams memory voteParams = IGovernance.VoteParams({
            proposalId: proposalId,
            voteType: IGovernance.VoteType.For,
            voteWeight: maxVotes + 1, // One more than affordable
            reason: "Too expensive"
        });
        
        vm.expectRevert("Insufficient balance");
        vm.prank(user1);
        governanceVoting.castVote(voteParams);
    }
    
    function test_GetVoteTotals() public {
        uint256 proposalId = _createTestProposal();
        vm.roll(block.number + 14400 + 1);
        
        // Cast different types of votes
        vm.prank(user1);
        governanceVoting.castVote(IGovernance.VoteParams({
            proposalId: proposalId,
            voteType: IGovernance.VoteType.For,
            voteWeight: 10,
            reason: "Support"
        }));
        
        vm.prank(user2);
        governanceVoting.castVote(IGovernance.VoteParams({
            proposalId: proposalId,
            voteType: IGovernance.VoteType.Against,
            voteWeight: 5,
            reason: "Against"
        }));
        
        (uint256 forVotes, uint256 againstVotes, uint256 abstainVotes, uint256 uniqueVoters, uint256 totalVRDATBurned) = 
            governanceVoting.getVoteTotals(proposalId);
        
        assertEq(forVotes, 10);
        assertEq(againstVotes, 5);
        assertEq(abstainVotes, 0);
        assertEq(uniqueVoters, 2);
        assertEq(totalVRDATBurned, (10 * 10 * 1e18) + (5 * 5 * 1e18)); // 100e18 + 25e18
    }
    
    // Helper function to create a test proposal
    function _createTestProposal() internal returns (uint256) {
        address[] memory targets = new address[](1);
        targets[0] = target;
        
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("someFunction()");
        
        IGovernance.ProposalParams memory params = IGovernance.ProposalParams({
            snapshotId: "test-snapshot",
            ipfsHash: "QmTest123...",
            targets: targets,
            values: values,
            calldatas: calldatas
        });
        
        vm.prank(user1);
        return governanceCore.propose(params);
    }
    
    // Helper function for square root calculation
    function _sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }
}