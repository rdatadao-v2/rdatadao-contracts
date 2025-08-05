// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BaseDeployScript} from "../shared/BaseDeployScript.sol";
import {console2} from "forge-std/console2.sol";

/**
 * @title DeployRDATWithVesting
 * @notice Deploys RDAT token with vesting contract per DAO vote
 * @dev Implements the approved tokenomics:
 * - Total Supply: 100M RDAT
 * - Migration Reserve: 30M (100% at TGE)
 * - Future Rewards: 30M (locked until Phase 3)
 * - Treasury: 25M (10% at TGE, 6-month cliff, 5% monthly)
 * - Liquidity: 15M (33% at TGE, rest for staking)
 */
contract DeployRDATWithVesting is BaseDeployScript {
    // Contract addresses (to be deployed)
    address public rdatToken;
    address public vestingContract;
    
    // Allocation addresses (configure these before deployment)
    address public migrationReserve = address(0x1); // TODO: Set actual address
    address public futureRewards = address(0x2);    // TODO: Set actual address
    // Treasury is set in parent BaseDeployScript
    address public liquidityPool = address(0x4);    // TODO: Set actual address
    
    function deploy() internal override {
        console2.log("=== Deploying RDAT with DAO-approved tokenomics ===");
        console2.log("Total Supply: 100,000,000 RDAT");
        
        // Step 1: Deploy RDAT token
        // TODO: Import and deploy actual RDAT contract
        // rdatToken = address(new Rdat(...));
        
        console2.log("RDAT Token deployed at:", rdatToken);
        
        // Step 2: Deploy vesting contract
        // TODO: Import RDATVesting
        // vestingContract = address(new RDATVesting(rdatToken));
        
        console2.log("Vesting Contract deployed at:", vestingContract);
        
        // Step 3: Mint tokens according to allocation
        console2.log("\n=== Token Distribution ===");
        
        // Migration Reserve: 30M (direct to migration contract)
        console2.log("Migration Reserve: 30,000,000 RDAT");
        console2.log("  Address:", migrationReserve);
        console2.log("  Vesting: None (100% at TGE)");
        
        // Future Rewards: 30M (to vesting contract)
        console2.log("\nFuture Rewards: 30,000,000 RDAT");
        console2.log("  Address:", futureRewards);
        console2.log("  Vesting: Locked until Phase 3");
        
        // Treasury: 25M (to vesting contract)
        console2.log("\nTreasury & Ecosystem: 25,000,000 RDAT");
        console2.log("  Address:", treasury);
        console2.log("  Vesting: 10% at TGE, 6-month cliff, 5% monthly");
        
        // Liquidity: 15M (to vesting contract)
        console2.log("\nLiquidity & Staking: 15,000,000 RDAT");
        console2.log("  Address:", liquidityPool);
        console2.log("  Vesting: 33% at TGE, remainder for staking");
        
        // Step 4: Set up vesting schedules
        console2.log("\n=== Setting up Vesting Schedules ===");
        // TODO: Call vestingContract.setupDAOVesting(...)
        
        // Step 5: Transfer ownership to multi-sig
        console2.log("\n=== Finalizing Deployment ===");
        console2.log("TODO: Transfer ownership to DAO multi-sig");
        console2.log("TODO: Renounce minting capability");
        
        // Summary
        console2.log("\n=== Deployment Summary ===");
        console2.log("Chain:", block.chainid);
        console2.log("RDAT Token:", rdatToken);
        console2.log("Vesting Contract:", vestingContract);
        console2.log("Total Supply: 100,000,000 RDAT");
        console2.log("\nIMPORTANT: Update allocation addresses before mainnet deployment!");
    }
}