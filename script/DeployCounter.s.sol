// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../src/Counter.sol";

/**
 * @title DeployCounter
 * @dev Test deployment script to verify chain configurations
 * 
 * Usage:
 * - Local: forge script script/DeployCounter.s.sol --rpc-url http://localhost:8545 --broadcast
 * - Testnet: forge script script/DeployCounter.s.sol --rpc-url $VANA_MOKSHA_RPC_URL --broadcast
 * - Mainnet Simulation: forge script script/DeployCounter.s.sol --rpc-url $VANA_RPC_URL
 */
contract DeployCounter is Script {
    Counter public counter;
    
    // Chain IDs
    uint256 constant VANA_MAINNET = 1480;
    uint256 constant VANA_MOKSHA = 14800;
    uint256 constant BASE_MAINNET = 8453;
    uint256 constant BASE_SEPOLIA = 84532;
    
    function run() external {
        // Get deployer info
        address deployer = msg.sender;
        uint256 chainId = block.chainid;
        string memory chainName = getChainName(chainId);
        
        console2.log("\n========================================");
        console2.log("     Counter Deployment Test");
        console2.log("========================================");
        console2.log("Chain: %s (ID: %s)", chainName, chainId);
        console2.log("Deployer: %s", deployer);
        console2.log("Balance: %s ETH", deployer.balance / 1e18);
        
        // Check if mainnet and warn
        if (chainId == VANA_MAINNET || chainId == BASE_MAINNET) {
            console2.log("\n[WARNING] This is a MAINNET!");
            console2.log("To actually deploy, add --broadcast flag");
            console2.log("Current mode: SIMULATION ONLY\n");
        }
        
        // Start broadcast (or simulation)
        vm.startBroadcast();
        
        // Deploy Counter
        console2.log("\nDeploying Counter...");
        counter = new Counter();
        console2.log("Counter deployed at: %s", address(counter));
        
        // Set initial value
        counter.setNumber(42);
        console2.log("Initial number set to: %s", counter.number());
        
        // Test increment
        counter.increment();
        console2.log("After increment: %s", counter.number());
        
        vm.stopBroadcast();
        
        // Post-deployment info
        console2.log("\n========================================");
        console2.log("     Deployment Summary");
        console2.log("========================================");
        console2.log("Contract: %s", address(counter));
        console2.log("Chain: %s", chainName);
        console2.log("Block: %s", block.number);
        console2.log("Deployer: %s", deployer);
        
        // Verification command
        if (chainId != VANA_MAINNET && chainId != BASE_MAINNET) {
            console2.log("\nTo verify contract:");
            if (chainId == BASE_SEPOLIA) {
                console2.log("forge verify-contract %s src/Counter.sol:Counter --chain-id %s --etherscan-api-key $BASESCAN_API_KEY", address(counter), chainId);
            } else {
                console2.log("forge verify-contract %s src/Counter.sol:Counter --chain-id %s", address(counter), chainId);
            }
        }
        
        // Gas usage estimate
        uint256 gasUsed = 200000; // Rough estimate for Counter deployment
        uint256 gasPrice = tx.gasprice > 0 ? tx.gasprice : 20 gwei;
        uint256 deploymentCost = gasUsed * gasPrice;
        console2.log("\nEstimated deployment cost: %s ETH", deploymentCost / 1e18);
        console2.log("At gas price: %s gwei", gasPrice / 1e9);
    }
    
    function getChainName(uint256 chainId) internal pure returns (string memory) {
        if (chainId == VANA_MAINNET) return "Vana Mainnet";
        if (chainId == VANA_MOKSHA) return "Vana Moksha Testnet";
        if (chainId == BASE_MAINNET) return "Base Mainnet";
        if (chainId == BASE_SEPOLIA) return "Base Sepolia Testnet";
        if (chainId == 31337) return "Local Anvil";
        return "Unknown Chain";
    }
}