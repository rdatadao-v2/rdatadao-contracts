// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/vRDAT.sol";
import "../src/StakingPositions.sol";
import "../src/TreasuryWallet.sol";
import "../src/RevenueCollector.sol";
import "../src/EmergencyPause.sol";
import "../src/ProofOfContributionStub.sol";

contract DeployFullSystemOptimized is Script {
    // Store addresses to avoid stack too deep
    struct DeployedContracts {
        address emergencyPause;
        address vrdat;
        address staking;
        address treasuryWallet;
        address revenueCollector;
        address poc;
    }

    function run() external {
        // Get deployment parameters
        address rdatToken = vm.envAddress("RDAT_TOKEN_ADDRESS");
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        address admin = vm.envAddress("ADMIN_ADDRESS");

        require(rdatToken != address(0), "RDAT_TOKEN_ADDRESS not set");
        require(treasury != address(0), "TREASURY_ADDRESS not set");
        require(admin != address(0), "ADMIN_ADDRESS not set");

        console2.log("Deploying supporting contracts...");
        console2.log("  RDAT Token:", rdatToken);
        console2.log("  Treasury:", treasury);
        console2.log("  Admin:", admin);

        vm.startBroadcast();

        DeployedContracts memory contracts;

        // 1. Deploy EmergencyPause
        console2.log("\n1. Deploying EmergencyPause...");
        contracts.emergencyPause = address(new EmergencyPause(admin));
        console2.log("  EmergencyPause deployed at:", contracts.emergencyPause);

        // 2. Deploy vRDAT
        console2.log("\n2. Deploying vRDAT...");
        contracts.vrdat = address(new vRDAT(admin));
        console2.log("  vRDAT deployed at:", contracts.vrdat);

        // 3. Deploy StakingPositions
        console2.log("\n3. Deploying StakingPositions...");
        contracts.staking = deployStaking(rdatToken, contracts.vrdat, contracts.emergencyPause, admin);
        console2.log("  StakingPositions deployed at:", contracts.staking);

        // 4. Configure vRDAT roles (skip if deployer != admin)
        if (msg.sender == admin) {
            console2.log("\n4. Configuring vRDAT roles...");
            vRDAT(contracts.vrdat).grantRole(vRDAT(contracts.vrdat).MINTER_ROLE(), contracts.staking);
            vRDAT(contracts.vrdat).grantRole(vRDAT(contracts.vrdat).BURNER_ROLE(), contracts.staking);
            console2.log("  Minter and Burner roles granted");
        } else {
            console2.log("\n4. Skipping vRDAT role configuration (deployer != admin)");
            console2.log("  Admin must manually grant MINTER_ROLE and BURNER_ROLE to StakingPositions");
        }

        // 5. Deploy TreasuryWallet
        console2.log("\n5. Deploying TreasuryWallet...");
        contracts.treasuryWallet = deployTreasury(rdatToken, treasury, admin);
        console2.log("  TreasuryWallet deployed at:", contracts.treasuryWallet);

        // 6. Deploy RevenueCollector
        console2.log("\n6. Deploying RevenueCollector...");
        contracts.revenueCollector = deployRevenue(contracts.staking, treasury, contracts.treasuryWallet, admin);
        console2.log("  RevenueCollector deployed at:", contracts.revenueCollector);

        // 7. Deploy ProofOfContributionStub
        console2.log("\n7. Deploying ProofOfContributionStub...");
        contracts.poc = address(new ProofOfContributionStub(admin, rdatToken));
        console2.log("  ProofOfContributionStub deployed at:", contracts.poc);

        // 8. Configure emergency pausers (skip if deployer != admin)
        if (msg.sender == admin) {
            console2.log("\n8. Configuring emergency pausers...");
            EmergencyPause(contracts.emergencyPause).addPauser(admin);
            console2.log("  Admin added as emergency pauser");
        } else {
            console2.log("\n8. Skipping emergency pauser configuration (deployer != admin)");
            console2.log("  Admin must manually add pausers using addPauser()");
        }

        vm.stopBroadcast();

        // Summary
        printSummary(contracts);
    }

    function deployStaking(address rdatToken, address vrdat, address emergencyPause, address admin)
        internal
        returns (address)
    {
        address impl = address(new StakingPositions());

        bytes memory initData =
            abi.encodeWithSelector(StakingPositions.initialize.selector, rdatToken, vrdat, emergencyPause, admin);

        return address(new ERC1967Proxy(impl, initData));
    }

    function deployTreasury(address rdatToken, address treasury, address admin) internal returns (address) {
        address impl = address(new TreasuryWallet());

        bytes memory initData = abi.encodeWithSelector(TreasuryWallet.initialize.selector, rdatToken, treasury, admin);

        return address(new ERC1967Proxy(impl, initData));
    }

    function deployRevenue(address staking, address treasury, address treasuryWallet, address admin)
        internal
        returns (address)
    {
        address impl = address(new RevenueCollector());

        bytes memory initData =
            abi.encodeWithSelector(RevenueCollector.initialize.selector, staking, treasury, treasuryWallet, admin);

        return address(new ERC1967Proxy(impl, initData));
    }

    function printSummary(DeployedContracts memory contracts) internal pure {
        console2.log("\n========================================");
        console2.log("     Supporting Contracts Deployed");
        console2.log("========================================");
        console2.log("EmergencyPause:", contracts.emergencyPause);
        console2.log("vRDAT:", contracts.vrdat);
        console2.log("StakingPositions:", contracts.staking);
        console2.log("TreasuryWallet:", contracts.treasuryWallet);
        console2.log("RevenueCollector:", contracts.revenueCollector);
        console2.log("ProofOfContribution:", contracts.poc);
        console2.log("");
        console2.log("All contracts configured and ready!");
        console2.log("");
        console2.log("Next steps:");
        console2.log("1. Transfer RDAT tokens to TreasuryWallet");
        console2.log("2. Configure RewardsManager if needed");
        console2.log("3. Set up staking parameters");
        console2.log("4. Register DLP on Vana");
    }
}
