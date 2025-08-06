// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @title IRewardModule
 * @author r/datadao
 * @notice Base interface that all reward distribution modules must implement
 * @dev Modules handle specific reward logic and are called by the RewardsManager
 */
interface IRewardModule {
    /**
     * @notice Module metadata for identification and UI
     */
    struct ModuleInfo {
        string name;             // Module name (e.g., "vRDAT Governance Rewards")
        string version;          // Module version (e.g., "1.0.0")
        address rewardToken;     // Token distributed by this module
        bool isActive;           // Whether module is currently active
        bool supportsHistory;    // Whether module can calculate historical rewards
        uint256 totalAllocated;  // Total tokens allocated to this module
        uint256 totalDistributed;// Total tokens distributed so far
    }

    // Events
    event RewardDistributed(
        address indexed user,
        uint256 indexed stakeId,
        uint256 amount,
        address token
    );
    
    event RewardSlashed(
        address indexed user,
        uint256 indexed stakeId,
        uint256 amount,
        address token
    );
    
    event ModuleStatusChanged(bool active);
    event AllocationIncreased(uint256 amount);

    // Errors
    error NotRewardsManager();
    error ModuleInactive();
    error InsufficientAllocation();
    error InvalidStakeData();
    error DistributionFailed();
    error SlashingFailed();

    /**
     * @notice Called when a user creates a new stake
     * @dev Only callable by RewardsManager
     * @param user Address of the staker
     * @param stakeId Unique identifier for the stake
     * @param amount Amount of tokens staked
     * @param lockPeriod Duration of the stake lock
     */
    function onStake(
        address user,
        uint256 stakeId,
        uint256 amount,
        uint256 lockPeriod
    ) external;

    /**
     * @notice Called when a user unstakes (normal or emergency)
     * @dev Only callable by RewardsManager
     * @param user Address of the staker
     * @param stakeId Unique identifier for the stake
     * @param amount Amount being unstaked
     * @param emergency Whether this is an emergency withdrawal
     */
    function onUnstake(
        address user,
        uint256 stakeId,
        uint256 amount,
        bool emergency
    ) external;

    /**
     * @notice Calculate pending rewards for a stake
     * @dev Must not revert even if stake doesn't exist
     * @param user Address of the staker
     * @param stakeId Unique identifier for the stake
     * @return amount Pending reward amount
     */
    function calculateRewards(
        address user,
        uint256 stakeId
    ) external view returns (uint256 amount);

    /**
     * @notice Claim rewards for a stake
     * @dev Only callable by RewardsManager
     * @param user Address of the staker
     * @param stakeId Unique identifier for the stake
     * @return amount Amount of rewards claimed
     */
    function claimRewards(
        address user,
        uint256 stakeId
    ) external returns (uint256 amount);

    /**
     * @notice Get module information
     * @return Module metadata
     */
    function getModuleInfo() external view returns (ModuleInfo memory);

    /**
     * @notice Check if module is active
     * @return Whether module is accepting new stakes and distributing rewards
     */
    function isActive() external view returns (bool);

    /**
     * @notice Get the reward token address
     * @return Address of the token distributed by this module
     */
    function rewardToken() external view returns (address);

    /**
     * @notice Get total allocated tokens
     * @return Total tokens allocated to this module
     */
    function totalAllocated() external view returns (uint256);

    /**
     * @notice Get total distributed tokens
     * @return Total tokens distributed by this module
     */
    function totalDistributed() external view returns (uint256);

    /**
     * @notice Get remaining allocation
     * @return Tokens remaining to be distributed
     */
    function remainingAllocation() external view returns (uint256);

    /**
     * @notice Emergency function to recover tokens
     * @dev Only callable by admin in emergency situations
     * @param token Token to recover
     * @param amount Amount to recover
     */
    function emergencyWithdraw(address token, uint256 amount) external;
}