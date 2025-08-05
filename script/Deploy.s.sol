// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../src/RDAT.sol";
import "../src/vRDAT.sol";
import "../src/Staking.sol";
import "../src/MigrationBridge.sol";
import "./PreDeploymentCheck.s.sol";

/**
 * @title Deploy
 * @dev Deployment script for RDAT contracts
 * 
 * Usage:
 * - Testnet: forge script script/Deploy.s.sol --rpc-url $VANA_MOKSHA_RPC_URL --broadcast
 * - Mainnet: forge script script/Deploy.s.sol --rpc-url $VANA_RPC_URL --broadcast
 */
contract Deploy is Script {
    // Deployment addresses
    address public treasury;
    address public multisig;
    
    // Pre-deployment check
    bool public constant RUN_CHECKS = true;
    
    // Deployed contracts
    RDAT public rdat;
    vRDAT public vrdat;
    Staking public staking;
    MigrationBridge public bridge;
    
    function run() external {
        // Load deployment config based on chain
        uint256 chainId = block.chainid;
        
        if (chainId == 1480 || chainId == 14800) {
            // Vana chains use Vana multisig
            treasury = vm.envAddress("VANA_MULTISIG_ADDRESS");
            multisig = vm.envAddress("VANA_MULTISIG_ADDRESS");
        } else if (chainId == 8453 || chainId == 84532) {
            // Base chains use Base multisig (though V2 won't deploy there)
            treasury = vm.envAddress("BASE_MULTISIG_ADDRESS");
            multisig = vm.envAddress("BASE_MULTISIG_ADDRESS");
        } else {
            revert("Unsupported chain");
        }
        
        // Validate config
        require(treasury != address(0), "Treasury not set");
        require(multisig != address(0), "Multisig not set");
        
        // Run pre-deployment checks if enabled
        if (RUN_CHECKS) {
            console2.log("Running pre-deployment checks...");
            try new PreDeploymentCheck().run() {
                console2.log("Pre-deployment checks passed!");
            } catch Error(string memory reason) {
                console2.log("Pre-deployment check failed: %s", reason);
                revert("Pre-deployment checks failed");
            }
        }
        
        // Start deployment
        vm.startBroadcast();
        
        // 1. Deploy RDAT
        console2.log("Deploying RDAT...");
        rdat = new RDAT(treasury);
        console2.log("RDAT deployed at:", address(rdat));
        
        // 2. Deploy vRDAT
        console2.log("Deploying vRDAT...");
        vrdat = new vRDAT();
        console2.log("vRDAT deployed at:", address(vrdat));
        
        // 3. Deploy Staking
        console2.log("Deploying Staking...");
        staking = new Staking(address(rdat), address(vrdat));
        console2.log("Staking deployed at:", address(staking));
        
        // 4. Deploy MigrationBridge
        console2.log("Deploying MigrationBridge...");
        bridge = new MigrationBridge(address(rdat));
        console2.log("MigrationBridge deployed at:", address(bridge));
        
        // 5. Configure roles
        console2.log("Configuring roles...");
        
        // Grant minter roles
        rdat.grantRole(rdat.MINTER_ROLE(), address(bridge));
        vrdat.grantRole(vrdat.MINTER_ROLE(), address(staking));
        
        // Setup multi-sig as admin
        rdat.grantRole(rdat.DEFAULT_ADMIN_ROLE(), multisig);
        vrdat.grantRole(vrdat.DEFAULT_ADMIN_ROLE(), multisig);
        staking.grantRole(staking.DEFAULT_ADMIN_ROLE(), multisig);
        bridge.grantRole(bridge.DEFAULT_ADMIN_ROLE(), multisig);
        
        // Renounce deployer admin (keeping one for initial setup)
        if (msg.sender != multisig) {
            console2.log("Renouncing deployer admin roles...");
            rdat.renounceRole(rdat.DEFAULT_ADMIN_ROLE(), msg.sender);
            vrdat.renounceRole(vrdat.DEFAULT_ADMIN_ROLE(), msg.sender);
            staking.renounceRole(staking.DEFAULT_ADMIN_ROLE(), msg.sender);
            bridge.renounceRole(bridge.DEFAULT_ADMIN_ROLE(), msg.sender);
        }
        
        vm.stopBroadcast();
        
        // Log deployment summary
        console2.log("\n=== Deployment Summary ===");
        console2.log("RDAT:", address(rdat));
        console2.log("vRDAT:", address(vrdat));
        console2.log("Staking:", address(staking));
        console2.log("MigrationBridge:", address(bridge));
        console2.log("Treasury:", treasury);
        console2.log("Multisig:", multisig);
        console2.log("========================\n");
    }
}