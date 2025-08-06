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
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployAllLocal is Script {
    // Deployed addresses
    RDATUpgradeable public rdat;
    vRDAT public vrdat;
    StakingPositions public staking;
    EmergencyPause public emergencyPause;
    TreasuryWallet public treasury;
    TokenVesting public vesting;
    VanaMigrationBridge public migrationBridge;
    MigrationBonusVesting public bonusVesting;
    
    function run() external {
        address admin = msg.sender;
        console2.log("Deploying all contracts to local chain");
        console2.log("Admin:", admin);
        
        vm.startBroadcast();
        
        // 1. Deploy EmergencyPause
        emergencyPause = new EmergencyPause(admin);
        console2.log("EmergencyPause:", address(emergencyPause));
        
        // 2. Deploy RDAT (using existing deployment at 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0)
        rdat = RDATUpgradeable(0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0);
        console2.log("RDAT (existing):", address(rdat));
        
        // 3. Deploy vRDAT
        vrdat = new vRDAT(admin);
        console2.log("vRDAT:", address(vrdat));
        
        // 4. Deploy StakingPositions (upgradeable)
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
        
        // 5. Deploy TreasuryWallet
        TreasuryWallet treasuryImpl = new TreasuryWallet();
        bytes memory treasuryInitData = abi.encodeWithSelector(
            TreasuryWallet.initialize.selector,
            admin,
            address(rdat)
        );
        ERC1967Proxy treasuryProxy = new ERC1967Proxy(address(treasuryImpl), treasuryInitData);
        treasury = TreasuryWallet(payable(address(treasuryProxy)));
        console2.log("TreasuryWallet:", address(treasury));
        
        // 6. Deploy TokenVesting
        vesting = new TokenVesting(address(rdat), admin);
        console2.log("TokenVesting:", address(vesting));
        
        // 7. Deploy Migration contracts
        address[] memory validators = new address[](3);
        validators[0] = admin; // For testing, use admin as validator
        validators[1] = address(0x1);
        validators[2] = address(0x2);
        
        migrationBridge = new VanaMigrationBridge(
            address(rdat),
            admin,
            validators
        );
        console2.log("VanaMigrationBridge:", address(migrationBridge));
        
        // 8. Deploy MigrationBonusVesting
        bonusVesting = new MigrationBonusVesting(address(rdat), admin);
        console2.log("MigrationBonusVesting:", address(bonusVesting));
        
        // Configure contracts
        console2.log("\nConfiguring contracts...");
        
        // Grant minter role to staking
        vrdat.grantRole(vrdat.MINTER_ROLE(), address(staking));
        console2.log("Granted MINTER_ROLE to StakingPositions");
        
        // Configure migration bonus vesting
        bonusVesting.setMigrationBridge(address(migrationBridge));
        migrationBridge.setBonusVesting(address(bonusVesting));
        console2.log("Configured migration bonus vesting");
        
        // Transfer some RDAT to migration bridge for testing
        uint256 migrationAllocation = 1_000_000e18; // 1M RDAT for testing
        rdat.transfer(address(migrationBridge), migrationAllocation);
        console2.log("Transferred", migrationAllocation / 1e18, "RDAT to migration bridge");
        
        // Transfer some RDAT to bonus vesting
        uint256 bonusAllocation = 100_000e18; // 100K RDAT for testing
        rdat.transfer(address(bonusVesting), bonusAllocation);
        console2.log("Transferred", bonusAllocation / 1e18, "RDAT to bonus vesting");
        
        vm.stopBroadcast();
        
        console2.log("\n=== Deployment Summary ===");
        console2.log("RDAT:", address(rdat));
        console2.log("vRDAT:", address(vrdat));
        console2.log("StakingPositions:", address(staking));
        console2.log("EmergencyPause:", address(emergencyPause));
        console2.log("TreasuryWallet:", address(treasury));
        console2.log("TokenVesting:", address(vesting));
        console2.log("VanaMigrationBridge:", address(migrationBridge));
        console2.log("MigrationBonusVesting:", address(bonusVesting));
        console2.log("\nAll contracts deployed successfully!");
    }
}