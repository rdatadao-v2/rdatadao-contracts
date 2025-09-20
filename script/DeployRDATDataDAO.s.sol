// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script, console2} from "forge-std/Script.sol";
import {RDATDataDAO} from "../src/RDATDataDAO.sol";

contract DeployRDATDataDAO is Script {
    function run() external returns (address) {
        // Get deployed RDAT token address
        address rdatToken = 0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E;
        address treasury = 0x77D2713972af12F1E3EF39b5395bfD65C862367C;
        address vanaMultisig = 0xe4F7Eca807C57311e715C3Ef483e72Fa8D5bCcDF;

        console2.log("========================================");
        console2.log("DEPLOYING RDATDataDAO for DLP Registration");
        console2.log("========================================");
        console2.log("RDAT Token:", rdatToken);
        console2.log("Treasury:", treasury);
        console2.log("DLP Owner (Multisig):", vanaMultisig);
        console2.log("");

        vm.startBroadcast();

        // Prepare initial validators array
        address[] memory initialValidators = new address[](3);
        initialValidators[0] = vm.envAddress("VALIDATOR_1"); // Angela
        initialValidators[1] = vm.envAddress("VALIDATOR_2"); // monkfenix.eth
        initialValidators[2] = vm.envAddress("VALIDATOR_3_MAINNET"); // Base multisig

        // Deploy RDATDataDAO
        RDATDataDAO dataDAO = new RDATDataDAO(
            rdatToken,
            treasury,
            vanaMultisig,
            initialValidators
        );

        console2.log("RDATDataDAO deployed at:", address(dataDAO));

        vm.stopBroadcast();

        console2.log("");
        console2.log("========================================");
        console2.log("DEPLOYMENT COMPLETE");
        console2.log("========================================");
        console2.log("RDATDataDAO Address:", address(dataDAO));
        console2.log("Ready for DLP Registration");

        return address(dataDAO);
    }
}