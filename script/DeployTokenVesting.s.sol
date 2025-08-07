// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../src/TokenVesting.sol";

contract DeployTokenVesting is Script {
    function run() external {
        // Use environment variables or default to local values
        address rdatToken = vm.envOr("RDAT_ADDRESS", address(0xeC31f163d2ba0DBa1F579F2C86BE01531AC515bD));
        address admin = vm.envOr("ADMIN_ADDRESS", address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266));

        console2.log("=== TokenVesting Deployment ===");
        console2.log("RDAT Token:", rdatToken);
        console2.log("Admin:", admin);

        vm.startBroadcast();

        // Deploy TokenVesting
        TokenVesting tokenVesting = new TokenVesting(rdatToken, admin);

        console2.log("TokenVesting deployed at:", address(tokenVesting));

        // Setup team beneficiaries (example)
        address alice = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // Second anvil account
        address bob = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC; // Third anvil account

        tokenVesting.addBeneficiary(alice, 3_000_000e18); // 3M RDAT
        tokenVesting.addBeneficiary(bob, 2_000_000e18); // 2M RDAT

        console2.log("Added beneficiaries:");
        console2.log("- Alice:", alice, "- 3M RDAT");
        console2.log("- Bob:", bob, "- 2M RDAT");
        console2.log("Total allocated:", tokenVesting.totalAllocated() / 1e18, "RDAT");

        vm.stopBroadcast();

        console2.log("=== Deployment Complete ===");
        console2.log("Next steps:");
        console2.log("1. Transfer tokens from Treasury to TokenVesting");
        console2.log("2. Set eligibility date when DLP rewards confirmed");
    }
}
