// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script, console2} from "forge-std/Script.sol";

/**
 * @title Deployment Overview for RDAT V2
 * @notice Shows what contracts get deployed to which networks
 */
contract DeploymentOverview is Script {
    function run() external view {
        console2.log("=== RDAT V2 Multi-Chain Deployment Strategy ===\n");
        
        console2.log("PROJECT TYPE: Vana-native token project");
        console2.log("V1 TOKEN: Currently on Base mainnet");
        console2.log("V2 TOKEN: Will live on Vana network\n");
        
        console2.log("--- BASE NETWORKS (V1 Location) ---");
        console2.log("Base Mainnet (8453):");
        console2.log("  [X] MigrationBridge - Burns V1 RDAT tokens");
        console2.log("  [ ] RDAT V2 Token - NOT DEPLOYED HERE");
        console2.log("  [ ] Other V2 contracts - NOT DEPLOYED HERE");
        console2.log("");
        console2.log("Base Sepolia (84532):");
        console2.log("  [X] MigrationBridge - For testing migration flow");
        console2.log("  [X] MockRDAT - Simulates V1 token for testing");
        console2.log("  [ ] RDAT V2 Token - NOT DEPLOYED HERE");
        console2.log("");
        
        console2.log("--- VANA NETWORKS (V2 Home) ---");
        console2.log("Vana Mainnet (1480):");
        console2.log("  [X] RDAT V2 Token (Upgradeable)");
        console2.log("  [X] vRDAT (Soul-bound governance token)");
        console2.log("  [X] Staking Contract");
        console2.log("  [X] Revenue Collector");
        console2.log("  [X] Migration Bridge (Vana side)");
        console2.log("  [X] Proof of Contribution");
        console2.log("  [X] Emergency Pause System");
        console2.log("");
        console2.log("Vana Moksha Testnet (14800):");
        console2.log("  [X] All V2 contracts for testing");
        console2.log("");
        
        console2.log("--- MIGRATION FLOW ---");
        console2.log("1. User approves MigrationBridge on Base");
        console2.log("2. MigrationBridge burns V1 RDAT on Base");
        console2.log("3. Event emitted with burn proof");
        console2.log("4. Validators confirm burn on Vana");
        console2.log("5. User claims V2 RDAT on Vana (1:1 + bonus)");
        console2.log("");
        
        console2.log("--- KEY ADDRESSES ---");
        console2.log("Deployer: 0x58eCB94e6F5e6521228316b55c465ad2A2938FbB");
        console2.log("Base Treasury: 0x90013583c66D2bf16327cB5Bc4a647AcceCF4B9A");
        console2.log("Vana Treasury: 0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319");
        console2.log("V1 RDAT on Base: 0x4498cd8Ba045E00673402353f5a4347562707e7D");
    }
}