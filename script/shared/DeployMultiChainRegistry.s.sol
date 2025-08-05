// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BaseDeployScript} from "./BaseDeployScript.sol";
import {MultiChainRegistry} from "../../src/shared/MultiChainRegistry.sol";
import {console} from "forge-std/console.sol";

contract DeployMultiChainRegistry is BaseDeployScript {
    MultiChainRegistry public registry;
    
    function deploy() internal override {
        console.log("Deploying MultiChainRegistry...");
        
        registry = new MultiChainRegistry();
        
        console.log("MultiChainRegistry deployed at:", address(registry));
        console.log("Deployed on chain:", registry.getChainName());
    }
}