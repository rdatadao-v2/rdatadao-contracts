// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/BaseMigrationBridge.sol";

contract TestMigration is Script {
    address constant V1_TOKEN = 0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E;
    address constant MIGRATION_BRIDGE = 0xb7d6f8eadfD4415cb27686959f010771FE94561b;
    
    // Test accounts with V1 tokens
    address constant TEST_ACCOUNT_1 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address constant TEST_ACCOUNT_2 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    address constant TEST_ACCOUNT_3 = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
    
    function run() external {
        console2.log("\n========================================");
        console2.log("    Testing V1 -> V2 Migration Flow");
        console2.log("========================================\n");
        
        // Check current state
        IERC20 v1Token = IERC20(V1_TOKEN);
        BaseMigrationBridge bridge = BaseMigrationBridge(MIGRATION_BRIDGE);
        
        console2.log("Base Sepolia Setup:");
        console2.log("  V1 Token:", V1_TOKEN);
        console2.log("  Migration Bridge:", MIGRATION_BRIDGE);
        console2.log("");
        
        console2.log("Test Account Balances:");
        uint256 balance1 = v1Token.balanceOf(TEST_ACCOUNT_1);
        uint256 balance2 = v1Token.balanceOf(TEST_ACCOUNT_2);
        uint256 balance3 = v1Token.balanceOf(TEST_ACCOUNT_3);
        
        console2.log("  Account 1:", TEST_ACCOUNT_1);
        console2.log("    Balance:", balance1 / 1e18, "RDAT V1");
        console2.log("  Account 2:", TEST_ACCOUNT_2);
        console2.log("    Balance:", balance2 / 1e18, "RDAT V1");
        console2.log("  Account 3:", TEST_ACCOUNT_3);
        console2.log("    Balance:", balance3 / 1e18, "RDAT V1");
        console2.log("");
        
        console2.log("Bridge Statistics:");
        console2.log("  Total Migrated:", bridge.totalMigrated() / 1e18, "RDAT");
        console2.log("  Bridge is Paused:", bridge.paused());
        console2.log("");
        
        console2.log("Migration Process:");
        console2.log("  1. User approves bridge to spend V1 tokens");
        console2.log("  2. User calls migrate(amount) on bridge");
        console2.log("  3. Bridge locks V1 tokens and emits event");
        console2.log("  4. Oracle detects event and triggers V2 distribution on Vana");
        console2.log("  5. User receives V2 tokens on Vana network");
        console2.log("");
        
        console2.log("To test migration:");
        console2.log("  1. Get test ETH from Base Sepolia faucet");
        console2.log("  2. Import test account private key to wallet");
        console2.log("  3. Approve bridge contract for V1 tokens");
        console2.log("  4. Call migrate() with desired amount");
        console2.log("  5. Check for V2 tokens on Vana Moksha");
    }
    
    function checkMigration(address user) external view {
        BaseMigrationBridge bridge = BaseMigrationBridge(MIGRATION_BRIDGE);
        
        uint256 migrated = bridge.userBurnedAmounts(user);
        if (migrated > 0) {
            console2.log("User has migrated:", migrated / 1e18, "RDAT");
            console2.log("  Address:", user);
        } else {
            console2.log("User has not migrated yet:", user);
        }
    }
}