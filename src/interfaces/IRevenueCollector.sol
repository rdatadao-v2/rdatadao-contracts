// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @title IRevenueCollector
 * @author r/datadao
 * @notice Interface for the revenue collection and distribution system
 */
interface IRevenueCollector {
    // Events
    event RevenueReported(address indexed token, uint256 amount, address indexed reporter);
    event RevenueDistributed(
        address indexed token, 
        uint256 totalAmount, 
        uint256 stakingAmount, 
        uint256 treasuryAmount, 
        uint256 contributorAmount
    );
    event ThresholdUpdated(address indexed token, uint256 oldThreshold, uint256 newThreshold);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event ContributorPoolUpdated(address indexed oldPool, address indexed newPool);
    event TokenSupported(address indexed token, uint256 threshold);
    event TokenRemoved(address indexed token);
    event EmergencyRecovery(address indexed token, uint256 amount, address indexed recipient);

    // Core functions
    function notifyRevenue(address token, uint256 amount) external;
    function distribute(address token) external returns (uint256 stakingAmount, uint256 treasuryAmount, uint256 contributorAmount);
    function distributeAll() external returns (
        address[] memory tokens,
        uint256[] memory stakingAmounts,
        uint256[] memory treasuryAmounts,
        uint256[] memory contributorAmounts
    );

    // View functions
    function pendingRevenue(address token) external view returns (uint256);
    function distributionThreshold(address token) external view returns (uint256);
    function totalRevenueCollected(address token) external view returns (uint256);
    function totalDistributed(address token) external view returns (uint256);
    function getSupportedTokens() external view returns (address[] memory);
    function getPendingRevenue() external view returns (address[] memory tokens, uint256[] memory amounts);
    function isDistributionNeeded() external view returns (bool needed, address[] memory tokensReady);
    function getStats() external view returns (uint256 totalDistributions_, uint256 lastDistributionTime_, uint256 supportedTokenCount);

    // Admin functions
    function setDistributionThreshold(address token, uint256 threshold) external;
    function setTreasury(address newTreasury) external;
    function setContributorPool(address newContributorPool) external;
    function addSupportedToken(address token, uint256 threshold) external;
    function removeSupportedToken(address token) external;
}