// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script, console2} from "forge-std/Script.sol";
import {SimpleVanaDLP} from "../src/SimpleVanaDLP.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title DeploySimpleVanaDLP
 * @notice Deploy simplified Vana DLP for r/datadao registry registration
 * @dev Uses minimal interface for registry compatibility while maintaining RDAT integration
 */
contract DeploySimpleVanaDLP is Script {
    // Our r/datadao configuration
    address constant RDAT_TOKEN = 0xEb0c43d5987de0672A22e350930F615Af646e28c;
    address constant MULTISIG = 0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319;

    // DLP Configuration
    string constant DLP_NAME = "r/datadao";
    string constant PUBLIC_KEY = ""; // Can be set later
    string constant PROOF_INSTRUCTION = "reddit_data_validation_v1";
    uint256 constant FILE_REWARD_FACTOR = 10; // 10 RDAT per file

    function run() external returns (address dlpProxy) {
        console2.log("========================================");
        console2.log("DEPLOY SIMPLE VANA DLP");
        console2.log("========================================");
        console2.log("Chain ID:", block.chainid);
        console2.log("DLP Name:", DLP_NAME);
        console2.log("Owner:", MULTISIG);
        console2.log("RDAT Token:", RDAT_TOKEN);
        console2.log("");

        vm.startBroadcast();

        // Step 1: Deploy implementation
        SimpleVanaDLP implementation = new SimpleVanaDLP();
        console2.log("[OK] Implementation deployed at:", address(implementation));

        // Step 2: Prepare initialization data
        SimpleVanaDLP.InitParams memory params = SimpleVanaDLP.InitParams({
            ownerAddress: MULTISIG,
            tokenAddress: RDAT_TOKEN,
            dlpName: DLP_NAME,
            dlpPublicKey: PUBLIC_KEY,
            dlpProofInstruction: PROOF_INSTRUCTION,
            dlpFileRewardFactor: FILE_REWARD_FACTOR
        });

        bytes memory initData = abi.encodeWithSelector(SimpleVanaDLP.initialize.selector, params);

        // Step 3: Deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);

        dlpProxy = address(proxy);
        console2.log("[OK] DLP Proxy deployed at:", dlpProxy);

        vm.stopBroadcast();

        // Verify deployment
        console2.log("");
        console2.log("Deployment Verification:");

        SimpleVanaDLP dlp = SimpleVanaDLP(dlpProxy);
        console2.log("  Name:", dlp.name());
        console2.log("  Token:", address(dlp.token()));
        console2.log("  File Reward Factor:", dlp.fileRewardFactor());
        console2.log("  Version:", dlp.version());

        console2.log("");
        console2.log("Next Steps:");
        console2.log("1. Register DLP with Vana Registry");
        console2.log("2. Fund DLP with RDAT tokens");
        console2.log("3. Configure public key if needed");
        console2.log("4. Begin data contribution");

        console2.log("");
        console2.log("Registry Registration:");
        console2.log("  DLP Address:", dlpProxy);
        console2.log("  Owner:", MULTISIG);
        console2.log("  Treasury:", MULTISIG);
        console2.log("  Name: r/datadao");
        console2.log("  Fee: 1 VANA");

        console2.log("");
        console2.log("========================================");
        console2.log("Simple Vana DLP Deployment Complete!");
        console2.log("========================================");

        return dlpProxy;
    }

    /**
     * @notice Check deployment prerequisites
     */
    function check() external view {
        console2.log("========================================");
        console2.log("SIMPLE VANA DLP CHECK");
        console2.log("========================================");
        console2.log("Chain:", block.chainid == 14800 ? "Vana Moksha" : "Unknown");
        console2.log("");

        // Check RDAT token
        console2.log("RDAT Token:", RDAT_TOKEN);
        console2.log("  Has code:", RDAT_TOKEN.code.length > 0);

        console2.log("");
        console2.log("Multisig:", MULTISIG);
        console2.log("  Balance:", MULTISIG.balance / 1e18, "VANA");

        console2.log("");
        console2.log("DLP Configuration:");
        console2.log("  Name:", DLP_NAME);
        console2.log("  Proof Instruction:", PROOF_INSTRUCTION);
        console2.log("  File Reward Factor:", FILE_REWARD_FACTOR, "RDAT");

        bool ready = RDAT_TOKEN.code.length > 0;
        console2.log("");
        console2.log("Ready for deployment:", ready);
    }
}
