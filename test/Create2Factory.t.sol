// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Create2Factory} from "../src/Create2Factory.sol";
import {MockRDAT} from "../src/mocks/MockRDAT.sol";

contract Create2FactoryTest is Test {
    Create2Factory public factory;
    address public deployer;

    event ContractDeployed(address indexed deployer, address indexed deployed, bytes32 salt);

    function setUp() public {
        deployer = makeAddr("deployer");
        factory = new Create2Factory();
    }

    function test_DeploySimpleContract() public {
        bytes memory bytecode = type(SimpleContract).creationCode;
        bytes32 salt = keccak256("test_salt");

        // Predict address
        address predicted = factory.computeAddress(bytecode, salt);

        // Deploy
        vm.prank(deployer);
        vm.expectEmit(true, true, true, true);
        emit ContractDeployed(deployer, predicted, salt);

        address deployed = factory.deploy(bytecode, salt);

        // Verify
        assertEq(deployed, predicted);
        assertTrue(deployed.code.length > 0);

        // Verify the contract works
        SimpleContract simple = SimpleContract(deployed);
        assertEq(simple.value(), 42);
    }

    function test_DeployWithConstructorArgs() public {
        // Deploy MockRDAT with constructor arguments
        address owner = makeAddr("owner");
        bytes memory bytecode = type(MockRDAT).creationCode;
        bytes memory constructorArgs = abi.encode(owner);
        bytes32 salt = keccak256("mockrdat_salt");

        // Deploy using deployWithConstructor
        vm.prank(deployer);
        address deployed = factory.deployWithConstructor(bytecode, salt, constructorArgs);

        // Verify deployment
        assertTrue(deployed != address(0));
        assertTrue(deployed.code.length > 0);

        // Verify the contract was initialized correctly
        MockRDAT mockRdat = MockRDAT(deployed);
        assertEq(mockRdat.owner(), owner);
        assertEq(mockRdat.name(), "RData");
        assertEq(mockRdat.totalSupply(), 30_000_000 * 10 ** 18);
    }

    function test_DeterministicAddresses() public {
        bytes memory bytecode = type(SimpleContract).creationCode;
        bytes32 salt = keccak256("deterministic_test");

        // Deploy from different accounts - should get same address prediction
        address predicted1 = factory.computeAddress(bytecode, salt);

        // Deploy
        vm.prank(deployer);
        address deployed1 = factory.deploy(bytecode, salt);

        assertEq(deployed1, predicted1);

        // Try to deploy again with same salt - should fail
        vm.prank(deployer);
        vm.expectRevert(Create2Factory.DeploymentFailed.selector);
        factory.deploy(bytecode, salt);
    }

    function test_DifferentSaltsDifferentAddresses() public {
        bytes memory bytecode = type(SimpleContract).creationCode;
        bytes32 salt1 = keccak256("salt1");
        bytes32 salt2 = keccak256("salt2");

        address predicted1 = factory.computeAddress(bytecode, salt1);
        address predicted2 = factory.computeAddress(bytecode, salt2);

        // Addresses should be different
        assertTrue(predicted1 != predicted2);

        // Deploy both
        vm.startPrank(deployer);
        address deployed1 = factory.deploy(bytecode, salt1);
        address deployed2 = factory.deploy(bytecode, salt2);
        vm.stopPrank();

        assertEq(deployed1, predicted1);
        assertEq(deployed2, predicted2);
    }

    function test_ComputeAddressWithDeployer() public {
        bytes memory bytecode = type(SimpleContract).creationCode;
        bytes32 salt = keccak256("deployer_test");

        // Compute address for different deployers
        address predicted1 = factory.computeAddressWithDeployer(bytecode, salt, address(factory));
        address predicted2 = factory.computeAddressWithDeployer(bytecode, salt, address(0x1234));

        // Should be different
        assertTrue(predicted1 != predicted2);

        // Deploy via factory
        address deployed = factory.deploy(bytecode, salt);
        assertEq(deployed, predicted1);
    }

    function test_RevertOnZeroBytecode() public {
        bytes memory emptyBytecode = "";
        bytes32 salt = keccak256("empty_test");

        vm.expectRevert(Create2Factory.ZeroBytecode.selector);
        factory.deploy(emptyBytecode, salt);
    }

    function test_RevertOnZeroSalt() public {
        bytes memory bytecode = type(SimpleContract).creationCode;
        bytes32 zeroSalt = bytes32(0);

        vm.expectRevert(Create2Factory.ZeroSalt.selector);
        factory.deploy(bytecode, zeroSalt);
    }

    function test_CrossChainDeterminism() public {
        // Simulate deployment on different chains
        bytes memory bytecode = type(SimpleContract).creationCode;
        bytes32 salt = keccak256("cross_chain_test");

        // Base chain (8453)
        vm.chainId(8453);
        address predictedBase = factory.computeAddress(bytecode, salt);

        // Vana chain (1480)
        vm.chainId(1480);
        address predictedVana = factory.computeAddress(bytecode, salt);

        // Addresses should be the same (deterministic across chains)
        assertEq(predictedBase, predictedVana);
    }

    function testFuzz_Deploy(bytes32 salt, uint256 value) public {
        vm.assume(salt != bytes32(0));
        vm.assume(value < 1000);

        // Create bytecode with value
        bytes memory bytecode = abi.encodePacked(type(ParameterizedContract).creationCode, abi.encode(value));

        // Predict
        address predicted = factory.computeAddress(bytecode, salt);

        // Deploy
        address deployed = factory.deploy(bytecode, salt);

        // Verify
        assertEq(deployed, predicted);
        ParameterizedContract param = ParameterizedContract(deployed);
        assertEq(param.value(), value);
    }
}

// Test contracts
contract SimpleContract {
    uint256 public constant value = 42;
}

contract ParameterizedContract {
    uint256 public value;

    constructor(uint256 _value) {
        value = _value;
    }
}
