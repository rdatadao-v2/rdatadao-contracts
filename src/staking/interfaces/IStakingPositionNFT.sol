// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IStakingPositionNFT {
    function mint(address to, uint256 tokenId) external;
    function burn(uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address);
}