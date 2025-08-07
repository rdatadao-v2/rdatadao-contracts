// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "../interfaces/IGovernance.sol";

/**
 * @title MockGovernance
 * @notice Mock implementation for testing
 * @dev Minimal implementation to verify compilation
 */
contract MockGovernance is IGovernance {
    uint256 public override proposalCount;
    bool public override isPaused;
    
    mapping(uint256 => ProposalState) public proposalStates;
    
    function propose(ProposalParams calldata params) external override returns (uint256) {
        require(!isPaused, "Governance paused");
        require(params.targets.length > 0, "No targets");
        
        proposalCount++;
        proposalStates[proposalCount] = ProposalState.Pending;
        
        emit ProposalCreated(proposalCount, msg.sender, params.snapshotId);
        return proposalCount;
    }
    
    function castVote(VoteParams calldata params) external override {
        require(!isPaused, "Governance paused");
        require(params.proposalId > 0 && params.proposalId <= proposalCount, "Invalid proposal");
        
        emit VoteCast(msg.sender, params.proposalId, params.voteType, params.voteWeight);
    }
    
    function execute(uint256 proposalId) external override {
        require(!isPaused, "Governance paused");
        require(proposalStates[proposalId] == ProposalState.Succeeded, "Not succeeded");
        
        proposalStates[proposalId] = ProposalState.Executed;
        emit ProposalExecuted(proposalId);
    }
    
    function cancel(uint256 proposalId) external override {
        require(!isPaused, "Governance paused");
        require(proposalStates[proposalId] == ProposalState.Pending, "Not pending");
        
        proposalStates[proposalId] = ProposalState.Cancelled;
        emit ProposalCancelled(proposalId);
    }
    
    function state(uint256 proposalId) external view override returns (ProposalState) {
        return proposalStates[proposalId];
    }
    
    function voteCost(uint256 votes) external pure override returns (uint256) {
        return votes * votes * 1e18; // Quadratic cost in wei
    }
    
    function setPaused(bool _paused) external {
        isPaused = _paused;
    }
}