// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";
import {TestHelpers} from "../TestHelpers.sol";

/**
 * @title SetupTest
 * @dev Basic test to verify our testing framework is properly configured
 */
contract SetupTest is TestHelpers {
    function setUp() public {
        labelAddresses();
    }
    
    function test_SetupWorks() public view {
        assertEq(block.chainid, 31337, "Should be on Anvil");
        assertTrue(treasury != address(0), "Treasury should be set");
        assertTrue(alice != address(0), "Alice should be set");
    }
    
    function test_TimeHelpers() public {
        uint256 startTime = block.timestamp;
        advanceTime(ONE_DAY);
        assertEq(block.timestamp, startTime + ONE_DAY, "Time should advance by 1 day");
    }
    
    function test_BlockHelpers() public {
        uint256 startBlock = block.number;
        advanceBlocks(10);
        assertEq(block.number, startBlock + 10, "Should advance 10 blocks");
    }
}