// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script, console2} from "forge-std/Script.sol";
import {RDATUpgradeable} from "../src/RDATUpgradeable.sol";
import {Create2Factory} from "../src/Create2Factory.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployRDATUpgradeable is Script {
    // Deployment addresses
    address public treasury;
    address public admin;

    // Contracts
    Create2Factory public factory;
    RDATUpgradeable public implementation;
    RDATUpgradeable public rdat;

    // CREATE2 salts for deterministic deployment
    bytes32 constant FACTORY_SALT = keccak256("RDAT_V2_FACTORY");
    bytes32 constant IMPLEMENTATION_SALT = keccak256("RDAT_V2_IMPLEMENTATION");
    bytes32 constant PROXY_SALT = keccak256("RDAT_V2_PROXY");

    function run() external {
        // Load deployment parameters
        treasury = vm.envOr("TREASURY_ADDRESS", makeAddr("treasury"));
        admin = vm.envOr("ADMIN_ADDRESS", makeAddr("admin"));

        console2.log("Deploying RDAT Upgradeable with:");
        console2.log("  Treasury:", treasury);
        console2.log("  Admin:", admin);
        console2.log("  Chain ID:", block.chainid);

        // Start deployment
        vm.startBroadcast();

        // 1. Deploy CREATE2 factory if not already deployed
        address factoryAddress = _deployOrGetFactory();
        factory = Create2Factory(factoryAddress);

        // 2. Deploy implementation via CREATE2
        address implAddress = _deployImplementation();
        implementation = RDATUpgradeable(implAddress);

        // 3. Deploy proxy via CREATE2
        address proxyAddress = _deployProxy(implAddress);
        rdat = RDATUpgradeable(proxyAddress);

        vm.stopBroadcast();

        // Log deployment addresses
        console2.log("\nDeployment complete!");
        console2.log("CREATE2 Factory:", address(factory));
        console2.log("Implementation:", address(implementation));
        console2.log("Proxy (RDAT):", address(rdat));

        // Verify deployment
        _verifyDeployment();
    }

    function _deployOrGetFactory() internal returns (address) {
        // Check if factory already exists at predicted address
        bytes memory factoryBytecode = type(Create2Factory).creationCode;
        address predictedFactory = _computeCreate2Address(factoryBytecode, FACTORY_SALT, msg.sender);

        if (predictedFactory.code.length > 0) {
            console2.log("Factory already deployed at:", predictedFactory);
            return predictedFactory;
        }

        // Deploy factory
        console2.log("Deploying CREATE2 factory...");
        bytes32 salt = FACTORY_SALT;
        address deployed;
        assembly {
            deployed := create2(0, add(factoryBytecode, 0x20), mload(factoryBytecode), salt)
        }
        require(deployed != address(0), "Factory deployment failed");
        require(deployed == predictedFactory, "Factory address mismatch");

        return deployed;
    }

    function _deployImplementation() internal returns (address) {
        bytes memory implBytecode = type(RDATUpgradeable).creationCode;

        // Predict address
        address predicted = factory.computeAddress(implBytecode, IMPLEMENTATION_SALT);

        // Check if already deployed
        if (predicted.code.length > 0) {
            console2.log("Implementation already deployed at:", predicted);
            return predicted;
        }

        // Deploy via factory
        console2.log("Deploying implementation...");
        address deployed = factory.deploy(implBytecode, IMPLEMENTATION_SALT);
        require(deployed == predicted, "Implementation address mismatch");

        return deployed;
    }

    function _deployProxy(address _implementation) internal returns (address) {
        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(RDATUpgradeable.initialize.selector, treasury, admin);

        // Prepare proxy bytecode with constructor args
        bytes memory proxyBytecode =
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(_implementation, initData));

        // Predict address
        address predicted = factory.computeAddress(proxyBytecode, PROXY_SALT);

        // Check if already deployed
        if (predicted.code.length > 0) {
            console2.log("Proxy already deployed at:", predicted);
            return predicted;
        }

        // Deploy via factory
        console2.log("Deploying proxy...");
        address deployed = factory.deploy(proxyBytecode, PROXY_SALT);
        require(deployed == predicted, "Proxy address mismatch");

        return deployed;
    }

    function _verifyDeployment() internal view {
        console2.log("\nVerifying deployment...");

        // Verify proxy initialization
        require(rdat.totalSupply() == 70_000_000 * 10 ** 18, "Invalid total supply");
        require(rdat.balanceOf(treasury) == 70_000_000 * 10 ** 18, "Invalid treasury balance");

        // Verify roles
        require(rdat.hasRole(rdat.DEFAULT_ADMIN_ROLE(), admin), "Admin role not set");
        require(rdat.hasRole(rdat.PAUSER_ROLE(), admin), "Pauser role not set");
        require(rdat.hasRole(rdat.UPGRADER_ROLE(), admin), "Upgrader role not set");

        console2.log("Deployment verified successfully");
    }

    function _computeCreate2Address(bytes memory bytecode, bytes32 salt, address deployer)
        internal
        pure
        returns (address)
    {
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, keccak256(bytecode)));
        return address(uint160(uint256(hash)));
    }

    // Helper function to compute addresses without deployment
    function computeAddresses() external {
        address deployer = vm.envOr("DEPLOYER_ADDRESS", msg.sender);
        console2.log("Computing deployment addresses for chain:", block.chainid);
        console2.log("Deployer address:", deployer);

        // Factory address
        bytes memory factoryBytecode = type(Create2Factory).creationCode;
        address predictedFactory = _computeCreate2Address(factoryBytecode, FACTORY_SALT, deployer);
        console2.log("Factory address:", predictedFactory);

        // Use factory address to compute other addresses
        Create2Factory tempFactory = Create2Factory(predictedFactory);

        // Implementation address
        bytes memory implBytecode = type(RDATUpgradeable).creationCode;
        address predictedImpl = tempFactory.computeAddress(implBytecode, IMPLEMENTATION_SALT);
        console2.log("Implementation address:", predictedImpl);

        // Proxy address
        bytes memory initData = abi.encodeWithSelector(
            RDATUpgradeable.initialize.selector,
            treasury != address(0) ? treasury : makeAddr("treasury"),
            admin != address(0) ? admin : makeAddr("admin")
        );
        bytes memory proxyBytecode =
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(predictedImpl, initData));
        address predictedProxy = tempFactory.computeAddress(proxyBytecode, PROXY_SALT);
        console2.log("Proxy (RDAT) address:", predictedProxy);
    }
}
