// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IEmergencyPause.sol";

/**
 * @title EmergencyPause
 * @author r/datadao
 * @notice Shared emergency pause system for protocol-wide emergency response
 * @dev Implements auto-expiry mechanism and multi-pauser support
 * 
 * Key Features:
 * - Multiple authorized pausers
 * - Auto-expiry after fixed duration
 * - Only guardian can unpause before expiry
 * - Reentrancy protection
 * - Event logging for transparency
 */
contract EmergencyPause is AccessControl, ReentrancyGuard, IEmergencyPause {
    // Roles
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
    bytes32 public constant PAUSER_MANAGER_ROLE = keccak256("PAUSER_MANAGER_ROLE");
    
    // Constants
    uint256 public constant override PAUSE_DURATION = 72 hours; // 3 days auto-expiry
    
    // State
    bool private _paused;
    uint256 public override pausedAt;
    mapping(address => bool) public override pausers;
    
    // Additional events
    event PauserAdded(address indexed pauser);
    event PauserRemoved(address indexed pauser);
    
    /**
     * @dev Constructor sets up initial roles
     * @param admin Address to receive admin and guardian roles
     */
    constructor(address admin) {
        require(admin != address(0), "Invalid admin");
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GUARDIAN_ROLE, admin);
        _grantRole(PAUSER_MANAGER_ROLE, admin);
    }
    
    /**
     * @dev Add a new emergency pauser
     * @param pauser Address to grant pause permission
     */
    function addPauser(address pauser) external override onlyRole(PAUSER_MANAGER_ROLE) {
        require(pauser != address(0), "Invalid pauser");
        require(!pausers[pauser], "Already a pauser");
        
        pausers[pauser] = true;
        emit PauserAdded(pauser);
    }
    
    /**
     * @dev Remove an emergency pauser
     * @param pauser Address to revoke pause permission
     */
    function removePauser(address pauser) external override onlyRole(PAUSER_MANAGER_ROLE) {
        require(pausers[pauser], "Not a pauser");
        
        pausers[pauser] = false;
        emit PauserRemoved(pauser);
    }
    
    /**
     * @dev Trigger emergency pause
     * @notice Can only be called by authorized pausers
     */
    function emergencyPause() external override nonReentrant {
        require(pausers[msg.sender], "Not authorized to pause");
        require(!_isPaused(), "Already paused");
        
        _paused = true;
        pausedAt = block.timestamp;
        
        emit EmergencyPaused(msg.sender);
    }
    
    /**
     * @dev Unpause before auto-expiry
     * @notice Only guardian can unpause early
     */
    function emergencyUnpause() external override onlyRole(GUARDIAN_ROLE) nonReentrant {
        require(_isPaused(), "Not paused");
        
        _paused = false;
        pausedAt = 0;
        
        emit EmergencyUnpaused(msg.sender);
    }
    
    /**
     * @dev Check if system is currently paused
     * @return paused Whether emergency pause is active (considering auto-expiry)
     */
    function emergencyPaused() external view override returns (bool) {
        return _isPaused();
    }
    
    /**
     * @dev Internal function to check pause state with auto-expiry
     * @return Whether the system is currently paused
     */
    function _isPaused() internal view returns (bool) {
        if (!_paused) {
            return false;
        }
        
        // Check if pause has auto-expired
        if (block.timestamp >= pausedAt + PAUSE_DURATION) {
            return false;
        }
        
        return true;
    }
    
    /**
     * @dev Get remaining pause time
     * @return remainingSeconds Seconds until auto-unpause (0 if not paused)
     */
    function pauseTimeRemaining() external view returns (uint256 remainingSeconds) {
        if (!_isPaused()) {
            return 0;
        }
        
        uint256 expiryTime = pausedAt + PAUSE_DURATION;
        if (block.timestamp >= expiryTime) {
            return 0;
        }
        
        return expiryTime - block.timestamp;
    }
    
    /**
     * @dev Check if an address is an authorized pauser
     * @param account Address to check
     * @return authorized Whether the address can pause
     */
    function isPauser(address account) external view returns (bool) {
        return pausers[account];
    }
    
    /**
     * @dev Modifier to check if not paused
     * @notice Use this in inheriting contracts
     */
    modifier whenNotEmergencyPaused() {
        require(!_isPaused(), "Emergency pause active");
        _;
    }
    
    /**
     * @dev Modifier to check if paused
     * @notice Use this in inheriting contracts
     */
    modifier whenEmergencyPaused() {
        require(_isPaused(), "Not emergency paused");
        _;
    }
}