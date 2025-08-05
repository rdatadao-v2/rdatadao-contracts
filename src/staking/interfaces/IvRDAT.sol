// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IvRDAT {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
    function votingPower(address account) external view returns (uint256);
    function votingPowerAt(address account, uint256 blockNumber) external view returns (uint256);
}