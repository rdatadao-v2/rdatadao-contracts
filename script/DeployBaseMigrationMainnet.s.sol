// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script, console2} from "forge-std/Script.sol";
import {BaseMigrationBridge} from "../src/BaseMigrationBridge.sol";

contract DeployBaseMigrationMainnet is Script {
    // RDAT V1 on Base Mainnet
    address constant RDAT_V1 = 0x4498cd8Ba045E00673402353f5a4347562707e7D;

    function run() external returns (address) {
        // Get admin from environment
        address admin = vm.envAddress("BASE_MULTISIG_ADDRESS");
        require(admin != address(0), "BASE_MULTISIG_ADDRESS not set");

        console2.log("========================================");
        console2.log("BASE MAINNET - Migration Bridge Deployment");
        console2.log("========================================");
        console2.log("RDAT V1 Token:", RDAT_V1);
        console2.log("Admin:", admin);
        console2.log("");

        vm.startBroadcast();

        // Deploy BaseMigrationBridge
        BaseMigrationBridge bridge = new BaseMigrationBridge(RDAT_V1, admin);

        console2.log("BaseMigrationBridge deployed at:", address(bridge));

        vm.stopBroadcast();

        console2.log("");
        console2.log("========================================");
        console2.log("DEPLOYMENT COMPLETE");
        console2.log("========================================");

        return address(bridge);
    }
}
