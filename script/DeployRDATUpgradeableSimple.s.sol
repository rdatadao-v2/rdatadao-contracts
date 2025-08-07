// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script, console2} from "forge-std/Script.sol";
import {RDATUpgradeable} from "../src/RDATUpgradeable.sol";
import {Create2Factory} from "../src/Create2Factory.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployRDATUpgradeableSimple is Script {
    function run() external {
        // Load deployment parameters
        address treasury = vm.envOr("TREASURY_ADDRESS", address(0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319));
        address admin = vm.envOr("ADMIN_ADDRESS", address(0xaA10a84CE7d9AE517a52c6d5cA153b369Af99ecF));

        console2.log("Deploying RDAT Upgradeable with:");
        console2.log("  Treasury:", treasury);
        console2.log("  Admin:", admin);
        console2.log("  Chain ID:", block.chainid);

        vm.startBroadcast();

        // 1. Deploy CREATE2 factory
        Create2Factory factory = new Create2Factory();
        console2.log("CREATE2 Factory deployed at:", address(factory));

        // 2. Deploy implementation
        RDATUpgradeable implementation = new RDATUpgradeable();
        console2.log("Implementation deployed at:", address(implementation));

        // 3. Deploy proxy with initialization
        // For local testing, use treasury as migration contract temporarily
        address migrationContract = treasury; // In production, this would be the actual migration bridge
        bytes memory initData =
            abi.encodeWithSelector(RDATUpgradeable.initialize.selector, treasury, admin, migrationContract);

        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        console2.log("Proxy (RDAT) deployed at:", address(proxy));

        vm.stopBroadcast();

        // Verify deployment
        RDATUpgradeable rdat = RDATUpgradeable(address(proxy));
        console2.log("\nVerifying deployment...");
        console2.log("Total Supply:", rdat.totalSupply());
        console2.log("Treasury Balance:", rdat.balanceOf(treasury));
        console2.log("Admin has DEFAULT_ADMIN_ROLE:", rdat.hasRole(rdat.DEFAULT_ADMIN_ROLE(), admin));
        console2.log("Admin has PAUSER_ROLE:", rdat.hasRole(rdat.PAUSER_ROLE(), admin));
        console2.log("Admin has UPGRADER_ROLE:", rdat.hasRole(rdat.UPGRADER_ROLE(), admin));
    }

    // Dry run function to simulate deployment without sending transactions
    function dryRun() external view {
        // Load deployment parameters
        address treasury = vm.envOr("TREASURY_ADDRESS", address(0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319));
        address admin = vm.envOr("ADMIN_ADDRESS", address(0xaA10a84CE7d9AE517a52c6d5cA153b369Af99ecF));
        address deployer = vm.envOr("DEPLOYER_ADDRESS", msg.sender);

        console2.log("=== DRY RUN - Simulating deployment ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", deployer);
        console2.log("Treasury:", treasury);
        console2.log("Admin:", admin);

        // Calculate deployment addresses
        uint256 currentNonce = vm.getNonce(deployer);
        console2.log("Current deployer nonce:", currentNonce);

        address factoryAddr = vm.computeCreateAddress(deployer, currentNonce);
        address implAddr = vm.computeCreateAddress(deployer, currentNonce + 1);
        address proxyAddr = vm.computeCreateAddress(deployer, currentNonce + 2);

        console2.log("\nPredicted addresses:");
        console2.log("CREATE2 Factory:", factoryAddr);
        console2.log("Implementation:", implAddr);
        console2.log("Proxy (RDAT):", proxyAddr);

        // Estimate gas costs
        uint256 factoryGas = 300000; // Approximate
        uint256 implGas = 3000000; // Approximate
        uint256 proxyGas = 500000; // Approximate
        uint256 totalGas = factoryGas + implGas + proxyGas;

        console2.log("\nEstimated gas costs:");
        console2.log("CREATE2 Factory:", factoryGas);
        console2.log("Implementation:", implGas);
        console2.log("Proxy:", proxyGas);
        console2.log("Total:", totalGas);

        // Check deployer balance
        uint256 deployerBalance = deployer.balance;
        console2.log("\nDeployer balance:", deployerBalance);

        if (deployerBalance == 0) {
            console2.log("WARNING: Deployer has no balance!");
        }
    }
}
