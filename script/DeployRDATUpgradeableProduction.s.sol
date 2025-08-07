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
 * @notice Production deployment script using structs to avoid stack too deep
 * @dev Correctly distributes 100M tokens: 70M to Treasury, 30M to Migration
 */
contract DeployRDATUpgradeableProduction is Script {
    // Token distribution constants
    uint256 constant TOTAL_SUPPLY = 100_000_000e18;
    uint256 constant TREASURY_ALLOCATION = 70_000_000e18;
    uint256 constant MIGRATION_ALLOCATION = 30_000_000e18;

    // Deployment configuration struct
    struct DeploymentConfig {
        address multisig;
        address deployer;
        uint256 chainId;
    }

    // Deployment addresses struct
    struct DeploymentResult {
        address rdatProxy;
        address treasuryProxy;
        address migrationBridge;
        address factory;
    }

    function run() external returns (DeploymentResult memory result) {
        // Load configuration
        DeploymentConfig memory config = DeploymentConfig({
            multisig: vm.envAddress("ADMIN_ADDRESS"),
            deployer: msg.sender,
            chainId: block.chainid
        });

        require(config.multisig != address(0), "ADMIN_ADDRESS not set");

        console2.log("========================================");
        console2.log("PRODUCTION DEPLOYMENT - RDAT V2");
        console2.log("========================================");
        console2.log("Chain ID:", config.chainId);
        console2.log("Deployer:", config.deployer);
        console2.log("Multisig:", config.multisig);
        console2.log("");

        vm.startBroadcast();

        // Deploy using helper function to avoid stack too deep
        result = _deploySystem(config);

        vm.stopBroadcast();

        // Verify deployment
        _verifyDeployment(result, config);

        return result;
    }

    function _deploySystem(DeploymentConfig memory config) internal returns (DeploymentResult memory result) {
        // Step 1: Deploy CREATE2 Factory
        Create2Factory factory = new Create2Factory();
        result.factory = address(factory);
        console2.log("\n[1/4] CREATE2 Factory deployed:", result.factory);

        // Step 2: Deploy Treasury
        result.treasuryProxy = _deployTreasury(config);
        console2.log("[2/4] TreasuryWallet deployed:", result.treasuryProxy);

        // Step 3: Deploy Migration Bridge  
        result.migrationBridge = _deployMigrationBridge(config);
        console2.log("[3/4] VanaMigrationBridge deployed:", result.migrationBridge);

        // Step 4: Deploy RDAT with Treasury and Migration addresses
        result.rdatProxy = _deployRDAT(config, result.treasuryProxy, result.migrationBridge);
        console2.log("[4/4] RDAT Token deployed:", result.rdatProxy);

        return result;
    }

    function _deployTreasury(DeploymentConfig memory config) internal returns (address) {
        TreasuryWallet treasuryImpl = new TreasuryWallet();
        
        // Deploy proxy (uninitialized initially)
        ERC1967Proxy treasuryProxy = new ERC1967Proxy(address(treasuryImpl), "");
        
        return address(treasuryProxy);
    }

    function _deployMigrationBridge(DeploymentConfig memory config) internal returns (address) {
        address[] memory validators = new address[](1);
        validators[0] = config.multisig;
        
        // Deploy with placeholder address, will be updated later
        VanaMigrationBridge bridge = new VanaMigrationBridge(
            address(1), // Placeholder - will be updated
            config.multisig,
            validators
        );
        
        return address(bridge);
    }

    function _deployRDAT(
        DeploymentConfig memory config, 
        address treasury, 
        address migration
    ) internal returns (address) {
        RDATUpgradeable rdatImpl = new RDATUpgradeable();
        
        bytes memory initData = abi.encodeWithSelector(
            RDATUpgradeable.initialize.selector,
            treasury,
            config.multisig,
            migration
        );
        
        ERC1967Proxy rdatProxy = new ERC1967Proxy(address(rdatImpl), initData);
        
        // Now initialize treasury with RDAT address
        TreasuryWallet(payable(treasury)).initialize(config.multisig, address(rdatProxy));
        
        return address(rdatProxy);
    }

    function _verifyDeployment(DeploymentResult memory result, DeploymentConfig memory config) internal view {
        console2.log("\n========================================");
        console2.log("DEPLOYMENT VERIFICATION");
        console2.log("========================================");

        RDATUpgradeable rdat = RDATUpgradeable(result.rdatProxy);
        console2.log("Total Supply:", rdat.totalSupply() / 1e18, "RDAT");
        console2.log("Treasury Balance:", rdat.balanceOf(result.treasuryProxy) / 1e18, "RDAT");
        console2.log("Migration Balance:", rdat.balanceOf(result.migrationBridge) / 1e18, "RDAT");
        console2.log("Multisig Balance:", rdat.balanceOf(config.multisig) / 1e18, "RDAT");

        // Verify distribution
        require(rdat.totalSupply() == TOTAL_SUPPLY, "Invalid total supply");
        require(rdat.balanceOf(result.treasuryProxy) == TREASURY_ALLOCATION, "Invalid treasury allocation");
        require(rdat.balanceOf(result.migrationBridge) == MIGRATION_ALLOCATION, "Invalid migration allocation");
        require(rdat.balanceOf(config.multisig) == 0, "Multisig should have 0 balance");

        console2.log("\n[OK] Deployment successful and verified!");
        console2.log("========================================");
    }

    function dryRun() external view {
        DeploymentConfig memory config = DeploymentConfig({
            multisig: vm.envOr("ADMIN_ADDRESS", address(0)),
            deployer: vm.envOr("DEPLOYER_ADDRESS", msg.sender),
            chainId: block.chainid
        });

        console2.log("========================================");
        console2.log("DRY RUN - PRODUCTION DEPLOYMENT");
        console2.log("========================================");
        console2.log("Chain ID:", config.chainId);
        console2.log("Deployer:", config.deployer);
        console2.log("Multisig:", config.multisig);

        if (config.multisig == address(0)) {
            console2.log("\n[ERROR] ADMIN_ADDRESS not set!");
            return;
        }

        console2.log("\n========================================");
        console2.log("Token Distribution Plan:");
        console2.log("  70M RDAT -> TreasuryWallet contract");
        console2.log("  30M RDAT -> VanaMigrationBridge contract");
        console2.log("  0 RDAT -> Multisig (correct!)");
        console2.log("========================================");
    }
}