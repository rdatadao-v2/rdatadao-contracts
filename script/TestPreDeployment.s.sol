// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

/**
 * @title TestPreDeployment
 * @dev Simple test to verify pre-deployment readiness
 */
contract TestPreDeployment is Script {
    address constant EXPECTED_DEPLOYER = 0x58eCB94e6F5e6521228316b55c465ad2A2938FbB;
    address constant VANA_MULTISIG = 0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319;
    address constant BASE_MULTISIG = 0x90013583c66D2bf16327cB5Bc4a647AcceCF4B9A;

    function run() external view {
        console2.log("\n=== Pre-Deployment Test ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("Sender:", msg.sender);
        console2.log("Expected:", EXPECTED_DEPLOYER);

        // Check if sender matches
        if (msg.sender == EXPECTED_DEPLOYER) {
            console2.log("[PASS] Correct deployer address");

            // Check balance
            uint256 balance = EXPECTED_DEPLOYER.balance;
            console2.log("Balance:", balance / 1e18, "ETH");

            if (balance > 0.05 ether) {
                console2.log("[PASS] Sufficient balance for deployment");
            } else {
                console2.log("[WARN] Low balance, may need more funds");
            }

            // Check multisig
            address multisig = block.chainid == 1480 || block.chainid == 14800 ? VANA_MULTISIG : BASE_MULTISIG;

            console2.log("Multisig:", multisig);
            console2.log("Multisig balance:", multisig.balance / 1e18, "ETH");

            console2.log("\n[SUCCESS] Pre-deployment check complete!");
        } else {
            console2.log("[FAIL] Wrong deployer address!");
        }
    }
}
