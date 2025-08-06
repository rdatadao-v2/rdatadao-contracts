// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {VanaMigrationBridge} from "../src/VanaMigrationBridge.sol";
import {MigrationBonusVesting} from "../src/MigrationBonusVesting.sol";
import {RDATUpgradeable} from "../src/RDATUpgradeable.sol";
import {TreasuryWallet} from "../src/TreasuryWallet.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title DeployMigrationWithVesting
 * @notice Deployment script showing how to set up migration with bonus vesting
 * @dev This demonstrates the complete setup including funding sources
 */
contract DeployMigrationWithVesting is Script {
    // Addresses (update for your deployment)
    address public admin;
    address public treasuryWallet;
    address public rdatToken;
    address public validator1;
    address public validator2; 
    address public validator3;
    
    // Allocations
    uint256 public constant MIGRATION_ALLOCATION = 30_000_000e18; // From migration reserve
    uint256 public constant BONUS_ALLOCATION = 2_000_000e18; // From liquidity & staking (for bonuses)
    
    function run() external {
        // Load environment variables
        admin = vm.envAddress("ADMIN_ADDRESS");
        treasuryWallet = vm.envAddress("TREASURY_WALLET_ADDRESS");
        rdatToken = vm.envAddress("RDAT_TOKEN_ADDRESS");
        validator1 = vm.envAddress("VALIDATOR_1_ADDRESS");
        validator2 = vm.envAddress("VALIDATOR_2_ADDRESS");
        validator3 = vm.envAddress("VALIDATOR_3_ADDRESS");
        
        vm.startBroadcast();
        
        // 1. Deploy VanaMigrationBridge with validators
        address[] memory validators = new address[](3);
        validators[0] = validator1;
        validators[1] = validator2;
        validators[2] = validator3;
        
        VanaMigrationBridge migrationBridge = new VanaMigrationBridge(
            rdatToken,
            admin,
            validators
        );
        console2.log("VanaMigrationBridge deployed at:", address(migrationBridge));
        
        // 2. Deploy MigrationBonusVesting contract
        MigrationBonusVesting bonusVesting = new MigrationBonusVesting(
            rdatToken,
            admin
        );
        console2.log("MigrationBonusVesting deployed at:", address(bonusVesting));
        
        // 3. Configure bonus vesting to accept grants from migration bridge
        bonusVesting.setMigrationBridge(address(migrationBridge));
        console2.log("Migration bridge authorized on vesting contract");
        
        // 4. Configure migration bridge to use bonus vesting
        migrationBridge.setBonusVesting(address(bonusVesting));
        console2.log("Bonus vesting configured on migration bridge");
        
        // 5. Fund the contracts from TreasuryWallet
        // Note: In production, this would require DAO approval or admin action
        
        // Transfer migration allocation (1:1 exchange)
        console2.log("\nFunding migration bridge with 30M RDAT for 1:1 exchange...");
        // TreasuryWallet(treasuryWallet).distribute(
        //     address(migrationBridge), 
        //     MIGRATION_ALLOCATION,
        //     "Migration reserve allocation"
        // );
        
        // Transfer bonus allocation to vesting contract
        console2.log("Funding bonus vesting with 2M RDAT from staking incentives...");
        // TreasuryWallet(treasuryWallet).distribute(
        //     address(bonusVesting),
        //     BONUS_ALLOCATION,
        //     "Migration bonus incentives from liquidity & staking allocation"
        // );
        
        // 6. Verify setup
        console2.log("\n=== Deployment Summary ===");
        console2.log("VanaMigrationBridge:", address(migrationBridge));
        console2.log("MigrationBonusVesting:", address(bonusVesting));
        console2.log("Migration allocation:", MIGRATION_ALLOCATION / 1e18, "RDAT");
        console2.log("Bonus allocation:", BONUS_ALLOCATION / 1e18, "RDAT");
        console2.log("Validators:", validators.length);
        
        // Calculate maximum possible bonuses
        uint256 maxBonusRate = migrationBridge.WEEK_1_2_BONUS(); // 5%
        uint256 maxPossibleBonus = (MIGRATION_ALLOCATION * maxBonusRate) / 10000;
        console2.log("\nMax possible bonus (if all migrate in week 1-2):", maxPossibleBonus / 1e18, "RDAT");
        console2.log("Bonus allocation covers:", (BONUS_ALLOCATION * 100) / maxPossibleBonus, "% of max scenario");
        
        vm.stopBroadcast();
    }
    
    /**
     * @notice Dry run to preview the deployment
     */
    function dryRun() external view {
        console2.log("=== Migration Deployment Plan ===");
        console2.log("\n1. Deploy VanaMigrationBridge");
        console2.log("   - 30M RDAT allocation for 1:1 exchange");
        console2.log("   - 3 validators for consensus");
        console2.log("   - 6-hour challenge period");
        console2.log("   - 300K daily limit");
        
        console2.log("\n2. Deploy MigrationBonusVesting");
        console2.log("   - 12-month linear vesting for bonuses");
        console2.log("   - No cliff period");
        console2.log("   - Automatic beneficiary management");
        
        console2.log("\n3. Fund contracts from TreasuryWallet");
        console2.log("   - 30M RDAT to migration bridge (migration reserve)");
        console2.log("   - 2M RDAT to bonus vesting (liquidity & staking allocation)");
        
        console2.log("\n4. Bonus structure:");
        console2.log("   - Week 1-2: 5% bonus (vested over 12 months)");
        console2.log("   - Week 3-4: 3% bonus (vested over 12 months)");
        console2.log("   - Week 5-8: 1% bonus (vested over 12 months)");
        console2.log("   - After week 8: No bonus");
        
        console2.log("\nNote: Bonus allocation of 2M RDAT assumes ~13% migration in first 2 weeks");
    }
}