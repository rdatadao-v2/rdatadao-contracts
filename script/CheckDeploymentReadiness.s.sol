// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "./PreDeploymentCheck.s.sol";

/**
 * @title CheckDeploymentReadiness
 * @dev Standalone script to check deployment readiness without deploying
 * 
 * Usage:
 * forge script script/CheckDeploymentReadiness.s.sol --rpc-url $VANA_RPC_URL
 * forge script script/CheckDeploymentReadiness.s.sol --rpc-url $VANA_MOKSHA_RPC_URL
 * forge script script/CheckDeploymentReadiness.s.sol --rpc-url $BASE_RPC_URL
 */
contract CheckDeploymentReadiness is PreDeploymentCheck {
    // Inherits all functionality from PreDeploymentCheck
    // This is just a convenient alias for running checks independently
}