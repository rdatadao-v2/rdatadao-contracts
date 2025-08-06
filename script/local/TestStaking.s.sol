// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../../src/RDATUpgradeable.sol";
import "../../src/StakingPositions.sol";
import "../../src/vRDAT.sol";

contract TestStaking is Script {
    RDATUpgradeable public rdat = RDATUpgradeable(0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0);
    vRDAT public vrdat = vRDAT(0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9);
    StakingPositions public staking = StakingPositions(0x0165878A594ca255338adfa4d48449f69242Eb8F);
    
    function run() external {
        address user = msg.sender;
        uint256 stakeAmount = 1000e18; // 1000 RDAT
        uint256 lockDuration = 30 days;
        
        console2.log("Testing staking functionality");
        console2.log("User:", user);
        console2.log("Stake amount:", stakeAmount / 1e18, "RDAT");
        console2.log("Lock duration:", lockDuration / 1 days, "days");
        
        vm.startBroadcast();
        
        // Check balances
        uint256 rdatBalance = rdat.balanceOf(user);
        uint256 vrdatBalance = vrdat.balanceOf(user);
        console2.log("\nInitial balances:");
        console2.log("RDAT:", rdatBalance / 1e18);
        console2.log("vRDAT:", vrdatBalance / 1e18);
        
        // Approve staking contract
        console2.log("\nApproving staking contract...");
        rdat.approve(address(staking), stakeAmount);
        
        // Stake tokens
        console2.log("Staking tokens...");
        uint256 positionId = staking.stake(stakeAmount, lockDuration);
        console2.log("Created position ID:", positionId);
        
        // Check position details
        StakingPositions.Position memory position = staking.getPosition(positionId);
        console2.log("\nPosition details:");
        console2.log("Amount:", position.amount / 1e18, "RDAT");
        console2.log("Start time:", position.startTime);
        console2.log("Lock period:", position.lockPeriod / 1 days, "days");
        console2.log("Multiplier:", position.multiplier);
        console2.log("vRDAT minted:", position.vrdatMinted / 1e18);
        
        // Check updated balances
        uint256 newRdatBalance = rdat.balanceOf(user);
        uint256 newVrdatBalance = vrdat.balanceOf(user);
        console2.log("\nUpdated balances:");
        console2.log("RDAT:", newRdatBalance / 1e18);
        console2.log("vRDAT:", newVrdatBalance / 1e18);
        
        // Check staking contract balance
        uint256 stakingBalance = rdat.balanceOf(address(staking));
        console2.log("\nStaking contract RDAT balance:", stakingBalance / 1e18);
        
        vm.stopBroadcast();
        
        console2.log("\nStaking test completed successfully!");
    }
}