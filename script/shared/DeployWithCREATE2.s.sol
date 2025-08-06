// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../../src/CREATE2Factory.sol";
import "../../src/RDATUpgradeable.sol";
import "../../src/TreasuryWallet.sol";
import "../../src/vRDAT.sol";
import "../../src/StakingPositions.sol";
// import "../../src/rewards/RewardsManager.sol"; // TODO: Implement RewardsManager
import "../../src/EmergencyPause.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title DeployWithCREATE2
 * @author r/datadao
 * @notice Deployment script using CREATE2 for deterministic addresses
 * @dev Resolves circular dependencies between RDAT and TreasuryWallet
 */
contract DeployWithCREATE2 is Script {
    // Deployment salts
    bytes32 constant FACTORY_SALT = keccak256("CREATE2_FACTORY_V1");
    bytes32 constant RDAT_SALT = keccak256("RDAT_V2");
    bytes32 constant TREASURY_SALT = keccak256("TREASURY_V2");
    bytes32 constant VRDAT_SALT = keccak256("VRDAT_V2");
    bytes32 constant STAKING_SALT = keccak256("STAKING_V2");
    bytes32 constant REWARDS_SALT = keccak256("REWARDS_V2");
    bytes32 constant EMERGENCY_SALT = keccak256("EMERGENCY_V2");
    
    // Contract instances
    Create2Factory public factory;
    EmergencyPause public emergencyPause;
    vRDAT public vrdat;
    TreasuryWallet public treasury;
    RDATUpgradeable public rdat;
    StakingPositions public staking;
    // RewardsManager public rewardsManager; // TODO: Implement RewardsManager
    
    struct DeploymentAddresses {
        address factory;
        address emergencyPause;
        address vrdat;
        address treasuryProxy;
        address rdatProxy;
        address staking;
        // address rewardsManager; // TODO: Implement RewardsManager
    }
    
    function run() external returns (DeploymentAddresses memory addresses) {
        // Get deployment parameters from environment or use defaults for testing
        address admin = vm.envOr("ADMIN_ADDRESS", address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266));
        address migrationBridge = vm.envOr("MIGRATION_BRIDGE_ADDRESS", address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8));
        uint256 deployerPrivateKey = vm.envOr("DEPLOYER_PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy CREATE2 factory if not already deployed
        addresses.factory = deployFactory();
        factory = Create2Factory(addresses.factory);
        
        // 2. Calculate deterministic addresses
        address predictedTreasury = calculateTreasuryAddress();
        address predictedRDAT = calculateRDATAddress(predictedTreasury, admin, migrationBridge);
        
        console2.log("Predicted Treasury:", predictedTreasury);
        console2.log("Predicted RDAT:", predictedRDAT);
        
        // 3. Deploy non-circular dependencies first
        addresses.emergencyPause = address(deployEmergencyPause(admin));
        addresses.vrdat = address(deployVRDAT(predictedRDAT, admin));
        
        // 4. Deploy RDAT with predicted treasury address
        addresses.rdatProxy = deployRDAT(predictedTreasury, admin, migrationBridge);
        require(addresses.rdatProxy == predictedRDAT, "RDAT address mismatch");
        
        // 5. Deploy Treasury with actual RDAT address
        addresses.treasuryProxy = deployTreasury(admin, addresses.rdatProxy);
        require(addresses.treasuryProxy == predictedTreasury, "Treasury address mismatch");
        
        // 6. Deploy remaining contracts
        addresses.staking = address(deployStaking(
            addresses.rdatProxy,
            addresses.vrdat,
            addresses.emergencyPause,
            admin
        ));
        
        // TODO: Deploy RewardsManager when implemented
        // addresses.rewardsManager = address(deployRewardsManager(
        //     addresses.staking,
        //     addresses.emergencyPause,
        //     admin
        // ));
        
        vm.stopBroadcast();
        
        // Log deployment addresses
        console2.log("\n=== Deployment Complete ===");
        console2.log("Factory:", addresses.factory);
        console2.log("EmergencyPause:", addresses.emergencyPause);
        console2.log("vRDAT:", addresses.vrdat);
        console2.log("Treasury:", addresses.treasuryProxy);
        console2.log("RDAT:", addresses.rdatProxy);
        console2.log("Staking:", addresses.staking);
        // console2.log("RewardsManager:", addresses.rewardsManager); // TODO
        
        return addresses;
    }
    
    function deployFactory() internal returns (address) {
        // Check if factory already exists at predicted address
        bytes memory factoryBytecode = type(Create2Factory).creationCode;
        address predictedFactory = computeCreate2Address(
            factoryBytecode,
            FACTORY_SALT,
            address(this)
        );
        
        if (predictedFactory.code.length > 0) {
            console2.log("Factory already deployed at:", predictedFactory);
            return predictedFactory;
        }
        
        // Deploy factory using CREATE2 from this contract
        address deployed;
        bytes32 salt = FACTORY_SALT;
        assembly {
            deployed := create2(0, add(factoryBytecode, 0x20), mload(factoryBytecode), salt)
        }
        require(deployed != address(0), "Factory deployment failed");
        
        return deployed;
    }
    
    function calculateTreasuryAddress() internal view returns (address) {
        // Treasury implementation
        bytes memory implBytecode = type(TreasuryWallet).creationCode;
        address implAddress = factory.computeAddress(implBytecode, TREASURY_SALT);
        
        // Treasury proxy with empty initialization data
        bytes memory proxyBytecode = abi.encodePacked(
            type(ERC1967Proxy).creationCode,
            abi.encode(implAddress, "")
        );
        
        return factory.computeAddress(proxyBytecode, TREASURY_SALT);
    }
    
    function calculateRDATAddress(
        address treasuryAddress,
        address admin,
        address migrationBridge
    ) internal view returns (address) {
        // RDAT implementation
        bytes memory implBytecode = type(RDATUpgradeable).creationCode;
        address implAddress = factory.computeAddress(implBytecode, RDAT_SALT);
        
        // RDAT proxy with initialization data
        bytes memory initData = abi.encodeCall(
            RDATUpgradeable.initialize,
            (treasuryAddress, admin, migrationBridge)
        );
        
        bytes memory proxyBytecode = abi.encodePacked(
            type(ERC1967Proxy).creationCode,
            abi.encode(implAddress, initData)
        );
        
        return factory.computeAddress(proxyBytecode, RDAT_SALT);
    }
    
    function deployEmergencyPause(address admin) internal returns (EmergencyPause) {
        bytes memory bytecode = abi.encodePacked(
            type(EmergencyPause).creationCode,
            abi.encode(admin)
        );
        address deployed = factory.deploy(bytecode, EMERGENCY_SALT);
        return EmergencyPause(deployed);
    }
    
    function deployVRDAT(address rdatAddress, address admin) internal returns (vRDAT) {
        bytes memory bytecode = abi.encodePacked(
            type(vRDAT).creationCode,
            abi.encode(rdatAddress, admin)
        );
        address deployed = factory.deploy(bytecode, VRDAT_SALT);
        return vRDAT(deployed);
    }
    
    function deployRDAT(
        address treasuryAddress,
        address admin,
        address migrationBridge
    ) internal returns (address) {
        // Deploy implementation
        bytes memory implBytecode = type(RDATUpgradeable).creationCode;
        address implementation = factory.deploy(implBytecode, RDAT_SALT);
        
        // Deploy proxy
        bytes memory initData = abi.encodeCall(
            RDATUpgradeable.initialize,
            (treasuryAddress, admin, migrationBridge)
        );
        
        bytes memory proxyBytecode = abi.encodePacked(
            type(ERC1967Proxy).creationCode,
            abi.encode(implementation, initData)
        );
        
        return factory.deploy(proxyBytecode, RDAT_SALT);
    }
    
    function deployTreasury(address admin, address rdatAddress) internal returns (address) {
        // Deploy implementation
        bytes memory implBytecode = type(TreasuryWallet).creationCode;
        address implementation = factory.deploy(implBytecode, TREASURY_SALT);
        
        // Deploy proxy (uninitialized)
        bytes memory proxyBytecode = abi.encodePacked(
            type(ERC1967Proxy).creationCode,
            abi.encode(implementation, "")
        );
        
        address proxy = factory.deploy(proxyBytecode, TREASURY_SALT);
        
        // Initialize treasury
        TreasuryWallet(payable(proxy)).initialize(admin, rdatAddress);
        
        return proxy;
    }
    
    function deployStaking(
        address rdatToken,
        address vrdatToken,
        address emergencyPauseAddress,
        address admin
    ) internal returns (StakingPositions) {
        bytes memory bytecode = abi.encodePacked(
            type(StakingPositions).creationCode,
            abi.encode(rdatToken, vrdatToken, emergencyPauseAddress, admin)
        );
        address deployed = factory.deploy(bytecode, STAKING_SALT);
        return StakingPositions(deployed);
    }
    
    // TODO: Implement RewardsManager deployment
    // function deployRewardsManager(
    //     address stakingContract,
    //     address emergencyPauseAddress,
    //     address admin
    // ) internal returns (RewardsManager) {
    //     bytes memory bytecode = abi.encodePacked(
    //         type(RewardsManager).creationCode,
    //         abi.encode(stakingContract, emergencyPauseAddress, admin)
    //     );
    //     address deployed = factory.deploy(bytecode, REWARDS_SALT);
    //     return RewardsManager(deployed);
    // }
    
    function computeCreate2Address(
        bytes memory bytecode,
        bytes32 salt,
        address deployer
    ) internal pure returns (address) {
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
}