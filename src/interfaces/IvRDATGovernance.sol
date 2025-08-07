// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @title IvRDATGovernance
 * @notice Interface for vRDAT governance-specific functions
 * @dev Minimal interface to avoid circular dependencies
 */
interface IvRDATGovernance {
    /**
     * @notice Burn vRDAT tokens for governance voting
     * @param from Address to burn from
     * @param amount Amount to burn
     */
    function burnForGovernance(address from, uint256 amount) external;
    
    /**
     * @notice Get the current balance of vRDAT tokens
     * @param account Address to check
     * @return balance Current vRDAT balance
     */
    function balanceOf(address account) external view returns (uint256);
}