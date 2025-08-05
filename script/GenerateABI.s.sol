// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

/**
 * @title GenerateABI
 * @notice Script to help generate ABI files for frontend integration
 * @dev Run with: forge script script/GenerateABI.s.sol
 */
contract GenerateABI is Script {
    function run() public view {
        console.log("=== ABI Generation Guide ===");
        console.log("");
        console.log("Foundry automatically generates ABI files when you compile contracts.");
        console.log("");
        console.log("ABI locations:");
        console.log("- JSON artifacts: out/[ContractName].sol/[ContractName].json");
        console.log("- Contains ABI, bytecode, and metadata");
        console.log("");
        console.log("To generate clean ABI files:");
        console.log("1. Compile contracts: forge build");
        console.log("2. Extract ABI: forge inspect [ContractName] abi > abi/[ContractName].json");
        console.log("");
        console.log("Example commands:");
        console.log("- forge inspect MockRDAT abi > abi/MockRDAT.json");
        console.log("- forge inspect RdatMigration abi > abi/RdatMigration.json");
        console.log("- forge inspect RdatDistributor abi > abi/RdatDistributor.json");
        console.log("");
        console.log("For wagmi integration, see scripts/export-abi.sh");
    }
}