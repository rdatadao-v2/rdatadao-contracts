// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @title IMigrationBridge
 * @dev Interface for V1 to V2 cross-chain migration with enhanced security
 */
interface IMigrationBridge {
    // Structs
    struct MigrationRequest {
        address user;
        uint256 amount;
        uint256 bonus;
        bytes32 burnTxHash;
        uint256 burnBlockNumber;
        uint256 validatorApprovals;
        uint256 challengeEndTime;
        bool executed;
        bool challenged;
    }

    // Events - Base side
    event MigrationInitiated(bytes32 indexed requestId, address indexed user, uint256 amount, bytes32 burnTxHash);

    // Events - Vana side
    event MigrationValidated(bytes32 indexed requestId, address indexed validator);
    event MigrationChallenged(bytes32 indexed requestId, address indexed challenger);
    event ChallengeOverridden(bytes32 indexed requestId, address indexed admin);
    event MigrationExecuted(bytes32 indexed requestId, address indexed user, uint256 amount, uint256 bonus);
    event ValidatorAdded(address indexed validator);
    event ValidatorRemoved(address indexed validator);
    event DailyLimitReset(uint256 newDayTimestamp);

    // Functions - Base side
    function initiateMigration(uint256 amount) external;

    // Functions - Vana side
    function submitValidation(address user, uint256 amount, bytes32 burnTxHash, uint256 burnBlockNumber) external;

    function challengeMigration(bytes32 requestId) external;
    function executeMigration(bytes32 requestId) external;
    function addValidator(address validator) external;
    function removeValidator(address validator) external;

    // Shared functions
    function pause() external;
    function unpause() external;
    function calculateBonus(uint256 amount) external view returns (uint256);

    // State getters
    function migrationRequests(bytes32 requestId) external view returns (MigrationRequest memory);
    function processedBurnHashes(bytes32 burnHash) external view returns (bool);
    function validators(address validator) external view returns (bool);
    function validatorCount() external view returns (uint256);
    function hasValidated(bytes32 requestId, address validator) external view returns (bool);

    // Migration tracking
    function userMigrations(address user) external view returns (uint256);
    function totalMigrated() external view returns (uint256);
    function dailyMigrated() external view returns (uint256);
    function lastResetTime() external view returns (uint256);

    // Constants
    function CHALLENGE_PERIOD() external view returns (uint256); // 6 hours
    function MIN_VALIDATORS() external view returns (uint256); // 2
    function CONFIRMATION_BLOCKS() external view returns (uint256); // 12
    function DAILY_LIMIT() external view returns (uint256); // Dynamic based on supply

    // Bonus constants
    function WEEK_1_2_BONUS() external view returns (uint256); // 500 (5%)
    function WEEK_3_4_BONUS() external view returns (uint256); // 300 (3%)
    function WEEK_5_8_BONUS() external view returns (uint256); // 100 (1%)
    function BASIS_POINTS() external view returns (uint256); // 10000
}
