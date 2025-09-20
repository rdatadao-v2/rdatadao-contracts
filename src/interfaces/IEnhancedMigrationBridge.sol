// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @title IEnhancedMigrationBridge
 * @notice Production-ready interface for migration bridge with enhanced challenge mechanism
 * @dev Audit H-02 remediation: Production-grade challenge resolution
 */
interface IEnhancedMigrationBridge {
    enum ChallengeStatus {
        None,
        Challenged,
        Upheld, // Challenge was valid, migration blocked
        Overruled // Challenge was invalid, migration proceeds

    }

    struct ChallengeDetails {
        address challenger;
        uint256 challengeTime;
        uint256 votesFor; // Votes supporting the challenge
        uint256 votesAgainst; // Votes against the challenge
        ChallengeStatus status;
        mapping(address => bool) hasVoted;
    }

    struct EnhancedMigrationRequest {
        address user;
        uint256 amount;
        bytes32 burnTxHash;
        uint256 burnBlockNumber;
        uint256 validatorApprovals;
        uint256 challengeEndTime;
        bool executed;
        ChallengeDetails challenge;
        mapping(address => bool) hasValidated;
    }

    // Events
    event ChallengeVoteCast(bytes32 indexed requestId, address indexed voter, bool supportChallenge);
    event ChallengeResolved(bytes32 indexed requestId, ChallengeStatus result);

    /**
     * @notice Vote on a challenged migration
     * @param requestId The migration request ID
     * @param supportChallenge True to support the challenge, false to oppose
     */
    function voteOnChallenge(bytes32 requestId, bool supportChallenge) external;

    /**
     * @notice Resolve a challenge based on voting results
     * @param requestId The migration request ID
     */
    function resolveChallenge(bytes32 requestId) external;

    /**
     * @notice Get challenge voting period duration
     */
    function challengeVotingPeriod() external view returns (uint256);

    /**
     * @notice Get minimum votes required to resolve a challenge
     */
    function challengeQuorum() external view returns (uint256);
}
