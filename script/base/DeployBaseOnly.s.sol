// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BaseDeployScript} from "../shared/BaseDeployScript.sol";
import {BaseOnlyContract} from "../../src/base/BaseOnlyContract.sol";
import {console} from "forge-std/console.sol";

contract DeployBaseOnly is BaseDeployScript {
    BaseOnlyContract public baseContract;
    
    function deploy() internal override {
        console.log("Deploying BaseOnlyContract to Base...");
        
        baseContract = new BaseOnlyContract();
        
        console.log("BaseOnlyContract deployed at:", address(baseContract));
        console.log("Greeting:", baseContract.greeting());
    }
}