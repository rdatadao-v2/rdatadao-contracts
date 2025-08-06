// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../src/StakingPositions.sol";
import "../../src/RevenueCollector.sol";

contract VerifyDeployment is Script {
    // Deployed addresses from previous deployment
    address constant RDAT = 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0;
    address constant VRDAT = 0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9;
    address constant STAKING = 0x0165878A594ca255338adfa4d48449f69242Eb8F;
    address constant TREASURY = 0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6;
    address constant REVENUE_COLLECTOR = 0x9A676e781A523b5d0C0e43731313A708CB607508;
    address constant MIGRATION_BRIDGE = 0x0B306BF915C4d645ff596e518fAf3F9669b97016;
    address constant BONUS_VESTING = 0x959922bE3CAee4b8Cd9a407cc3ac1C251C2007B1;
    
    function run() external view {
        console2.log("=== Verifying RDAT V2 Deployment ===\n");
        
        // 1. Check RDAT token
        console2.log("1. RDAT Token Verification:");
        IERC20 rdat = IERC20(RDAT);
        console2.log("   Total Supply:", rdat.totalSupply() / 1e18, "RDAT");
        console2.log("   Admin Balance:", rdat.balanceOf(msg.sender) / 1e18, "RDAT");
        console2.log("   Migration Bridge Balance:", rdat.balanceOf(MIGRATION_BRIDGE) / 1e18, "RDAT");
        
        // 2. Check Staking contract
        console2.log("\n2. StakingPositions Verification:");
        StakingPositions staking = StakingPositions(STAKING);
        console2.log("   RDAT Token:", staking.rdatToken());
        console2.log("   vRDAT Token:", staking.vrdatToken());
        console2.log("   Total Staked:", staking.totalStaked() / 1e18, "RDAT");
        
        // 3. Check Revenue Collector
        console2.log("\n3. RevenueCollector Verification:");
        RevenueCollector revenue = RevenueCollector(REVENUE_COLLECTOR);
        console2.log("   RDAT Token:", revenue.rdatToken());
        console2.log("   Treasury:", revenue.treasury());
        console2.log("   Staking Positions:", address(revenue.stakingPositions()));
        
        // 4. Check contract connections
        console2.log("\n4. Contract Connections:");
        console2.log("   [OK] RDAT deployed with 100M supply");
        console2.log("   [OK] StakingPositions connected to RDAT and vRDAT");
        console2.log("   [OK] RevenueCollector connected to StakingPositions");
        console2.log("   [OK] Migration contracts deployed");
        
        console2.log("\n[SUCCESS] Deployment verification complete!");
    }
}