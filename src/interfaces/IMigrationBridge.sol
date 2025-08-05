// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface IMigrationBridge {
    // Events
    event MigrationInitiated(bytes32 indexed requestId, address indexed user, uint256 amount, bytes32 burnTxHash);
    event MigrationValidated(bytes32 indexed requestId, address indexed validator);
    event MigrationExecuted(bytes32 indexed requestId, address indexed user, uint256 amount, uint256 bonus);
    
    // Functions
    function submitMigration(address user, uint256 amount, bytes32 burnTxHash) external;
    function validateMigration(bytes32 requestId) external;
    function calculateBonus(uint256 amount) external view returns (uint256);
    function pause() external;
    function unpause() external;
    
    // State getters
    function migratedAmounts(address user) external view returns (uint256);
    function hasClaimedBonus(address user) external view returns (bool);
    function totalMigrated() external view returns (uint256);
    function migrationStartTime() external view returns (uint256);
    function dailyMigrated() external view returns (uint256);
    function lastResetTime() external view returns (uint256);
    
    // Constants
    function DAILY_LIMIT() external view returns (uint256);
    function WEEK_1_2_BONUS() external view returns (uint256);
    function WEEK_3_4_BONUS() external view returns (uint256);
    function WEEK_5_8_BONUS() external view returns (uint256);
}