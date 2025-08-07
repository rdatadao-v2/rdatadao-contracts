// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title TestHelpers
 * @dev Common testing utilities and helpers for RDAT tests
 */
contract TestHelpers is Test {
    // Common test addresses
    address public constant ZERO_ADDRESS = address(0);
    address public treasury = makeAddr("treasury");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    // Common test amounts
    uint256 public constant ONE_RDAT = 1e18;
    uint256 public constant THOUSAND_RDAT = 1000e18;
    uint256 public constant MILLION_RDAT = 1_000_000e18;

    // Time constants
    uint256 public constant ONE_DAY = 1 days;
    uint256 public constant ONE_WEEK = 7 days;
    uint256 public constant THIRTY_DAYS = 30 days;
    uint256 public constant NINETY_DAYS = 90 days;
    uint256 public constant ONE_YEAR = 365 days;

    // Helper functions
    function advanceTime(uint256 duration) internal {
        skip(duration);
    }

    function advanceBlocks(uint256 blocks) internal {
        vm.roll(block.number + blocks);
    }

    function expectAccessControlRevert(address account, bytes32 role) internal {
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("AccessControlUnauthorizedAccount(address,bytes32)")), account, role
            )
        );
    }

    /**
     * @dev Labels common addresses for better test output
     */
    function labelAddresses() internal {
        vm.label(treasury, "Treasury");
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(charlie, "Charlie");
    }
}
