// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../src/RDAT_V2.sol";
import "../src/vRDAT_V2.sol";
import "../src/StakingV2.sol";
import "../src/MigrationBridge_V2.sol";
import "./PreDeploymentCheck.s.sol";

/**
 * @title DeployV2Beta
 * @dev Deployment script for RDAT V2 Beta contracts
 * 
 * Usage:
 * - Testnet: forge script script/DeployV2Beta.s.sol --rpc-url $VANA_MOKSHA_RPC_URL --broadcast
 * - Mainnet: forge script script/DeployV2Beta.s.sol --rpc-url $VANA_RPC_URL --broadcast
 */
contract DeployV2Beta is Script {
    // Deployment addresses
    address public treasury;
    address public multisig;
    
    // Pre-deployment check
    bool public constant RUN_CHECKS = true;
    
    // Deployed contracts
    RDAT_V2 public rdatV2;
    vRDAT_V2 public vrdatV2;
    StakingV2 public stakingV2;
    MigrationBridge_V2 public bridgeV2;
    
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
        
        // 1. Deploy RDAT_V2
        console2.log("Deploying RDAT_V2...");
        rdatV2 = new RDAT_V2(treasury);
        console2.log("RDAT_V2 deployed at:", address(rdatV2));
        
        // 2. Deploy vRDAT_V2
        console2.log("Deploying vRDAT_V2...");
        vrdatV2 = new vRDAT_V2();
        console2.log("vRDAT_V2 deployed at:", address(vrdatV2));
        
        // 3. Deploy StakingV2
        console2.log("Deploying StakingV2...");
        stakingV2 = new StakingV2(address(rdatV2), address(vrdatV2));
        console2.log("StakingV2 deployed at:", address(stakingV2));
        
        // 4. Deploy MigrationBridge_V2
        console2.log("Deploying MigrationBridge_V2...");
        bridgeV2 = new MigrationBridge_V2(address(rdatV2));
        console2.log("MigrationBridge_V2 deployed at:", address(bridgeV2));
        
        // 5. Configure roles
        console2.log("Configuring roles...");
        
        // Grant minter roles
        rdatV2.grantRole(rdatV2.MINTER_ROLE(), address(bridgeV2));
        vrdatV2.grantRole(vrdatV2.MINTER_ROLE(), address(stakingV2));
        
        // Setup multi-sig as admin
        rdatV2.grantRole(rdatV2.DEFAULT_ADMIN_ROLE(), multisig);
        vrdatV2.grantRole(vrdatV2.DEFAULT_ADMIN_ROLE(), multisig);
        stakingV2.grantRole(stakingV2.DEFAULT_ADMIN_ROLE(), multisig);
        bridgeV2.grantRole(bridgeV2.DEFAULT_ADMIN_ROLE(), multisig);
        
        // Renounce deployer admin (keeping one for initial setup)
        if (msg.sender != multisig) {
            console2.log("Renouncing deployer admin roles...");
            rdatV2.renounceRole(rdatV2.DEFAULT_ADMIN_ROLE(), msg.sender);
            vrdatV2.renounceRole(vrdatV2.DEFAULT_ADMIN_ROLE(), msg.sender);
            stakingV2.renounceRole(stakingV2.DEFAULT_ADMIN_ROLE(), msg.sender);
            bridgeV2.renounceRole(bridgeV2.DEFAULT_ADMIN_ROLE(), msg.sender);
        }
        
        vm.stopBroadcast();
        
        // Log deployment summary
        console2.log("\n=== Deployment Summary ===");
        console2.log("RDAT_V2:", address(rdatV2));
        console2.log("vRDAT_V2:", address(vrdatV2));
        console2.log("StakingV2:", address(stakingV2));
        console2.log("MigrationBridge_V2:", address(bridgeV2));
        console2.log("Treasury:", treasury);
        console2.log("Multisig:", multisig);
        console2.log("========================\n");
    }
}