// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script, console2} from "forge-std/Script.sol";
import {RDATDataDAO} from "../src/RDATDataDAO.sol";

/**
 * @title DeployRDATDataDAO
 * @notice Deploy the r/datadao DLP (Data Liquidity Pool) contract
 * @dev This creates the actual DLP contract that can be registered with Vana
 */
contract DeployRDATDataDAO is Script {
    // Deployed contract addresses on Vana Moksha
    address constant RDAT_TOKEN = 0xEb0c43d5987de0672A22e350930F615Af646e28c;
    address constant TREASURY = 0x31C3e3F091FB2A25d4dac82474e7dc709adE754a;
    address constant MULTISIG = 0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319;

    // Initial validators (same as migration bridge)
    address constant VALIDATOR_1 = 0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319; // Multisig
    address constant VALIDATOR_2 = 0x58eCB94e6F5e6521228316b55c465ad2A2938FbB; // Deployer
    address constant VALIDATOR_3 = 0xC9Af4E56741f255743e8f4877d4cfa9971E910C2; // Additional

    function run() external returns (address dlpAddress) {
        console2.log("========================================");
        console2.log("DEPLOY RDAT DATA DAO (DLP)");
        console2.log("========================================");
        console2.log("Chain ID:", block.chainid);
        console2.log("RDAT Token:", RDAT_TOKEN);
        console2.log("Treasury:", TREASURY);
        console2.log("Admin:", MULTISIG);
        console2.log("");

        // Prepare initial validators
        address[] memory initialValidators = new address[](3);
        initialValidators[0] = VALIDATOR_1;
        initialValidators[1] = VALIDATOR_2;
        initialValidators[2] = VALIDATOR_3;

        console2.log("Initial Validators:");
        console2.log("  1.", VALIDATOR_1, "(Multisig)");
        console2.log("  2.", VALIDATOR_2, "(Deployer)");
        console2.log("  3.", VALIDATOR_3, "(Additional)");
        console2.log("");

        vm.startBroadcast();

        // Deploy the DLP contract
        RDATDataDAO dlp = new RDATDataDAO(RDAT_TOKEN, TREASURY, MULTISIG, initialValidators);

        dlpAddress = address(dlp);

        console2.log("[OK] RDATDataDAO deployed at:", dlpAddress);

        vm.stopBroadcast();

        // Verify deployment
        console2.log("");
        console2.log("Deployment Verification:");
        console2.log("  DLP Name:", dlp.DLP_NAME());
        console2.log("  Version:", dlp.VERSION());
        console2.log("  RDAT Token:", address(dlp.rdatToken()));
        console2.log("  Treasury:", dlp.treasury());
        console2.log("");

        // Get stats
        (
            uint256 contributions,
            uint256 validatorCount,
            uint256 epoch,
            uint256 nextEpochTime,
            string memory name,
            string memory version
        ) = dlp.getStats();

        console2.log("Initial Stats:");
        console2.log("  Total Contributions:", contributions);
        console2.log("  Validator Count:", validatorCount);
        console2.log("  Current Epoch:", epoch);
        console2.log("  Next Epoch Time:", nextEpochTime);
        console2.log("");

        console2.log("Next Steps:");
        console2.log("1. Fund DLP with RDAT tokens for rewards");
        console2.log("2. Register DLP with Vana Registry");
        console2.log("3. Set up data contribution pipeline");
        console2.log("4. Begin validation and reward distribution");

        console2.log("");
        console2.log("========================================");
        console2.log("DLP Deployment Complete!");
        console2.log("========================================");

        return dlpAddress;
    }

    /**
     * @notice Check deployment requirements
     */
    function check() external view {
        console2.log("========================================");
        console2.log("DLP DEPLOYMENT CHECK");
        console2.log("========================================");
        console2.log("Chain:", block.chainid == 14800 ? "Vana Moksha" : "Unknown");
        console2.log("");

        // Check that RDAT token exists
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(RDAT_TOKEN)
        }

        if (codeSize > 0) {
            console2.log("[OK] RDAT Token deployed at:", RDAT_TOKEN);
        } else {
            console2.log("[ERROR] RDAT Token not found at:", RDAT_TOKEN);
        }

        // Check validator addresses
        console2.log("");
        console2.log("Validator Addresses:");
        console2.log("  Multisig:", VALIDATOR_1);
        console2.log("    Balance:", VALIDATOR_1.balance / 1e18, "VANA");
        console2.log("  Deployer:", VALIDATOR_2);
        console2.log("    Balance:", VALIDATOR_2.balance / 1e18, "VANA");
        console2.log("  Additional:", VALIDATOR_3);
        console2.log("    Balance:", VALIDATOR_3.balance / 1e18, "VANA");

        console2.log("");
        console2.log("Ready for deployment:", codeSize > 0);
    }
}
