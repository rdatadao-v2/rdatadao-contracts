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

        // Setup validators
        address[] memory validators = new address[](3);
        validators[0] = 0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319; // Multisig (admin)
        validators[1] = 0x58eCB94e6F5e6521228316b55c465ad2A2938FbB; // Deployer
        validators[2] = 0xC9Af4E56741f255743e8f4877d4cfa9971E910C2; // Additional validator

        // Deploy the migration bridge with validators
        VanaMigrationBridge bridge = new VanaMigrationBridge(rdatToken, admin, validators);
        bridgeAddress = address(bridge);

        console2.log("[OK] VanaMigrationBridge deployed at:", bridgeAddress);
        console2.log("[OK] Initialized with validators:");
        for (uint256 i = 0; i < validators.length; i++) {
            console2.log("   -", validators[i]);
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

        IERC20 rdat = IERC20(rdatToken);

        console2.log("========================================");
        console2.log("MIGRATION BRIDGE STATUS");
        console2.log("========================================");
        console2.log("Bridge Address:", bridgeAddress);
        console2.log("RDAT Token:", rdatToken);
        console2.log("");

        // Check balance
        uint256 balance = rdat.balanceOf(bridgeAddress);

        console2.log("Token Status:");
        console2.log("  Current Balance:", balance / 1e18, "RDAT");
        console2.log("");

        if (balance == 0) {
            console2.log("[ERROR] Bridge not funded!");
        } else if (balance == MIGRATION_ALLOCATION) {
            console2.log("[OK] Bridge properly funded and ready");
        } else {
            console2.log("[WARNING] Bridge has unexpected balance:", balance / 1e18, "RDAT");
        }
    }
}
