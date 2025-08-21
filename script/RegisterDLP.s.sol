// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../src/RDATUpgradeable.sol";

// DLP Registration struct
struct DLPInfo {
    address dlpAddress;
    address ownerAddress;
    address treasuryAddress;
    string name;
    string iconUrl;
    string website;
    string metadata;
}

interface IDLPRegistryProxy {
    function registerDlp(DLPInfo calldata dlpInfo) external payable;

    function dlpIds(address dlpAddress) external view returns (uint256);

    function dlps(uint256 dlpId)
        external
        view
        returns (
            address dlpAddress,
            address ownerAddress,
            address treasuryAddress,
            string memory name,
            string memory iconUrl,
            string memory website,
            string memory metadata,
            bool isActive,
            uint256 createdAt,
            uint256 updatedAt
        );
}

/**
 * @title RegisterDLP
 * @notice Script to register r/datadao as a DLP on Vana network
 * @dev Registers the RDATDataDAO contract with Vana's DLPRegistryProxy
 *
 * Required environment variables:
 * - RDAT_DATA_DAO_ADDRESS: The deployed RDATDataDAO contract address
 * - RDAT_TOKEN_ADDRESS: The deployed RDAT token address (for updating)
 * - TREASURY_ADDRESS: The treasury address for the DLP
 * - ADMIN_ADDRESS: The admin address for the DLP
 *
 * Usage:
 * forge script script/RegisterDLP.s.sol:RegisterDLP \
 *   --rpc-url $VANA_RPC_URL \
 *   --broadcast \
 *   --private-key $DEPLOYER_PRIVATE_KEY \
 *   -vvvv
 */
contract RegisterDLP is Script {
    // Vana DLPRegistryProxy addresses
    address constant DLP_REGISTRY_MAINNET = 0x4D59880a924526d1dD33260552Ff4328b1E18a43;
    address constant DLP_REGISTRY_MOKSHA = 0x4D59880a924526d1dD33260552Ff4328b1E18a43; // Same on testnet
    
    // Alternative registry address from Vana docs (doesn't work with current interface)
    // address constant DLP_REGISTRY_MOKSHA_ALT = 0x8C8788f98385F6ba1adD4234e551ABba0f82Cb7C;

    // Registration fee
    uint256 constant REGISTRATION_FEE = 1 ether; // 1 VANA

    // r/datadao DLP information
    string constant DLP_NAME = "r/datadao";
    string constant DLP_ICON = "https://rdatadao.org/logo.png"; // Update with actual logo URL
    string constant DLP_WEBSITE = "https://rdatadao.org";
    string constant DLP_METADATA =
        '{"description":"Reddit Data DAO","type":"SocialMedia","dataSource":"Reddit","version":"2.0"}';

    function run() external {
        // Get deployment parameters from environment
        address rdatDataDAO = vm.envAddress("RDAT_DATA_DAO_ADDRESS"); // The DLP contract
        address rdatToken = vm.envAddress("RDAT_TOKEN_ADDRESS"); // The token contract (for updating later)
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        address admin = vm.envAddress("ADMIN_ADDRESS");

        // Determine which network we're on
        uint256 chainId = block.chainid;
        address dlpRegistry;

        if (chainId == 1480) {
            // Vana Mainnet
            dlpRegistry = DLP_REGISTRY_MAINNET;
            console2.log("Using Vana Mainnet DLP Registry:", dlpRegistry);
        } else if (chainId == 14800) {
            // Vana Moksha Testnet
            dlpRegistry = DLP_REGISTRY_MOKSHA;
            console2.log("Using Vana Moksha DLP Registry:", dlpRegistry);
        } else {
            revert("Unsupported network - must be Vana Mainnet (1480) or Moksha (14800)");
        }

        // Start broadcasting transactions
        vm.startBroadcast();

        // Step 1: Check if already registered
        IDLPRegistryProxy registry = IDLPRegistryProxy(dlpRegistry);
        uint256 existingDlpId = registry.dlpIds(rdatDataDAO);

        if (existingDlpId > 0) {
            console2.log("DLP already registered with ID:", existingDlpId);

            // Get registration details
            (address dlpAddress, address ownerAddress, address treasuryAddress, string memory name,,,,,,) =
                registry.dlps(existingDlpId);

            console2.log("  DLP Address:", dlpAddress);
            console2.log("  Owner:", ownerAddress);
            console2.log("  Treasury:", treasuryAddress);
            console2.log("  Name:", name);

            // Update our contract with the DLP ID
            RDATUpgradeable rdat = RDATUpgradeable(rdatToken);
            if (!rdat.dlpRegistered() || rdat.dlpId() != existingDlpId) {
                console2.log("\nUpdating RDAT contract with DLP registration...");
                rdat.setDLPRegistry(dlpRegistry);
                rdat.updateDLPRegistration(existingDlpId);
                console2.log("[OK] RDAT contract updated with DLP ID:", existingDlpId);
            }

            vm.stopBroadcast();
            return;
        }

        // Step 2: Register as new DLP
        console2.log("\n[START] Registering r/datadao as DLP on Vana...");
        console2.log("  DLP Contract Address:", rdatDataDAO);
        console2.log("  Token Address:", rdatToken);
        console2.log("  Owner Address:", admin);
        console2.log("  Treasury Address:", treasury);
        console2.log("  Name:", DLP_NAME);
        console2.log("  Registration Fee:", REGISTRATION_FEE / 1e18, "VANA");

        // Check balance for registration fee (use msg.sender which is the deployer)
        uint256 balance = msg.sender.balance;
        require(balance >= REGISTRATION_FEE, "Insufficient VANA for registration fee");

        // Create DLP info struct
        DLPInfo memory dlpInfo = DLPInfo({
            dlpAddress: rdatDataDAO,
            ownerAddress: admin,
            treasuryAddress: treasury,
            name: DLP_NAME,
            iconUrl: DLP_ICON,
            website: DLP_WEBSITE,
            metadata: DLP_METADATA
        });

        // Register the DLP using struct
        registry.registerDlp{value: REGISTRATION_FEE}(dlpInfo);

        // Step 3: Get the assigned DLP ID
        uint256 dlpId = registry.dlpIds(rdatDataDAO);
        require(dlpId > 0, "Registration failed - no DLP ID assigned");

        console2.log("\n[OK] Successfully registered as DLP!");
        console2.log("  DLP ID:", dlpId);

        // Step 4: Update our RDAT contract with DLP info (SKIPPED - can be done manually later)
        console2.log("\n[SKIP] RDAT contract update skipped for now");
        console2.log("  DLP registration succeeded - token updates can be done separately");
        // RDATUpgradeable rdatContract = RDATUpgradeable(rdatToken);
        // rdatContract.setDLPRegistry(dlpRegistry);
        // rdatContract.updateDLPRegistration(dlpId);

        // Step 5: Verify registration
        console2.log("\n[VERIFY] Verifying registration...");
        console2.log("  DLP ID:", dlpId);

        vm.stopBroadcast();

        console2.log("\n[SUCCESS] DLP Registration Complete!");
        console2.log("Use this DLP ID for all Vana operations:", dlpId);
    }

    /**
     * @notice Check DLP registration status without registering
     */
    function check() external view {
        address rdatDataDAO = vm.envAddress("RDAT_DATA_DAO_ADDRESS");
        address rdatToken = vm.envAddress("RDAT_TOKEN_ADDRESS");

        uint256 chainId = block.chainid;
        address dlpRegistry = (chainId == 1480) ? DLP_REGISTRY_MAINNET : DLP_REGISTRY_MOKSHA;

        IDLPRegistryProxy registry = IDLPRegistryProxy(dlpRegistry);
        uint256 dlpId = registry.dlpIds(rdatDataDAO);

        if (dlpId == 0) {
            console2.log("[ERROR] DLP not registered");
            console2.log("  RDATDataDAO Address:", rdatDataDAO);
            console2.log("  Run this script with --broadcast to register");
        } else {
            console2.log("[OK] DLP is registered!");
            console2.log("  DLP ID:", dlpId);
            console2.log("  RDATDataDAO Address:", rdatDataDAO);
            console2.log("  RDAT Token Address:", rdatToken);
        }
    }
}
