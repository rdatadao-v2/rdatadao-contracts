// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

/**
 * @title GenerateABI
 * @notice Script to help generate ABI files for frontend integration
 * @dev Run with: forge script script/GenerateABI.s.sol
 */
contract GenerateABI is Script {
    function run() public pure {
        console2.log("=== ABI Generation Guide ===");
        console2.log("");
        console2.log("Foundry automatically generates ABI files when you compile contracts.");
        console2.log("");
        console2.log("ABI locations:");
        console2.log("- JSON artifacts: out/[ContractName].sol/[ContractName].json");
        console2.log("- Contains ABI, bytecode, and metadata");
        console2.log("");
        console2.log("To generate clean ABI files:");
        console2.log("1. Compile contracts: forge build");
        console2.log("2. Extract ABI: forge inspect [ContractName] abi > abi/[ContractName].json");
        console2.log("");
        console2.log("Example commands:");
        console2.log("- forge inspect MockRDAT abi > abi/MockRDAT.json");
        console2.log("- forge inspect RdatMigration abi > abi/RdatMigration.json");
        console2.log("- forge inspect RdatDistributor abi > abi/RdatDistributor.json");
        console2.log("");
        console2.log("For wagmi integration, see scripts/export-abi.sh");
    }
}
