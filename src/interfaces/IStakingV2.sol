// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface IStakingV2 {
    // Structs
    struct StakeInfo {
        uint256 amount;
        uint256 startTime;
        uint256 lockPeriod;
        uint256 vrdatMinted;
        uint256 rewardsClaimed;
    }
    
    // Events
    event Staked(address indexed user, uint256 amount, uint256 lockPeriod);
    event Unstaked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    
    // Functions
    function stake(uint256 amount, uint256 lockPeriod) external;
    function unstake() external;
    function pause() external;
    function unpause() external;
    
    // State getters
    function stakes(address user) external view returns (StakeInfo memory);
    function totalStaked() external view returns (uint256);
    function lockMultipliers(uint256 lockPeriod) external view returns (uint256);
    function rdatToken() external view returns (address);
    function vrdatToken() external view returns (address);
}