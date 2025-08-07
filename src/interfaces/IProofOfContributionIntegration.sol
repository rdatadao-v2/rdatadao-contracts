// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @title IProofOfContributionIntegration
 * @author r/datadao
 * @notice Interface for ProofOfContribution integration with RDATUpgradeable
 * @dev Used by RDATUpgradeable to notify PoC contract of data contributions
 */
interface IProofOfContributionIntegration {
    /**
     * @notice Records a data contribution from RDATUpgradeable
     * @param contributor Address of the contributor
     * @param qualityScore Quality score of the contribution (0-100)
     * @param dataHash Hash of the contributed data
     * @return success Whether the contribution was recorded
     */
    function recordContribution(address contributor, uint256 qualityScore, bytes32 dataHash)
        external
        returns (bool success);

    /**
     * @notice Gets the total contribution score for a user in an epoch
     * @param contributor Address to check
     * @param epoch Epoch number
     * @return score Total quality score for the epoch
     */
    function getEpochScore(address contributor, uint256 epoch) external view returns (uint256 score);

    /**
     * @notice Gets the total score for all contributors in an epoch
     * @param epoch Epoch number
     * @return totalScore Sum of all contributor scores
     */
    function getEpochTotalScore(uint256 epoch) external view returns (uint256 totalScore);

    /**
     * @notice Checks if a user has contributed in an epoch
     * @param contributor Address to check
     * @param epoch Epoch number
     * @return hasContributed Whether the user contributed
     */
    function hasContributedInEpoch(address contributor, uint256 epoch) external view returns (bool hasContributed);

    /**
     * @notice Gets the current epoch number
     * @return epoch Current epoch
     */
    function getCurrentEpoch() external view returns (uint256 epoch);
}
