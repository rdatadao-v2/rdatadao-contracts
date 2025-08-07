// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @title IStakingPositions
 * @author r/datadao
 * @notice Interface for NFT-based staking positions
 */
interface IStakingPositions {
    // Structs
    struct Position {
        uint256 amount; // Amount of RDAT staked
        uint256 startTime; // When stake was created
        uint256 lockPeriod; // Lock duration in seconds
        uint256 multiplier; // Reward multiplier (with PRECISION)
        uint256 vrdatMinted; // Amount of vRDAT minted
        uint256 lastRewardTime; // Last time rewards were calculated
        uint256 rewardsClaimed; // Total rewards claimed
    }

    // Events
    event Staked(
        address indexed user, uint256 indexed positionId, uint256 amount, uint256 lockPeriod, uint256 multiplier
    );
    event Unstaked(address indexed user, uint256 indexed positionId, uint256 amount, uint256 vrdatBurned);
    event RewardsClaimed(address indexed user, uint256 indexed positionId, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed positionId, uint256 amountReceived, uint256 penalty);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    event MultipliersUpdated(uint256 month1, uint256 month3, uint256 month6, uint256 month12);
    event RewardsManagerUpdated(address indexed newRewardsManager);

    // Errors
    error ZeroAmount();
    error InvalidLockDuration();
    error InsufficientBalance();
    error StakeStillLocked();
    error NoRewardsToClaim();
    error InvalidMultiplier();
    error PositionDoesNotExist();
    error NotPositionOwner();
    error TransferWhileLocked();
    error TransferWithActiveRewards();
    error BelowMinimumStake();
    error TooManyPositions();

    // Core functions
    function stake(uint256 amount, uint256 lockPeriod) external returns (uint256 positionId);
    function unstake(uint256 positionId) external;
    function claimRewards(uint256 positionId) external;
    function claimAllRewards() external;
    function emergencyWithdraw(uint256 positionId) external;

    // View functions
    function calculatePendingRewards(uint256 positionId) external view returns (uint256);
    function getUserTotalRewards(address user) external view returns (uint256);
    function canUnstake(uint256 positionId) external view returns (bool);
    function getPosition(uint256 positionId) external view returns (Position memory);
    function getUserPositions(address user) external view returns (uint256[] memory);

    // Admin functions
    function setRewardRate(uint256 newRate) external;
    function setMultipliers(uint256 month1, uint256 month3, uint256 month6, uint256 month12) external;
    function rescueTokens(address token, uint256 amount) external;
    function pause() external;
    function unpause() external;

    // Revenue distribution
    function notifyRewardAmount(uint256 amount) external;

    // State getters
    function rdatToken() external view returns (address);
    function vrdatToken() external view returns (address);
    function totalStaked() external view returns (uint256);
    function totalRewardsDistributed() external view returns (uint256);
    function rewardRate() external view returns (uint256);
    function lockMultipliers(uint256 lockPeriod) external view returns (uint256);
}
