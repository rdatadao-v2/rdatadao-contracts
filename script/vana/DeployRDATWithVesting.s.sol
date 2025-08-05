// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BaseDeployScript} from "../shared/BaseDeployScript.sol";
import {console} from "forge-std/console.sol";

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
    address public treasury = address(0x3);         // TODO: Set actual address
    address public liquidityPool = address(0x4);    // TODO: Set actual address
    
    function deploy() internal override {
        console.log("=== Deploying RDAT with DAO-approved tokenomics ===");
        console.log("Total Supply: 100,000,000 RDAT");
        
        // Step 1: Deploy RDAT token
        // TODO: Import and deploy actual RDAT contract
        // rdatToken = address(new Rdat(...));
        
        console.log("RDAT Token deployed at:", rdatToken);
        
        // Step 2: Deploy vesting contract
        // TODO: Import RDATVesting
        // vestingContract = address(new RDATVesting(rdatToken));
        
        console.log("Vesting Contract deployed at:", vestingContract);
        
        // Step 3: Mint tokens according to allocation
        console.log("\n=== Token Distribution ===");
        
        // Migration Reserve: 30M (direct to migration contract)
        console.log("Migration Reserve: 30,000,000 RDAT");
        console.log("  Address:", migrationReserve);
        console.log("  Vesting: None (100% at TGE)");
        
        // Future Rewards: 30M (to vesting contract)
        console.log("\nFuture Rewards: 30,000,000 RDAT");
        console.log("  Address:", futureRewards);
        console.log("  Vesting: Locked until Phase 3");
        
        // Treasury: 25M (to vesting contract)
        console.log("\nTreasury & Ecosystem: 25,000,000 RDAT");
        console.log("  Address:", treasury);
        console.log("  Vesting: 10% at TGE, 6-month cliff, 5% monthly");
        
        // Liquidity: 15M (to vesting contract)
        console.log("\nLiquidity & Staking: 15,000,000 RDAT");
        console.log("  Address:", liquidityPool);
        console.log("  Vesting: 33% at TGE, remainder for staking");
        
        // Step 4: Set up vesting schedules
        console.log("\n=== Setting up Vesting Schedules ===");
        // TODO: Call vestingContract.setupDAOVesting(...)
        
        // Step 5: Transfer ownership to multi-sig
        console.log("\n=== Finalizing Deployment ===");
        console.log("TODO: Transfer ownership to DAO multi-sig");
        console.log("TODO: Renounce minting capability");
        
        // Summary
        console.log("\n=== Deployment Summary ===");
        console.log("Chain:", block.chainid);
        console.log("RDAT Token:", rdatToken);
        console.log("Vesting Contract:", vestingContract);
        console.log("Total Supply: 100,000,000 RDAT");
        console.log("\nIMPORTANT: Update allocation addresses before mainnet deployment!");
    }
}