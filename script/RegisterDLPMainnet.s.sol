// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script, console2} from "forge-std/Script.sol";

interface IDLPRegistry {
    struct DLPInfo {
        address dlpAddress;
        address ownerAddress;
        address treasuryAddress;
        string name;
        string iconUrl;
        string website;
        string metadata;
    }

    function registerDlp(DLPInfo calldata info) external payable returns (uint256);
}

contract RegisterDLPMainnet is Script {
    // Vana Mainnet DLP Registry
    address constant DLP_REGISTRY = 0x4D59880a924526d1dD33260552Ff4328b1E18a43;
    uint256 constant REGISTRATION_FEE = 1 ether; // 1 VANA

    function run() external returns (uint256) {
        // For DLP registration, we use the RDAT token address itself as the DLP
        address rdatToken = 0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E;
        address vanaMultisig = 0xe4F7Eca807C57311e715C3Ef483e72Fa8D5bCcDF;

        console2.log("========================================");
        console2.log("DLP REGISTRATION - VANA MAINNET");
        console2.log("========================================");
        console2.log("DLP Registry:", DLP_REGISTRY);
        console2.log("RDAT Token (DLP):", rdatToken);
        console2.log("Owner/Treasury:", vanaMultisig);
        console2.log("Registration Fee:", REGISTRATION_FEE / 1e18, "VANA");
        console2.log("");

        vm.startBroadcast();

        IDLPRegistry registry = IDLPRegistry(DLP_REGISTRY);

        // Create DLP info
        IDLPRegistry.DLPInfo memory dlpInfo = IDLPRegistry.DLPInfo({
            dlpAddress: rdatToken,  // Using RDAT token address as DLP
            ownerAddress: vanaMultisig,
            treasuryAddress: vanaMultisig,
            name: "r/datadao",
            iconUrl: "https://rdatadao.org/logo.png",
            website: "https://rdatadao.org",
            metadata: '{"description":"Reddit Data DAO - RDAT Token","type":"SocialMedia","dataSource":"Reddit","version":"2.0"}'
        });

        console2.log("Registering DLP with the following info:");
        console2.log("- Name:", dlpInfo.name);
        console2.log("- Website:", dlpInfo.website);
        console2.log("");

        // Register DLP (costs 1 VANA)
        uint256 dlpId = registry.registerDlp{value: REGISTRATION_FEE}(dlpInfo);

        console2.log("SUCCESS! DLP Registered with ID:", dlpId);
        console2.log("");

        vm.stopBroadcast();

        console2.log("========================================");
        console2.log("REGISTRATION COMPLETE");
        console2.log("========================================");
        console2.log("DLP ID:", dlpId);
        console2.log("SAVE THIS ID FOR FRONTEND INTEGRATION!");

        return dlpId;
    }
}