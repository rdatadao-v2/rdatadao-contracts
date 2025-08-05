// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BaseDeployScript} from "../shared/BaseDeployScript.sol";
import {MockRDAT} from "../../src/mocks/MockRDAT.sol";
import {console} from "forge-std/console.sol";

/**
 * @title DeployMockRDAT
 * @notice Deployment script for MockRDAT token (replicating Base mainnet RDAT)
 * @dev Deploy with: forge script script/mocks/DeployMockRDAT.s.sol:DeployMockRDAT --rpc-url $RPC_URL --broadcast
 */
contract DeployMockRDAT is BaseDeployScript {
    MockRDAT public mockRDAT;
    
    // Base mainnet RDAT address for reference
    address constant BASE_MAINNET_RDAT = 0x4498cd8ba045e00673402353f5a4347562707e7d;
    
    function deploy() internal override {
        console.log("Deploying MockRDAT token...");
        console.log("Replicating Base mainnet RDAT at:", BASE_MAINNET_RDAT);
        
        mockRDAT = new MockRDAT(deployer);
        
        console.log("MockRDAT deployed at:", address(mockRDAT));
        console.log("Total supply:", mockRDAT.totalSupply());
        console.log("Deployer balance:", mockRDAT.balanceOf(deployer));
        
        // Log deployment info for migration testing
        console.log("\n=== Deployment Summary ===");
        console.log("Network:", block.chainid);
        console.log("MockRDAT address:", address(mockRDAT));
        console.log("Use this address in migration contract tests");
    }
}