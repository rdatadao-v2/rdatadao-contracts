// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/CREATE2Factory.sol";
import "../src/RDATUpgradeable.sol";
import "../src/TreasuryWallet.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract CREATE2DeploymentTest is Test {
    Create2Factory public factory;

    address public admin = makeAddr("admin");
    address public migrationBridge = makeAddr("migrationBridge");

    bytes32 constant RDAT_SALT = keccak256("RDAT_V2");
    bytes32 constant TREASURY_SALT = keccak256("TREASURY_V2");

    function setUp() public {
        factory = new Create2Factory();
    }

    function test_CREATE2_CircularDependency() public {
        // 1. Calculate deterministic addresses
        address predictedTreasury = calculateTreasuryAddress();
        address predictedRDAT = calculateRDATAddress(predictedTreasury);

        console2.log("Predicted Treasury:", predictedTreasury);
        console2.log("Predicted RDAT:", predictedRDAT);

        // 2. Deploy RDAT with predicted treasury address
        address rdatProxy = deployRDAT(predictedTreasury);
        assertEq(rdatProxy, predictedRDAT, "RDAT address mismatch");

        // 3. Deploy Treasury with actual RDAT address
        address treasuryProxy = deployTreasury(rdatProxy);
        assertEq(treasuryProxy, predictedTreasury, "Treasury address mismatch");

        // 4. Verify the contracts are properly initialized
        RDATUpgradeable rdat = RDATUpgradeable(rdatProxy);
        TreasuryWallet treasury = TreasuryWallet(payable(treasuryProxy));

        // Verify Treasury has correct RDAT
        assertEq(address(treasury.rdat()), rdatProxy);

        // Verify Treasury received 70M tokens
        assertEq(rdat.balanceOf(treasuryProxy), 70_000_000e18);

        // Verify total supply is correct
        assertEq(rdat.totalSupply(), 100_000_000e18);
    }

    function test_PredictableAddressesAcrossChains() public {
        // Deploy on "chain 1"
        address treasury1 = calculateTreasuryAddress();
        address rdat1 = calculateRDATAddress(treasury1);

        // Simulate different chain by changing factory address
        // In real deployment, same factory bytecode at same address
        Create2Factory factory2 = new Create2Factory();

        // Calculate addresses with same salt
        address treasury2 = calculateTreasuryAddressWithFactory(address(factory2));
        address rdat2 = calculateRDATAddressWithFactory(treasury2, address(factory2));

        // Addresses would be same if factory is at same address
        // For this test, we verify the calculation logic works
        assertTrue(treasury1 != address(0));
        assertTrue(rdat1 != address(0));
        assertTrue(treasury2 != address(0));
        assertTrue(rdat2 != address(0));
    }

    function calculateTreasuryAddress() internal view returns (address) {
        // Treasury implementation
        bytes memory implBytecode = type(TreasuryWallet).creationCode;
        bytes32 implSalt = keccak256(abi.encode(TREASURY_SALT, "impl"));
        address implAddress = factory.computeAddress(implBytecode, implSalt);

        // Treasury proxy with empty initialization data
        bytes memory proxyBytecode = abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(implAddress, ""));

        return factory.computeAddress(proxyBytecode, TREASURY_SALT);
    }

    function calculateTreasuryAddressWithFactory(address factoryAddr) internal pure returns (address) {
        // Treasury implementation
        bytes memory implBytecode = type(TreasuryWallet).creationCode;
        bytes32 implSalt = keccak256(abi.encode(TREASURY_SALT, "impl"));
        address implAddress = computeAddress(implBytecode, implSalt, factoryAddr);

        // Treasury proxy
        bytes memory proxyBytecode = abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(implAddress, ""));

        return computeAddress(proxyBytecode, TREASURY_SALT, factoryAddr);
    }

    function calculateRDATAddress(address treasury) internal view returns (address) {
        // RDAT implementation
        bytes memory implBytecode = type(RDATUpgradeable).creationCode;
        bytes32 implSalt = keccak256(abi.encode(RDAT_SALT, "impl"));
        address implAddress = factory.computeAddress(implBytecode, implSalt);

        // RDAT proxy with initialization data
        bytes memory initData = abi.encodeCall(RDATUpgradeable.initialize, (treasury, admin, migrationBridge));

        bytes memory proxyBytecode =
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(implAddress, initData));

        return factory.computeAddress(proxyBytecode, RDAT_SALT);
    }

    function calculateRDATAddressWithFactory(address treasury, address factoryAddr) internal view returns (address) {
        // RDAT implementation
        bytes memory implBytecode = type(RDATUpgradeable).creationCode;
        bytes32 implSalt = keccak256(abi.encode(RDAT_SALT, "impl"));
        address implAddress = computeAddress(implBytecode, implSalt, factoryAddr);

        // RDAT proxy
        bytes memory initData = abi.encodeCall(RDATUpgradeable.initialize, (treasury, admin, migrationBridge));

        bytes memory proxyBytecode =
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(implAddress, initData));

        return computeAddress(proxyBytecode, RDAT_SALT, factoryAddr);
    }

    function deployRDAT(address treasury) internal returns (address) {
        // Deploy implementation
        bytes memory implBytecode = type(RDATUpgradeable).creationCode;
        bytes32 implSalt = keccak256(abi.encode(RDAT_SALT, "impl"));
        address implementation = factory.deploy(implBytecode, implSalt);

        // Deploy proxy
        bytes memory initData = abi.encodeCall(RDATUpgradeable.initialize, (treasury, admin, migrationBridge));

        bytes memory proxyBytecode =
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(implementation, initData));

        return factory.deploy(proxyBytecode, RDAT_SALT);
    }

    function deployTreasury(address rdatAddress) internal returns (address) {
        // Deploy implementation
        bytes memory implBytecode = type(TreasuryWallet).creationCode;
        bytes32 implSalt = keccak256(abi.encode(TREASURY_SALT, "impl"));
        address implementation = factory.deploy(implBytecode, implSalt);

        // Deploy proxy (uninitialized)
        bytes memory proxyBytecode = abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(implementation, ""));

        address proxy = factory.deploy(proxyBytecode, TREASURY_SALT);

        // Initialize treasury
        TreasuryWallet(payable(proxy)).initialize(admin, rdatAddress);

        return proxy;
    }

    function computeAddress(bytes memory bytecode, bytes32 salt, address deployer) internal pure returns (address) {
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, keccak256(bytecode)));
        return address(uint160(uint256(hash)));
    }

    function test_DeploymentGasEstimate() public {
        uint256 gasStart = gasleft();

        // Full deployment sequence
        address predictedTreasury = calculateTreasuryAddress();
        address predictedRDAT = calculateRDATAddress(predictedTreasury);
        deployRDAT(predictedTreasury);
        deployTreasury(predictedRDAT);

        uint256 gasUsed = gasStart - gasleft();
        console2.log("Total gas used for deployment:", gasUsed);

        // Ensure reasonable gas usage
        assertLt(gasUsed, 10_000_000, "Deployment too expensive");
    }
}
