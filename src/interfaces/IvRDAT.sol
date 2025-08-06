// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface IvRDAT {
    // Events
    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);
    
    // Errors
    error NonTransferableToken();
    error ExceedsMaxBalance();
    
    // Functions
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
    
    // Non-transferable functions (will revert)
    function transfer(address to, uint256 amount) external pure returns (bool);
    function transferFrom(address from, address to, uint256 amount) external pure returns (bool);
    function approve(address spender, uint256 amount) external pure returns (bool);
    
    // State getters
    function totalSupply() external view returns (uint256);
    
    // Constants
    function MAX_PER_ADDRESS() external view returns (uint256);
}