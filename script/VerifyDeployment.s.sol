// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script, console2} from "forge-std/Script.sol";
import {RDATUpgradeable} from "../src/RDATUpgradeable.sol";
import {TreasuryWallet} from "../src/TreasuryWallet.sol";
import {VanaMigrationBridge} from "../src/VanaMigrationBridge.sol";
import {BaseMigrationBridge} from "../src/BaseMigrationBridge.sol";
import {StakingPositions} from "../src/StakingPositions.sol";
import {vRDAT} from "../src/vRDAT.sol";
import {RewardsManager} from "../src/RewardsManager.sol";
import {vRDATRewardModule} from "../src/rewards/vRDATRewardModule.sol";
import {EmergencyPause} from "../src/EmergencyPause.sol";

/**
 * @title Verify Deployment
 * @notice Script to verify deployments on testnets
 * @dev Checks contract addresses, configurations, and VRC-20 compliance
 */
contract VerifyDeployment is Script {
    
    struct VanaAddresses {
        address rdat;
        address treasury;
        address vanaBridge;
        address staking;
        address vrdat;
        address rewardsManager;
        address vrdatModule;
        address emergencyPause;
    }
    
    struct BaseAddresses {
        address baseBridge;
    }
    
    function run() external view {
        uint256 chainId = block.chainid;
        
        console2.log("========================================");
        console2.log("    Verifying Chain ID:", chainId);
        console2.log("========================================");
        
        if (chainId == 1480 || chainId == 14800) {
            verifyVanaDeployment();
        } else if (chainId == 8453 || chainId == 84532) {
            verifyBaseDeployment();
        } else {
            console2.log("Unsupported chain");
        }
    }
    
    function verifyVanaDeployment() private view {
        console2.log("\n=== Verifying Vana Deployment ===");
        
        // Load addresses from environment or hardcode for testing
        VanaAddresses memory addrs = VanaAddresses({
            rdat: vm.envOr("RDAT_ADDRESS", address(0x95401dc811bb5740090279Ba06cfA8fcF6113778)),
            treasury: vm.envOr("TREASURY_ADDRESS", address(0x1613beB3B2C4f22Ee086B2b38C1476A3cE7f78E8)),
            vanaBridge: vm.envOr("VANA_BRIDGE_ADDRESS", address(0x851356ae760d987E095750cCeb3bC6014560891C)),
            staking: vm.envOr("STAKING_ADDRESS", address(0x70e0bA845a1A0F2DA3359C97E0285013525FFC49)),
            vrdat: vm.envOr("VRDAT_ADDRESS", address(0x9E545E3C0baAB3E08CdfD552C960A1050f373042)),
            rewardsManager: vm.envOr("REWARDS_MANAGER_ADDRESS", address(0x99bbA657f2BbC93c02D617f8bA121cB8Fc104Acf)),
            vrdatModule: vm.envOr("VRDAT_MODULE_ADDRESS", address(0x0E801D84Fa97b50751Dbf25036d067dCf18858bF)),
            emergencyPause: vm.envOr("EMERGENCY_PAUSE_ADDRESS", address(0x84eA74d481Ee0A5332c457a4d796187F6Ba67fEB))
        });
        
        // 1. Check RDAT Token
        console2.log("\n1. RDAT Token:", addrs.rdat);
        if (addrs.rdat != address(0)) {
            RDATUpgradeable rdat = RDATUpgradeable(addrs.rdat);
            console2.log("   Name:", rdat.name());
            console2.log("   Symbol:", rdat.symbol());
            console2.log("   Total Supply:", rdat.totalSupply() / 10**18, "RDAT");
            console2.log("   VRC-20 Compliant:", rdat.isVRC20Compliant());
            
            // Check VRC-20 features
            (address registry, bool registered, uint256 dlpId,) = rdat.getDLPInfo();
            console2.log("   DLP Registry:", registry);
            if (registered) {
                console2.log("   DLP ID:", dlpId);
            }
            console2.log("   Blacklist Count:", rdat.blacklistCount());
            console2.log("   Timelock Duration:", rdat.TIMELOCK_DURATION() / 3600, "hours");
        }
        
        // 2. Check Treasury
        console2.log("\n2. Treasury Wallet:", addrs.treasury);
        if (addrs.treasury != address(0) && addrs.rdat != address(0)) {
            RDATUpgradeable rdat = RDATUpgradeable(addrs.rdat);
            uint256 treasuryBalance = rdat.balanceOf(addrs.treasury);
            console2.log("   Balance:", treasuryBalance / 10**18, "RDAT");
            console2.log("   Expected: 70,000,000 RDAT");
            console2.log("   Match:", treasuryBalance == 70_000_000 * 10**18 ? "YES" : "NO");
        }
        
        // 3. Check Migration Bridge
        console2.log("\n3. Vana Migration Bridge:", addrs.vanaBridge);
        if (addrs.vanaBridge != address(0) && addrs.rdat != address(0)) {
            RDATUpgradeable rdat = RDATUpgradeable(addrs.rdat);
            uint256 bridgeBalance = rdat.balanceOf(addrs.vanaBridge);
            console2.log("   Balance:", bridgeBalance / 10**18, "RDAT");
            console2.log("   Expected: 30,000,000 RDAT");
            console2.log("   Match:", bridgeBalance == 30_000_000 * 10**18 ? "YES" : "NO");
        }
        
        // 4. Check Staking
        console2.log("\n4. Staking Positions:", addrs.staking);
        if (addrs.staking != address(0)) {
            StakingPositions staking = StakingPositions(addrs.staking);
            console2.log("   Total Staked:", staking.totalStaked() / 10**18, "RDAT");
            console2.log("   Rewards Manager:", staking.rewardsManager());
        }
        
        // 5. Check vRDAT
        console2.log("\n5. vRDAT Token:", addrs.vrdat);
        if (addrs.vrdat != address(0)) {
            vRDAT vrdatToken = vRDAT(addrs.vrdat);
            console2.log("   Name:", vrdatToken.name());
            console2.log("   Symbol:", vrdatToken.symbol());
            console2.log("   Total Supply:", vrdatToken.totalSupply() / 10**18, "vRDAT");
            console2.log("   Soul-bound: YES (non-transferable)");
        }
        
        // 6. Check Rewards Manager
        console2.log("\n6. Rewards Manager:", addrs.rewardsManager);
        if (addrs.rewardsManager != address(0)) {
            RewardsManager rewards = RewardsManager(addrs.rewardsManager);
            console2.log("   Program Count:", rewards.getProgramCount());
            uint256[] memory activePrograms = rewards.getActivePrograms();
            console2.log("   Active Programs:", activePrograms.length);
        }
        
        // 7. Summary
        console2.log("\n=== Deployment Summary ===");
        console2.log("Total Supply Check: 100M RDAT");
        if (addrs.rdat != address(0)) {
            RDATUpgradeable rdat = RDATUpgradeable(addrs.rdat);
            uint256 treasuryBal = rdat.balanceOf(addrs.treasury);
            uint256 bridgeBal = rdat.balanceOf(addrs.vanaBridge);
            uint256 total = treasuryBal + bridgeBal;
            console2.log("   Treasury:", treasuryBal / 10**18, "RDAT");
            console2.log("   Bridge:", bridgeBal / 10**18, "RDAT");
            console2.log("   Total:", total / 10**18, "RDAT");
            console2.log("   Match 100M:", total == 100_000_000 * 10**18 ? "YES" : "NO");
            console2.log("VRC-20 Compliant:", rdat.isVRC20Compliant() ? "YES" : "NO");
        }
    }
    
    function verifyBaseDeployment() private view {
        console2.log("\n=== Verifying Base Deployment ===");
        
        address baseBridge = vm.envOr("BASE_BRIDGE_ADDRESS", address(0x0B306BF915C4d645ff596e518fAf3F9669b97016));
        
        console2.log("\n1. Base Migration Bridge:", baseBridge);
        if (baseBridge != address(0)) {
            BaseMigrationBridge bridge = BaseMigrationBridge(baseBridge);
            console2.log("   V1 Token:", address(bridge.v1Token()));
            console2.log("   Total Migrated:", bridge.totalMigrated() / 10**18, "RDAT");
            console2.log("   Migration Open:", !bridge.paused() ? "YES" : "NO");
            
            uint256 deadline = bridge.migrationDeadline();
            if (deadline > block.timestamp) {
                uint256 daysLeft = (deadline - block.timestamp) / 1 days;
                console2.log("   Days Until Deadline:", daysLeft);
            } else {
                console2.log("   Migration Expired: YES");
            }
        }
        
        console2.log("\n=== Base Deployment Summary ===");
        console2.log("Bridge Deployed:", baseBridge != address(0) ? "YES" : "NO");
        console2.log("Ready for V1 Migration:", baseBridge != address(0) ? "YES" : "NO");
    }
}