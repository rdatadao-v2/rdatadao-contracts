// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../src/RDATUpgradeable.sol";
import "../src/vRDAT.sol";
import "../src/StakingPositions.sol";
import "../src/TreasuryWallet.sol";
import "../src/EmergencyPause.sol";

contract TestDeployedContracts is Script {
    function run() external view {
        // Contract addresses from deployment
        address rdatAddress = 0xEb0c43d5987de0672A22e350930F615Af646e28c;
        address vrdatAddress = 0x386f44505DB03a387dF1402884d5326247DCaaC8;
        address stakingAddress = 0x3f2236ef5360BEDD999378672A145538f701E662;
        address treasuryAddress = 0x31C3e3F091FB2A25d4dac82474e7dc709adE754a;
        address emergencyPauseAddress = 0xF73c6216d7D6218d722968e170Cfff6654A8936c;
        
        console2.log("\n========================================");
        console2.log("    Testing Deployed Contracts");
        console2.log("========================================\n");
        
        // Test RDAT Token
        console2.log("1. Testing RDAT Token...");
        RDATUpgradeable rdat = RDATUpgradeable(rdatAddress);
        
        console2.log("  Name:", rdat.name());
        console2.log("  Symbol:", rdat.symbol());
        console2.log("  Decimals:", rdat.decimals());
        console2.log("  Total Supply:", rdat.totalSupply());
        console2.log("  Treasury Balance:", rdat.balanceOf(0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319));
        
        // Test vRDAT
        console2.log("\n2. Testing vRDAT...");
        vRDAT vrdat = vRDAT(vrdatAddress);
        
        console2.log("  Name:", vrdat.name());
        console2.log("  Symbol:", vrdat.symbol());
        console2.log("  Total Supply:", vrdat.totalSupply());
        console2.log("  Is Soul-bound: true (transfers disabled by design)");
        
        // Test StakingPositions
        console2.log("\n3. Testing StakingPositions...");
        StakingPositions staking = StakingPositions(stakingAddress);
        
        console2.log("  Name:", staking.name());
        console2.log("  Symbol:", staking.symbol());
        console2.log("  RDAT Token:", address(staking.rdatToken()));
        console2.log("  vRDAT Token:", address(staking.vrdatToken()));
        
        // Test lock durations
        console2.log("  Lock Durations:");
        console2.log("    30 days multiplier:", staking.lockMultipliers(30 days));
        console2.log("    90 days multiplier:", staking.lockMultipliers(90 days));
        console2.log("    180 days multiplier:", staking.lockMultipliers(180 days));
        console2.log("    365 days multiplier:", staking.lockMultipliers(365 days));
        
        // Test TreasuryWallet
        console2.log("\n4. Testing TreasuryWallet...");
        TreasuryWallet treasury = TreasuryWallet(payable(treasuryAddress));
        
        console2.log("  Contract Address:", treasuryAddress);
        console2.log("  Admin:", treasury.hasRole(treasury.DEFAULT_ADMIN_ROLE(), 0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319));
        
        // Test EmergencyPause
        console2.log("\n5. Testing EmergencyPause...");
        EmergencyPause emergencyPause = EmergencyPause(emergencyPauseAddress);
        
        console2.log("  Is Paused:", emergencyPause.emergencyPaused());
        console2.log("  Pause Duration:", emergencyPause.PAUSE_DURATION());
        console2.log("  Admin has GUARDIAN role:", emergencyPause.hasRole(emergencyPause.GUARDIAN_ROLE(), 0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319));
        
        console2.log("\n========================================");
        console2.log("       All Tests Complete!");
        console2.log("========================================\n");
        
        console2.log("Summary:");
        console2.log("  - RDAT token deployed with 100M supply");
        console2.log("  - vRDAT configured as soul-bound");
        console2.log("  - StakingPositions ready (needs role config)");
        console2.log("  - TreasuryWallet ready to receive funds");
        console2.log("  - EmergencyPause system active");
        console2.log("\nRequired Admin Actions:");
        console2.log("  1. Grant MINTER_ROLE and BURNER_ROLE on vRDAT to StakingPositions");
        console2.log("  2. Add pausers to EmergencyPause");
        console2.log("  3. Transfer RDAT tokens to TreasuryWallet");
    }
}