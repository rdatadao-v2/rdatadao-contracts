// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script, console2} from "forge-std/Script.sol";
import {RDATUpgradeable} from "../src/RDATUpgradeable.sol";
import {TreasuryWallet} from "../src/TreasuryWallet.sol";
import {VanaMigrationBridge} from "../src/VanaMigrationBridge.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title Deploy RDAT with VRC-20 Compliance
 * @notice Deploys RDAT V2 with minimal VRC-20 features (Option B)
 * @dev Includes updateable DLP Registry for post-deployment configuration
 */
contract DeployRDATWithVRC20 is Script {
    
    // Constants
    uint256 constant TOTAL_SUPPLY = 100_000_000 * 10**18;
    uint256 constant TREASURY_ALLOCATION = 70_000_000 * 10**18;
    uint256 constant MIGRATION_ALLOCATION = 30_000_000 * 10**18;
    
    function run() external {
        // Load configuration
        address admin = vm.envOr("ADMIN_ADDRESS", address(0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319));
        address treasury = vm.envOr("TREASURY_ADDRESS", admin);
        
        // Optional: DLP Registry can be set later
        address dlpRegistry = vm.envOr("DLP_REGISTRY", address(0));
        uint256 dlpId = vm.envOr("DLP_ID", uint256(0));
        
        console2.log("=== RDAT Deployment with VRC-20 Compliance ===");
        console2.log("Admin:", admin);
        console2.log("Treasury:", treasury);
        
        if (dlpRegistry != address(0)) {
            console2.log("DLP Registry:", dlpRegistry);
            console2.log("DLP ID:", dlpId);
        } else {
            console2.log("DLP Registry: Will be configured post-deployment");
        }
        
        vm.startBroadcast();
        
        // 1. Deploy Treasury Wallet
        console2.log("\n1. Deploying TreasuryWallet...");
        TreasuryWallet treasuryImpl = new TreasuryWallet();
        bytes memory treasuryInitData = abi.encodeWithSelector(
            TreasuryWallet.initialize.selector,
            admin,
            address(0) // RDAT address will be set later
        );
        ERC1967Proxy treasuryProxy = new ERC1967Proxy(
            address(treasuryImpl),
            treasuryInitData
        );
        TreasuryWallet treasuryWallet = TreasuryWallet(payable(address(treasuryProxy)));
        console2.log("  TreasuryWallet deployed at:", address(treasuryWallet));
        
        // 2. Deploy Migration Bridge
        console2.log("\n2. Deploying VanaMigrationBridge...");
        address[] memory validators = new address[](3);
        validators[0] = admin; // In production, use separate validators
        validators[1] = admin;
        validators[2] = admin;
        
        VanaMigrationBridge migrationBridge = new VanaMigrationBridge(
            address(0), // RDAT address will be set later
            admin,
            validators
        );
        console2.log("  MigrationBridge deployed at:", address(migrationBridge));
        
        // 3. Deploy RDAT with VRC-20 features
        console2.log("\n3. Deploying RDATUpgradeable...");
        RDATUpgradeable implementation = new RDATUpgradeable();
        
        bytes memory initData = abi.encodeWithSelector(
            RDATUpgradeable.initialize.selector,
            address(treasuryWallet),
            admin,
            address(migrationBridge)
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );
        
        RDATUpgradeable rdat = RDATUpgradeable(address(proxy));
        console2.log("  RDAT deployed at:", address(rdat));
        
        // 4. Configure VRC-20 features if DLP Registry provided
        if (dlpRegistry != address(0)) {
            console2.log("\n4. Configuring VRC-20 features...");
            
            // Set DLP Registry
            rdat.setDLPRegistry(dlpRegistry);
            console2.log("  DLP Registry set");
            
            // Register with DLP if ID provided
            if (dlpId > 0) {
                rdat.updateDLPRegistration(dlpId);
                console2.log("  Registered with DLP ID:", dlpId);
            }
        }
        
        vm.stopBroadcast();
        
        // Verify deployment
        console2.log("\n=== Deployment Verification ===");
        verifyDeployment(address(rdat), address(treasuryWallet), address(migrationBridge));
    }
    
    function verifyDeployment(address rdat, address treasury, address bridge) internal view {
        RDATUpgradeable token = RDATUpgradeable(rdat);
        
        console2.log("\nToken Information:");
        console2.log("  Name:", token.name());
        console2.log("  Symbol:", token.symbol());
        console2.log("  Total Supply:", token.totalSupply() / 10**18, "RDAT");
        
        console2.log("\nAllocations:");
        console2.log("  Treasury Balance:", token.balanceOf(treasury) / 10**18, "RDAT");
        console2.log("  Migration Bridge:", token.balanceOf(bridge) / 10**18, "RDAT");
        
        console2.log("\nVRC-20 Compliance:");
        console2.log("  VRC-20 Compliant:", token.isVRC20Compliant());
        console2.log("  Blacklist Count:", token.blacklistCount());
        console2.log("  Timelock Duration:", token.TIMELOCK_DURATION() / 3600, "hours");
        
        (address registry, bool registered, uint256 dlpId,) = token.getDLPInfo();
        console2.log("\nDLP Status:");
        if (registry != address(0)) {
            console2.log("  Registry:", registry);
            console2.log("  Registered:", registered);
            if (registered) {
                console2.log("  DLP ID:", dlpId);
            }
        } else {
            console2.log("  Registry: Not set (can be configured post-deployment)");
        }
        
        console2.log("\nDeployment successful!");
        console2.log("\nNext Steps:");
        console2.log("1. If DLP Registry not set, call setDLPRegistry() when address available");
        console2.log("2. Register with DLP using updateDLPRegistration()");
        console2.log("3. Configure any initial blacklist entries if needed");
        console2.log("4. Schedule any critical operations with 48-hour timelock");
    }
    
    function dryRun() external view {
        address admin = vm.envOr("ADMIN_ADDRESS", address(0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319));
        address treasury = vm.envOr("TREASURY_ADDRESS", admin);
        address dlpRegistry = vm.envOr("DLP_REGISTRY", address(0));
        uint256 dlpId = vm.envOr("DLP_ID", uint256(0));
        
        console2.log("=== RDAT VRC-20 Deployment Dry Run ===");
        console2.log("\nConfiguration:");
        console2.log("  Admin:", admin);
        console2.log("  Treasury:", treasury);
        
        console2.log("\nVRC-20 Features:");
        console2.log("  - Blocklisting system");
        console2.log("  - 48-hour timelocks");
        console2.log("  - Updateable DLP Registry");
        
        if (dlpRegistry != address(0)) {
            console2.log("\nDLP Configuration:");
            console2.log("  Registry:", dlpRegistry);
            console2.log("  ID:", dlpId);
        } else {
            console2.log("\nDLP Configuration:");
            console2.log("  Registry will be set post-deployment");
            console2.log("  This allows deployment without waiting for Vana");
        }
        
        console2.log("\nDeployment Steps:");
        console2.log("  1. Deploy TreasuryWallet (UUPS proxy)");
        console2.log("  2. Deploy VanaMigrationBridge");
        console2.log("  3. Deploy RDATUpgradeable (UUPS proxy)");
        console2.log("  4. Configure DLP if registry provided");
        
        console2.log("\nPost-Deployment:");
        console2.log("  - Set DLP Registry when available");
        console2.log("  - Register with DLP");
        console2.log("  - Configure blacklist if needed");
        console2.log("  - All VRC-20 features ready");
        
        console2.log("\nReady to deploy!");
    }
}