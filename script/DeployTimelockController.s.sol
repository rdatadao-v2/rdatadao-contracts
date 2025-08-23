// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title DeployTimelockController
 * @notice Production-ready deployment of OpenZeppelin TimelockController for audit L-04
 * @dev This script deploys a timelock that should hold critical roles like UPGRADER_ROLE
 * 
 * Usage:
 * forge script script/DeployTimelockController.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY
 * 
 * After deployment:
 * 1. Grant UPGRADER_ROLE to the timelock address
 * 2. Revoke UPGRADER_ROLE from EOA accounts
 * 3. All upgrades will require 48-hour delay
 */
contract DeployTimelockController is Script {
    // Configuration
    uint256 public constant MIN_DELAY = 48 hours; // Minimum delay for operations
    
    // Addresses (configure these for your deployment)
    address public constant MULTISIG_ADMIN = address(0); // Set your multisig here
    
    function run() external returns (address timelock) {
        // Get deployment parameters from environment
        address admin = vm.envOr("ADMIN_ADDRESS", MULTISIG_ADMIN);
        require(admin != address(0), "Admin address not set");
        
        // For production, proposers and executors should be different
        // Proposers: can schedule operations
        // Executors: can execute after delay
        address[] memory proposers = new address[](1);
        proposers[0] = admin; // In production, use a multisig
        
        address[] memory executors = new address[](1);
        executors[0] = admin; // In production, could be different multisig
        
        vm.startBroadcast();
        
        // Deploy TimelockController
        timelock = address(new TimelockController(
            MIN_DELAY,           // minDelay
            proposers,           // proposers
            executors,           // executors
            admin               // admin (optional, can be address(0) to renounce)
        ));
        
        console2.log("TimelockController deployed at:", timelock);
        console2.log("Min delay:", MIN_DELAY / 3600, "hours");
        console2.log("Admin:", admin);
        
        vm.stopBroadcast();
        
        // Log next steps
        console2.log("\n=== NEXT STEPS ===");
        console2.log("1. Grant UPGRADER_ROLE to timelock:");
        console2.log("   rdatToken.grantRole(UPGRADER_ROLE, %s)", timelock);
        console2.log("2. Revoke UPGRADER_ROLE from EOA:");
        console2.log("   rdatToken.revokeRole(UPGRADER_ROLE, currentUpgrader)");
        console2.log("3. For other critical roles, repeat the process");
        
        return timelock;
    }
    
    /**
     * @notice Helper to schedule an upgrade through the timelock
     * @dev Call this to prepare an upgrade transaction
     */
    function scheduleUpgrade(
        address timelock,
        address target,
        bytes memory data
    ) external {
        TimelockController controller = TimelockController(payable(timelock));
        
        // Schedule the operation
        controller.schedule(
            target,                          // target
            0,                              // value
            data,                           // data
            bytes32(0),                     // predecessor
            keccak256(abi.encode(target, data, block.timestamp)), // salt
            MIN_DELAY                       // delay
        );
        
        console2.log("Upgrade scheduled. Can execute after:", block.timestamp + MIN_DELAY);
    }
}