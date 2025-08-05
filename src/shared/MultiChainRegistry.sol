// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title MultiChainRegistry
 * @notice This contract can be deployed on both Base and Vana with chain-specific features
 */
contract MultiChainRegistry {
    enum Chain { Base, Vana, Other }
    
    Chain public deployedChain;
    mapping(address => bool) public registeredUsers;
    mapping(address => uint256) public userScores;
    
    event UserRegistered(address indexed user, Chain chain);
    event ScoreUpdated(address indexed user, uint256 newScore);
    
    constructor() {
        if (block.chainid == 8453 || block.chainid == 84532) {
            deployedChain = Chain.Base;
        } else if (block.chainid == 1480 || block.chainid == 14800) {
            deployedChain = Chain.Vana;
        } else {
            deployedChain = Chain.Other;
        }
    }
    
    function register() external {
        require(!registeredUsers[msg.sender], "Already registered");
        registeredUsers[msg.sender] = true;
        
        // Chain-specific initial scores
        if (deployedChain == Chain.Base) {
            userScores[msg.sender] = 100; // Base users start with 100
        } else if (deployedChain == Chain.Vana) {
            userScores[msg.sender] = 200; // Vana users start with 200
        } else {
            userScores[msg.sender] = 50; // Other chains start with 50
        }
        
        emit UserRegistered(msg.sender, deployedChain);
    }
    
    function updateScore(address user, uint256 score) external {
        require(registeredUsers[user], "User not registered");
        
        // Chain-specific score limits
        if (deployedChain == Chain.Base) {
            require(score <= 1000, "Base: Score cannot exceed 1000");
        } else if (deployedChain == Chain.Vana) {
            require(score <= 2000, "Vana: Score cannot exceed 2000");
        }
        
        userScores[user] = score;
        emit ScoreUpdated(user, score);
    }
    
    function getChainName() external view returns (string memory) {
        if (deployedChain == Chain.Base) return "Base";
        if (deployedChain == Chain.Vana) return "Vana";
        return "Other";
    }
}