// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @title IRevenueCollector
 * @dev Interface for revenue collection and distribution mechanism
 * Implements 50/30/20 split for stakers/treasury/development
 */
interface IRevenueCollector {
    // Events
    event RevenueCollected(address indexed token, uint256 amount);
    event RevenueDistributed(uint256 stakersShare, uint256 treasuryShare, uint256 developmentShare);
    event DistributionAddressesSet(address staking, address treasury, address development);
    event EmergencyWithdraw(address indexed token, uint256 amount);
    
    // Functions
    function collectRevenue(address token, uint256 amount) external;
    function distributeRevenue(address token) external;
    function setDistributionAddresses(
        address _stakingContract,
        address _treasury,
        address _development
    ) external;
    function emergencyWithdraw(address token) external;
    
    // State getters
    function stakingContract() external view returns (address);
    function treasury() external view returns (address);
    function development() external view returns (address);
    function pendingRevenue(address token) external view returns (uint256);
    function totalCollected(address token) external view returns (uint256);
    function totalDistributed(address token) external view returns (uint256);
    
    // Constants
    function STAKERS_SHARE() external view returns (uint256); // 5000 (50%)
    function TREASURY_SHARE() external view returns (uint256); // 3000 (30%)
    function DEVELOPMENT_SHARE() external view returns (uint256); // 2000 (20%)
    function BASIS_POINTS() external view returns (uint256); // 10000
}