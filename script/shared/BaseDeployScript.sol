// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

abstract contract BaseDeployScript is Script {
    uint256 public deployerPrivateKey;
    address public deployer;
    address public vanaMultisig;
    address public baseMultisig;
    address public treasury;

    // Chain IDs
    uint256 constant BASE_MAINNET = 8453;
    uint256 constant BASE_SEPOLIA = 84532;
    uint256 constant VANA_MAINNET = 1480;
    uint256 constant VANA_MOKSHA = 14800;

    modifier broadcast() {
        vm.startBroadcast(deployerPrivateKey);
        _;
        vm.stopBroadcast();
    }

    function setUp() public virtual {
        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        deployer = vm.addr(deployerPrivateKey);

        // Load multisig addresses from env
        vanaMultisig = vm.envAddress("VANA_MULTISIG_ADDRESS");
        baseMultisig = vm.envAddress("BASE_MULTISIG_ADDRESS");

        // Determine treasury based on chain
        if (block.chainid == VANA_MAINNET || block.chainid == VANA_MOKSHA) {
            treasury = vanaMultisig;
        } else if (block.chainid == BASE_MAINNET || block.chainid == BASE_SEPOLIA) {
            treasury = baseMultisig;
        } else {
            // Local development - use deployer as treasury
            treasury = deployer;
        }

        console2.log("Deployer address:", deployer);
        console2.log("Chain ID:", block.chainid);
        console2.log("Treasury address:", treasury);
    }

    function run() public virtual {
        setUp();
        deploy();
    }

    function deploy() internal virtual;

    function getChainName() internal view returns (string memory) {
        if (block.chainid == BASE_MAINNET) return "Base Mainnet";
        if (block.chainid == BASE_SEPOLIA) return "Base Sepolia";
        if (block.chainid == VANA_MAINNET) return "Vana Mainnet";
        if (block.chainid == VANA_MOKSHA) return "Vana Moksha";
        if (block.chainid == 31337) return "Anvil Local";
        return "Unknown Chain";
    }
}
