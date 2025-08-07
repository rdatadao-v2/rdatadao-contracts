// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @title IVRC20Basic
 * @dev Basic VRC-20 compliance interface for V2 Beta
 * Full VRC-20 compliance will be implemented in Phase 3
 */
interface IVRC20Basic {
    // VRC-20 identification
    function isVRC20() external view returns (bool);

    // VRC-20 contract connections (stubs for V2 Beta)
    function pocContract() external view returns (address);
    function dataRefiner() external view returns (address);

    // Events for VRC-20 compliance
    event VRCContractSet(string contractType, address indexed contractAddress);
}
