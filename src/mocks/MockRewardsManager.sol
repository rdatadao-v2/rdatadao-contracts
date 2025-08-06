// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "../interfaces/IRewardsManager.sol";

/**
 * @title MockRewardsManager
 * @notice Minimal mock implementation of RewardsManager for testing
 */
contract MockRewardsManager is IRewardsManager {
    address public stakingManager;
    
    function notifyStake(
        address user,
        uint256 stakeId,
        uint256 amount,
        uint256 lockPeriod
    ) external override {
        // Mock implementation - do nothing
    }
    
    function notifyUnstake(
        address user,
        uint256 stakeId,
        bool emergency
    ) external override {
        // Mock implementation - do nothing
    }
    
    // Required but not used in tests
    function registerProgram(
        address rewardModule,
        string calldata name,
        uint256 startTime,
        uint256 endTime
    ) external override returns (uint256) {
        return 0;
    }
    
    function updateProgramStatus(uint256 programId, bool active) external override {}
    function emergencyPauseProgram(uint256 programId) external override {}
    function emergencyUnpauseProgram(uint256 programId) external override {}
    
    function claimRewards(uint256 stakeId) external override returns (ClaimInfo[] memory) {
        return new ClaimInfo[](0);
    }
    
    function claimRewardsFor(address user, uint256 stakeId) external override returns (ClaimInfo[] memory) {
        return new ClaimInfo[](0);
    }
    
    function claimAllRewards() external override returns (ClaimInfo[] memory) {
        return new ClaimInfo[](0);
    }
    
    function calculateRewards(address user, uint256 stakeId) external view override returns (uint256[] memory amounts, address[] memory tokens) {
        amounts = new uint256[](0);
        tokens = new address[](0);
    }
    
    function calculateAllRewards(address user) external view override returns (uint256[] memory amounts, address[] memory tokens) {
        amounts = new uint256[](0);
        tokens = new address[](0);
    }
    
    function getProgram(uint256 programId) external view override returns (RewardProgram memory) {
        return RewardProgram(address(0), address(0), "", 0, 0, false, false);
    }
    
    function getProgramCount() external view override returns (uint256) {
        return 0;
    }
    
    function getActivePrograms() external view override returns (uint256[] memory) {
        return new uint256[](0);
    }
    
    function getUserClaimablePrograms(address user, uint256 stakeId) external view override returns (uint256[] memory) {
        return new uint256[](0);
    }
    
    function setStakingManager(address _stakingManager) external override {
        stakingManager = _stakingManager;
    }
}