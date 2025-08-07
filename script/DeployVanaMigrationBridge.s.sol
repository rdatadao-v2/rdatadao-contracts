// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script, console2} from "forge-std/Script.sol";
import {VanaMigrationBridge} from "../src/VanaMigrationBridge.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title DeployVanaMigrationBridge
 * @notice Deploy the Vana-side migration bridge and fund it with 30M RDAT
 * @dev To be run after RDAT is deployed and tokens are available
 */
contract DeployVanaMigrationBridge is Script {
    // Constants
    uint256 constant MIGRATION_ALLOCATION = 30_000_000e18;
    
    function run() external returns (address bridgeAddress) {
        // Load configuration
        address rdatToken = vm.envAddress("RDAT_TOKEN_ADDRESS");
        address admin = vm.envAddress("ADMIN_ADDRESS");
        
        require(rdatToken != address(0), "RDAT_TOKEN_ADDRESS not set");
        require(admin != address(0), "ADMIN_ADDRESS not set");
        
        console2.log("========================================");
        console2.log("DEPLOY VANA MIGRATION BRIDGE");
        console2.log("========================================");
        console2.log("Chain ID:", block.chainid);
        console2.log("RDAT Token:", rdatToken);
        console2.log("Admin:", admin);
        console2.log("Migration Allocation: 30M RDAT");
        console2.log("");
        
        vm.startBroadcast();
        
        // Deploy the migration bridge
        VanaMigrationBridge bridge = new VanaMigrationBridge(
            rdatToken,
            admin
        );
        bridgeAddress = address(bridge);
        
        console2.log("[OK] VanaMigrationBridge deployed at:", bridgeAddress);
        
        // Add initial validators (for testnet, we'll add a few test validators)
        if (block.chainid == 14800) { // Vana Moksha testnet
            address validator1 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // Test validator 1
            address validator2 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC; // Test validator 2
            
            bridge.addValidator(validator1);
            bridge.addValidator(validator2);
            
            console2.log("[OK] Added test validators:");
            console2.log("   -", validator1);
            console2.log("   -", validator2);
        }
        
        vm.stopBroadcast();
        
        // Check if we need to fund the bridge
        IERC20 rdat = IERC20(rdatToken);
        uint256 bridgeBalance = rdat.balanceOf(bridgeAddress);
        
        console2.log("");
        console2.log("Bridge Balance:", bridgeBalance / 1e18, "RDAT");
        
        if (bridgeBalance == 0) {
            console2.log("");
            console2.log("[WARNING]  IMPORTANT: Bridge needs to be funded with 30M RDAT");
            console2.log("Execute from multisig or token holder:");
            console2.log("");
            console2.log("cast send", rdatToken);
            console2.log("  'transfer(address,uint256)'");
            console2.log("  ", bridgeAddress);
            console2.log("  ", MIGRATION_ALLOCATION);
            console2.log("  --rpc-url <RPC_URL>");
            console2.log("  --private-key <HOLDER_KEY>");
        } else if (bridgeBalance == MIGRATION_ALLOCATION) {
            console2.log("[OK] Bridge properly funded with 30M RDAT");
        } else {
            console2.log("[WARNING]  Bridge has unexpected balance:", bridgeBalance / 1e18, "RDAT");
        }
        
        console2.log("");
        console2.log("========================================");
        console2.log("Deployment Complete!");
        console2.log("========================================");
        
        return bridgeAddress;
    }
    
    /**
     * @notice Dry run to check deployment requirements
     */
    function dryRun() external view {
        address rdatToken = vm.envOr("RDAT_TOKEN_ADDRESS", address(0));
        address admin = vm.envOr("ADMIN_ADDRESS", address(0));
        address deployer = vm.envOr("DEPLOYER_ADDRESS", msg.sender);
        
        console2.log("========================================");
        console2.log("DRY RUN - MIGRATION BRIDGE DEPLOYMENT");
        console2.log("========================================");
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", deployer);
        console2.log("RDAT Token:", rdatToken);
        console2.log("Admin:", admin);
        console2.log("");
        
        if (rdatToken == address(0)) {
            console2.log("[ERROR] ERROR: RDAT_TOKEN_ADDRESS not set!");
            console2.log("   For Vana Moksha testnet: 0xEb0c43d5987de0672A22e350930F615Af646e28c");
            return;
        }
        
        if (admin == address(0)) {
            console2.log("[ERROR] ERROR: ADMIN_ADDRESS not set!");
            console2.log("   For Vana Moksha testnet: 0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319");
            return;
        }
        
        // Check token holder balance (who will fund the bridge)
        IERC20 rdat = IERC20(rdatToken);
        
        // Check multisig balance (current holder on testnet)
        uint256 multisigBalance = rdat.balanceOf(admin);
        console2.log("Multisig Balance:", multisigBalance / 1e18, "RDAT");
        
        if (multisigBalance >= MIGRATION_ALLOCATION) {
            console2.log("[OK] Multisig has sufficient balance to fund bridge");
        } else {
            console2.log("[ERROR] Insufficient balance to fund bridge");
            console2.log("   Required: 30M RDAT");
            console2.log("   Available:", multisigBalance / 1e18, "RDAT");
        }
        
        // Predict deployment address
        uint256 currentNonce = vm.getNonce(deployer);
        address predictedBridge = vm.computeCreateAddress(deployer, currentNonce);
        
        console2.log("");
        console2.log("Predicted Bridge Address:", predictedBridge);
        console2.log("");
        console2.log("Next Steps:");
        console2.log("1. Deploy bridge contract");
        console2.log("2. Fund with 30M RDAT from multisig");
        console2.log("3. Configure validators");
        console2.log("4. Deploy Base-side bridge");
        console2.log("========================================");
    }
    
    /**
     * @notice Check bridge status after deployment
     */
    function checkBridge() external view {
        address bridgeAddress = vm.envAddress("BRIDGE_ADDRESS");
        address rdatToken = vm.envAddress("RDAT_TOKEN_ADDRESS");
        
        require(bridgeAddress != address(0), "BRIDGE_ADDRESS not set");
        require(rdatToken != address(0), "RDAT_TOKEN_ADDRESS not set");
        
        VanaMigrationBridge bridge = VanaMigrationBridge(bridgeAddress);
        IERC20 rdat = IERC20(rdatToken);
        
        console2.log("========================================");
        console2.log("MIGRATION BRIDGE STATUS");
        console2.log("========================================");
        console2.log("Bridge Address:", bridgeAddress);
        console2.log("RDAT Token:", rdatToken);
        console2.log("");
        
        // Check balance
        uint256 balance = rdat.balanceOf(bridgeAddress);
        uint256 claimed = bridge.totalMigrated();
        uint256 remaining = balance;
        
        console2.log("Token Status:");
        console2.log("  Current Balance:", balance / 1e18, "RDAT");
        console2.log("  Total Migrated:", claimed / 1e18, "RDAT");
        console2.log("  Remaining:", remaining / 1e18, "RDAT");
        console2.log("");
        
        // Check configuration
        console2.log("Configuration:");
        console2.log("  Admin:", bridge.owner());
        console2.log("  Validator Count:", bridge.validatorCount());
        console2.log("  Min Validators:", bridge.minValidators());
        console2.log("  Daily Limit:", bridge.dailyLimit() / 1e18, "RDAT");
        console2.log("  Migration Deadline:", bridge.migrationDeadline());
        
        if (balance == 0) {
            console2.log("");
            console2.log("[ERROR] Bridge not funded!");
        } else if (balance == MIGRATION_ALLOCATION) {
            console2.log("");
            console2.log("[OK] Bridge properly funded and ready");
        }
    }
}