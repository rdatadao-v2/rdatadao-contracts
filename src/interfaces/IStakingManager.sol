// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @title IStakingManager
 * @author r/datadao
 * @notice Interface for the StakingManager contract that handles core staking logic only
 * @dev This contract is immutable and contains no reward logic - only staking state management
 */
interface IStakingManager {
    /**
     * @notice Stake information for a position
     * @dev Each user can have multiple stakes identified by stakeId
     */
    struct StakeInfo {
        uint256 amount;          // Amount of RDAT staked
        uint256 startTime;       // Timestamp when stake was created
        uint256 endTime;         // Timestamp when stake unlocks
        uint256 lockPeriod;      // Lock duration in seconds (30/90/180/365 days)
        bool active;             // Whether stake is currently active
        bool emergencyUnlocked;  // Whether stake was unlocked via emergency migration
    }

    // Events
    event Staked(
        address indexed user,
        uint256 indexed stakeId,
        uint256 amount,
        uint256 lockPeriod,
        uint256 endTime
    );
    
    event Unstaked(
        address indexed user,
        uint256 indexed stakeId,
        uint256 amount,
        bool emergency
    );
    
    event EmergencyMigrationEnabled(uint256 timestamp);
    event EmergencyMigrationDisabled(uint256 timestamp);

    // Errors
    error InvalidAmount();
    error InvalidLockPeriod();
    error StakeNotFound();
    error StakeStillLocked();
    error StakeNotActive();
    error EmergencyMigrationNotEnabled();
    error InsufficientBalance();
    error TransferFailed();

    // Core staking functions
    function stake(uint256 amount, uint256 lockPeriod) external returns (uint256 stakeId);
    function unstake(uint256 stakeId) external returns (uint256 amount);
    function emergencyWithdraw(uint256 stakeId) external returns (uint256 amount);
    
    // View functions for rewards contracts
    function getStake(address user, uint256 stakeId) external view returns (StakeInfo memory);
    function getUserStakeIds(address user) external view returns (uint256[] memory);
    function getUserActiveStakeIds(address user) external view returns (uint256[] memory);
    function isStakeActive(address user, uint256 stakeId) external view returns (bool);
    
    // Aggregate view functions
    function totalStaked() external view returns (uint256);
    function userTotalStaked(address user) external view returns (uint256);
    function userActiveStakeCount(address user) external view returns (uint256);
    
    // Lock period validation
    function isValidLockPeriod(uint256 lockPeriod) external pure returns (bool);
    function getMultiplier(uint256 lockPeriod) external view returns (uint256);
    
    // Emergency functions (admin only)
    function enableEmergencyMigration() external;
    function disableEmergencyMigration() external;
    function isEmergencyMigrationEnabled() external view returns (bool);
    
    // Constants
    function MONTH_1() external pure returns (uint256);
    function MONTH_3() external pure returns (uint256);
    function MONTH_6() external pure returns (uint256);
    function MONTH_12() external pure returns (uint256);
    function MIN_STAKE_AMOUNT() external pure returns (uint256);
    function MAX_STAKE_AMOUNT() external pure returns (uint256);
    function EMERGENCY_WITHDRAW_PENALTY() external pure returns (uint256); // In basis points (5000 = 50%)
}