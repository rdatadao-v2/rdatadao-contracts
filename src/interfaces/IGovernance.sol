// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @title IGovernance
 * @notice Minimal governance interface for r/datadao
 * @dev Designed to avoid stack depth issues
 */
interface IGovernance {
    // Proposal states
    enum ProposalState {
        Pending,
        Active,
        Defeated,
        Succeeded,
        Executed,
        Cancelled
    }
    
    // Voting types
    enum VoteType {
        Against,
        For,
        Abstain
    }
    
    // Structs for parameters to avoid stack issues
    struct ProposalParams {
        string snapshotId;
        string ipfsHash;
        address[] targets;
        uint256[] values;
        bytes[] calldatas;
    }
    
    struct VoteParams {
        uint256 proposalId;
        VoteType voteType;
        uint256 voteWeight;
        string reason;
    }
    
    // Events
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string snapshotId);
    event VoteCast(address indexed voter, uint256 indexed proposalId, VoteType voteType, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);
    
    // Core functions
    function propose(ProposalParams calldata params) external returns (uint256);
    function castVote(VoteParams calldata params) external;
    function execute(uint256 proposalId) external;
    function cancel(uint256 proposalId) external;
    
    // View functions
    function state(uint256 proposalId) external view returns (ProposalState);
    function proposalCount() external view returns (uint256);
    function voteCost(uint256 votes) external pure returns (uint256);
    function isPaused() external view returns (bool);
}