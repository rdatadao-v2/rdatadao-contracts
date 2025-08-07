// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

/**
 * @title OffChainSimulator
 * @notice Simulates off-chain services and coordination for scenario testing
 * @dev Provides mock implementations for:
 *      - Validator network coordination
 *      - Snapshot.org voting integration
 *      - Cross-chain message passing
 *      - External oracle data feeds
 */
contract OffChainSimulator is Test {
    
    // ============ Validator Network Simulation ============
    
    struct ValidatorState {
        bool isActive;
        bool isOnline;
        uint256 reputation;
        uint256 lastSeen;
    }
    
    struct MigrationRequest {
        address user;
        uint256 amount;
        bytes32 burnTxHash;
        uint256 baseBlockNumber;
        uint256 validationsReceived;
        mapping(address => bool) hasValidated;
        bool isChallenged;
        bool isProcessed;
        uint256 challengeDeadline;
    }
    
    mapping(address => ValidatorState) public validators;
    mapping(bytes32 => MigrationRequest) public migrationRequests;
    address[] public validatorList;
    uint256 public constant MIN_VALIDATORS_FOR_CONSENSUS = 2;
    uint256 public constant CHALLENGE_PERIOD = 6 hours;
    
    // Events
    event ValidatorAdded(address indexed validator);
    event ValidatorStatusChanged(address indexed validator, bool isOnline);
    event MigrationRequestCreated(bytes32 indexed requestId, address indexed user, uint256 amount);
    event ValidationSubmitted(bytes32 indexed requestId, address indexed validator);
    event ConsensusReached(bytes32 indexed requestId);
    event MigrationChallenged(bytes32 indexed requestId, address indexed challenger);
    
    /**
     * @notice Simulates the validator network processing a migration request
     * @param user Address of the user migrating
     * @param amount Amount being migrated
     * @param burnTxHash Hash of the burn transaction on Base
     * @param baseBlockNumber Block number on Base where burn occurred
     */
    function simulateValidatorNetwork(
        address user, 
        uint256 amount, 
        bytes32 burnTxHash, 
        uint256 baseBlockNumber
    ) external returns (bytes32 requestId) {
        requestId = keccak256(abi.encodePacked(user, amount, burnTxHash, baseBlockNumber));
        
        MigrationRequest storage request = migrationRequests[requestId];
        request.user = user;
        request.amount = amount;
        request.burnTxHash = burnTxHash;
        request.baseBlockNumber = baseBlockNumber;
        request.challengeDeadline = block.timestamp + CHALLENGE_PERIOD;
        
        emit MigrationRequestCreated(requestId, user, amount);
        
        // Simulate validators processing the request
        _simulateValidatorProcessing(requestId);
        
        return requestId;
    }
    
    /**
     * @notice Adds a validator to the network
     */
    function addValidator(address validator) external {
        require(validator != address(0), "Invalid validator");
        require(!validators[validator].isActive, "Validator already active");
        
        validators[validator] = ValidatorState({
            isActive: true,
            isOnline: true,
            reputation: 100,
            lastSeen: block.timestamp
        });
        
        validatorList.push(validator);
        emit ValidatorAdded(validator);
    }
    
    /**
     * @notice Simulates a validator going offline
     */
    function simulateValidatorOffline(address validator) external {
        require(validators[validator].isActive, "Validator not active");
        
        validators[validator].isOnline = false;
        validators[validator].lastSeen = block.timestamp;
        
        emit ValidatorStatusChanged(validator, false);
    }
    
    /**
     * @notice Simulates a validator coming back online
     */
    function simulateValidatorOnline(address validator) external {
        require(validators[validator].isActive, "Validator not active");
        
        validators[validator].isOnline = true;
        validators[validator].lastSeen = block.timestamp;
        
        emit ValidatorStatusChanged(validator, true);
    }
    
    /**
     * @notice Simulates a challenge to a migration request
     */
    function simulateChallenge(bytes32 requestId, address challenger) external {
        MigrationRequest storage request = migrationRequests[requestId];
        require(request.user != address(0), "Request doesn't exist");
        require(!request.isChallenged, "Already challenged");
        require(block.timestamp < request.challengeDeadline, "Challenge period expired");
        
        request.isChallenged = true;
        emit MigrationChallenged(requestId, challenger);
    }
    
    /**
     * @notice Internal function to simulate validator processing
     */
    function _simulateValidatorProcessing(bytes32 requestId) internal {
        MigrationRequest storage request = migrationRequests[requestId];
        uint256 activeValidators = 0;
        
        // Count online validators
        for (uint256 i = 0; i < validatorList.length; i++) {
            if (validators[validatorList[i]].isOnline) {
                activeValidators++;
            }
        }
        
        // Simulate validator responses (assume 80% response rate)
        uint256 respondingValidators = (activeValidators * 80) / 100;
        if (respondingValidators < MIN_VALIDATORS_FOR_CONSENSUS) {
            respondingValidators = MIN_VALIDATORS_FOR_CONSENSUS;
        }
        
        uint256 validationsSubmitted = 0;
        for (uint256 i = 0; i < validatorList.length && validationsSubmitted < respondingValidators; i++) {
            address validator = validatorList[i];
            if (validators[validator].isOnline && !request.hasValidated[validator]) {
                request.hasValidated[validator] = true;
                request.validationsReceived++;
                validationsSubmitted++;
                
                emit ValidationSubmitted(requestId, validator);
            }
        }
        
        if (request.validationsReceived >= MIN_VALIDATORS_FOR_CONSENSUS) {
            emit ConsensusReached(requestId);
        }
    }
    
    // ============ Snapshot Integration Simulation ============
    
    struct SnapshotProposal {
        bytes32 id;
        string ipfsHash;
        uint256 startTime;
        uint256 endTime;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool isFinalized;
        bool passed;
        mapping(address => bool) hasVoted;
        mapping(address => uint8) votes; // 0=abstain, 1=for, 2=against
    }
    
    mapping(bytes32 => SnapshotProposal) public snapshotProposals;
    uint256 public constant SNAPSHOT_VOTING_PERIOD = 7 days;
    
    event SnapshotProposalCreated(bytes32 indexed proposalId, string ipfsHash);
    event SnapshotVoteCast(bytes32 indexed proposalId, address indexed voter, uint8 vote, uint256 weight);
    event SnapshotFinalized(bytes32 indexed proposalId, bool passed);
    
    /**
     * @notice Creates a snapshot proposal for off-chain voting
     */
    function createSnapshot(string memory ipfsHash) external returns (bytes32 proposalId) {
        proposalId = keccak256(abi.encodePacked(ipfsHash, block.timestamp));
        
        SnapshotProposal storage proposal = snapshotProposals[proposalId];
        proposal.id = proposalId;
        proposal.ipfsHash = ipfsHash;
        proposal.startTime = block.timestamp;
        proposal.endTime = block.timestamp + SNAPSHOT_VOTING_PERIOD;
        
        emit SnapshotProposalCreated(proposalId, ipfsHash);
        return proposalId;
    }
    
    /**
     * @notice Simulates a vote on snapshot
     */
    function simulateSnapshotVote(
        bytes32 proposalId, 
        address voter, 
        uint8 vote, // 0=abstain, 1=for, 2=against
        uint256 votingPower
    ) external {
        SnapshotProposal storage proposal = snapshotProposals[proposalId];
        require(proposal.id != bytes32(0), "Proposal doesn't exist");
        require(block.timestamp >= proposal.startTime, "Voting not started");
        require(block.timestamp <= proposal.endTime, "Voting ended");
        require(!proposal.hasVoted[voter], "Already voted");
        require(vote <= 2, "Invalid vote type");
        
        proposal.hasVoted[voter] = true;
        proposal.votes[voter] = vote;
        
        if (vote == 0) {
            proposal.abstainVotes += votingPower;
        } else if (vote == 1) {
            proposal.forVotes += votingPower;
        } else {
            proposal.againstVotes += votingPower;
        }
        
        emit SnapshotVoteCast(proposalId, voter, vote, votingPower);
    }
    
    /**
     * @notice Finalizes a snapshot proposal
     */
    function finalizeSnapshot(bytes32 proposalId) external returns (bool passed) {
        SnapshotProposal storage proposal = snapshotProposals[proposalId];
        require(proposal.id != bytes32(0), "Proposal doesn't exist");
        require(block.timestamp > proposal.endTime, "Voting still active");
        require(!proposal.isFinalized, "Already finalized");
        
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        
        // Simple majority wins (ignoring abstains)
        proposal.passed = proposal.forVotes > proposal.againstVotes;
        proposal.isFinalized = true;
        
        emit SnapshotFinalized(proposalId, proposal.passed);
        return proposal.passed;
    }
    
    // ============ Time Management Simulation ============
    
    uint256 private _timeOffset;
    uint256 private _blockOffset;
    
    /**
     * @notice Simulates time progression for testing
     */
    function simulateTimeProgression(uint256 daysToSkip) external {
        _timeOffset += daysToSkip * 1 days;
        vm.warp(block.timestamp + daysToSkip * 1 days);
        
        console2.log("[TIME] Simulated", daysToSkip, "days forward");
        console2.log("   Current timestamp:", block.timestamp);
    }
    
    /**
     * @notice Simulates block progression
     */
    function simulateBlockProgression(uint256 blocksToSkip) external {
        _blockOffset += blocksToSkip;
        vm.roll(block.number + blocksToSkip);
        
        console2.log("[BLOCKS] Simulated", blocksToSkip, "blocks forward");
        console2.log("   Current block:", block.number);
    }
    
    // ============ External Oracle Simulation ============
    
    mapping(address => uint256) private _tokenPrices;
    mapping(address => bool) private _marketConditions; // true = bullish, false = bearish
    
    event PriceFeedUpdated(address indexed token, uint256 newPrice);
    event MarketConditionChanged(bool bullish);
    
    /**
     * @notice Simulates price feed updates
     */
    function simulatePriceFeeds(address token, uint256 priceInUSD) external {
        _tokenPrices[token] = priceInUSD;
        emit PriceFeedUpdated(token, priceInUSD);
        
        console2.log("[PRICE] Price updated for", vm.toString(token));
        console2.log("   New price: $", priceInUSD / 1e8); // Assuming 8 decimals
    }
    
    /**
     * @notice Simulates market condition changes
     */
    function simulateMarketConditions(bool bullish) external {
        _marketConditions[msg.sender] = bullish;
        emit MarketConditionChanged(bullish);
        
        console2.log("[MARKET] Market condition:", bullish ? "BULLISH" : "BEARISH");
    }
    
    /**
     * @notice Gets simulated token price
     */
    function getTokenPrice(address token) external view returns (uint256) {
        return _tokenPrices[token];
    }
    
    /**
     * @notice Gets simulated market condition
     */
    function getMarketCondition() external view returns (bool bullish) {
        return _marketConditions[msg.sender];
    }
    
    // ============ Utility Functions ============
    
    /**
     * @notice Gets the current number of active validators
     */
    function getActiveValidatorCount() external view returns (uint256 count) {
        for (uint256 i = 0; i < validatorList.length; i++) {
            if (validators[validatorList[i]].isActive && validators[validatorList[i]].isOnline) {
                count++;
            }
        }
    }
    
    /**
     * @notice Checks if a migration request has reached consensus
     */
    function hasConsensus(bytes32 requestId) external view returns (bool) {
        return migrationRequests[requestId].validationsReceived >= MIN_VALIDATORS_FOR_CONSENSUS;
    }
    
    /**
     * @notice Checks if a migration request can be executed
     */
    function canExecuteMigration(bytes32 requestId) external view returns (bool) {
        MigrationRequest storage request = migrationRequests[requestId];
        return request.validationsReceived >= MIN_VALIDATORS_FOR_CONSENSUS &&
               !request.isChallenged &&
               block.timestamp >= request.challengeDeadline &&
               !request.isProcessed;
    }
    
    /**
     * @notice Gets snapshot proposal results
     */
    function getSnapshotResults(bytes32 proposalId) external view returns (
        uint256 forVotes,
        uint256 againstVotes,
        uint256 abstainVotes,
        bool passed,
        bool finalized
    ) {
        SnapshotProposal storage proposal = snapshotProposals[proposalId];
        return (
            proposal.forVotes,
            proposal.againstVotes,
            proposal.abstainVotes,
            proposal.passed,
            proposal.isFinalized
        );
    }
    
    /**
     * @notice Resets all simulation state (for test cleanup)
     */
    function resetSimulation() external {
        // Reset validators
        for (uint256 i = 0; i < validatorList.length; i++) {
            delete validators[validatorList[i]];
        }
        delete validatorList;
        
        // Reset time offsets
        _timeOffset = 0;
        _blockOffset = 0;
        
        console2.log("[RESET] Simulation state reset");
    }
}