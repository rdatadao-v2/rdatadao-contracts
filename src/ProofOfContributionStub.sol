// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IProofOfContribution.sol";
import "./interfaces/IProofOfContributionIntegration.sol";

/**
 * @title ProofOfContributionStub
 * @author r/datadao
 * @notice Minimal stub implementation for Vana DLP compliance
 * @dev Simplified version to avoid stack depth issues
 */
contract ProofOfContributionStub is IProofOfContribution, IProofOfContributionIntegration, AccessControl {
    // Roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant INTEGRATION_ROLE = keccak256("INTEGRATION_ROLE");
    
    // Minimal state using structs to avoid stack issues
    struct ContributionData {
        uint256 count;
        uint256 totalScore;
        uint256 pendingRewards;
    }
    
    struct SystemState {
        address dlpAddress;
        uint256 currentEpoch;
        bool isActive;
    }
    
    SystemState public systemState;
    mapping(address => ContributionData) public contributorData;
    mapping(address => bool) public validators;
    
    // Events
    event SystemInitialized(address dlpAddress, address admin);
    event ContributionValidated(address indexed contributor, uint256 indexed contributionId);
    
    constructor(address _admin, address _dlpAddress) {
        require(_admin != address(0), "Invalid admin");
        require(_dlpAddress != address(0), "Invalid DLP");
        
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
        
        systemState = SystemState({
            dlpAddress: _dlpAddress,
            currentEpoch: 1,
            isActive: true
        });
        
        emit SystemInitialized(_dlpAddress, _admin);
    }
    
    // Core functions with minimal parameters
    function recordContribution(
        address contributor,
        uint256 qualityScore,
        bytes32 dataHash
    ) external override onlyRole(INTEGRATION_ROLE) returns (bool) {
        require(systemState.isActive, "PoC inactive");
        require(contributor != address(0), "Invalid contributor");
        require(qualityScore <= 100, "Invalid quality score");
        require(dataHash != bytes32(0), "Invalid data hash");
        
        ContributionData storage data = contributorData[contributor];
        data.count++;
        data.totalScore += qualityScore;
        
        emit ContributionRecorded(contributor, qualityScore, dataHash);
        return true;
    }
    
    function validateContribution(
        address contributor,
        uint256 contributionId
    ) external override {
        require(validators[msg.sender], "Not validator");
        // Minimal validation logic
        emit ContributionValidated(contributor, contributionId);
    }
    
    function claimRewards(address contributor) external override returns (uint256) {
        require(systemState.isActive, "PoC inactive");
        
        ContributionData storage data = contributorData[contributor];
        uint256 rewards = data.pendingRewards;
        require(rewards > 0, "No rewards");
        
        data.pendingRewards = 0;
        
        emit RewardsDistributed(contributor, rewards);
        return rewards;
    }
    
    // Admin functions
    function addValidator(address validator) external override onlyRole(ADMIN_ROLE) {
        validators[validator] = true;
        emit ValidatorAdded(validator);
    }
    
    function removeValidator(address validator) external override onlyRole(ADMIN_ROLE) {
        validators[validator] = false;
        emit ValidatorRemoved(validator);
    }
    
    function grantIntegrationRole(address account) external onlyRole(ADMIN_ROLE) {
        _grantRole(INTEGRATION_ROLE, account);
    }
    
    // View functions
    function contributions(address, uint256) external view override returns (Contribution memory) {
        return Contribution({
            timestamp: block.timestamp,
            score: 0,
            dataHash: bytes32(0),
            validated: false
        });
    }
    
    function contributionCount(address contributor) external view override returns (uint256) {
        return contributorData[contributor].count;
    }
    
    function pendingRewards(address contributor) external view override returns (uint256) {
        return contributorData[contributor].pendingRewards;
    }
    
    function totalScore(address contributor) external view override returns (uint256) {
        return contributorData[contributor].totalScore;
    }
    
    function isValidator(address validator) external view override returns (bool) {
        return validators[validator];
    }
    
    function dlpAddress() external view override returns (address) {
        return systemState.dlpAddress;
    }
    
    function isActive() external view override returns (bool) {
        return systemState.isActive;
    }
    
    // Integration interface functions
    function getCurrentEpoch() external view override returns (uint256) {
        return systemState.currentEpoch;
    }
    
    function getEpochScore(address contributor, uint256) external view override returns (uint256) {
        return contributorData[contributor].totalScore;
    }
    
    function getEpochTotalScore(uint256) external pure override returns (uint256) {
        return 1000000; // Stub value
    }
    
    function hasContributedInEpoch(address contributor, uint256) external view override returns (bool) {
        return contributorData[contributor].count > 0;
    }
}