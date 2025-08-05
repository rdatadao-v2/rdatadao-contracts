// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface IEmergencyPause {
    // Events
    event EmergencyPaused(address indexed pauser);
    event EmergencyUnpaused(address indexed guardian);
    
    // Functions
    function addPauser(address pauser) external;
    function removePauser(address pauser) external;
    function emergencyPause() external;
    function emergencyUnpause() external;
    
    // State getters
    function emergencyPaused() external view returns (bool);
    function pausedAt() external view returns (uint256);
    function pausers(address pauser) external view returns (bool);
    
    // Constants
    function PAUSE_DURATION() external view returns (uint256);
}