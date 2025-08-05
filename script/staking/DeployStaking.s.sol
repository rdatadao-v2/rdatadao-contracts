// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BaseDeployScript} from "../shared/BaseDeployScript.sol";
import {console} from "forge-std/console.sol";
import {StakingManager} from "../../src/staking/StakingManager.sol";
import {vRDAT} from "../../src/staking/vRDAT.sol";
import {StakingPositionNFT} from "../../src/staking/StakingPositionNFT.sol";
import {RewardProgramManager} from "../../src/staking/RewardProgramManager.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title DeployStaking
 * @notice Deploys the complete staking system
 * @dev Includes StakingManager, vRDAT, Position NFT, and Reward Manager
 */
contract DeployStaking is BaseDeployScript {
    // Deployed contracts
    address public stakingManager;
    address public vRDAT;
    address public positionNFT;
    address public rewardManager;
    
    // Configuration
    address public rdatToken; // Should be set to deployed RDAT address
    address public treasury; // Treasury for penalties and fees
    
    function deploy() internal override {
        console.log("=== Deploying RDAT Staking System ===");
        
        // Set default addresses - should be updated for production
        rdatToken = address(0); // Set to deployed RDAT token address
        treasury = deployer; // Set to treasury/multisig address
        
        console.log("RDAT Token:", rdatToken);
        console.log("Treasury:", treasury);
        
        // Step 1: Deploy vRDAT (governance token)
        console.log("\n1. Deploying vRDAT...");
        vRDAT vrdat = new vRDAT();
        vRDAT = address(vrdat);
        console.log("vRDAT deployed at:", vRDAT);
        
        // Step 2: Deploy Position NFT
        console.log("\n2. Deploying StakingPositionNFT...");
        StakingPositionNFT nft = new StakingPositionNFT();
        positionNFT = address(nft);
        console.log("Position NFT deployed at:", positionNFT);
        
        // Step 3: Deploy Reward Program Manager
        console.log("\n3. Deploying RewardProgramManager...");
        RewardProgramManager rewards = new RewardProgramManager(treasury);
        rewardManager = address(rewards);
        console.log("Reward Manager deployed at:", rewardManager);
        
        // Step 4: Deploy Staking Manager (main contract)
        console.log("\n4. Deploying StakingManager...");
        
        // Deploy implementation
        StakingManager implementation = new StakingManager();
        console.log("StakingManager implementation:", address(implementation));
        
        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            StakingManager.initialize.selector,
            rdatToken,
            vRDAT,
            positionNFT,
            rewardManager,
            treasury
        );
        
        // Deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        stakingManager = address(proxy);
        console.log("Staking Manager deployed at:", stakingManager);
        
        // Step 5: Configure contracts
        console.log("\n5. Configuring contracts...");
        
        // Grant roles
        console.log("- Granting StakingManager minter role on vRDAT");
        bytes32 MINTER_ROLE = keccak256("MINTER_ROLE");
        bytes32 BURNER_ROLE = keccak256("BURNER_ROLE");
        bytes32 STAKING_MANAGER_ROLE = keccak256("STAKING_MANAGER_ROLE");
        
        vrdat.grantRole(MINTER_ROLE, stakingManager);
        vrdat.grantRole(BURNER_ROLE, stakingManager);
        
        console.log("- Granting StakingManager minter role on Position NFT");
        nft.grantRole(MINTER_ROLE, stakingManager);
        nft.grantRole(BURNER_ROLE, stakingManager);
        
        console.log("- Granting StakingManager role on Reward Manager");
        rewards.grantRole(STAKING_MANAGER_ROLE, stakingManager);
        
        console.log("- Setting up initial reward programs");
        if (rdatToken != address(0)) {
            // Create base RDAT rewards program (1 year, 10% APR)
            uint256 rewardAmount = 1_000_000e18; // 1M RDAT for rewards
            uint256 duration = 365 days;
            uint256 baseAPR = 1000; // 10% in basis points
            
            // Transfer rewards to contract first
            IERC20(rdatToken).transfer(address(rewards), rewardAmount);
            
            // Create program
            rewards.createRewardProgram(
                IERC20(rdatToken),
                rewardAmount,
                duration,
                baseAPR
            );
            
            console.log("- Created base RDAT reward program");
        }
        
        // Step 6: Initialize staking parameters
        console.log("\n6. Setting initial parameters...");
        console.log("- Min stake: 100 RDAT");
        console.log("- Max stake: 10,000,000 RDAT");
        console.log("- Lock periods: 30, 90, 180, 365 days");
        console.log("- Multipliers: 1x, 1.5x, 2x, 4x");
        
        // Summary
        console.log("\n=== Deployment Summary ===");
        console.log("Network:", block.chainid);
        console.log("Staking Manager:", stakingManager);
        console.log("vRDAT Token:", vRDAT);
        console.log("Position NFT:", positionNFT);
        console.log("Reward Manager:", rewardManager);
        
        console.log("\n=== Next Steps ===");
        console.log("1. Fund reward programs with RDAT");
        console.log("2. Set up additional reward programs");
        console.log("3. Configure validator registry (if applicable)");
        console.log("4. Transfer ownership to multi-sig");
    }
}