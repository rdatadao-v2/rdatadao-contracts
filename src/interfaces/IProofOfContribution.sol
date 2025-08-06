// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @title IProofOfContribution
 * @dev Minimal Proof of Contribution interface for Vana DLP compliance
 * This is a stub implementation for V2 Beta - full implementation in Phase 3
 */
interface IProofOfContribution {
    // Events
    event ContributionRecorded(address indexed contributor, uint256 score, bytes32 dataHash);
    event ValidatorAdded(address indexed validator);
    event ValidatorRemoved(address indexed validator);
    event RewardsDistributed(address indexed contributor, uint256 amount);
    
    // Structs
    struct Contribution {
        uint256 timestamp;
        uint256 score;
        bytes32 dataHash;
        bool validated;
    }
    
    // Functions
    function validateContribution(
        address contributor,
        uint256 contributionId
    ) external;
    
    function claimRewards(address contributor) external returns (uint256);
    
    function addValidator(address validator) external;
    function removeValidator(address validator) external;
    
    // State getters
    function contributions(address contributor, uint256 index) external view returns (Contribution memory);
    function contributionCount(address contributor) external view returns (uint256);
    function pendingRewards(address contributor) external view returns (uint256);
    function totalScore(address contributor) external view returns (uint256);
    function isValidator(address validator) external view returns (bool);
    
    // Vana DLP compliance getters
    function dlpAddress() external view returns (address);
    function isActive() external view returns (bool);
}