// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BaseDeployScript} from "../shared/BaseDeployScript.sol";
import {Counter} from "../../src/Counter.sol";
import {console} from "forge-std/console.sol";

contract DeployCounterBase is BaseDeployScript {
    Counter public counter;
    
    function deploy() internal override {
        console.log("Deploying Counter to Base...");
        
        counter = new Counter();
        
        console.log("Counter deployed at:", address(counter));
        
        // Base-specific initialization
        counter.setNumber(100); // Start at 100 for Base
        console.log("Initial number set to:", counter.number());
    }
}