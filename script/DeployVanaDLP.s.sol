// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script, console2} from "forge-std/Script.sol";
import {DataLiquidityPoolImplementation} from "../src/DataLiquidityPoolImplementation.sol";
import {DataLiquidityPoolProxy} from "../src/DataLiquidityPoolProxy.sol";

/**
 * @title DeployVanaDLP
 * @notice Deploy official Vana Data Liquidity Pool template for r/datadao
 * @dev Uses Vana's official DataLiquidityPoolProxy template for registry compatibility
 */
contract DeployVanaDLP is Script {
    // Vana Moksha testnet addresses
    address constant DATA_REGISTRY = 0x8C8788f98385F6ba1adD4234e551ABba0f82Cb7C;
    address constant TEE_POOL = 0x3c92fD91639b41f13338CE62f19131e7d19eaa0D;

    // Our r/datadao configuration
    address constant RDAT_TOKEN = 0xEb0c43d5987de0672A22e350930F615Af646e28c;
    address constant MULTISIG = 0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319;
    address constant TRUSTED_FORWARDER = address(0); // No meta-transactions needed initially

    // DLP Configuration
    string constant DLP_NAME = "r/datadao";
    string constant PUBLIC_KEY = ""; // Can be set later via updatePublicKey
    string constant PROOF_INSTRUCTION = "reddit_data_validation_v1"; // Reddit-specific validation
    uint256 constant FILE_REWARD_FACTOR = 1000; // 1000 = 1x multiplier (adjust as needed)

    function run() external returns (address dlpProxy) {
        console2.log("========================================");
        console2.log("DEPLOY OFFICIAL VANA DLP");
        console2.log("========================================");
        console2.log("Chain ID:", block.chainid);
        console2.log("DLP Name:", DLP_NAME);
        console2.log("Owner:", MULTISIG);
        console2.log("RDAT Token:", RDAT_TOKEN);
        console2.log("");

        vm.startBroadcast();

        // Step 1: Deploy the implementation contract
        DataLiquidityPoolImplementation implementation = new DataLiquidityPoolImplementation();
        console2.log("[OK] Implementation deployed at:", address(implementation));

        // Step 2: Prepare initialization data
        DataLiquidityPoolImplementation.InitParams memory params = DataLiquidityPoolImplementation.InitParams({
            trustedForwarder: TRUSTED_FORWARDER,
            ownerAddress: MULTISIG,
            tokenAddress: RDAT_TOKEN,
            dataRegistryAddress: DATA_REGISTRY,
            teePoolAddress: TEE_POOL,
            name: DLP_NAME,
            publicKey: PUBLIC_KEY,
            proofInstruction: PROOF_INSTRUCTION,
            fileRewardFactor: FILE_REWARD_FACTOR
        });

        bytes memory initData = abi.encodeWithSelector(DataLiquidityPoolImplementation.initialize.selector, params);

        // Step 3: Deploy the proxy with initialization
        DataLiquidityPoolProxy proxy = new DataLiquidityPoolProxy(address(implementation), initData);

        dlpProxy = address(proxy);
        console2.log("[OK] DLP Proxy deployed at:", dlpProxy);

        vm.stopBroadcast();

        // Verify deployment
        console2.log("");
        console2.log("Deployment Verification:");

        DataLiquidityPoolImplementation dlp = DataLiquidityPoolImplementation(dlpProxy);
        console2.log("  Name:", dlp.name());
        console2.log("  Token:", address(dlp.token()));
        console2.log("  Data Registry:", address(dlp.dataRegistry()));
        console2.log("  TEE Pool:", address(dlp.teePool()));
        console2.log("  File Reward Factor:", dlp.fileRewardFactor());

        console2.log("");
        console2.log("Next Steps:");
        console2.log("1. Register DLP with Vana Registry");
        console2.log("2. Fund DLP with RDAT tokens");
        console2.log("3. Configure public key and proof instructions");
        console2.log("4. Begin data contribution process");

        console2.log("");
        console2.log("Registry Registration Command:");
        console2.log("Use DLP address:", dlpProxy);
        console2.log("Registry fee: 1 VANA");

        console2.log("");
        console2.log("========================================");
        console2.log("Vana DLP Deployment Complete!");
        console2.log("========================================");

        return dlpProxy;
    }

    /**
     * @notice Check deployment prerequisites
     */
    function check() external view {
        console2.log("========================================");
        console2.log("VANA DLP DEPLOYMENT CHECK");
        console2.log("========================================");
        console2.log("Chain:", block.chainid == 14800 ? "Vana Moksha" : "Unknown");
        console2.log("");

        // Check Vana contracts exist
        console2.log("Vana Infrastructure:");
        console2.log("  Data Registry:", DATA_REGISTRY);
        console2.log("    Has code:", DATA_REGISTRY.code.length > 0);

        console2.log("  TEE Pool:", TEE_POOL);
        console2.log("    Has code:", TEE_POOL.code.length > 0);

        console2.log("");
        console2.log("r/datadao Configuration:");
        console2.log("  RDAT Token:", RDAT_TOKEN);
        console2.log("    Has code:", RDAT_TOKEN.code.length > 0);

        console2.log("  Multisig:", MULTISIG);
        console2.log("    Balance:", MULTISIG.balance / 1e18, "VANA");

        console2.log("");
        console2.log("DLP Parameters:");
        console2.log("  Name:", DLP_NAME);
        console2.log("  Proof Instruction:", PROOF_INSTRUCTION);
        console2.log("  File Reward Factor:", FILE_REWARD_FACTOR);

        bool ready = DATA_REGISTRY.code.length > 0 && TEE_POOL.code.length > 0 && RDAT_TOKEN.code.length > 0;

        console2.log("");
        console2.log("Ready for deployment:", ready);
    }
}
