// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title BasicTimelock
 * @notice Simple timelock for critical admin functions (audit remediation L-04)
 * @dev This provides a basic 48-hour delay for role management and upgrades
 *      Future versions should use OpenZeppelin TimelockController for full functionality
 */
abstract contract BasicTimelock is AccessControl {
    uint256 public constant TIMELOCK_DELAY = 48 hours;
    
    struct PendingAction {
        bytes32 id;
        address target;
        bytes data;
        uint256 executeAfter;
        bool executed;
    }
    
    mapping(bytes32 => PendingAction) public pendingActions;
    
    event ActionScheduled(bytes32 indexed actionId, address indexed target, uint256 executeAfter);
    event ActionExecuted(bytes32 indexed actionId);
    event ActionCancelled(bytes32 indexed actionId);
    
    error TimelockNotReady();
    error ActionAlreadyExecuted();
    error ActionDoesNotExist();
    error OnlyAdminCanCancel();
    
    /**
     * @notice Schedule an action with timelock delay
     * @param target The target contract address
     * @param data The function call data
     * @return actionId The unique ID of the scheduled action
     */
    function _scheduleAction(address target, bytes memory data) internal returns (bytes32 actionId) {
        actionId = keccak256(abi.encodePacked(target, data, block.timestamp));
        
        pendingActions[actionId] = PendingAction({
            id: actionId,
            target: target,
            data: data,
            executeAfter: block.timestamp + TIMELOCK_DELAY,
            executed: false
        });
        
        emit ActionScheduled(actionId, target, block.timestamp + TIMELOCK_DELAY);
    }
    
    /**
     * @notice Execute a scheduled action after timelock
     * @param actionId The ID of the action to execute
     */
    function executeScheduledAction(bytes32 actionId) external {
        PendingAction storage action = pendingActions[actionId];
        
        if (action.target == address(0)) revert ActionDoesNotExist();
        if (action.executed) revert ActionAlreadyExecuted();
        if (block.timestamp < action.executeAfter) revert TimelockNotReady();
        
        action.executed = true;
        
        (bool success, ) = action.target.call(action.data);
        require(success, "Action execution failed");
        
        emit ActionExecuted(actionId);
    }
    
    /**
     * @notice Cancel a pending action (admin only)
     * @param actionId The ID of the action to cancel
     */
    function cancelScheduledAction(bytes32 actionId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        PendingAction storage action = pendingActions[actionId];
        
        if (action.target == address(0)) revert ActionDoesNotExist();
        if (action.executed) revert ActionAlreadyExecuted();
        
        delete pendingActions[actionId];
        
        emit ActionCancelled(actionId);
    }
    
    /**
     * @notice Check if an action is ready to execute
     * @param actionId The ID of the action
     * @return ready True if the action can be executed
     */
    function isActionReady(bytes32 actionId) external view returns (bool ready) {
        PendingAction storage action = pendingActions[actionId];
        return action.target != address(0) && 
               !action.executed && 
               block.timestamp >= action.executeAfter;
    }
}