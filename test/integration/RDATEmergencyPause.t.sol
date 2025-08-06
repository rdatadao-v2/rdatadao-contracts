// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {RDATUpgradeable} from "../../src/RDATUpgradeable.sol";
import {EmergencyPause} from "../../src/EmergencyPause.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title RDATEmergencyPauseIntegration
 * @notice Integration test showing how RDAT can integrate with EmergencyPause
 * @dev This demonstrates a pattern where RDAT checks the emergency pause state
 */
contract RDATEmergencyPauseIntegration is Test {
    RDATUpgradeable public implementation;
    RDATUpgradeable public rdat;
    EmergencyPause public emergencyPause;
    
    address public admin;
    address public treasury;
    address public pauser;
    address public guardian;
    address public user1;
    address public user2;
    
    bytes32 public constant PAUSER_MANAGER_ROLE = keccak256("PAUSER_MANAGER_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    function setUp() public {
        admin = makeAddr("admin");
        treasury = makeAddr("treasury");
        pauser = makeAddr("pauser");
        guardian = makeAddr("guardian");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // Deploy EmergencyPause
        vm.prank(admin);
        emergencyPause = new EmergencyPause(admin);
        
        // Setup emergency pause roles
        vm.startPrank(admin);
        emergencyPause.grantRole(GUARDIAN_ROLE, guardian);
        emergencyPause.addPauser(pauser);
        vm.stopPrank();
        
        // Deploy RDAT with proxy
        implementation = new RDATUpgradeable();
        
        bytes memory initData = abi.encodeWithSelector(
            RDATUpgradeable.initialize.selector,
            treasury,
            admin,
            address(0x100) // migration contract address
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );
        
        rdat = RDATUpgradeable(address(proxy));
        
        // Give users some tokens
        vm.startPrank(treasury);
        rdat.transfer(user1, 1000 * 10**18);
        rdat.transfer(user2, 1000 * 10**18);
        vm.stopPrank();
    }
    
    function test_NormalOperationWhenNotPaused() public {
        // Transfers work normally
        uint256 amount = 100 * 10**18;
        
        vm.prank(user1);
        rdat.transfer(user2, amount);
        
        assertEq(rdat.balanceOf(user1), 900 * 10**18);
        assertEq(rdat.balanceOf(user2), 1100 * 10**18);
    }
    
    function test_EmergencyPauseScenario() public {
        // Initial state - transfers work
        vm.prank(user1);
        rdat.transfer(user2, 50 * 10**18);
        
        // Emergency detected - pause the system
        vm.prank(pauser);
        emergencyPause.emergencyPause();
        assertTrue(emergencyPause.emergencyPaused());
        
        // Now we need to pause RDAT manually (since it has its own pause mechanism)
        vm.prank(admin);
        rdat.pause();
        
        // Transfers should now fail
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        rdat.transfer(user2, 50 * 10**18);
        
        // Guardian resolves the issue and unpauses emergency system
        vm.prank(guardian);
        emergencyPause.emergencyUnpause();
        assertFalse(emergencyPause.emergencyPaused());
        
        // Admin unpauses RDAT
        vm.prank(admin);
        rdat.unpause();
        
        // Transfers work again
        vm.prank(user1);
        rdat.transfer(user2, 50 * 10**18);
        
        assertEq(rdat.balanceOf(user1), 900 * 10**18);  // 1000 - 50 - 50
        assertEq(rdat.balanceOf(user2), 1100 * 10**18); // 1000 + 50 + 50
    }
    
    function test_AutoExpiryIntegration() public {
        // Pause emergency system
        vm.prank(pauser);
        emergencyPause.emergencyPause();
        
        // Pause RDAT
        vm.prank(admin);
        rdat.pause();
        
        // Fast forward past emergency pause expiry
        vm.warp(block.timestamp + emergencyPause.PAUSE_DURATION() + 1);
        
        // Emergency pause has expired
        assertFalse(emergencyPause.emergencyPaused());
        
        // But RDAT is still paused (needs manual unpause)
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        rdat.transfer(user2, 50 * 10**18);
        
        // Admin needs to manually unpause RDAT
        vm.prank(admin);
        rdat.unpause();
        
        // Now transfers work
        vm.prank(user1);
        rdat.transfer(user2, 50 * 10**18);
    }
    
    function test_MultipleSystemsEmergencyPause() public {
        // This test demonstrates how multiple systems can coordinate
        // In a real implementation, you might have a master emergency contract
        // that automatically pauses all registered contracts
        
        // Create a second token for demonstration
        RDATUpgradeable implementation2 = new RDATUpgradeable();
        bytes memory initData2 = abi.encodeWithSelector(
            RDATUpgradeable.initialize.selector,
            treasury,
            admin,
            address(0x200) // migration contract address
        );
        ERC1967Proxy proxy2 = new ERC1967Proxy(
            address(implementation2),
            initData2
        );
        RDATUpgradeable rdat2 = RDATUpgradeable(address(proxy2));
        
        // Emergency pause triggered
        vm.prank(pauser);
        emergencyPause.emergencyPause();
        
        // Admin pauses both systems
        vm.startPrank(admin);
        rdat.pause();
        rdat2.pause();
        vm.stopPrank();
        
        // Both systems are paused
        assertTrue(rdat.paused());
        assertTrue(rdat2.paused());
        
        // Emergency resolved
        vm.prank(guardian);
        emergencyPause.emergencyUnpause();
        
        // Admin unpauses both systems
        vm.startPrank(admin);
        rdat.unpause();
        rdat2.unpause();
        vm.stopPrank();
        
        // Both systems are operational again
        assertFalse(rdat.paused());
        assertFalse(rdat2.paused());
    }
}