// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../src/EmergencyPause.sol";
import "../src/vRDAT.sol";
import "../src/ProofOfContributionStub.sol";
import "../src/mocks/MockGovernance.sol";
import "../src/governance/GovernanceCore.sol";
import "../src/governance/GovernanceVoting.sol";
import "../src/governance/GovernanceExecution.sol";

/**
 * @title DeploySimple
 * @notice Simple deployment script to test compilation
 * @dev Deploys contracts one at a time to avoid stack issues
 */
contract DeploySimple is Script {
    // Deployment results
    address public emergencyPause;
    address public vrdatToken;
    address public pocStub;
    address public governance;
    address public governanceCore;
    address public governanceVoting;
    address payable public governanceExecution;
    
    function run() external {
        address admin = vm.envAddress("ADMIN_ADDRESS");
        address dlpAddress = vm.envAddress("DLP_ADDRESS");
        
        console.log("Starting simple deployment...");
        console.log("Admin:", admin);
        console.log("DLP:", dlpAddress);
        
        vm.startBroadcast();
        
        // Deploy EmergencyPause
        console.log("\n1. Deploying EmergencyPause...");
        emergencyPause = address(new EmergencyPause(admin));
        console.log("   Deployed at:", emergencyPause);
        
        // Deploy vRDAT
        console.log("\n2. Deploying vRDAT...");
        vrdatToken = address(new vRDAT(admin));
        console.log("   Deployed at:", vrdatToken);
        
        // Deploy ProofOfContributionStub
        console.log("\n3. Deploying ProofOfContributionStub...");
        pocStub = address(new ProofOfContributionStub(admin, dlpAddress));
        console.log("   Deployed at:", pocStub);
        
        // Deploy MockGovernance
        console.log("\n4. Deploying MockGovernance...");
        governance = address(new MockGovernance());
        console.log("   Deployed at:", governance);
        
        // Deploy Modular Governance Components
        console.log("\n5. Deploying GovernanceCore...");
        governanceCore = address(new GovernanceCore(admin));
        console.log("   Deployed at:", governanceCore);
        
        console.log("\n6. Deploying GovernanceVoting...");
        governanceVoting = address(new GovernanceVoting(vrdatToken, admin));
        console.log("   Deployed at:", governanceVoting);
        
        console.log("\n7. Deploying GovernanceExecution...");
        governanceExecution = payable(address(new GovernanceExecution(admin)));
        console.log("   Deployed at:", governanceExecution);
        
        // Configure governance modules
        console.log("\n8. Configuring governance modules...");
        GovernanceVoting(governanceVoting).setGovernanceCore(governanceCore);
        GovernanceExecution(governanceExecution).setGovernanceCore(governanceCore);
        vRDAT(vrdatToken).grantRole(keccak256("GOVERNANCE_ROLE"), governanceVoting);
        console.log("   Governance modules configured");
        
        vm.stopBroadcast();
        
        // Summary
        console.log("\n=== Deployment Summary ===");
        console.log("EmergencyPause:", emergencyPause);
        console.log("vRDAT:", vrdatToken);
        console.log("ProofOfContribution:", pocStub);
        console.log("MockGovernance:", governance);
        console.log("GovernanceCore:", governanceCore);
        console.log("GovernanceVoting:", governanceVoting);
        console.log("GovernanceExecution:", governanceExecution);
        console.log("\nDeployment complete!");
    }
    
    function dryRun() external view {
        address admin = vm.envOr("ADMIN_ADDRESS", address(0x1));
        address dlp = vm.envOr("DLP_ADDRESS", address(0x2));
        address deployer = vm.envOr("DEPLOYER_ADDRESS", msg.sender);
        
        console.log("=== Dry Run ===");
        console.log("Admin:", admin);
        console.log("DLP:", dlp);
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        
        console.log("\nExpected deployment order:");
        console.log("1. EmergencyPause");
        console.log("2. vRDAT");
        console.log("3. ProofOfContributionStub");
        console.log("4. MockGovernance");
        console.log("5. GovernanceCore");
        console.log("6. GovernanceVoting");
        console.log("7. GovernanceExecution");
        console.log("8. Configure governance modules");
    }
}