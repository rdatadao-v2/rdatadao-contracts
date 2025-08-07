// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/IGovernance.sol";
import "../interfaces/IvRDATGovernance.sol";

/**
 * @title GovernanceVoting
 * @notice Handles quadratic voting with vRDAT burning
 * @dev Separate contract to manage voting logic
 */
contract GovernanceVoting is AccessControl, ReentrancyGuard {
    // Roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    
    // State
    struct ProposalVotes {
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        uint256 uniqueVoters;
        uint256 totalVRDATBurned;
        mapping(address => VoteReceipt) receipts;
    }
    
    struct VoteReceipt {
        bool hasVoted;
        IGovernance.VoteType voteType;
        uint256 weight;
        uint256 vrdatBurned;
    }
    
    mapping(uint256 => ProposalVotes) public proposalVotes;
    IvRDATGovernance public immutable vRDAT;
    address public governanceCore;
    
    // Constants
    uint256 public constant MIN_QUORUM_VRDAT = 10_000e18; // 10k vRDAT minimum
    uint256 public constant MIN_UNIQUE_VOTERS = 10;
    
    // Events
    event VoteCast(
        address indexed voter,
        uint256 indexed proposalId,
        IGovernance.VoteType voteType,
        uint256 weight,
        uint256 vrdatBurned
    );
    
    constructor(address _vRDAT, address _admin) {
        require(_vRDAT != address(0), "Invalid vRDAT");
        require(_admin != address(0), "Invalid admin");
        
        vRDAT = IvRDATGovernance(_vRDAT);
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
    }
    
    /**
     * @notice Set the governance core contract
     * @param _governanceCore Address of governance core
     */
    function setGovernanceCore(address _governanceCore) external onlyRole(ADMIN_ROLE) {
        require(_governanceCore != address(0), "Invalid address");
        governanceCore = _governanceCore;
        _grantRole(GOVERNANCE_ROLE, _governanceCore);
    }
    
    /**
     * @notice Cast a vote on a proposal
     * @param params Vote parameters
     */
    function castVote(IGovernance.VoteParams calldata params) 
        external 
        nonReentrant 
    {
        require(params.proposalId > 0, "Invalid proposal");
        require(params.voteWeight > 0, "Invalid weight");
        
        ProposalVotes storage votes = proposalVotes[params.proposalId];
        VoteReceipt storage receipt = votes.receipts[msg.sender];
        
        require(!receipt.hasVoted, "Already voted");
        
        // Calculate quadratic cost
        uint256 cost = voteCost(params.voteWeight);
        
        // Burn vRDAT
        vRDAT.burnForGovernance(msg.sender, cost);
        
        // Record vote
        receipt.hasVoted = true;
        receipt.voteType = params.voteType;
        receipt.weight = params.voteWeight;
        receipt.vrdatBurned = cost;
        
        // Update totals
        if (params.voteType == IGovernance.VoteType.For) {
            votes.forVotes += params.voteWeight;
        } else if (params.voteType == IGovernance.VoteType.Against) {
            votes.againstVotes += params.voteWeight;
        } else {
            votes.abstainVotes += params.voteWeight;
        }
        
        votes.uniqueVoters++;
        votes.totalVRDATBurned += cost;
        
        emit VoteCast(msg.sender, params.proposalId, params.voteType, params.voteWeight, cost);
    }
    
    /**
     * @notice Calculate quadratic voting cost
     * @param votes Number of votes
     * @return cost Cost in vRDAT (wei)
     */
    function voteCost(uint256 votes) public pure returns (uint256) {
        return votes * votes * 1e18;
    }
    
    /**
     * @notice Check if proposal meets quorum
     * @param proposalId The proposal ID
     * @return hasQuorum Whether quorum is met
     */
    function hasQuorum(uint256 proposalId) external view returns (bool) {
        ProposalVotes storage votes = proposalVotes[proposalId];
        return votes.totalVRDATBurned >= MIN_QUORUM_VRDAT && 
               votes.uniqueVoters >= MIN_UNIQUE_VOTERS;
    }
    
    /**
     * @notice Get vote receipt for a voter
     * @param proposalId The proposal ID
     * @param voter The voter address
     */
    function getReceipt(uint256 proposalId, address voter) 
        external 
        view 
        returns (
            bool hasVoted,
            IGovernance.VoteType voteType,
            uint256 weight,
            uint256 vrdatBurned
        ) 
    {
        VoteReceipt storage receipt = proposalVotes[proposalId].receipts[voter];
        return (receipt.hasVoted, receipt.voteType, receipt.weight, receipt.vrdatBurned);
    }
    
    /**
     * @notice Get vote totals for a proposal
     * @param proposalId The proposal ID
     */
    function getVoteTotals(uint256 proposalId) 
        external 
        view 
        returns (
            uint256 forVotes,
            uint256 againstVotes,
            uint256 abstainVotes,
            uint256 uniqueVoters,
            uint256 totalVRDATBurned
        ) 
    {
        ProposalVotes storage votes = proposalVotes[proposalId];
        return (
            votes.forVotes,
            votes.againstVotes,
            votes.abstainVotes,
            votes.uniqueVoters,
            votes.totalVRDATBurned
        );
    }
}