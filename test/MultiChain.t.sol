// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {BaseOnlyContract} from "../src/base/BaseOnlyContract.sol";
import {VanaDataContract} from "../src/vana/VanaDataContract.sol";
import {MultiChainRegistry} from "../src/shared/MultiChainRegistry.sol";

contract MultiChainTest is Test {
    function setUp() public {
        // Setup is minimal as contracts will be deployed in individual tests
    }
    
    function test_BaseOnlyContract_Deployment() public {
        // This test should only pass on Base chains
        if (block.chainid == 8453 || block.chainid == 84532) {
            BaseOnlyContract baseContract = new BaseOnlyContract();
            assertEq(baseContract.greeting(), "Hello from Base!");
            console.log("BaseOnlyContract deployed successfully on Base chain:", block.chainid);
        } else {
            vm.expectRevert("This contract can only be deployed on Base");
            new BaseOnlyContract();
            console.log("BaseOnlyContract correctly rejected on non-Base chain:", block.chainid);
        }
    }
    
    function test_VanaDataContract_Deployment() public {
        // This test should only pass on Vana chains
        if (block.chainid == 1480 || block.chainid == 14800) {
            VanaDataContract vanaContract = new VanaDataContract();
            assertEq(vanaContract.nextDataId(), 1);
            console.log("VanaDataContract deployed successfully on Vana chain:", block.chainid);
        } else {
            vm.expectRevert("This contract can only be deployed on Vana");
            new VanaDataContract();
            console.log("VanaDataContract correctly rejected on non-Vana chain:", block.chainid);
        }
    }
    
    function test_MultiChainRegistry_Deployment() public {
        // This should work on all chains
        MultiChainRegistry registry = new MultiChainRegistry();
        
        if (block.chainid == 8453 || block.chainid == 84532) {
            assertEq(registry.getChainName(), "Base");
            console.log("MultiChainRegistry deployed on Base");
        } else if (block.chainid == 1480 || block.chainid == 14800) {
            assertEq(registry.getChainName(), "Vana");
            console.log("MultiChainRegistry deployed on Vana");
        } else {
            assertEq(registry.getChainName(), "Other");
            console.log("MultiChainRegistry deployed on Other chain");
        }
    }
    
    function test_MultiChainRegistry_ChainSpecificBehavior() public {
        MultiChainRegistry registry = new MultiChainRegistry();
        
        // Register a user
        registry.register();
        
        // Check chain-specific initial scores
        if (block.chainid == 8453 || block.chainid == 84532) {
            assertEq(registry.userScores(address(this)), 100);
            console.log("Base user registered with score:", 100);
            
            // Test Base-specific score limit
            registry.updateScore(address(this), 1000);
            vm.expectRevert("Base: Score cannot exceed 1000");
            registry.updateScore(address(this), 1001);
        } else if (block.chainid == 1480 || block.chainid == 14800) {
            assertEq(registry.userScores(address(this)), 200);
            console.log("Vana user registered with score:", 200);
            
            // Test Vana-specific score limit
            registry.updateScore(address(this), 2000);
            vm.expectRevert("Vana: Score cannot exceed 2000");
            registry.updateScore(address(this), 2001);
        } else {
            assertEq(registry.userScores(address(this)), 50);
            console.log("Other chain user registered with score:", 50);
        }
    }
}