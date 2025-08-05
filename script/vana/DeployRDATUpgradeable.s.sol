// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script, console2} from "forge-std/Script.sol";
import {RDATUpgradeable} from "../../src/RDATUpgradeable.sol";
import {Create2Factory} from "../../src/Create2Factory.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title Deploy RDAT Upgradeable to Vana Networks
 * @notice This script deploys the RDAT V2 token ONLY to Vana networks
 * @dev RDAT V2 is a Vana-native token and should NOT be deployed to Base
 */
contract DeployRDATUpgradeable is Script {
    function run() external {
        // Verify we're deploying to Vana network
        require(
            block.chainid == 1480 || block.chainid == 14800,
            "RDAT V2 can only be deployed to Vana networks"
        );
        
        // Load deployment parameters
        address treasury = vm.envOr("TREASURY_ADDRESS", address(0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319));
        address admin = vm.envOr("ADMIN_ADDRESS", address(0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319));
        
        console2.log("Deploying RDAT V2 to Vana Network");
        console2.log("  Chain:", block.chainid == 1480 ? "Vana Mainnet" : "Vana Moksha");
        console2.log("  Treasury:", treasury);
        console2.log("  Admin:", admin);
        
        vm.startBroadcast();
        
        // 1. Deploy CREATE2 factory
        Create2Factory factory = new Create2Factory();
        console2.log("CREATE2 Factory:", address(factory));
        
        // 2. Deploy implementation
        RDATUpgradeable implementation = new RDATUpgradeable();
        console2.log("Implementation:", address(implementation));
        
        // 3. Deploy proxy with initialization
        bytes memory initData = abi.encodeWithSelector(
            RDATUpgradeable.initialize.selector,
            treasury,
            admin
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );
        console2.log("RDAT V2 Proxy:", address(proxy));
        
        vm.stopBroadcast();
        
        // Verify deployment
        RDATUpgradeable rdat = RDATUpgradeable(address(proxy));
        console2.log("\nVerification:");
        console2.log("  Name:", rdat.name());
        console2.log("  Symbol:", rdat.symbol());
        console2.log("  Total Supply:", rdat.totalSupply());
        console2.log("  Treasury Balance:", rdat.balanceOf(treasury));
        console2.log("  VRC-20 Compliant:", rdat.isVRC20());
    }
    
    function dryRun() external view {
        // Verify we're checking Vana network
        require(
            block.chainid == 1480 || block.chainid == 14800,
            "RDAT V2 dry run only for Vana networks"
        );
        
        address treasury = vm.envOr("TREASURY_ADDRESS", address(0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319));
        address admin = vm.envOr("ADMIN_ADDRESS", address(0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319));
        address deployer = vm.envOr("DEPLOYER_ADDRESS", msg.sender);
        
        console2.log("=== RDAT V2 Deployment Dry Run (Vana Network) ===");
        console2.log("Chain:", block.chainid == 1480 ? "Vana Mainnet" : "Vana Moksha");
        console2.log("Deployer:", deployer);
        console2.log("Treasury:", treasury);
        console2.log("Admin:", admin);
        
        uint256 nonce = vm.getNonce(deployer);
        console2.log("\nCurrent nonce:", nonce);
        
        // Predict addresses
        address factoryAddr = vm.computeCreateAddress(deployer, nonce);
        address implAddr = vm.computeCreateAddress(deployer, nonce + 1);
        address proxyAddr = vm.computeCreateAddress(deployer, nonce + 2);
        
        console2.log("\nPredicted addresses:");
        console2.log("  CREATE2 Factory:", factoryAddr);
        console2.log("  Implementation:", implAddr);
        console2.log("  RDAT V2 Proxy:", proxyAddr);
        
        // Check balance
        uint256 balance = deployer.balance;
        console2.log("\nDeployer balance:", balance, "wei");
        console2.log("Deployer balance:", balance / 1e18, "VANA");
        
        if (balance < 0.1 ether) {
            console2.log("WARNING: Low balance for deployment!");
        }
    }
}