// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/IGovernance.sol";

/**
 * @title GovernanceCore
 * @notice Core governance logic for proposal management
 * @dev Handles proposal creation and state transitions
 */
contract GovernanceCore is IGovernance, AccessControl, ReentrancyGuard {
    // Roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");

    // State
    struct ProposalCore {
        address proposer;
        string snapshotId;
        string ipfsHash;
        uint256 startBlock;
        uint256 endBlock;
        ProposalState state;
        bool executed;
        bool cancelled;
    }

    mapping(uint256 => ProposalCore) public proposals;
    uint256 public override proposalCount;
    bool public override isPaused;

    // Configuration (in blocks, assuming 12 second block times)
    uint256 public constant VOTING_DELAY = 14400; // 2 days = 2 * 24 * 60 * 60 / 12 = 14400 blocks
    uint256 public constant VOTING_PERIOD = 36000; // 5 days = 5 * 24 * 60 * 60 / 12 = 36000 blocks

    constructor(address admin) {
        require(admin != address(0), "Invalid admin");
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(EXECUTOR_ROLE, admin);
    }

    /**
     * @notice Create a new proposal
     * @param params Proposal parameters
     * @return proposalId The ID of the created proposal
     */
    function propose(ProposalParams calldata params) external override nonReentrant returns (uint256) {
        require(!isPaused, "Governance paused");
        require(bytes(params.snapshotId).length > 0, "Invalid snapshot");
        require(bytes(params.ipfsHash).length > 0, "Invalid IPFS hash");
        require(
            params.targets.length == params.values.length && params.targets.length == params.calldatas.length,
            "Length mismatch"
        );

        proposalCount++;
        uint256 proposalId = proposalCount;

        proposals[proposalId] = ProposalCore({
            proposer: msg.sender,
            snapshotId: params.snapshotId,
            ipfsHash: params.ipfsHash,
            startBlock: block.number + VOTING_DELAY,
            endBlock: block.number + VOTING_DELAY + VOTING_PERIOD,
            state: ProposalState.Pending,
            executed: false,
            cancelled: false
        });

        emit ProposalCreated(proposalId, msg.sender, params.snapshotId);
        return proposalId;
    }

    /**
     * @notice Cancel a proposal
     * @param proposalId The proposal to cancel
     */
    function cancel(uint256 proposalId) external override nonReentrant {
        ProposalCore storage proposal = proposals[proposalId];
        require(proposal.proposer == msg.sender || hasRole(ADMIN_ROLE, msg.sender), "Not authorized");
        require(!proposal.executed, "Already executed");
        require(!proposal.cancelled, "Already cancelled");

        proposal.cancelled = true;
        proposal.state = ProposalState.Cancelled;

        emit ProposalCancelled(proposalId);
    }

    /**
     * @notice Get proposal state
     * @param proposalId The proposal ID
     * @return Current state of the proposal
     */
    function state(uint256 proposalId) public view override returns (ProposalState) {
        ProposalCore storage proposal = proposals[proposalId];

        if (proposal.cancelled) {
            return ProposalState.Cancelled;
        }

        if (proposal.executed) {
            return ProposalState.Executed;
        }

        if (block.number < proposal.startBlock) {
            return ProposalState.Pending;
        }

        if (block.number <= proposal.endBlock) {
            return ProposalState.Active;
        }

        // This is simplified - real implementation would check vote results
        return ProposalState.Defeated;
    }

    /**
     * @notice Pause governance
     */
    function pauseGovernance() external onlyRole(ADMIN_ROLE) {
        isPaused = true;
    }

    /**
     * @notice Unpause governance
     */
    function unpauseGovernance() external onlyRole(ADMIN_ROLE) {
        isPaused = false;
    }

    // Simplified implementations for interface compliance
    function castVote(VoteParams calldata) external pure override {
        revert("Use GovernanceVoting contract");
    }

    function execute(uint256) external pure override {
        revert("Use GovernanceExecution contract");
    }

    function voteCost(uint256 votes) external pure override returns (uint256) {
        return votes * votes * 1e18;
    }
}
