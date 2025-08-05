// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IRewardProgramManager {
    function registerPosition(uint256 positionId, uint256 amount, uint256 lockPeriod) external;
    function unregisterPosition(uint256 positionId) external;
    function calculateRewards(uint256 positionId) external view returns (uint256);
    function claimRewards(uint256 positionId, address recipient) external returns (uint256);
    function treasury() external view returns (address);
}