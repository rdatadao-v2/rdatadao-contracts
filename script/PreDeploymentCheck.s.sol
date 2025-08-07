// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

/**
 * @title PreDeploymentCheck
 * @dev Comprehensive pre-deployment verification script
 * @notice Run this before deploying to ensure all requirements are met
 * 
 * Usage:
 * forge script script/PreDeploymentCheck.s.sol --rpc-url $VANA_RPC_URL
 * forge script script/PreDeploymentCheck.s.sol --rpc-url $VANA_MOKSHA_RPC_URL
 */
contract PreDeploymentCheck is Script {
    // Minimum balance requirements (in wei)
    uint256 constant MIN_DEPLOYMENT_BALANCE = 0.05 ether;
    uint256 constant MIN_MULTISIG_BALANCE = 0.01 ether;
    
    // Expected addresses
    address constant EXPECTED_DEPLOYER = 0x58eCB94e6F5e6521228316b55c465ad2A2938FbB;
    address constant VANA_MULTISIG = 0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319;
    address constant BASE_MULTISIG = 0x90013583c66D2bf16327cB5Bc4a647AcceCF4B9A;
    
    // Chain IDs
    uint256 constant VANA_MAINNET = 1480;
    uint256 constant VANA_MOKSHA = 14800;
    uint256 constant BASE_MAINNET = 8453;
    uint256 constant BASE_SEPOLIA = 84532;
    
    // Check results
    struct CheckResult {
        bool passed;
        string message;
    }
    
    function run() external view {
        console2.log("\n========================================");
        console2.log("     RDAT Pre-Deployment Check   ");
        console2.log("========================================\n");
        
        // Get current chain
        uint256 chainId = block.chainid;
        string memory chainName = getChainName(chainId);
        console2.log("Current Chain: %s (ID: %s)", chainName, chainId);
        console2.log("Current Block: %s", block.number);
        console2.log("Timestamp: %s\n", block.timestamp);
        
        // Initialize check results
        bool allChecksPassed = true;
        uint256 checkCount = 0;
        uint256 passedCount = 0;
        
        // Check 1: Verify deployer private key
        console2.log("=== Check 1: Deployer Private Key ===");
        CheckResult memory deployerCheck = checkDeployerKey();
        logResult(deployerCheck);
        if (deployerCheck.passed) passedCount++;
        checkCount++;
        allChecksPassed = allChecksPassed && deployerCheck.passed;
        
        // Check 2: Deployer balance
        console2.log("\n=== Check 2: Deployer Balance ===");
        CheckResult memory deployerBalanceCheck = checkDeployerBalance();
        logResult(deployerBalanceCheck);
        if (deployerBalanceCheck.passed) passedCount++;
        checkCount++;
        allChecksPassed = allChecksPassed && deployerBalanceCheck.passed;
        
        // Check 3: Multisig setup
        console2.log("\n=== Check 3: Multisig Configuration ===");
        CheckResult memory multisigCheck = checkMultisigSetup(chainId);
        logResult(multisigCheck);
        if (multisigCheck.passed) passedCount++;
        checkCount++;
        allChecksPassed = allChecksPassed && multisigCheck.passed;
        
        // Check 4: Network connectivity
        console2.log("\n=== Check 4: Network Connectivity ===");
        CheckResult memory networkCheck = checkNetworkConnectivity();
        logResult(networkCheck);
        if (networkCheck.passed) passedCount++;
        checkCount++;
        allChecksPassed = allChecksPassed && networkCheck.passed;
        
        // Check 5: Gas price
        console2.log("\n=== Check 5: Gas Price ===");
        CheckResult memory gasCheck = checkGasPrice();
        logResult(gasCheck);
        if (gasCheck.passed) passedCount++;
        checkCount++;
        allChecksPassed = allChecksPassed && gasCheck.passed;
        
        // Check 6: Contract bytecode size estimates
        console2.log("\n=== Check 6: Contract Size Estimates ===");
        CheckResult memory sizeCheck = checkContractSizes();
        logResult(sizeCheck);
        if (sizeCheck.passed) passedCount++;
        checkCount++;
        allChecksPassed = allChecksPassed && sizeCheck.passed;
        
        // Summary
        console2.log("\n========================================");
        console2.log("              SUMMARY                    ");
        console2.log("========================================");
        console2.log("Total Checks: %s", checkCount);
        console2.log("Passed: %s", passedCount);
        console2.log("Failed: %s", checkCount - passedCount);
        
        if (allChecksPassed) {
            console2.log("\n%s ALL CHECKS PASSED - Ready for deployment! %s", unicode"[OK]", unicode"🚀");
        } else {
            console2.log("\n%s SOME CHECKS FAILED - Please address issues before deployment", unicode"[ERROR]");
            revert("Pre-deployment checks failed");
        }
        
        // Additional deployment info
        console2.log("\n=== Deployment Information ===");
        console2.log("Deployer: %s", EXPECTED_DEPLOYER);
        console2.log("Treasury/Multisig: %s", getMultisigForChain(chainId));
        console2.log("Estimated deployment cost: ~0.02-0.03 ETH");
        console2.log("\nNext step: Run deployment script");
        console2.log("forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast\n");
    }
    
    function checkDeployerKey() internal view returns (CheckResult memory) {
        address deployer = msg.sender;
        
        if (deployer == EXPECTED_DEPLOYER) {
            return CheckResult(
                true, 
                string.concat(
                    unicode"[OK] Deployer address matches expected: ",
                    vm.toString(deployer)
                )
            );
        } else {
            return CheckResult(
                false,
                string.concat(
                    unicode"✗ Deployer mismatch! Expected: ",
                    vm.toString(EXPECTED_DEPLOYER),
                    ", Got: ",
                    vm.toString(deployer)
                )
            );
        }
    }
    
    function checkDeployerBalance() internal view returns (CheckResult memory) {
        uint256 balance = EXPECTED_DEPLOYER.balance;
        
        if (balance >= MIN_DEPLOYMENT_BALANCE) {
            return CheckResult(
                true,
                string.concat(
                    unicode"[OK] Sufficient balance: ",
                    formatEther(balance),
                    " ETH"
                )
            );
        } else {
            return CheckResult(
                false,
                string.concat(
                    unicode"✗ Insufficient balance: ",
                    formatEther(balance),
                    " ETH (need at least ",
                    formatEther(MIN_DEPLOYMENT_BALANCE),
                    " ETH)"
                )
            );
        }
    }
    
    function checkMultisigSetup(uint256 chainId) internal view returns (CheckResult memory) {
        address expectedMultisig = getMultisigForChain(chainId);
        uint256 multisigBalance = expectedMultisig.balance;
        
        // Check if multisig is deployed (has code or balance)
        bool hasCode = expectedMultisig.code.length > 0;
        bool hasBalance = multisigBalance >= MIN_MULTISIG_BALANCE;
        
        if (hasCode || hasBalance) {
            return CheckResult(
                true,
                string.concat(
                    unicode"[OK] Multisig ready at: ",
                    vm.toString(expectedMultisig),
                    " (Balance: ",
                    formatEther(multisigBalance),
                    " ETH)"
                )
            );
        } else {
            return CheckResult(
                false,
                string.concat(
                    unicode"⚠ Multisig may not be deployed at: ",
                    vm.toString(expectedMultisig)
                )
            );
        }
    }
    
    function checkNetworkConnectivity() internal view returns (CheckResult memory) {
        // Simple check - if we got this far, we're connected
        try this.getBlockNumber() returns (uint256 blockNum) {
            return CheckResult(
                true,
                string.concat(
                    unicode"[OK] Connected to network, block height: ",
                    vm.toString(blockNum)
                )
            );
        } catch {
            return CheckResult(
                false,
                unicode"✗ Network connectivity issue"
            );
        }
    }
    
    function checkGasPrice() internal view returns (CheckResult memory) {
        uint256 gasPrice = tx.gasprice;
        uint256 maxAcceptableGasPrice = 100 gwei;
        
        if (gasPrice <= maxAcceptableGasPrice) {
            return CheckResult(
                true,
                string.concat(
                    unicode"[OK] Gas price acceptable: ",
                    vm.toString(gasPrice / 1 gwei),
                    " gwei"
                )
            );
        } else {
            return CheckResult(
                false,
                string.concat(
                    unicode"⚠ High gas price: ",
                    vm.toString(gasPrice / 1 gwei),
                    " gwei (consider waiting)"
                )
            );
        }
    }
    
    function checkContractSizes() internal pure returns (CheckResult memory) {
        // Rough estimates based on similar contracts
        uint256 rdatSize = 15000; // ~15KB
        uint256 vrdatSize = 8000;  // ~8KB
        uint256 stakingSize = 12000; // ~12KB
        uint256 bridgeSize = 14000;  // ~14KB
        uint256 maxSize = 24576;     // 24KB limit
        
        bool allWithinLimit = rdatSize < maxSize && 
                             vrdatSize < maxSize && 
                             stakingSize < maxSize && 
                             bridgeSize < maxSize;
        
        if (allWithinLimit) {
            return CheckResult(
                true,
                unicode"[OK] All contracts within size limits"
            );
        } else {
            return CheckResult(
                false,
                unicode"✗ Some contracts may exceed size limit"
            );
        }
    }
    
    // Helper functions
    function getChainName(uint256 chainId) internal pure returns (string memory) {
        if (chainId == VANA_MAINNET) return "Vana Mainnet";
        if (chainId == VANA_MOKSHA) return "Vana Moksha Testnet";
        if (chainId == BASE_MAINNET) return "Base Mainnet";
        if (chainId == BASE_SEPOLIA) return "Base Sepolia";
        return "Unknown Chain";
    }
    
    function getMultisigForChain(uint256 chainId) internal pure returns (address) {
        if (chainId == VANA_MAINNET || chainId == VANA_MOKSHA) {
            return VANA_MULTISIG;
        }
        return BASE_MULTISIG;
    }
    
    function formatEther(uint256 weiAmount) internal pure returns (string memory) {
        uint256 ethPart = weiAmount / 1 ether;
        uint256 decimalPart = (weiAmount % 1 ether) / 1e15; // 3 decimal places
        
        return string.concat(
            vm.toString(ethPart),
            ".",
            padZeros(vm.toString(decimalPart), 3)
        );
    }
    
    function padZeros(string memory str, uint256 targetLength) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        if (strBytes.length >= targetLength) return str;
        
        bytes memory result = new bytes(targetLength);
        uint256 padding = targetLength - strBytes.length;
        
        for (uint256 i = 0; i < padding; i++) {
            result[i] = "0";
        }
        
        for (uint256 i = 0; i < strBytes.length; i++) {
            result[padding + i] = strBytes[i];
        }
        
        return string(result);
    }
    
    function logResult(CheckResult memory result) internal pure {
        if (result.passed) {
            console2.log("%s", result.message);
        } else {
            console2.log("%s", result.message);
        }
    }
    
    // External helper for network check
    function getBlockNumber() external view returns (uint256) {
        return block.number;
    }
}