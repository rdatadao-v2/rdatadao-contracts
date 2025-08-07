// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script, console2} from "forge-std/Script.sol";
import {RDATUpgradeable} from "../src/RDATUpgradeable.sol";
import {TreasuryWallet} from "../src/TreasuryWallet.sol";
import {VanaMigrationBridge} from "../src/VanaMigrationBridge.sol";
import {Create2Factory} from "../src/Create2Factory.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title DeployRDATUpgradeableProduction
 * @notice Production deployment script that correctly distributes 100M tokens:
 *         - 70M to TreasuryWallet contract
 *         - 30M to VanaMigrationBridge contract
 *         - 0 to multisig directly
 * @dev This fixes the issue in DeployRDATUpgradeableSimple where all tokens went to multisig
 */
contract DeployRDATUpgradeableProduction is Script {
    // Token distribution constants
    uint256 constant TOTAL_SUPPLY = 100_000_000e18;
    uint256 constant TREASURY_ALLOCATION = 70_000_000e18;
    uint256 constant MIGRATION_ALLOCATION = 30_000_000e18;
    
    function run() external returns (address rdatProxy, address treasuryProxy, address migrationBridge) {
        // Load deployment parameters
        address multisig = vm.envAddress("ADMIN_ADDRESS");
        address deployer = msg.sender;
        
        require(multisig != address(0), "ADMIN_ADDRESS not set");
        
        console2.log("========================================");
        console2.log("PRODUCTION DEPLOYMENT - RDAT V2");
        console2.log("========================================");
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", deployer);
        console2.log("Multisig:", multisig);
        console2.log("");
        console2.log("Token Distribution:");
        console2.log("  Total Supply: 100M RDAT");
        console2.log("  Treasury: 70M RDAT");
        console2.log("  Migration: 30M RDAT");
        console2.log("========================================");
        
        vm.startBroadcast();
        
        // Step 1: Deploy CREATE2 Factory
        Create2Factory factory = new Create2Factory();
        console2.log("\n[1/5] CREATE2 Factory deployed:", address(factory));
        
        // Step 2: Calculate future RDAT address using CREATE2
        // This is needed because Treasury and Migration contracts need to know RDAT address
        bytes32 salt = keccak256(abi.encodePacked("RDAT_V2_", block.chainid));
        
        // Prepare RDAT implementation deployment bytecode
        bytes memory rdatImplementationBytecode = type(RDATUpgradeable).creationCode;
        address predictedRDATImpl = factory.computeAddress(salt, keccak256(rdatImplementationBytecode));
        
        // We'll deploy proxy later, but we know its address will be deterministic
        // For now, we'll deploy in order and use the actual addresses
        
        // Step 3: Deploy TreasuryWallet (needs RDAT address, but we'll set it later)
        TreasuryWallet treasuryImpl = new TreasuryWallet();
        bytes memory treasuryInitData = abi.encodeWithSelector(
            TreasuryWallet.initialize.selector,
            address(0), // Will be set to RDAT address later
            multisig
        );
        
        ERC1967Proxy treasuryProxyContract = new ERC1967Proxy(
            address(treasuryImpl),
            treasuryInitData
        );
        treasuryProxy = address(treasuryProxyContract);
        console2.log("[2/5] TreasuryWallet deployed:", treasuryProxy);
        
        // Step 4: Deploy VanaMigrationBridge
        VanaMigrationBridge bridge = new VanaMigrationBridge(
            address(0), // Will be set to RDAT address later
            multisig
        );
        migrationBridge = address(bridge);
        console2.log("[3/5] VanaMigrationBridge deployed:", migrationBridge);
        
        // Step 5: Deploy RDAT implementation
        RDATUpgradeable rdatImpl = new RDATUpgradeable();
        console2.log("[4/5] RDAT Implementation deployed:", address(rdatImpl));
        
        // Step 6: Deploy RDAT proxy with proper initialization
        // The initialize function will mint tokens to treasury and migration contracts
        bytes memory rdatInitData = abi.encodeWithSelector(
            RDATUpgradeable.initialize.selector,
            treasuryProxy,      // 70M tokens go here
            multisig,           // Admin role
            migrationBridge     // 30M tokens go here
        );
        
        ERC1967Proxy rdatProxyContract = new ERC1967Proxy(
            address(rdatImpl),
            rdatInitData
        );
        rdatProxy = address(rdatProxyContract);
        console2.log("[5/5] RDAT Token deployed:", rdatProxy);
        
        // Step 7: Update Treasury and Migration contracts with RDAT address
        TreasuryWallet(treasuryProxy).setRDATToken(rdatProxy);
        VanaMigrationBridge(migrationBridge).setRDATToken(rdatProxy);
        
        vm.stopBroadcast();
        
        // Verify deployment
        console2.log("\n========================================");
        console2.log("DEPLOYMENT VERIFICATION");
        console2.log("========================================");
        
        RDATUpgradeable rdat = RDATUpgradeable(rdatProxy);
        console2.log("Total Supply:", rdat.totalSupply() / 1e18, "RDAT");
        console2.log("Treasury Balance:", rdat.balanceOf(treasuryProxy) / 1e18, "RDAT");
        console2.log("Migration Balance:", rdat.balanceOf(migrationBridge) / 1e18, "RDAT");
        console2.log("Multisig Balance:", rdat.balanceOf(multisig) / 1e18, "RDAT");
        
        // Verify roles
        console2.log("\nRole Verification:");
        console2.log("Multisig has DEFAULT_ADMIN_ROLE:", rdat.hasRole(rdat.DEFAULT_ADMIN_ROLE(), multisig));
        console2.log("Multisig has PAUSER_ROLE:", rdat.hasRole(rdat.PAUSER_ROLE(), multisig));
        
        // Verify distribution
        require(rdat.totalSupply() == TOTAL_SUPPLY, "Invalid total supply");
        require(rdat.balanceOf(treasuryProxy) == TREASURY_ALLOCATION, "Invalid treasury allocation");
        require(rdat.balanceOf(migrationBridge) == MIGRATION_ALLOCATION, "Invalid migration allocation");
        require(rdat.balanceOf(multisig) == 0, "Multisig should have 0 balance");
        
        console2.log("\n[OK] Deployment successful and verified!");
        console2.log("========================================");
        
        return (rdatProxy, treasuryProxy, migrationBridge);
    }
    
    /**
     * @notice Dry run to simulate deployment and check requirements
     */
    function dryRun() external view {
        address multisig = vm.envOr("ADMIN_ADDRESS", address(0));
        address deployer = vm.envOr("DEPLOYER_ADDRESS", msg.sender);
        
        console2.log("========================================");
        console2.log("DRY RUN - PRODUCTION DEPLOYMENT");
        console2.log("========================================");
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", deployer);
        console2.log("Multisig:", multisig);
        
        if (multisig == address(0)) {
            console2.log("\n[ERROR] ERROR: ADMIN_ADDRESS not set!");
            return;
        }
        
        // Check deployer balance
        uint256 deployerBalance = deployer.balance;
        console2.log("\nDeployer Balance:", deployerBalance);
        
        if (deployerBalance < 0.1 ether) {
            console2.log("[WARNING]  WARNING: Low deployer balance, may not have enough for gas");
        }
        
        // Calculate deployment addresses
        uint256 currentNonce = vm.getNonce(deployer);
        console2.log("\nCurrent Nonce:", currentNonce);
        
        console2.log("\nPredicted Addresses:");
        console2.log("  CREATE2 Factory:", vm.computeCreateAddress(deployer, currentNonce));
        console2.log("  Treasury Impl:", vm.computeCreateAddress(deployer, currentNonce + 1));
        console2.log("  Treasury Proxy:", vm.computeCreateAddress(deployer, currentNonce + 2));
        console2.log("  Migration Bridge:", vm.computeCreateAddress(deployer, currentNonce + 3));
        console2.log("  RDAT Impl:", vm.computeCreateAddress(deployer, currentNonce + 4));
        console2.log("  RDAT Proxy:", vm.computeCreateAddress(deployer, currentNonce + 5));
        
        // Estimate gas costs
        console2.log("\nEstimated Gas Requirements:");
        console2.log("  CREATE2 Factory: ~400k gas");
        console2.log("  Treasury: ~2M gas");
        console2.log("  Migration: ~1.5M gas");
        console2.log("  RDAT: ~4M gas");
        console2.log("  Total: ~8M gas");
        
        uint256 estimatedCost = 8_000_000 * 50 gwei;
        console2.log("\nEstimated Cost at 50 gwei:", estimatedCost / 1e18, "ETH");
        
        if (deployerBalance < estimatedCost) {
            console2.log("[ERROR] Insufficient balance for deployment!");
        } else {
            console2.log("[OK] Sufficient balance for deployment");
        }
        
        console2.log("\n========================================");
        console2.log("Token Distribution Plan:");
        console2.log("  70M RDAT → TreasuryWallet contract");
        console2.log("  30M RDAT → VanaMigrationBridge contract");
        console2.log("  0 RDAT → Multisig (correct!)");
        console2.log("========================================");
    }
}