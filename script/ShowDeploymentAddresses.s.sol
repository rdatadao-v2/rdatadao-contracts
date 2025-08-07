// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script, console2} from "forge-std/Script.sol";

contract ShowDeploymentAddresses is Script {
    struct ChainInfo {
        string name;
        uint256 chainId;
        string rpcUrl;
        address treasury;
        uint256 deployerNonce;
    }
    
    function run() external pure {
        address deployer = 0x58eCB94e6F5e6521228316b55c465ad2A2938FbB;
        
        console2.log("=== RDAT V2 Deployment Address Predictions ===");
        console2.log("Deployer:", deployer);
        console2.log("");
        
        // Define chains
        ChainInfo[4] memory chains = [
            ChainInfo("Base Mainnet", 8453, "https://mainnet.base.org", 0x90013583c66D2bf16327cB5Bc4a647AcceCF4B9A, 0),
            ChainInfo("Base Sepolia", 84532, "https://sepolia.base.org", 0x90013583c66D2bf16327cB5Bc4a647AcceCF4B9A, 5),
            ChainInfo("Vana Mainnet", 1480, "https://rpc.vana.org", 0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319, 0),
            ChainInfo("Vana Moksha", 14800, "https://rpc.moksha.vana.org", 0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319, 8)
        ];
        
        for (uint i = 0; i < chains.length; i++) {
            ChainInfo memory chain = chains[i];
            
            console2.log(string.concat("--- ", chain.name, " ---"));
            console2.log("Chain ID:", chain.chainId);
            console2.log("Treasury/Admin:", chain.treasury);
            console2.log("Current Nonce:", chain.deployerNonce);
            
            // Calculate addresses based on nonce
            address factory = computeCreateAddress(deployer, chain.deployerNonce);
            address implementation = computeCreateAddress(deployer, chain.deployerNonce + 1);
            address proxy = computeCreateAddress(deployer, chain.deployerNonce + 2);
            
            console2.log("Predicted Addresses:");
            console2.log("  CREATE2 Factory:", factory);
            console2.log("  Implementation:", implementation);
            console2.log("  RDAT Proxy:", proxy);
            console2.log("");
        }
        
        console2.log("=== Deployment Notes ===");
        console2.log("1. These addresses assume sequential deployment (Factory -> Implementation -> Proxy)");
        console2.log("2. Addresses will change if deployer nonce changes");
        console2.log("3. Use CREATE2 for truly deterministic cross-chain addresses");
        console2.log("4. Treasury receives 70M RDAT (100M - 30M migration allocation)");
    }
    
    function computeCreateAddress(address deployer, uint256 nonce) internal pure override returns (address) {
        if (nonce == 0) {
            return address(uint160(uint256(keccak256(abi.encodePacked(
                bytes1(0xd6),
                bytes1(0x94),
                deployer,
                bytes1(0x80)
            )))));
        }
        if (nonce <= 0x7f) {
            return address(uint160(uint256(keccak256(abi.encodePacked(
                bytes1(0xd6),
                bytes1(0x94),
                deployer,
                uint8(nonce)
            )))));
        }
        if (nonce <= 0xff) {
            return address(uint160(uint256(keccak256(abi.encodePacked(
                bytes1(0xd7),
                bytes1(0x94),
                deployer,
                bytes1(0x81),
                uint8(nonce)
            )))));
        }
        if (nonce <= 0xffff) {
            return address(uint160(uint256(keccak256(abi.encodePacked(
                bytes1(0xd8),
                bytes1(0x94),
                deployer,
                bytes1(0x82),
                uint16(nonce)
            )))));
        }
        revert("Nonce too large");
    }
}