// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../src/StakingPositions.sol";
import "../src/RDATUpgradeable.sol";
import "../src/vRDAT.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployStakingPositions is Script {
    // Deployment addresses (to be set based on environment)
    address public rdatAddress;
    address public vrdatAddress;
    address public adminAddress;
    
    function setUp() public {
        // These should be set based on your deployment environment
        // For local testing
        if (block.chainid == 31337) {
            rdatAddress = address(0); // Set after RDAT deployment
            vrdatAddress = address(0); // Set after vRDAT deployment
            adminAddress = msg.sender;
        }
        // Base Sepolia
        else if (block.chainid == 84532) {
            rdatAddress = address(0); // Set to deployed RDAT address
            vrdatAddress = address(0); // Set to deployed vRDAT address
            adminAddress = 0x90013583c66D2bf16327cB5Bc4a647AcceCF4B9A; // Gnosis Safe
        }
        // Base Mainnet
        else if (block.chainid == 8453) {
            rdatAddress = address(0); // Set to deployed RDAT address
            vrdatAddress = address(0); // Set to deployed vRDAT address
            adminAddress = 0x90013583c66D2bf16327cB5Bc4a647AcceCF4B9A; // Gnosis Safe
        }
        // Vana Testnet (Moksha)
        else if (block.chainid == 14800) {
            rdatAddress = address(0); // Set to deployed RDAT address
            vrdatAddress = address(0); // Set to deployed vRDAT address
            adminAddress = 0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319; // Gnosis Safe
        }
        // Vana Mainnet
        else if (block.chainid == 1480) {
            rdatAddress = address(0); // Set to deployed RDAT address
            vrdatAddress = address(0); // Set to deployed vRDAT address
            adminAddress = 0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319; // Gnosis Safe
        }
    }
    
    function run() public returns (address) {
        require(rdatAddress != address(0), "RDAT address not set");
        require(vrdatAddress != address(0), "vRDAT address not set");
        require(adminAddress != address(0), "Admin address not set");
        
        vm.startBroadcast();
        
        // Deploy implementation
        StakingPositions stakingImpl = new StakingPositions();
        console.log("StakingPositions implementation deployed at:", address(stakingImpl));
        
        // Deploy proxy
        bytes memory initData = abi.encodeCall(
            stakingImpl.initialize,
            (rdatAddress, vrdatAddress, adminAddress)
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(stakingImpl),
            initData
        );
        console.log("StakingPositions proxy deployed at:", address(proxy));
        
        // Cast proxy to interface
        StakingPositions staking = StakingPositions(address(proxy));
        
        // Grant required roles on vRDAT if we're the admin
        if (msg.sender == adminAddress) {
            vRDAT vrdat = vRDAT(vrdatAddress);
            
            // Grant MINTER_ROLE to staking contract
            vrdat.grantRole(vrdat.MINTER_ROLE(), address(proxy));
            console.log("Granted MINTER_ROLE to StakingPositions");
            
            // Grant BURNER_ROLE to staking contract
            vrdat.grantRole(vrdat.BURNER_ROLE(), address(proxy));
            console.log("Granted BURNER_ROLE to StakingPositions");
            
            // If RDAT is upgradeable and we have admin role
            try RDATUpgradeable(rdatAddress).hasRole(bytes32(0), msg.sender) returns (bool hasAdmin) {
                if (hasAdmin) {
                    RDATUpgradeable(rdatAddress).grantRole(
                        keccak256("MINTER_ROLE"), 
                        address(proxy)
                    );
                    console.log("Granted MINTER_ROLE on RDAT to StakingPositions");
                }
            } catch {
                console.log("Could not grant MINTER_ROLE on RDAT (not admin or not upgradeable)");
            }
        }
        
        vm.stopBroadcast();
        
        // Log deployment info
        console.log("==== StakingPositions Deployment Complete ====");
        console.log("Proxy Address:", address(proxy));
        console.log("Implementation Address:", address(stakingImpl));
        console.log("Admin:", adminAddress);
        console.log("RDAT Token:", rdatAddress);
        console.log("vRDAT Token:", vrdatAddress);
        console.log("============================================");
        
        return address(proxy);
    }
    
    // Helper function to deploy with specific addresses
    function deployWithAddresses(
        address _rdat,
        address _vrdat,
        address _admin
    ) public returns (address) {
        rdatAddress = _rdat;
        vrdatAddress = _vrdat;
        adminAddress = _admin;
        return run();
    }
}