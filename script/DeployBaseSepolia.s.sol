// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/BaseMigrationBridge.sol";

contract DeployBaseSepolia is Script {
    function run() external {
        // Get deployment parameters
        address admin = vm.envAddress("ADMIN_ADDRESS");
        require(admin != address(0), "ADMIN_ADDRESS not set");

        console2.log("Deploying to Base Sepolia...");
        console2.log("  Admin:", admin);

        vm.startBroadcast();

        // 1. Deploy Mock V1 RDAT Token (for testing)
        console2.log("\n1. Deploying Mock V1 RDAT Token...");
        MockRDATv1 v1Token = new MockRDATv1();
        console2.log("  Mock V1 RDAT deployed at:", address(v1Token));
        console2.log("  Total Supply:", v1Token.totalSupply());

        // 2. Deploy BaseMigrationBridge
        console2.log("\n2. Deploying BaseMigrationBridge...");
        BaseMigrationBridge bridge = new BaseMigrationBridge(address(v1Token), admin);
        console2.log("  BaseMigrationBridge deployed at:", address(bridge));

        // 3. Configure bridge
        console2.log("\n3. Configuring bridge...");
        // In production, the bridge would need to be funded with V2 tokens
        // For testing, we'll just note this requirement
        console2.log("  Note: Bridge needs to be funded with V2 tokens for migration");

        // 4. Mint some V1 tokens to test addresses (for testing)
        console2.log("\n4. Minting test V1 tokens...");
        address[] memory testAddresses = new address[](3);
        testAddresses[0] = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // Test address 1
        testAddresses[1] = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC; // Test address 2
        testAddresses[2] = 0x90F79bf6EB2c4f870365E785982E1f101E93b906; // Test address 3

        for (uint256 i = 0; i < testAddresses.length; i++) {
            v1Token.mint(testAddresses[i], 1000 * 10 ** 18); // 1000 tokens each
            console2.log("  Minted 1000 V1 tokens to:", testAddresses[i]);
        }

        vm.stopBroadcast();

        // Summary
        console2.log("\n========================================");
        console2.log("     Base Sepolia Deployment Complete");
        console2.log("========================================");
        console2.log("Mock V1 Token:", address(v1Token));
        console2.log("Migration Bridge:", address(bridge));
        console2.log("");
        console2.log("Test tokens minted to 3 addresses");
        console2.log("");
        console2.log("Next steps:");
        console2.log("1. Fund bridge with V2 tokens");
        console2.log("2. Test migration flow");
        console2.log("3. Verify contracts on Basescan");
    }
}

contract MockRDATv1 is ERC20 {
    constructor() ERC20("r/datadao V1", "RDATv1") {
        // Mint 30M tokens (matching V1 supply)
        _mint(msg.sender, 30_000_000 * 10 ** 18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
