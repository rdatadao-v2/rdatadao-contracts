// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../src/mocks/MockRDAT.sol";

/**
 * @title MockRDATFaucet
 * @notice Faucet script to mint MockRDAT v1 tokens for testing migration
 * @dev Only works on testnets with deployed MockRDAT contract
 *
 * Usage:
 * # Mint 10000 RDAT v1 to deployer wallet (default)
 * forge script script/MockRDATFaucet.s.sol --sig "mintToDeployer(uint256)" 10000 --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY
 *
 * # Distribute tokens from deployer to tester
 * forge script script/MockRDATFaucet.s.sol --sig "distributeToTester(address,uint256)" TESTER_ADDRESS 100 --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY
 *
 * # Check balance
 * forge script script/MockRDATFaucet.s.sol --sig "checkBalance(address)" YOUR_ADDRESS --rpc-url $BASE_SEPOLIA_RPC_URL
 */
contract MockRDATFaucet is Script {
    // Deployer wallet that holds test tokens for distribution
    address constant DEPLOYER_WALLET = 0x58eCB94e6F5e6521228316b55c465ad2A2938FbB;

    // Base Sepolia MockRDAT address
    address constant MOCK_RDAT_BASE_SEPOLIA = 0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E;

    // Local test addresses (if deployed locally)
    address constant MOCK_RDAT_LOCAL = address(0);

    /**
     * @notice Mint MockRDAT tokens to the deployer wallet for distribution
     * @param amountInTokens Amount in whole tokens (will be converted to wei)
     */
    function mintToDeployer(uint256 amountInTokens) external {
        mint(DEPLOYER_WALLET, amountInTokens);
    }

    /**
     * @notice Distribute MockRDAT tokens from deployer to a tester
     * @param tester Address of the tester to receive tokens
     * @param amountInTokens Amount in whole tokens to distribute
     */
    function distributeToTester(address tester, uint256 amountInTokens) external {
        uint256 chainId = block.chainid;
        address mockRdatAddress = _getMockRDATAddress(chainId);

        require(mockRdatAddress != address(0), "MockRDAT not deployed on this network");
        require(tester != address(0), "Invalid tester address");
        require(amountInTokens > 0, "Amount must be greater than 0");

        // Convert to wei (18 decimals)
        uint256 amountInWei = amountInTokens * 1e18;

        console2.log("\n========================================");
        console2.log("    MockRDAT V1 Distribution");
        console2.log("========================================\n");
        console2.log("From Deployer:", DEPLOYER_WALLET);
        console2.log("To Tester:", tester);
        console2.log("Amount:", amountInTokens, "RDAT");
        console2.log("");

        vm.startBroadcast();

        MockRDAT mockRdat = MockRDAT(mockRdatAddress);

        // Check deployer balance
        uint256 deployerBalance = mockRdat.balanceOf(DEPLOYER_WALLET);
        console2.log("Deployer balance:", deployerBalance / 1e18, "RDAT");

        if (deployerBalance < amountInWei) {
            console2.log("ERROR: Insufficient balance in deployer wallet");
            console2.log("   Need to mint more tokens to deployer first");
            vm.stopBroadcast();
            return;
        }

        // Transfer tokens from deployer to tester
        try mockRdat.transfer(tester, amountInWei) {
            uint256 newBalance = mockRdat.balanceOf(tester);
            console2.log("SUCCESS: Distributed", amountInTokens, "RDAT to", tester);
            console2.log("Tester new balance:", newBalance / 1e18, "RDAT");
        } catch Error(string memory reason) {
            console2.log("ERROR: Failed to distribute:", reason);
        }

        vm.stopBroadcast();
    }

    /**
     * @notice Mint MockRDAT tokens to a target address (general purpose)
     * @param recipient Address to receive tokens
     * @param amountInTokens Amount in whole tokens (will be converted to wei)
     */
    function mint(address recipient, uint256 amountInTokens) public {
        uint256 chainId = block.chainid;
        address mockRdatAddress = _getMockRDATAddress(chainId);

        require(mockRdatAddress != address(0), "MockRDAT not deployed on this network");
        require(recipient != address(0), "Invalid recipient address");
        require(amountInTokens > 0, "Amount must be greater than 0");

        // Convert to wei (18 decimals)
        uint256 amountInWei = amountInTokens * 1e18;

        console2.log("\n========================================");
        console2.log("    MockRDAT V1 Faucet");
        console2.log("========================================\n");
        console2.log("Network Chain ID:", chainId);
        console2.log("MockRDAT Address:", mockRdatAddress);
        console2.log("Recipient:", recipient);
        console2.log("Amount:", amountInTokens, "RDAT");
        console2.log("");

        vm.startBroadcast();

        MockRDAT mockRdat = MockRDAT(mockRdatAddress);

        // Check if mint is blocked
        if (mockRdat.mintBlocked()) {
            console2.log("ERROR: Minting is blocked on this MockRDAT contract");
            vm.stopBroadcast();
            return;
        }

        // Check current balance
        uint256 balanceBefore = mockRdat.balanceOf(recipient);
        console2.log("Balance before:", balanceBefore / 1e18, "RDAT");

        // Mint tokens
        try mockRdat.mint(recipient, amountInWei) {
            uint256 balanceAfter = mockRdat.balanceOf(recipient);
            console2.log("SUCCESS: Minted", amountInTokens, "RDAT");
            console2.log("Balance after:", balanceAfter / 1e18, "RDAT");
        } catch Error(string memory reason) {
            console2.log("ERROR: Failed to mint:", reason);
        }

        vm.stopBroadcast();

        console2.log("");
        console2.log("Next steps for migration testing:");
        console2.log("1. Approve the migration bridge to spend your tokens:");
        console2.log("   Bridge address: 0xb7d6f8eadfD4415cb27686959f010771FE94561b");
        console2.log("2. Call migrate() on the bridge contract");
        console2.log("3. Monitor for V2 tokens on Vana network");
    }

    /**
     * @notice Check MockRDAT balance of an address
     * @param account Address to check
     */
    function checkBalance(address account) external view {
        uint256 chainId = block.chainid;
        address mockRdatAddress = _getMockRDATAddress(chainId);

        require(mockRdatAddress != address(0), "MockRDAT not deployed on this network");

        MockRDAT mockRdat = MockRDAT(mockRdatAddress);
        uint256 balance = mockRdat.balanceOf(account);

        console2.log("\n========================================");
        console2.log("    MockRDAT V1 Balance Check");
        console2.log("========================================\n");
        console2.log("Network Chain ID:", chainId);
        console2.log("MockRDAT Address:", mockRdatAddress);
        console2.log("Account:", account);
        console2.log("Balance:", balance / 1e18, "RDAT");
        console2.log("Balance (wei):", balance);
    }

    /**
     * @notice Get faucet info and instructions
     */
    function info() external view {
        uint256 chainId = block.chainid;
        address mockRdatAddress = _getMockRDATAddress(chainId);

        console2.log("\n========================================");
        console2.log("    MockRDAT V1 Faucet Information");
        console2.log("========================================\n");

        if (mockRdatAddress == address(0)) {
            console2.log("ERROR: MockRDAT not deployed on this network (Chain ID:", chainId, ")");
            console2.log("");
            console2.log("Supported networks:");
            console2.log("- Base Sepolia (Chain ID: 84532)");
            console2.log("  MockRDAT: 0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E");
            return;
        }

        MockRDAT mockRdat = MockRDAT(mockRdatAddress);

        console2.log("Network Information:");
        console2.log("- Chain ID:", chainId);
        console2.log("- MockRDAT Address:", mockRdatAddress);
        console2.log("- Deployer Wallet:", DEPLOYER_WALLET);
        console2.log("- Total Supply:", mockRdat.totalSupply() / 1e18, "RDAT");
        console2.log("- Deployer Balance:", mockRdat.balanceOf(DEPLOYER_WALLET) / 1e18, "RDAT");
        console2.log("- Mint Blocked:", mockRdat.mintBlocked());
        console2.log("");

        console2.log("Faucet Commands (Deployer-Centric):");
        console2.log("");
        console2.log("1. Mint tokens to deployer wallet (for distribution):");
        console2.log("   forge script script/MockRDATFaucet.s.sol \\");
        console2.log("     --sig \"mintToDeployer(uint256)\" 10000 \\");
        console2.log("     --rpc-url $BASE_SEPOLIA_RPC_URL \\");
        console2.log("     --broadcast --private-key $DEPLOYER_PRIVATE_KEY");
        console2.log("");
        console2.log("2. Distribute tokens to testers:");
        console2.log("   forge script script/MockRDATFaucet.s.sol \\");
        console2.log("     --sig \"distributeToTester(address,uint256)\" TESTER_ADDRESS 100 \\");
        console2.log("     --rpc-url $BASE_SEPOLIA_RPC_URL \\");
        console2.log("     --broadcast --private-key $DEPLOYER_PRIVATE_KEY");
        console2.log("");
        console2.log("3. Check any balance:");
        console2.log("   forge script script/MockRDATFaucet.s.sol \\");
        console2.log("     --sig \"checkBalance(address)\" ADDRESS \\");
        console2.log("     --rpc-url $BASE_SEPOLIA_RPC_URL");
        console2.log("");
        console2.log("4. Direct mint to specific address (if needed):");
        console2.log("   forge script script/MockRDATFaucet.s.sol \\");
        console2.log("     --sig \"mint(address,uint256)\" ADDRESS 1000 \\");
        console2.log("     --rpc-url $BASE_SEPOLIA_RPC_URL \\");
        console2.log("     --broadcast --private-key $DEPLOYER_PRIVATE_KEY");
        console2.log("");

        console2.log("Migration Bridge:");
        console2.log("- Bridge Address: 0xb7d6f8eadfD4415cb27686959f010771FE94561b");
        console2.log("- Migration flow: Base Sepolia -> Vana Moksha");
        console2.log("");
        console2.log("Testing Workflow:");
        console2.log("1. Mint large amount to deployer (e.g., 10000 RDAT)");
        console2.log("2. Distribute smaller amounts to testers (e.g., 100 RDAT each)");
        console2.log("3. Testers approve bridge and migrate tokens");
        console2.log("4. Check for V2 tokens on Vana Moksha");
    }

    /**
     * @notice Get MockRDAT address for the current network
     */
    function _getMockRDATAddress(uint256 chainId) private pure returns (address) {
        if (chainId == 84532) {
            // Base Sepolia
            return MOCK_RDAT_BASE_SEPOLIA;
        } else if (chainId == 31337 || chainId == 8453) {
            // Local Anvil or Base local
            return MOCK_RDAT_LOCAL;
        }
        return address(0);
    }
}
