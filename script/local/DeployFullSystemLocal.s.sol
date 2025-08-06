// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../../src/RDATUpgradeable.sol";
import "../../src/vRDAT.sol";
import "../../src/StakingPositions.sol";
import "../../src/EmergencyPause.sol";
import "../../src/TreasuryWallet.sol";
import "../../src/TokenVesting.sol";
import "../../src/VanaMigrationBridge.sol";
import "../../src/MigrationBonusVesting.sol";
import "../../src/RevenueCollector.sol";
import "../../src/RewardsManager.sol";
import "../../src/rewards/vRDATRewardModule.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployFullSystemLocal is Script {
    // Core contracts
    RDATUpgradeable public rdat;
    vRDAT public vrdat;
    StakingPositions public staking;
    EmergencyPause public emergencyPause;
    
    // Financial contracts
    TreasuryWallet public treasury;
    TokenVesting public vesting;
    RevenueCollector public revenueCollector;
    
    // Rewards contracts
    RewardsManager public rewardsManager;
    vRDATRewardModule public vrdatModule;
    
    // Migration contracts
    VanaMigrationBridge public migrationBridge;
    MigrationBonusVesting public bonusVesting;
    
    // Configuration
    address public admin;
    address public treasuryAddr;
    uint256 public vrdatProgramId;
    
    function run() external {
        admin = vm.envOr("ADMIN_ADDRESS", address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266));
        treasuryAddr = vm.envOr("TREASURY_ADDRESS", address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266));
        
        console2.log("=== Deploying Full RDAT V2 System to Local Chain ===");
        console2.log("Admin:", admin);
        console2.log("Treasury:", treasuryAddr);
        console2.log("Chain ID:", block.chainid);
        
        vm.startBroadcast();
        
        // Deploy in phases to avoid stack too deep
        deployMigrationFirst(); // Deploy migration bridge first to get its address
        deployCore();
        deployFinancial();
        deployRewards();
        configureSystem();
        transferAllocations();
        
        vm.stopBroadcast();
        
        printSummary();
    }
    
    function deployMigrationFirst() internal {
        console2.log("\n=== Phase 0: Migration Bridge (needed for RDAT init) ===");
        
        // Deploy VanaMigrationBridge first since RDAT needs its address
        console2.log("Pre-calculating migration bridge address...");
        
        // For local testing, we'll use a dummy RDAT address initially
        address dummyRdat = address(0x1111111111111111111111111111111111111111);
        
        address[] memory validators = new address[](3);
        validators[0] = admin;
        validators[1] = address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8); // Anvil account 2
        validators[2] = address(0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC); // Anvil account 3
        
        migrationBridge = new VanaMigrationBridge(
            dummyRdat, // Will be updated later
            admin,
            validators
        );
        console2.log("   VanaMigrationBridge:", address(migrationBridge));
        
        // Deploy bonus vesting too
        bonusVesting = new MigrationBonusVesting(dummyRdat, admin); // Will be updated later
        console2.log("   MigrationBonusVesting:", address(bonusVesting));
    }
    
    function deployCore() internal {
        console2.log("\n=== Phase 1: Core Contracts ===");
        
        // 1. Deploy EmergencyPause
        console2.log("Deploying EmergencyPause...");
        emergencyPause = new EmergencyPause(admin);
        console2.log("   EmergencyPause:", address(emergencyPause));
        
        // 2. Deploy RDAT (upgradeable) - now we have the migration bridge address
        console2.log("Deploying RDAT Token...");
        RDATUpgradeable rdatImpl = new RDATUpgradeable();
        
        bytes memory rdatInitData = abi.encodeWithSelector(
            RDATUpgradeable.initialize.selector,
            treasuryAddr,
            admin,
            address(migrationBridge) // Use actual migration bridge address
        );
        ERC1967Proxy rdatProxy = new ERC1967Proxy(address(rdatImpl), rdatInitData);
        rdat = RDATUpgradeable(address(rdatProxy));
        console2.log("   RDAT Proxy:", address(rdat));
        console2.log("   Total Supply:", rdat.totalSupply() / 1e18, "RDAT");
        
        // 3. Deploy vRDAT
        console2.log("Deploying vRDAT...");
        vrdat = new vRDAT(admin);
        console2.log("   vRDAT:", address(vrdat));
        
        // 4. Deploy StakingPositions
        console2.log("Deploying StakingPositions...");
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
        console2.log("   StakingPositions:", address(staking));
    }
    
    function deployFinancial() internal {
        console2.log("\n=== Phase 2: Financial Contracts ===");
        
        // 5. Deploy TreasuryWallet
        console2.log("Deploying TreasuryWallet...");
        TreasuryWallet treasuryImpl = new TreasuryWallet();
        bytes memory treasuryInitData = abi.encodeWithSelector(
            TreasuryWallet.initialize.selector,
            admin,
            address(rdat)
        );
        ERC1967Proxy treasuryProxy = new ERC1967Proxy(address(treasuryImpl), treasuryInitData);
        treasury = TreasuryWallet(payable(address(treasuryProxy)));
        console2.log("   TreasuryWallet:", address(treasury));
        
        // 6. Deploy TokenVesting
        console2.log("Deploying TokenVesting...");
        vesting = new TokenVesting(address(rdat), admin);
        console2.log("   TokenVesting:", address(vesting));
        
        // 7. Deploy RevenueCollector
        console2.log("Deploying RevenueCollector...");
        RevenueCollector revenueImpl = new RevenueCollector();
        bytes memory revenueInitData = abi.encodeWithSelector(
            RevenueCollector.initialize.selector,
            address(staking),
            treasuryAddr,
            treasuryAddr, // Using treasury as contributor pool for testing
            admin
        );
        ERC1967Proxy revenueProxy = new ERC1967Proxy(address(revenueImpl), revenueInitData);
        revenueCollector = RevenueCollector(address(revenueProxy));
        console2.log("   RevenueCollector:", address(revenueCollector));
    }
    
    function deployRewards() internal {
        console2.log("\n=== Phase 3: Rewards System ===");
        
        // 8. Deploy RewardsManager
        console2.log("Deploying RewardsManager...");
        RewardsManager rewardsImpl = new RewardsManager();
        bytes memory rewardsInitData = abi.encodeWithSelector(
            RewardsManager.initialize.selector,
            address(staking),
            admin
        );
        ERC1967Proxy rewardsProxy = new ERC1967Proxy(address(rewardsImpl), rewardsInitData);
        rewardsManager = RewardsManager(address(rewardsProxy));
        console2.log("   RewardsManager:", address(rewardsManager));
        
        // 9. Deploy vRDATRewardModule
        console2.log("Deploying vRDATRewardModule...");
        vrdatModule = new vRDATRewardModule(
            address(vrdat),
            address(staking),
            address(rewardsManager),
            admin
        );
        console2.log("   vRDATRewardModule:", address(vrdatModule));
    }
    
    function configureSystem() internal {
        console2.log("\n=== Phase 4: System Configuration ===");
        
        // Update migration contracts with actual RDAT address
        console2.log("Updating migration contracts with RDAT address...");
        migrationBridge.setV2Token(address(rdat));
        bonusVesting.setRewardToken(address(rdat));
        console2.log("Updated migration contracts");
        
        // Grant necessary roles
        vrdat.grantRole(vrdat.MINTER_ROLE(), address(staking));
        console2.log("Granted MINTER_ROLE to StakingPositions");
        
        vrdat.grantRole(vrdat.MINTER_ROLE(), address(vrdatModule));
        console2.log("Granted MINTER_ROLE to vRDATRewardModule");
        
        // Connect contracts
        staking.setRewardsManager(address(rewardsManager));
        console2.log("Set RewardsManager in StakingPositions");
        
        revenueCollector.setRewardsManager(address(rewardsManager));
        console2.log("Set RewardsManager in RevenueCollector");
        
        // Register reward programs
        vrdatProgramId = rewardsManager.registerProgram(
            address(vrdatModule),
            "vRDAT Rewards",
            block.timestamp,
            365 days * 10 // 10 year duration
        );
        console2.log("Registered vRDAT reward program with ID:", vrdatProgramId);
        
        // Configure migration
        bonusVesting.setMigrationBridge(address(migrationBridge));
        migrationBridge.setBonusVesting(address(bonusVesting));
        console2.log("Configured migration bonus vesting");
        
        // Grant revenue reporter role
        revenueCollector.grantRole(revenueCollector.REVENUE_REPORTER_ROLE(), admin);
        console2.log("Granted REVENUE_REPORTER_ROLE to admin");
    }
    
    function transferAllocations() internal {
        console2.log("\n=== Phase 5: Initial Allocations ===");
        
        // Transfer to treasury wallet (if different from initial treasury)
        if (address(treasury) != treasuryAddr) {
            uint256 treasuryAllocation = 70_000_000e18; // 70M RDAT
            rdat.transfer(address(treasury), treasuryAllocation);
            console2.log("Transferred 70M RDAT to TreasuryWallet");
        }
        
        // Migration bridge already received 30M during RDAT initialization
        console2.log("Migration bridge balance:", rdat.balanceOf(address(migrationBridge)) / 1e18, "RDAT");
        
        // Transfer to bonus vesting (from treasury allocation)
        uint256 bonusAllocation = 3_000_000e18; // 3M RDAT for migration bonuses
        rdat.transfer(address(bonusVesting), bonusAllocation);
        console2.log("Transferred 3M RDAT to BonusVesting");
    }
    
    function printSummary() internal view {
        console2.log("\n=== Deployment Summary ===");
        console2.log("RDAT Token:", address(rdat));
        console2.log("vRDAT Token:", address(vrdat));
        console2.log("StakingPositions:", address(staking));
        console2.log("EmergencyPause:", address(emergencyPause));
        console2.log("TreasuryWallet:", address(treasury));
        console2.log("TokenVesting:", address(vesting));
        console2.log("RewardsManager:", address(rewardsManager));
        console2.log("vRDATRewardModule:", address(vrdatModule));
        console2.log("RevenueCollector:", address(revenueCollector));
        console2.log("VanaMigrationBridge:", address(migrationBridge));
        console2.log("MigrationBonusVesting:", address(bonusVesting));
        console2.log("\nFull system deployed successfully!");
        
        // Verify key configurations
        console2.log("\n=== Configuration Verification ===");
        console2.log("RDAT Total Supply:", rdat.totalSupply() / 1e18);
        console2.log("Migration Bridge Balance:", rdat.balanceOf(address(migrationBridge)) / 1e18);
        console2.log("Bonus Vesting Balance:", rdat.balanceOf(address(bonusVesting)) / 1e18);
        console2.log("vRDAT Reward Program ID:", vrdatProgramId);
        console2.log("Revenue Collector RDAT Token:", revenueCollector.rdatToken());
    }
}