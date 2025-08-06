// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @title ITreasuryWallet
 * @notice Interface for the TreasuryWallet contract
 */
interface ITreasuryWallet {
    // Structs
    struct VestingSchedule {
        uint256 total;
        uint256 released;
        uint256 tgeUnlock;
        uint256 cliffDuration;
        uint256 vestingDuration;
        uint256 vestingStart;
        uint256 lastRelease;
        bool isPhase3Gated;
        bool initialized;
    }
    
    // Events
    event VestingScheduleCreated(bytes32 indexed allocation, uint256 total, uint256 tgeUnlock);
    event TokensReleased(bytes32 indexed allocation, uint256 amount);
    event TokensDistributed(address indexed recipient, uint256 amount, string reason);
    event Phase3Activated(uint256 timestamp);
    event DAOProposalExecuted(uint256 indexed proposalId);
    
    // Functions
    function initialize(address _admin, address _rdat) external;
    function checkAndRelease() external;
    function distribute(address recipient, uint256 amount, string calldata reason) external;
    function setPhase3Active() external;
    function executeDAOProposal(
        uint256 proposalId,
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas
    ) external;
    
    // View functions
    function getVestingInfo(bytes32 allocation) external view returns (
        uint256 total,
        uint256 released,
        uint256 available,
        bool isActive
    );
    function phase3Active() external view returns (bool);
    function totalDistributed() external view returns (uint256);
    function distributionHistory(address recipient) external view returns (uint256);
}