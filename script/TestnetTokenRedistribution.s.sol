// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script, console2} from "forge-std/Script.sol";
import {RDATUpgradeable} from "../src/RDATUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title TestnetTokenRedistribution
 * @notice Remediation script to redistribute RDAT tokens on testnet from multisig to proper contracts
 * @dev Current state: Multisig has 100M tokens
 *      Target state: Treasury has 70M, Migration has 30M, Multisig has 0
 */
contract TestnetTokenRedistribution is Script {
    // Deployed testnet addresses (Vana Moksha)
    address constant RDAT_TOKEN = 0xEb0c43d5987de0672A22e350930F615Af646e28c;
    address constant TREASURY_WALLET = 0x31C3e3F091FB2A25d4dac82474e7dc709adE754a;
    address constant MULTISIG = 0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319;

    // Deployed migration bridge address
    address constant MIGRATION_BRIDGE = 0xdCa8b322c11515A3B5e6e806170b573bDe179328;

    // Token distribution
    uint256 constant TREASURY_ALLOCATION = 70_000_000e18;
    uint256 constant MIGRATION_ALLOCATION = 30_000_000e18;

    function run() external {
        console2.log("========================================");
        console2.log("TESTNET TOKEN REDISTRIBUTION");
        console2.log("========================================");
        console2.log("Chain:", block.chainid == 14800 ? "Vana Moksha" : "Unknown");
        console2.log("");

        IERC20 rdat = IERC20(RDAT_TOKEN);

        // Check current state
        uint256 multisigBalance = rdat.balanceOf(MULTISIG);
        uint256 treasuryBalance = rdat.balanceOf(TREASURY_WALLET);

        console2.log("Current Distribution:");
        console2.log("  Multisig:", multisigBalance / 1e18, "RDAT");
        console2.log("  Treasury:", treasuryBalance / 1e18, "RDAT");
        console2.log("");

        require(multisigBalance == 100_000_000e18, "Unexpected multisig balance");
        require(treasuryBalance == 0, "Treasury already has tokens");

        console2.log("Target Distribution:");
        console2.log("  Treasury: 70M RDAT");
        console2.log("  Migration: 30M RDAT");
        console2.log("  Multisig: 0 RDAT");
        console2.log("");

        // NOTE: This needs to be executed from the multisig wallet
        console2.log("WARNING: This script must be executed by the multisig!");
        console2.log("The following transactions need to be executed:");
        console2.log("");
        console2.log("1. Transfer 70M RDAT to TreasuryWallet:");
        console2.log("   rdat.transfer(TREASURY_WALLET, TREASURY_ALLOCATION)");
        console2.log("");
        console2.log("2. Transfer 30M RDAT to Migration Bridge:");
        console2.log("   rdat.transfer(MIGRATION_BRIDGE, MIGRATION_ALLOCATION)");
        console2.log("   Bridge Address:", MIGRATION_BRIDGE);
        console2.log("");

        // If running with broadcast (only works if sender is multisig)
        if (msg.sender == MULTISIG) {
            console2.log("[OK] Executing redistribution from multisig...");

            vm.startBroadcast();

            // Transfer to Treasury
            bool success1 = rdat.transfer(TREASURY_WALLET, TREASURY_ALLOCATION);
            require(success1, "Treasury transfer failed");
            console2.log("  [OK] Transferred 70M to Treasury");

            // Transfer to Migration Bridge
            bool success2 = rdat.transfer(MIGRATION_BRIDGE, MIGRATION_ALLOCATION);
            require(success2, "Migration transfer failed");
            console2.log("  [OK] Transferred 30M to Migration Bridge");

            vm.stopBroadcast();

            // Verify final state
            console2.log("");
            console2.log("Final Distribution:");
            console2.log("  Multisig:", rdat.balanceOf(MULTISIG) / 1e18, "RDAT");
            console2.log("  Treasury:", rdat.balanceOf(TREASURY_WALLET) / 1e18, "RDAT");
            console2.log("  Migration:", rdat.balanceOf(MIGRATION_BRIDGE) / 1e18, "RDAT");
        } else {
            console2.log("[ERROR] Not executing - sender is not multisig");
            console2.log("   Current sender:", msg.sender);
        }
    }

    /**
     * @notice Generate the transaction data for multisig execution
     */
    function generateTransactionData() external pure {
        console2.log("========================================");
        console2.log("MULTISIG TRANSACTION DATA");
        console2.log("========================================");
        console2.log("");
        console2.log("Transaction 1 - Transfer to Treasury:");
        console2.log("To:", RDAT_TOKEN);
        console2.log("Value: 0");
        console2.log("Data:");
        bytes memory transferData1 =
            abi.encodeWithSignature("transfer(address,uint256)", TREASURY_WALLET, TREASURY_ALLOCATION);
        console2.logBytes(transferData1);
        console2.log("");

        console2.log("Transaction 2 - Transfer to Migration Bridge:");
        console2.log("To:", RDAT_TOKEN);
        console2.log("Value: 0");
        console2.log("Data:");
        bytes memory transferData2 =
            abi.encodeWithSignature("transfer(address,uint256)", MIGRATION_BRIDGE, MIGRATION_ALLOCATION);
        console2.logBytes(transferData2);
        console2.log("");

        console2.log("Alternative: Use cast commands");
        console2.log("cast send", RDAT_TOKEN);
        console2.log("  'transfer(address,uint256)'");
        console2.log("  ", TREASURY_WALLET);
        console2.log("  ", TREASURY_ALLOCATION);
        console2.log("  --rpc-url https://rpc.moksha.vana.org");
        console2.log("  --private-key <MULTISIG_KEY>");
    }

    /**
     * @notice Check current token distribution
     */
    function checkDistribution() external view {
        IERC20 rdat = IERC20(RDAT_TOKEN);

        console2.log("========================================");
        console2.log("CURRENT TOKEN DISTRIBUTION");
        console2.log("========================================");
        console2.log("Chain:", block.chainid == 14800 ? "Vana Moksha" : "Unknown");
        console2.log("");

        uint256 totalSupply = rdat.totalSupply();
        uint256 multisigBalance = rdat.balanceOf(MULTISIG);
        uint256 treasuryBalance = rdat.balanceOf(TREASURY_WALLET);

        console2.log("Total Supply:", totalSupply / 1e18, "RDAT");
        console2.log("");
        console2.log("Balances:");
        console2.log("  Multisig:", multisigBalance / 1e18, "RDAT");
        console2.log("  Treasury:", treasuryBalance / 1e18, "RDAT");
        console2.log("");

        if (multisigBalance == 100_000_000e18) {
            console2.log("[ERROR] INCORRECT: All tokens are in multisig!");
            console2.log("   Need to redistribute to proper contracts");
        } else if (treasuryBalance == 70_000_000e18 && multisigBalance == 30_000_000e18) {
            console2.log("[WARNING] PARTIAL: Treasury funded, awaiting migration bridge");
        } else if (treasuryBalance == 70_000_000e18 && multisigBalance == 0) {
            uint256 bridgeBalance = rdat.balanceOf(MIGRATION_BRIDGE);
            console2.log("  Migration:", bridgeBalance / 1e18, "RDAT");
            if (bridgeBalance == 30_000_000e18) {
                console2.log("[OK] CORRECT: Tokens properly distributed");
            } else {
                console2.log("[WARNING] Migration bridge has incorrect balance");
            }
        } else {
            console2.log("[WARNING] UNKNOWN STATE");
        }
    }
}
