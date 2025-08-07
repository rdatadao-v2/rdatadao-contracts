// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/IGovernance.sol";

/**
 * @title GovernanceExecution
 * @notice Handles proposal execution with timelock
 * @dev Separate contract to manage execution logic
 */
contract GovernanceExecution is AccessControl, ReentrancyGuard {
    // Roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    // State
    struct ExecutionData {
        address[] targets;
        uint256[] values;
        bytes[] calldatas;
        bytes32 descriptionHash;
        uint256 eta; // Estimated time of arrival (execution time)
        bool executed;
    }

    mapping(uint256 => ExecutionData) public executionQueue;
    uint256 public constant TIMELOCK_DELAY = 2 days;

    // Events
    event ProposalQueued(uint256 indexed proposalId, uint256 eta);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);

    constructor(address _admin) {
        require(_admin != address(0), "Invalid admin");
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
        _grantRole(EXECUTOR_ROLE, _admin);
    }

    /**
     * @notice Queue a proposal for execution
     * @param proposalId The proposal ID
     * @param targets Target addresses for calls
     * @param values ETH values for calls
     * @param calldatas Encoded function calls
     * @param descriptionHash Hash of the proposal description
     */
    function queue(
        uint256 proposalId,
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas,
        bytes32 descriptionHash
    ) external onlyRole(GOVERNANCE_ROLE) {
        require(proposalId > 0, "Invalid proposal");
        require(targets.length == values.length && targets.length == calldatas.length, "Length mismatch");
        require(!executionQueue[proposalId].executed, "Already executed");

        uint256 eta = block.timestamp + TIMELOCK_DELAY;

        executionQueue[proposalId] = ExecutionData({
            targets: targets,
            values: values,
            calldatas: calldatas,
            descriptionHash: descriptionHash,
            eta: eta,
            executed: false
        });

        emit ProposalQueued(proposalId, eta);
    }

    /**
     * @notice Execute a queued proposal
     * @param proposalId The proposal ID to execute
     */
    function execute(uint256 proposalId) external nonReentrant onlyRole(EXECUTOR_ROLE) {
        ExecutionData storage data = executionQueue[proposalId];

        require(data.targets.length > 0, "Not queued");
        require(!data.executed, "Already executed");
        require(block.timestamp >= data.eta, "Timelock not met");

        data.executed = true;

        // Execute all calls
        for (uint256 i = 0; i < data.targets.length; i++) {
            (bool success, bytes memory returndata) = data.targets[i].call{value: data.values[i]}(data.calldatas[i]);

            if (!success) {
                // Decode revert reason
                if (returndata.length > 0) {
                    assembly {
                        revert(add(32, returndata), mload(returndata))
                    }
                } else {
                    revert("Execution failed");
                }
            }
        }

        emit ProposalExecuted(proposalId);
    }

    /**
     * @notice Cancel a queued proposal
     * @param proposalId The proposal ID to cancel
     */
    function cancel(uint256 proposalId) external onlyRole(ADMIN_ROLE) {
        ExecutionData storage data = executionQueue[proposalId];
        require(data.targets.length > 0, "Not queued");
        require(!data.executed, "Already executed");

        delete executionQueue[proposalId];
        emit ProposalCancelled(proposalId);
    }

    /**
     * @notice Get execution data for a proposal
     * @param proposalId The proposal ID
     */
    function getExecutionData(uint256 proposalId)
        external
        view
        returns (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 descriptionHash,
            uint256 eta,
            bool executed
        )
    {
        ExecutionData storage data = executionQueue[proposalId];
        return (data.targets, data.values, data.calldatas, data.descriptionHash, data.eta, data.executed);
    }

    /**
     * @notice Set the governance core contract
     * @param _governanceCore Address of governance core
     */
    function setGovernanceCore(address _governanceCore) external onlyRole(ADMIN_ROLE) {
        require(_governanceCore != address(0), "Invalid address");
        _grantRole(GOVERNANCE_ROLE, _governanceCore);
    }

    /**
     * @notice Receive ETH for proposal executions
     */
    receive() external payable {}
}
