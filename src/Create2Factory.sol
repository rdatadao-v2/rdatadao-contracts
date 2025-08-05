// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @title Create2Factory
 * @author r/datadao
 * @notice Factory contract for deterministic deployment using CREATE2
 * @dev Allows deployment of contracts to predictable addresses across different chains
 */
contract Create2Factory {
    // Events
    event ContractDeployed(address indexed deployer, address indexed deployed, bytes32 salt);
    
    // Errors
    error DeploymentFailed();
    error ZeroBytecode();
    error ZeroSalt();
    
    /**
     * @dev Deploys a contract using CREATE2
     * @param bytecode The bytecode of the contract to deploy
     * @param salt A unique salt for deterministic address generation
     * @return deployed The address of the deployed contract
     */
    function deploy(bytes memory bytecode, bytes32 salt) external returns (address deployed) {
        if (bytecode.length == 0) revert ZeroBytecode();
        if (salt == bytes32(0)) revert ZeroSalt();
        
        assembly {
            deployed := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        
        if (deployed == address(0)) revert DeploymentFailed();
        
        emit ContractDeployed(msg.sender, deployed, salt);
    }
    
    /**
     * @dev Computes the address of a contract to be deployed using CREATE2
     * @param bytecode The bytecode of the contract
     * @param salt The salt to use
     * @return The computed address
     */
    function computeAddress(bytes memory bytecode, bytes32 salt) external view returns (address) {
        return computeAddressWithDeployer(bytecode, salt, address(this));
    }
    
    /**
     * @dev Computes the address of a contract to be deployed using CREATE2 from a specific deployer
     * @param bytecode The bytecode of the contract
     * @param salt The salt to use
     * @param deployer The address that will deploy the contract
     * @return The computed address
     */
    function computeAddressWithDeployer(
        bytes memory bytecode,
        bytes32 salt,
        address deployer
    ) public pure returns (address) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                deployer,
                salt,
                keccak256(bytecode)
            )
        );
        return address(uint160(uint256(hash)));
    }
    
    /**
     * @dev Deploys a contract with constructor arguments using CREATE2
     * @param bytecode The bytecode of the contract (without constructor args)
     * @param salt A unique salt for deterministic address generation
     * @param constructorArgs The ABI-encoded constructor arguments
     * @return deployed The address of the deployed contract
     */
    function deployWithConstructor(
        bytes memory bytecode,
        bytes32 salt,
        bytes memory constructorArgs
    ) external returns (address deployed) {
        bytes memory fullBytecode = abi.encodePacked(bytecode, constructorArgs);
        return this.deploy(fullBytecode, salt);
    }
}