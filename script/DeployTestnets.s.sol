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
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title Deploy to Testnets
 * @notice Comprehensive deployment script for all testnets with VRC-20 features
 * @dev Deploys full system to local, testnet, or mainnet environments
 */
contract DeployTestnets is Script {
    
    // Deployment artifacts
    struct DeploymentAddresses {
        address rdat;
        address treasury;
        address vanaBridge;
        address baseBridge;
        address staking;
        address vrdat;
        address rewardsManager;
        address vrdatModule;
        address emergencyPause;
    }
    
    function run() external {
        uint256 chainId = block.chainid;
        
        console2.log("========================================");
        console2.log("    Deploying to Chain ID:", chainId);
        console2.log("========================================");
        
        if (chainId == 1480 || chainId == 14800) {
            deployToVana();
        } else if (chainId == 8453 || chainId == 84532) {
            deployToBase();
        } else {
            revert("Unsupported chain");
        }
    }
    
    function deployToVana() internal {
        address admin = vm.envOr("ADMIN_ADDRESS", address(0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319));
        
        console2.log("\n=== Deploying Vana Chain Components ===");
        console2.log("Admin:", admin);
        
        vm.startBroadcast();
        
        // Deploy in smaller chunks to avoid stack too deep
        DeploymentAddresses memory addrs = _deployVanaCore(admin);
        _deployVanaStaking(addrs, admin);
        _configureVanaSystem(addrs);
        
        vm.stopBroadcast();
        
        console2.log("\n=== Vana Deployment Complete ===");
        console2.log("VRC-20 Compliant:", RDATUpgradeable(addrs.rdat).isVRC20Compliant());
    }
    
    function _deployVanaCore(address admin) private returns (DeploymentAddresses memory addrs) {
        // 1. Deploy Emergency Pause
        addrs.emergencyPause = address(new EmergencyPause(admin));
        console2.log("EmergencyPause:", addrs.emergencyPause);
        
        // 2. Deploy vRDAT
        addrs.vrdat = address(new vRDAT(admin));
        console2.log("vRDAT:", addrs.vrdat);
        
        // 3. Deploy Treasury (with temporary RDAT address, will be updated after RDAT deployment)
        TreasuryWallet treasuryImpl = new TreasuryWallet();
        ERC1967Proxy treasuryProxy = new ERC1967Proxy(
            address(treasuryImpl),
            abi.encodeWithSelector(TreasuryWallet.initialize.selector, admin, address(0x1)) // Temporary address
        );
        addrs.treasury = address(treasuryProxy);
        console2.log("TreasuryWallet:", addrs.treasury);
        
        // 4. Deploy Migration Bridge (with temporary V2 token address, will be updated after RDAT deployment)
        address[] memory validators = new address[](3);
        validators[0] = address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8); // Anvil account #1
        validators[1] = address(0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC); // Anvil account #2  
        validators[2] = address(0x90F79bf6EB2c4f870365E785982E1f101E93b906); // Anvil account #3
        addrs.vanaBridge = address(new VanaMigrationBridge(address(0x1), admin, validators)); // Temporary address
        console2.log("VanaMigrationBridge:", addrs.vanaBridge);
        
        // 5. Deploy RDAT
        RDATUpgradeable rdatImpl = new RDATUpgradeable();
        ERC1967Proxy rdatProxy = new ERC1967Proxy(
            address(rdatImpl),
            abi.encodeWithSelector(RDATUpgradeable.initialize.selector, addrs.treasury, admin, addrs.vanaBridge)
        );
        addrs.rdat = address(rdatProxy);
        console2.log("RDAT:", addrs.rdat);
        
        return addrs;
    }
    
    function _deployVanaStaking(DeploymentAddresses memory addrs, address admin) private {
        // 6. Deploy Staking
        StakingPositions stakingImpl = new StakingPositions();
        ERC1967Proxy stakingProxy = new ERC1967Proxy(
            address(stakingImpl),
            abi.encodeWithSelector(StakingPositions.initialize.selector, addrs.rdat, addrs.vrdat, admin)
        );
        addrs.staking = address(stakingProxy);
        console2.log("StakingPositions:", addrs.staking);
        
        // 7. Deploy RewardsManager (initialize with admin first, set staking later)
        RewardsManager rewardsImpl = new RewardsManager();
        ERC1967Proxy rewardsProxy = new ERC1967Proxy(
            address(rewardsImpl),
            abi.encodeWithSelector(RewardsManager.initialize.selector, addrs.staking, admin) // stakingManager, admin
        );
        addrs.rewardsManager = address(rewardsProxy);
        console2.log("RewardsManager:", addrs.rewardsManager);
        
        // 8. Deploy vRDAT Module
        addrs.vrdatModule = address(new vRDATRewardModule(
            addrs.vrdat,
            addrs.staking,
            addrs.rewardsManager,
            admin
        ));
        console2.log("vRDATRewardModule:", addrs.vrdatModule);
    }
    
    function _configureVanaSystem(DeploymentAddresses memory addrs) private {
        // Wire up components
        vRDAT(addrs.vrdat).grantRole(vRDAT(addrs.vrdat).MINTER_ROLE(), addrs.vrdatModule);
        
        // Now we can register the program (admin has PROGRAM_MANAGER_ROLE from initialization)
        RewardsManager(addrs.rewardsManager).registerProgram(
            addrs.vrdatModule,
            "vRDAT Governance Rewards",
            0, // Start immediately
            0  // Perpetual duration
        );
        
        StakingPositions(addrs.staking).setRewardsManager(addrs.rewardsManager);
        
        // Configure VRC-20 if registry provided
        address dlpRegistry = vm.envOr("DLP_REGISTRY", address(0));
        if (dlpRegistry != address(0)) {
            RDATUpgradeable(addrs.rdat).setDLPRegistry(dlpRegistry);
            uint256 dlpId = vm.envOr("DLP_ID", uint256(0));
            if (dlpId > 0) {
                RDATUpgradeable(addrs.rdat).updateDLPRegistration(dlpId);
            }
            console2.log("DLP Registry configured");
        }
    }
    
    function deployToBase() internal {
        address admin = vm.envOr("ADMIN_ADDRESS", address(0x90013583c66D2bf16327cB5Bc4a647AcceCF4B9A));
        
        console2.log("\n=== Deploying Base Chain Components ===");
        console2.log("Admin:", admin);
        
        vm.startBroadcast();
        
        // Deploy only migration bridge for Base (with placeholder V1 token address)
        BaseMigrationBridge baseBridge = new BaseMigrationBridge(
            address(0x1), // V1 token address (placeholder)
            admin
        );
        console2.log("BaseMigrationBridge:", address(baseBridge));
        
        vm.stopBroadcast();
        
        console2.log("\n=== Base Deployment Complete ===");
    }
}