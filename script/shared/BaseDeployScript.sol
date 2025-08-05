// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

abstract contract BaseDeployScript is Script {
    uint256 public deployerPrivateKey;
    address public deployer;
    
    modifier broadcast() {
        vm.startBroadcast(deployerPrivateKey);
        _;
        vm.stopBroadcast();
    }
    
    function setUp() public virtual {
        deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deployer address:", deployer);
        console.log("Chain ID:", block.chainid);
    }
    
    function run() public virtual {
        setUp();
        deploy();
    }
    
    function deploy() internal virtual;
}