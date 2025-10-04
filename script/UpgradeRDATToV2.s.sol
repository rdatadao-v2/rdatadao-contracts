// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script, console2} from "forge-std/Script.sol";
import {RDATUpgradeableV2} from "../src/RDATUpgradeableV2.sol";
import {RDATUpgradeable} from "../src/RDATUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title UpgradeRDATToV2
 * @notice Deploys RDATUpgradeableV2 and provides upgrade instructions
 * @dev This script:
 *      1. Deploys the V2 implementation
 *      2. Outputs the upgrade call data for multisig execution
 */
contract UpgradeRDATToV2 is Script {
    // Vana Mainnet addresses
    address constant RDAT_PROXY = 0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E;
    address constant VANA_MULTISIG = 0xe4F7Eca807C57311e715C3Ef483e72Fa8D5bCcDF;
    address constant OLD_BRIDGE = 0x9d4aB2d3fb25D414dba1d9D22200356b5984D35E;
    address constant NEW_BRIDGE = 0xEb0c43d5987de0672A22e350930F615Af646e28c;

    function run() external {
        uint256 chainId = block.chainid;
        require(chainId == 1480, "Must run on Vana mainnet");

        console2.log("========================================");
        console2.log("RDAT V2 UPGRADE - RESCUE 30M RDAT");
        console2.log("========================================");
        console2.log("Chain ID:", chainId);
        console2.log("RDAT Proxy:", RDAT_PROXY);
        console2.log("Multisig:", VANA_MULTISIG);
        console2.log("");

        vm.startBroadcast();

        // Step 1: Deploy V2 implementation
        RDATUpgradeableV2 v2Implementation = new RDATUpgradeableV2();
        console2.log("[1/3] V2 Implementation deployed:", address(v2Implementation));

        vm.stopBroadcast();

        // Step 2: Generate upgrade call data
        bytes memory upgradeCallData = abi.encodeWithSignature(
            "upgradeToAndCall(address,bytes)",
            address(v2Implementation),
            "" // No initialization data needed
        );

        console2.log("\n[2/3] Upgrade Call Data (for multisig):");
        console2.log("Target:", RDAT_PROXY);
        console2.log("Call Data:", vm.toString(upgradeCallData));

        // Step 3: Generate rescue call data
        bytes memory rescueCallData = abi.encodeWithSelector(
            RDATUpgradeableV2.rescueBrokenBridgeFunds.selector
        );

        console2.log("\n[3/3] Rescue Call Data (after upgrade):");
        console2.log("Target:", RDAT_PROXY);
        console2.log("Call Data:", vm.toString(rescueCallData));

        // Step 4: Verify addresses
        console2.log("\n========================================");
        console2.log("VERIFICATION");
        console2.log("========================================");
        console2.log("Old Bridge (source):", OLD_BRIDGE);
        console2.log("New Bridge (destination):", NEW_BRIDGE);

        // Check old bridge balance
        uint256 oldBridgeBalance = RDATUpgradeable(RDAT_PROXY).balanceOf(OLD_BRIDGE);
        console2.log("Old Bridge Balance:", oldBridgeBalance / 1e18, "RDAT");

        // Check new bridge balance
        uint256 newBridgeBalance = RDATUpgradeable(RDAT_PROXY).balanceOf(NEW_BRIDGE);
        console2.log("New Bridge Balance:", newBridgeBalance / 1e18, "RDAT");

        console2.log("\n========================================");
        console2.log("NEXT STEPS");
        console2.log("========================================");
        console2.log("1. Execute upgrade transaction from multisig");
        console2.log("2. Wait for confirmation");
        console2.log("3. Execute rescue transaction from multisig");
        console2.log("4. Verify 30M RDAT transferred to new bridge");
        console2.log("========================================");
    }

    function dryRun() external view {
        console2.log("========================================");
        console2.log("DRY RUN - RDAT V2 UPGRADE");
        console2.log("========================================");
        console2.log("Chain ID:", block.chainid);
        console2.log("");
        console2.log("Will rescue:", RDATUpgradeable(RDAT_PROXY).balanceOf(OLD_BRIDGE) / 1e18, "RDAT");
        console2.log("From:", OLD_BRIDGE);
        console2.log("To:", NEW_BRIDGE);
        console2.log("========================================");
    }
}
