// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title BaseOnlyContract
 * @notice This contract is designed to be deployed only on Base blockchain
 */
contract BaseOnlyContract {
    uint256 public constant BASE_CHAIN_ID = 8453;
    uint256 public constant BASE_SEPOLIA_CHAIN_ID = 84532;
    
    string public greeting = "Hello from Base!";
    mapping(address => uint256) public balances;
    
    modifier onlyBase() {
        require(
            block.chainid == BASE_CHAIN_ID || block.chainid == BASE_SEPOLIA_CHAIN_ID,
            "This contract can only be deployed on Base"
        );
        _;
    }
    
    constructor() onlyBase {
        // Contract can only be deployed on Base
    }
    
    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }
    
    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
    }
}