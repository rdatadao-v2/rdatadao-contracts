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

contract DeployFullSystem is Script {
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

        // 1. Deploy EmergencyPause
        console2.log("\n1. Deploying EmergencyPause...");
        EmergencyPause emergencyPause = new EmergencyPause(admin);
        console2.log("  EmergencyPause deployed at:", address(emergencyPause));

        // 2. Deploy vRDAT (soul-bound governance token)
        console2.log("\n2. Deploying vRDAT...");
        vRDAT vrdat = new vRDAT(admin);
        console2.log("  vRDAT deployed at:", address(vrdat));

        // 3. Deploy StakingPositions (upgradeable)
        console2.log("\n3. Deploying StakingPositions...");
        StakingPositions stakingImpl = new StakingPositions();

        // Initialize data for proxy
        bytes memory initData = abi.encodeWithSelector(
            StakingPositions.initialize.selector, rdatToken, address(vrdat), address(emergencyPause), admin
        );

        // Deploy proxy
        ERC1967Proxy stakingProxy = new ERC1967Proxy(address(stakingImpl), initData);
        StakingPositions staking = StakingPositions(address(stakingProxy));
        console2.log("  StakingPositions deployed at:", address(staking));
        console2.log("  Implementation at:", address(stakingImpl));

        // 4. Configure vRDAT minter role for StakingPositions
        console2.log("\n4. Configuring vRDAT minter role...");
        vrdat.grantRole(vrdat.MINTER_ROLE(), address(staking));
        vrdat.grantRole(vrdat.BURNER_ROLE(), address(staking));
        console2.log("  Minter and Burner roles granted to StakingPositions");

        // 5. Deploy TreasuryWallet (upgradeable)
        console2.log("\n5. Deploying TreasuryWallet...");
        TreasuryWallet treasuryImpl = new TreasuryWallet();

        // Initialize data for proxy
        bytes memory treasuryInitData =
            abi.encodeWithSelector(TreasuryWallet.initialize.selector, rdatToken, treasury, admin);

        // Deploy proxy
        ERC1967Proxy treasuryProxy = new ERC1967Proxy(address(treasuryImpl), treasuryInitData);
        TreasuryWallet treasuryWallet = TreasuryWallet(payable(address(treasuryProxy)));
        console2.log("  TreasuryWallet deployed at:", address(treasuryWallet));
        console2.log("  Implementation at:", address(treasuryImpl));

        // 6. Deploy RevenueCollector (upgradeable) - using helper to avoid stack too deep
        console2.log("\n6. Deploying RevenueCollector...");
        address revenueCollector = _deployRevenueCollector(address(staking), treasury, address(treasuryWallet), admin);
        console2.log("  RevenueCollector deployed at:", revenueCollector);

        // 7. Deploy ProofOfContributionStub
        console2.log("\n7. Deploying ProofOfContributionStub...");
        ProofOfContributionStub poc = new ProofOfContributionStub(admin, rdatToken);
        console2.log("  ProofOfContributionStub deployed at:", address(poc));

        // 8. Configure emergency pausers
        console2.log("\n8. Configuring emergency pausers...");
        emergencyPause.addPauser(admin);
        console2.log("  Admin added as emergency pauser");

        // Renounce deployer roles if not admin
        if (msg.sender != admin) {
            console2.log("\n9. Renouncing deployer roles...");
            emergencyPause.renounceRole(emergencyPause.DEFAULT_ADMIN_ROLE(), msg.sender);
            vrdat.renounceRole(vrdat.DEFAULT_ADMIN_ROLE(), msg.sender);
            staking.renounceRole(staking.DEFAULT_ADMIN_ROLE(), msg.sender);
            treasuryWallet.renounceRole(treasuryWallet.DEFAULT_ADMIN_ROLE(), msg.sender);
            RevenueCollector(revenueCollector).renounceRole(
                RevenueCollector(revenueCollector).DEFAULT_ADMIN_ROLE(), msg.sender
            );
            console2.log("  Deployer roles renounced");
        }

        vm.stopBroadcast();

        // Summary
        console2.log("\n========================================");
        console2.log("     Supporting Contracts Deployed");
        console2.log("========================================");
        console2.log("EmergencyPause:", address(emergencyPause));
        console2.log("vRDAT:", address(vrdat));
        console2.log("StakingPositions:", address(staking));
        console2.log("TreasuryWallet:", address(treasuryWallet));
        console2.log("RevenueCollector:", revenueCollector);
        console2.log("ProofOfContribution:", address(poc));
        console2.log("");
        console2.log("All contracts configured and ready!");
        console2.log("");
        console2.log("Next steps:");
        console2.log("1. Transfer RDAT tokens to TreasuryWallet");
        console2.log("2. Configure RewardsManager if needed");
        console2.log("3. Set up staking parameters");
        console2.log("4. Register DLP on Vana");
    }

    /**
     * @notice Helper function to deploy RevenueCollector and avoid stack too deep
     */
    function _deployRevenueCollector(address staking, address treasury, address treasuryWallet, address admin)
        internal
        returns (address)
    {
        RevenueCollector revenueImpl = new RevenueCollector();
        ERC1967Proxy revenueProxy = new ERC1967Proxy(address(revenueImpl), "");
        RevenueCollector revenueCollector = RevenueCollector(address(revenueProxy));
        revenueCollector.initialize(staking, treasury, treasuryWallet, admin);
        return address(revenueCollector);
    }
}
