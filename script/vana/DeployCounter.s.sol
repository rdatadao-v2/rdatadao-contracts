// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BaseDeployScript} from "../shared/BaseDeployScript.sol";
import {Counter} from "../../src/Counter.sol";
import {console} from "forge-std/console.sol";

contract DeployCounterVana is BaseDeployScript {
    Counter public counter;
    
    function deploy() internal override {
        console.log("Deploying Counter to Vana...");
        
        counter = new Counter();
        
        console.log("Counter deployed at:", address(counter));
        
        // Vana-specific initialization
        counter.setNumber(200); // Start at 200 for Vana
        console.log("Initial number set to:", counter.number());
    }
}