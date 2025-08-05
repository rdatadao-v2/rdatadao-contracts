// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface IStaking {
    // Structs
    struct StakeInfo {
        uint256 amount;
        uint256 startTime;
        uint256 lockPeriod;
        uint256 vrdatMinted;
        uint256 rewardsClaimed;
        uint256 lastRewardTime;
        uint256 multiplier;
    }
    
    // Events
    event Staked(address indexed user, uint256 amount, uint256 lockPeriod, uint256 multiplier);
    event Unstaked(address indexed user, uint256 amount, uint256 vrdatBurned);
    event RewardsClaimed(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount, uint256 penalty);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    event MultipliersUpdated(uint256 month1, uint256 month3, uint256 month6, uint256 month12);
    
    // Errors
    error StakingPaused();
    error InsufficientBalance();
    error StakeStillLocked();
    error NoRewardsToClaim();
    error InvalidLockDuration();
    error ZeroAmount();
    error TransferFailed();
    error ExceedsMaxStakePerUser();
    error InvalidMultiplier();
    
    // Constants
    function MONTH_1() external view returns (uint256);
    function MONTH_3() external view returns (uint256);
    function MONTH_6() external view returns (uint256);
    function MONTH_12() external view returns (uint256);
    function MAX_STAKE_PER_USER() external view returns (uint256);
    function EMERGENCY_WITHDRAW_PENALTY() external view returns (uint256);
    
    // Functions
    function stake(uint256 amount, uint256 lockPeriod) external;
    function unstake() external;
    function claimRewards() external;
    function emergencyWithdraw() external;
    function pause() external;
    function unpause() external;
    
    // Admin functions
    function setRewardRate(uint256 newRate) external;
    function setMultipliers(uint256 month1, uint256 month3, uint256 month6, uint256 month12) external;
    function rescueTokens(address token, uint256 amount) external;
    
    // State getters
    function stakes(address user) external view returns (StakeInfo memory);
    function totalStaked() external view returns (uint256);
    function totalRewardsDistributed() external view returns (uint256);
    function lockMultipliers(uint256 lockPeriod) external view returns (uint256);
    function rdatToken() external view returns (address);
    function vrdatToken() external view returns (address);
    function rewardRate() external view returns (uint256);
    
    // View functions
    function calculatePendingRewards(address user) external view returns (uint256);
    function canUnstake(address user) external view returns (bool);
    function getStakeEndTime(address user) external view returns (uint256);
}