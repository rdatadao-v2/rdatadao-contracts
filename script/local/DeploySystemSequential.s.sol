// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../../src/EmergencyPause.sol";
import "../../src/vRDAT.sol";
import "../../src/StakingPositions.sol";
import "../../src/TreasuryWallet.sol";
import "../../src/TokenVesting.sol";
import "../../src/RevenueCollector.sol";
import "../../src/RewardsManager.sol";
import "../../src/rewards/vRDATRewardModule.sol";
import "../../src/VanaMigrationBridge.sol";
import "../../src/MigrationBonusVesting.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeploySystemSequential is Script {
    // RDAT already deployed at: 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
    address constant RDAT_ADDRESS = 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0;
    address public admin;

    // Contracts to deploy
    EmergencyPause public emergencyPause;
    vRDAT public vrdat;
    StakingPositions public staking;
    TreasuryWallet public treasury;
    TokenVesting public vesting;
    RevenueCollector public revenueCollector;
    RewardsManager public rewardsManager;
    vRDATRewardModule public vrdatModule;
    VanaMigrationBridge public migrationBridge;
    MigrationBonusVesting public bonusVesting;

    function run() external {
        admin = vm.envOr("ADMIN_ADDRESS", address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266));

        console2.log("=== Deploying Remaining Contracts ===");
        console2.log("Admin:", admin);
        console2.log("RDAT Token:", RDAT_ADDRESS);
        console2.log("Chain ID:", block.chainid);

        vm.startBroadcast();

        // 1. Deploy EmergencyPause
        console2.log("\n1. Deploying EmergencyPause...");
        emergencyPause = new EmergencyPause(admin);
        console2.log("   Deployed at:", address(emergencyPause));

        // 2. Deploy vRDAT
        console2.log("\n2. Deploying vRDAT...");
        vrdat = new vRDAT(admin);
        console2.log("   Deployed at:", address(vrdat));

        // 3. Deploy StakingPositions
        console2.log("\n3. Deploying StakingPositions...");
        StakingPositions stakingImpl = new StakingPositions();
        bytes memory stakingInitData = abi.encodeWithSelector(
            StakingPositions.initialize.selector, RDAT_ADDRESS, address(vrdat), admin, address(emergencyPause)
        );
        ERC1967Proxy stakingProxy = new ERC1967Proxy(address(stakingImpl), stakingInitData);
        staking = StakingPositions(address(stakingProxy));
        console2.log("   Implementation:", address(stakingImpl));
        console2.log("   Proxy:", address(staking));

        // 4. Deploy TreasuryWallet
        console2.log("\n4. Deploying TreasuryWallet...");
        TreasuryWallet treasuryImpl = new TreasuryWallet();
        bytes memory treasuryInitData = abi.encodeWithSelector(TreasuryWallet.initialize.selector, admin, RDAT_ADDRESS);
        ERC1967Proxy treasuryProxy = new ERC1967Proxy(address(treasuryImpl), treasuryInitData);
        treasury = TreasuryWallet(payable(address(treasuryProxy)));
        console2.log("   Implementation:", address(treasuryImpl));
        console2.log("   Proxy:", address(treasury));

        // 5. Deploy TokenVesting
        console2.log("\n5. Deploying TokenVesting...");
        vesting = new TokenVesting(RDAT_ADDRESS, admin);
        console2.log("   Deployed at:", address(vesting));

        // 6. Deploy RewardsManager
        console2.log("\n6. Deploying RewardsManager...");
        RewardsManager rewardsImpl = new RewardsManager();
        bytes memory rewardsInitData =
            abi.encodeWithSelector(RewardsManager.initialize.selector, address(staking), admin);
        ERC1967Proxy rewardsProxy = new ERC1967Proxy(address(rewardsImpl), rewardsInitData);
        rewardsManager = RewardsManager(address(rewardsProxy));
        console2.log("   Implementation:", address(rewardsImpl));
        console2.log("   Proxy:", address(rewardsManager));

        // 7. Deploy vRDATRewardModule
        console2.log("\n7. Deploying vRDATRewardModule...");
        vrdatModule = new vRDATRewardModule(address(vrdat), address(staking), address(rewardsManager), admin);
        console2.log("   Deployed at:", address(vrdatModule));

        // 8. Deploy RevenueCollector
        console2.log("\n8. Deploying RevenueCollector...");
        RevenueCollector revenueImpl = new RevenueCollector();
        bytes memory revenueInitData = abi.encodeWithSelector(
            RevenueCollector.initialize.selector,
            address(staking),
            admin, // Using admin as treasury for simplicity
            admin, // Using admin as contributor pool for simplicity
            admin
        );
        ERC1967Proxy revenueProxy = new ERC1967Proxy(address(revenueImpl), revenueInitData);
        revenueCollector = RevenueCollector(address(revenueProxy));
        console2.log("   Implementation:", address(revenueImpl));
        console2.log("   Proxy:", address(revenueCollector));

        // 9. Deploy Migration contracts
        console2.log("\n9. Deploying Migration contracts...");
        address[] memory validators = new address[](3);
        validators[0] = admin;
        validators[1] = address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8);
        validators[2] = address(0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC);

        migrationBridge = new VanaMigrationBridge(RDAT_ADDRESS, admin, validators);
        console2.log("   VanaMigrationBridge:", address(migrationBridge));

        bonusVesting = new MigrationBonusVesting(RDAT_ADDRESS, admin);
        console2.log("   MigrationBonusVesting:", address(bonusVesting));

        // Configuration
        console2.log("\n=== Configuring Contracts ===");

        // Grant minter roles
        vrdat.grantRole(vrdat.MINTER_ROLE(), address(staking));
        console2.log("Granted MINTER_ROLE to StakingPositions");

        vrdat.grantRole(vrdat.MINTER_ROLE(), address(vrdatModule));
        console2.log("Granted MINTER_ROLE to vRDATRewardModule");

        // Connect contracts
        staking.setRewardsManager(address(rewardsManager));
        console2.log("Set RewardsManager in StakingPositions");

        revenueCollector.setRewardsManager(address(rewardsManager));
        console2.log("Set RewardsManager in RevenueCollector");

        // Register vRDAT reward module
        uint256 vrdatProgramId =
            rewardsManager.registerProgram(address(vrdatModule), "vRDAT Rewards", block.timestamp, 365 days * 10);
        console2.log("Registered vRDAT reward program with ID:", vrdatProgramId);

        // Configure migration
        bonusVesting.setMigrationBridge(address(migrationBridge));
        migrationBridge.setBonusVesting(address(bonusVesting));
        console2.log("Configured migration bonus vesting");

        // Grant revenue reporter role
        revenueCollector.grantRole(revenueCollector.REVENUE_REPORTER_ROLE(), admin);
        console2.log("Granted REVENUE_REPORTER_ROLE to admin");

        vm.stopBroadcast();

        // Summary
        console2.log("\n=== Deployment Complete ===");
        console2.log("EmergencyPause:", address(emergencyPause));
        console2.log("vRDAT:", address(vrdat));
        console2.log("StakingPositions:", address(staking));
        console2.log("TreasuryWallet:", address(treasury));
        console2.log("TokenVesting:", address(vesting));
        console2.log("RewardsManager:", address(rewardsManager));
        console2.log("vRDATRewardModule:", address(vrdatModule));
        console2.log("RevenueCollector:", address(revenueCollector));
        console2.log("VanaMigrationBridge:", address(migrationBridge));
        console2.log("MigrationBonusVesting:", address(bonusVesting));

        console2.log("\nNote: Remember to transfer RDAT allocations to:");
        console2.log("- TreasuryWallet (if using separate treasury)");
        console2.log("- MigrationBonusVesting for bonus payouts");
    }
}
