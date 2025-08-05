// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BaseDeployScript} from "../shared/BaseDeployScript.sol";
import {VanaDataContract} from "../../src/vana/VanaDataContract.sol";
import {console} from "forge-std/console.sol";

contract DeployVanaData is BaseDeployScript {
    VanaDataContract public dataContract;
    
    function deploy() internal override {
        console.log("Deploying VanaDataContract to Vana...");
        
        dataContract = new VanaDataContract();
        
        console.log("VanaDataContract deployed at:", address(dataContract));
        console.log("Next data ID:", dataContract.nextDataId());
    }
}