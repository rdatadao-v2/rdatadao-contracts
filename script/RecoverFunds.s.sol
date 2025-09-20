// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script, console2} from "forge-std/Script.sol";

/**
 * @title RecoverFunds
 * @notice Script to transfer remaining funds from deployer to main wallet
 */
contract RecoverFunds is Script {
    address constant DESTINATION = 0xC9Af4E56741f255743e8f4877d4cfa9971E910C2; // monkfenix.eth

    function run() external {
        uint256 chainId = block.chainid;
        address deployer = msg.sender;
        uint256 balance = deployer.balance;

        console2.log("========================================");
        console2.log("RECOVERING FUNDS");
        console2.log("========================================");
        console2.log("Chain ID:", chainId);
        console2.log("Deployer:", deployer);
        console2.log("Destination:", DESTINATION);
        console2.log("Current Balance:", balance);

        // Calculate amount to transfer (keep some for gas)
        uint256 gasReserve;
        if (chainId == 1480) {
            // Vana - keep 0.02 VANA for gas
            gasReserve = 0.02 ether;
        } else if (chainId == 8453) {
            // Base - keep 0.0001 ETH for gas
            gasReserve = 0.0001 ether;
        } else {
            revert("Unsupported chain");
        }

        if (balance <= gasReserve) {
            console2.log("Balance too low to transfer after gas reserve");
            return;
        }

        uint256 amountToTransfer = balance - gasReserve;

        console2.log("Gas Reserve:", gasReserve);
        console2.log("Amount to Transfer:", amountToTransfer);

        vm.startBroadcast();

        // Transfer native currency
        (bool success,) = DESTINATION.call{value: amountToTransfer}("");
        require(success, "Transfer failed");

        vm.stopBroadcast();

        console2.log("");
        console2.log("========================================");
        console2.log("TRANSFER COMPLETE");
        console2.log("========================================");
        console2.log("Transferred:", amountToTransfer);
        console2.log("Remaining for gas:", gasReserve);
    }
}
