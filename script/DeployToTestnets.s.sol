// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script, console2} from "forge-std/Script.sol";
import {RDATUpgradeable} from "../src/RDATUpgradeable.sol";
import {StakingPositions} from "../src/StakingPositions.sol";
import {vRDAT} from "../src/vRDAT.sol";
import {EmergencyPause} from "../src/EmergencyPause.sol";
import {RewardsManager} from "../src/RewardsManager.sol";
import {vRDATRewardModule} from "../src/rewards/vRDATRewardModule.sol";
import {RevenueCollector} from "../src/RevenueCollector.sol";
import {TreasuryWallet} from "../src/TreasuryWallet.sol";
import {TokenVesting} from "../src/TokenVesting.sol";
import {VanaMigrationBridge} from "../src/VanaMigrationBridge.sol";
import {MigrationBonusVesting} from "../src/MigrationBonusVesting.sol";
import {ProofOfContributionStub} from "../src/ProofOfContributionStub.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title DeployToTestnets
 * @notice Deployment script for Vana Moksha and Base Sepolia testnets
 * @dev Run with appropriate environment variables set
 */
contract DeployToTestnets is Script {
    // Deployment addresses
    RDATUpgradeable public rdat;
    StakingPositions public staking;
    vRDAT public vrdat;
    EmergencyPause public emergencyPause;
    RewardsManager public rewardsManager;
    vRDATRewardModule public vrdatModule;
    RevenueCollector public revenueCollector;
    TreasuryWallet public treasury;
    TokenVesting public vesting;
    VanaMigrationBridge public migrationBridge;
    MigrationBonusVesting public bonusVesting;
    ProofOfContributionStub public proofOfContribution;
    
    // Configuration based on chain
    function getChainConfig() internal view returns (
        address admin,
        address treasuryAddr,
        string memory chainName
    ) {
        uint256 chainId = block.chainid;
        
        if (chainId == 14800) { // Vana Moksha
            admin = 0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319;
            treasuryAddr = 0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319;
            chainName = "Vana Moksha Testnet";
        } else if (chainId == 84532) { // Base Sepolia
            admin = 0x90013583c66D2bf16327cB5Bc4a647AcceCF4B9A;
            treasuryAddr = 0x90013583c66D2bf16327cB5Bc4a647AcceCF4B9A;
            chainName = "Base Sepolia Testnet";
        } else if (chainId == 1480) { // Vana Mainnet (for future)
            admin = 0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319;
            treasuryAddr = 0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319;
            chainName = "Vana Mainnet";
        } else if (chainId == 8453) { // Base Mainnet (for future)
            admin = 0x90013583c66D2bf16327cB5Bc4a647AcceCF4B9A;
            treasuryAddr = 0x90013583c66D2bf16327cB5Bc4a647AcceCF4B9A;
            chainName = "Base Mainnet";
        } else {
            revert("Unsupported chain ID");
        }
    }
    
    function run() external {
        (address admin, address treasuryAddr, string memory chainName) = getChainConfig();
        
        console2.log("\n========================================");
        console2.log("Deploying RDAT V2 to", chainName);
        console2.log("========================================");
        console2.log("Chain ID:", block.chainid);
        console2.log("Admin:", admin);
        console2.log("Treasury:", treasuryAddr);
        console2.log("Deployer:", msg.sender);
        
        vm.startBroadcast();
        
        // Phase 1: Core Infrastructure
        console2.log("\n=== Phase 1: Core Infrastructure ===");
        deployCore(admin, treasuryAddr);
        
        // Phase 2: Financial Contracts
        console2.log("\n=== Phase 2: Financial Contracts ===");
        deployFinancial(admin, treasuryAddr);
        
        // Phase 3: Rewards System
        console2.log("\n=== Phase 3: Rewards System ===");
        deployRewards(admin);
        
        // Phase 4: Migration Infrastructure
        console2.log("\n=== Phase 4: Migration Infrastructure ===");
        deployMigration(admin);
        
        // Phase 5: System Configuration
        console2.log("\n=== Phase 5: System Configuration ===");
        configureSystem(admin);
        
        // Phase 6: Verification
        console2.log("\n=== Phase 6: Deployment Verification ===");
        verifyDeployment(admin, treasuryAddr);
        
        vm.stopBroadcast();
        
        // Output summary
        outputDeploymentSummary(chainName);
    }
    
    function deployCore(address admin, address treasuryAddr) internal {
        // 1. Deploy EmergencyPause
        emergencyPause = new EmergencyPause(admin);
        console2.log("EmergencyPause:", address(emergencyPause));
        
        // 2. Deploy ProofOfContribution stub
        // Using a dummy DLP address for the stub
        address dlpAddress = address(0x1234567890123456789012345678901234567890);
        proofOfContribution = new ProofOfContributionStub(admin, dlpAddress);
        console2.log("ProofOfContribution:", address(proofOfContribution));
        
        // 3. Predict RDAT address to handle circular dependency
        // Calculate where RDAT proxy will be deployed
        uint256 currentNonce = vm.getNonce(address(this));
        // Skip nonces for: migrationBridge, bonusVesting, rdatImpl
        address predictedRdatAddress = vm.computeCreateAddress(address(this), currentNonce + 3);
        console2.log("Predicted RDAT address:", predictedRdatAddress);
        
        // 4. Deploy migration contracts with predicted RDAT address
        address[] memory validators = new address[](3); // Need at least 3 validators
        validators[0] = admin;
        validators[1] = address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8); // Test validator 2
        validators[2] = address(0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC); // Test validator 3
        
        migrationBridge = new VanaMigrationBridge(
            predictedRdatAddress,
            admin,
            validators
        );
        console2.log("MigrationBridge:", address(migrationBridge));
        
        bonusVesting = new MigrationBonusVesting(predictedRdatAddress, admin);
        console2.log("MigrationBonusVesting:", address(bonusVesting));
        
        // 5. Deploy RDAT Token (upgradeable) at predicted address
        RDATUpgradeable rdatImpl = new RDATUpgradeable();
        bytes memory rdatInitData = abi.encodeWithSelector(
            RDATUpgradeable.initialize.selector,
            treasuryAddr,
            admin,
            address(migrationBridge)
        );
        ERC1967Proxy rdatProxy = new ERC1967Proxy(address(rdatImpl), rdatInitData);
        rdat = RDATUpgradeable(address(rdatProxy));
        console2.log("RDAT Token:", address(rdat));
        console2.log("  Total Supply:", rdat.totalSupply() / 1e18, "RDAT");
        
        // Verify RDAT was deployed at predicted address
        require(address(rdat) == predictedRdatAddress, "RDAT address mismatch");
        
        // Set bonus vesting in migration bridge
        migrationBridge.setBonusVesting(address(bonusVesting));
        
        // 5. Deploy vRDAT
        vrdat = new vRDAT(admin);
        console2.log("vRDAT:", address(vrdat));
        
        // 6. Deploy StakingPositions
        StakingPositions stakingImpl = new StakingPositions();
        bytes memory stakingInitData = abi.encodeWithSelector(
            StakingPositions.initialize.selector,
            address(rdat),
            address(vrdat),
            admin,
            address(emergencyPause)
        );
        ERC1967Proxy stakingProxy = new ERC1967Proxy(address(stakingImpl), stakingInitData);
        staking = StakingPositions(address(stakingProxy));
        console2.log("StakingPositions:", address(staking));
    }
    
    function deployFinancial(address admin, address treasuryAddr) internal {
        // Deploy TreasuryWallet
        TreasuryWallet treasuryImpl = new TreasuryWallet();
        bytes memory treasuryInitData = abi.encodeWithSelector(
            TreasuryWallet.initialize.selector,
            admin,
            address(rdat)
        );
        ERC1967Proxy treasuryProxy = new ERC1967Proxy(address(treasuryImpl), treasuryInitData);
        treasury = TreasuryWallet(payable(address(treasuryProxy)));
        console2.log("TreasuryWallet:", address(treasury));
        
        // Deploy TokenVesting
        vesting = new TokenVesting(address(rdat), admin);
        console2.log("TokenVesting:", address(vesting));
        
        // Deploy RevenueCollector
        RevenueCollector revenueImpl = new RevenueCollector();
        bytes memory revenueInitData = abi.encodeWithSelector(
            RevenueCollector.initialize.selector,
            address(staking),
            treasuryAddr,
            treasuryAddr, // Using treasury as contributor pool for testnet
            admin
        );
        ERC1967Proxy revenueProxy = new ERC1967Proxy(address(revenueImpl), revenueInitData);
        revenueCollector = RevenueCollector(address(revenueProxy));
        console2.log("RevenueCollector:", address(revenueCollector));
    }
    
    function deployRewards(address admin) internal {
        // Deploy RewardsManager
        RewardsManager rewardsImpl = new RewardsManager();
        bytes memory rewardsInitData = abi.encodeWithSelector(
            RewardsManager.initialize.selector,
            address(staking),
            admin
        );
        ERC1967Proxy rewardsProxy = new ERC1967Proxy(address(rewardsImpl), rewardsInitData);
        rewardsManager = RewardsManager(address(rewardsProxy));
        console2.log("RewardsManager:", address(rewardsManager));
        
        // Deploy vRDATRewardModule
        vrdatModule = new vRDATRewardModule(
            address(vrdat),
            address(staking),
            address(rewardsManager),
            admin
        );
        console2.log("vRDATRewardModule:", address(vrdatModule));
    }
    
    function deployMigration(address) internal {
        // Migration bridge already deployed in core
        console2.log("MigrationBonusVesting:", address(bonusVesting));
        
        // Configure bonus vesting
        bonusVesting.setMigrationBridge(address(migrationBridge));
        migrationBridge.setBonusVesting(address(bonusVesting));
    }
    
    function configureSystem(address admin) internal {
        // Grant necessary roles
        vrdat.grantRole(vrdat.MINTER_ROLE(), address(staking));
        vrdat.grantRole(vrdat.MINTER_ROLE(), address(vrdatModule));
        console2.log("Granted MINTER_ROLE to StakingPositions and vRDATRewardModule");
        
        // Connect contracts
        staking.setRewardsManager(address(rewardsManager));
        revenueCollector.setRewardsManager(address(rewardsManager));
        console2.log("Connected RewardsManager to StakingPositions and RevenueCollector");
        
        // Register vRDAT reward program
        uint256 vrdatProgramId = rewardsManager.registerProgram(
            address(vrdatModule),
            "vRDAT Rewards",
            block.timestamp,
            365 days * 10 // 10 year duration
        );
        console2.log("Registered vRDAT reward program with ID:", vrdatProgramId);
        
        // Grant revenue reporter role
        revenueCollector.grantRole(revenueCollector.REVENUE_REPORTER_ROLE(), admin);
        console2.log("Granted REVENUE_REPORTER_ROLE to admin");
    }
    
    function verifyDeployment(address admin, address) internal view {
        require(rdat.totalSupply() == 100_000_000e18, "Total supply mismatch");
        require(rdat.balanceOf(address(migrationBridge)) == 30_000_000e18, "Migration allocation mismatch");
        require(rdat.hasRole(rdat.DEFAULT_ADMIN_ROLE(), admin), "Admin role not set");
        require(staking.rdatToken() == address(rdat), "RDAT token not set in staking");
        require(staking.vrdatToken() == address(vrdat), "vRDAT token not set in staking");
        require(vrdat.hasRole(vrdat.MINTER_ROLE(), address(staking)), "Staking cannot mint vRDAT");
        
        console2.log("[SUCCESS] All deployment checks passed!");
    }
    
    function outputDeploymentSummary(string memory chainName) internal view {
        console2.log("\n========================================");
        console2.log("DEPLOYMENT SUMMARY -", chainName);
        console2.log("========================================");
        console2.log("\nCore Contracts:");
        console2.log("  RDAT Token:", address(rdat));
        console2.log("  vRDAT Token:", address(vrdat));
        console2.log("  StakingPositions:", address(staking));
        console2.log("  EmergencyPause:", address(emergencyPause));
        
        console2.log("\nFinancial Contracts:");
        console2.log("  TreasuryWallet:", address(treasury));
        console2.log("  TokenVesting:", address(vesting));
        console2.log("  RevenueCollector:", address(revenueCollector));
        
        console2.log("\nRewards System:");
        console2.log("  RewardsManager:", address(rewardsManager));
        console2.log("  vRDATRewardModule:", address(vrdatModule));
        
        console2.log("\nMigration:");
        console2.log("  VanaMigrationBridge:", address(migrationBridge));
        console2.log("  MigrationBonusVesting:", address(bonusVesting));
        
        console2.log("\nCompliance:");
        console2.log("  ProofOfContribution:", address(proofOfContribution));
        
        console2.log("\n[SUCCESS] Deployment complete!");
    }
}