// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BaseDeployScript} from "../shared/BaseDeployScript.sol";
import {MockRDAT} from "../../src/mocks/MockRDAT.sol";
import {console2} from "forge-std/console2.sol";

/**
 * @title DeployMockRDAT
 * @notice Deployment script for MockRDAT token (replicating Base mainnet RDAT)
 * @dev Deploy with: forge script script/mocks/DeployMockRDAT.s.sol:DeployMockRDAT --rpc-url $RPC_URL --broadcast
 */
contract DeployMockRDAT is BaseDeployScript {
    MockRDAT public mockRDAT;

    // Base mainnet RDAT address for reference
    address constant BASE_MAINNET_RDAT = 0x4498cd8Ba045E00673402353f5a4347562707e7D;

    function deploy() internal override {
        console2.log("Deploying MockRDAT token...");
        console2.log("Replicating Base mainnet RDAT at:", BASE_MAINNET_RDAT);

        mockRDAT = new MockRDAT(deployer);

        console2.log("MockRDAT deployed at:", address(mockRDAT));
        console2.log("Total supply:", mockRDAT.totalSupply());
        console2.log("Deployer balance:", mockRDAT.balanceOf(deployer));

        // Log deployment info for migration testing
        console2.log("\n=== Deployment Summary ===");
        console2.log("Network:", block.chainid);
        console2.log("MockRDAT address:", address(mockRDAT));
        console2.log("Use this address in migration contract tests");
    }
}
