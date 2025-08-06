// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./interfaces/IProofOfContribution.sol";
import "./interfaces/IRewardsManager.sol";
import "./interfaces/IEmergencyPause.sol";

/**
 * @title ProofOfContribution
 * @author r/datadao
 * @notice Full implementation of Proof of Contribution for VRC-15 compliance
 * @dev Manages data contribution validation, quality scoring, and epoch-based rewards
 * 
 * Key features:
 * - Validator management with multi-sig validation
 * - Quality-based contribution scoring (0-100 scale)
 * - Epoch-based reward distribution
 * - Integration with RewardsManager for claims
 * - Emergency pause capability
 */
contract ProofOfContribution is IProofOfContribution, AccessControl, ReentrancyGuard, Pausable {
    using EnumerableSet for EnumerableSet.AddressSet;

    // Roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
    bytes32 public constant REWARD_MANAGER_ROLE = keccak256("REWARD_MANAGER_ROLE");

    // Configuration constants
    uint256 public constant EPOCH_DURATION = 1 days;
    uint256 public constant MIN_VALIDATORS = 2;
    uint256 public constant MAX_QUALITY_SCORE = 100;
    uint256 public constant VALIDATION_WINDOW = 6 hours;

    // State variables
    address public immutable _dlpAddress;
    IRewardsManager public rewardsManager;
    IEmergencyPause public emergencyPauseContract;
    
    // Epoch tracking
    uint256 public currentEpoch;
    uint256 public epochStartTime;
    uint256 public totalEpochScore;
    mapping(uint256 => uint256) public epochTotalScores;
    mapping(uint256 => uint256) public epochRewardPools;
    
    // Contribution tracking
    mapping(address => Contribution[]) private _contributions;
    mapping(address => uint256) private _totalScores;
    mapping(address => mapping(uint256 => uint256)) private _epochScores;
    mapping(address => uint256) private _lastClaimedEpoch;
    
    // Validation tracking
    mapping(bytes32 => uint256) private _validationCounts;
    mapping(bytes32 => mapping(address => bool)) private _hasValidated;
    EnumerableSet.AddressSet private _validators;
    
    // Contributor rewards
    mapping(address => uint256) private _pendingRewards;
    mapping(address => uint256) private _claimedRewards;
    
    // Emergency state
    bool private _isActive = true;

    // Events
    event EpochAdvanced(uint256 indexed newEpoch, uint256 epochScore);
    event RewardPoolSet(uint256 indexed epoch, uint256 amount);
    event ContributionValidated(address indexed contributor, uint256 indexed contributionId, address validator);

    // Errors
    error InsufficientValidators();
    error InvalidScore();
    error InvalidContribution();
    error AlreadyValidated();
    error NotValidator();
    error EpochNotFinished();
    error NoRewardsToClaim();
    error ContractNotActive();
    error ValidationWindowExpired();

    constructor(
        address dlpAddress_,
        address _emergencyPause,
        address[] memory _initialValidators
    ) {
        require(dlpAddress_ != address(0), "Invalid DLP address");
        require(_emergencyPause != address(0), "Invalid emergency pause");
        require(_initialValidators.length >= MIN_VALIDATORS, "Insufficient initial validators");

        _dlpAddress = dlpAddress_;
        emergencyPauseContract = IEmergencyPause(_emergencyPause);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        
        // Initialize validators
        for (uint256 i = 0; i < _initialValidators.length; i++) {
            _grantRole(VALIDATOR_ROLE, _initialValidators[i]);
            _validators.add(_initialValidators[i]);
            emit ValidatorAdded(_initialValidators[i]);
        }
        
        // Initialize first epoch
        currentEpoch = 1;
        epochStartTime = block.timestamp;
    }

    // ========== EXTERNAL FUNCTIONS ==========

    /**
     * @notice Records a new data contribution
     * @param contributor Address of the contributor
     * @param score Quality score (0-100)
     * @param dataHash Hash of the contributed data
     */
    function recordContribution(
        address contributor,
        uint256 score,
        bytes32 dataHash
    ) external override nonReentrant whenNotPaused {
        if (!_isActive) revert ContractNotActive();
        if (score > MAX_QUALITY_SCORE) revert InvalidScore();
        if (contributor == address(0)) revert InvalidContribution();
        if (dataHash == bytes32(0)) revert InvalidContribution();
        
        // Check if we need to advance epoch
        if (block.timestamp >= epochStartTime + EPOCH_DURATION) {
            _advanceEpoch();
        }
        
        // Record contribution
        Contribution memory contribution = Contribution({
            timestamp: block.timestamp,
            score: score,
            dataHash: dataHash,
            validated: false
        });
        
        _contributions[contributor].push(contribution);
        
        emit ContributionRecorded(contributor, score, dataHash);
    }

    /**
     * @notice Validates a contribution (only validators)
     * @param contributor Address of the contributor
     * @param contributionId Index of the contribution
     */
    function validateContribution(
        address contributor,
        uint256 contributionId
    ) external override nonReentrant whenNotPaused {
        if (!hasRole(VALIDATOR_ROLE, msg.sender)) revert NotValidator();
        if (!_validators.contains(msg.sender)) revert NotValidator();
        
        Contribution[] storage contribs = _contributions[contributor];
        if (contributionId >= contribs.length) revert InvalidContribution();
        
        Contribution storage contribution = contribs[contributionId];
        
        // Check validation window
        if (block.timestamp > contribution.timestamp + VALIDATION_WINDOW) {
            revert ValidationWindowExpired();
        }
        
        // Create validation key
        bytes32 validationKey = keccak256(abi.encodePacked(contributor, contributionId));
        
        // Check if this validator already validated
        if (_hasValidated[validationKey][msg.sender]) revert AlreadyValidated();
        
        // Record validation
        _hasValidated[validationKey][msg.sender] = true;
        _validationCounts[validationKey]++;
        
        emit ContributionValidated(contributor, contributionId, msg.sender);
        
        // If enough validators have validated, mark as validated
        // With 2 validators, require both. With 3+, require 2.
        uint256 requiredValidations = _validators.length() == 2 ? 2 : (_validators.length() >= 3 ? 2 : 1);
        if (_validationCounts[validationKey] >= requiredValidations && !contribution.validated) {
            contribution.validated = true;
            
            // Add to scores
            _totalScores[contributor] += contribution.score;
            _epochScores[contributor][currentEpoch] += contribution.score;
            totalEpochScore += contribution.score;
        }
    }

    /**
     * @notice Claims accumulated rewards for a contributor
     * @param contributor Address to claim for
     * @return amount Amount of rewards claimed
     */
    function claimRewards(address contributor) external override nonReentrant returns (uint256) {
        if (!_isActive) revert ContractNotActive();
        
        // Update pending rewards
        _updatePendingRewards(contributor);
        
        uint256 amount = _pendingRewards[contributor];
        if (amount == 0) revert NoRewardsToClaim();
        
        _pendingRewards[contributor] = 0;
        _claimedRewards[contributor] += amount;
        _lastClaimedEpoch[contributor] = currentEpoch;
        
        emit RewardsDistributed(contributor, amount);
        
        // Note: Actual token transfer would be handled by RewardsManager
        // This contract tracks contribution scores and calculates proportional rewards
        
        return amount;
    }

    /**
     * @notice Adds a new validator
     * @param validator Address to add as validator
     */
    function addValidator(address validator) external override onlyRole(ADMIN_ROLE) {
        require(validator != address(0), "Invalid validator");
        
        _grantRole(VALIDATOR_ROLE, validator);
        _validators.add(validator);
        
        emit ValidatorAdded(validator);
    }

    /**
     * @notice Removes a validator
     * @param validator Address to remove as validator
     */
    function removeValidator(address validator) external override onlyRole(ADMIN_ROLE) {
        require(_validators.length() > MIN_VALIDATORS, "Cannot go below minimum validators");
        
        _revokeRole(VALIDATOR_ROLE, validator);
        _validators.remove(validator);
        
        emit ValidatorRemoved(validator);
    }

    /**
     * @notice Manually advances to the next epoch
     * @dev Can only be called after epoch duration has passed
     */
    function advanceEpoch() external {
        if (block.timestamp < epochStartTime + EPOCH_DURATION) revert EpochNotFinished();
        _advanceEpoch();
    }

    /**
     * @notice Sets the reward pool for a specific epoch
     * @param epoch Epoch number
     * @param amount Reward amount for the epoch
     */
    function setEpochRewardPool(uint256 epoch, uint256 amount) external onlyRole(ADMIN_ROLE) {
        epochRewardPools[epoch] = amount;
        emit RewardPoolSet(epoch, amount);
    }

    /**
     * @notice Sets the rewards manager contract
     * @param _rewardsManager Address of rewards manager
     */
    function setRewardsManager(address _rewardsManager) external onlyRole(ADMIN_ROLE) {
        require(_rewardsManager != address(0), "Invalid rewards manager");
        rewardsManager = IRewardsManager(_rewardsManager);
        _grantRole(REWARD_MANAGER_ROLE, _rewardsManager);
    }

    /**
     * @notice Emergency pause function
     */
    function pause() external {
        require(
            hasRole(ADMIN_ROLE, msg.sender) || 
            (address(emergencyPauseContract) != address(0) && emergencyPauseContract.emergencyPaused()),
            "Not authorized to pause"
        );
        _pause();
    }

    /**
     * @notice Unpause function
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @notice Deactivates the contract (one-way operation)
     */
    function deactivate() external onlyRole(ADMIN_ROLE) {
        _isActive = false;
    }

    // ========== VIEW FUNCTIONS ==========

    /**
     * @notice Gets a specific contribution
     */
    function contributions(address contributor, uint256 index) external view override returns (Contribution memory) {
        require(index < _contributions[contributor].length, "Index out of bounds");
        return _contributions[contributor][index];
    }

    /**
     * @notice Gets contribution count for a contributor
     */
    function contributionCount(address contributor) external view override returns (uint256) {
        return _contributions[contributor].length;
    }

    /**
     * @notice Gets pending rewards for a contributor
     */
    function pendingRewards(address contributor) external view override returns (uint256) {
        uint256 pending = _pendingRewards[contributor];
        
        // Calculate rewards for epochs since last claim
        uint256 lastClaimed = _lastClaimedEpoch[contributor];
        if (lastClaimed == 0) lastClaimed = 1;
        
        for (uint256 epoch = lastClaimed; epoch < currentEpoch; epoch++) {
            uint256 epochScore = _epochScores[contributor][epoch];
            uint256 epochTotal = epochTotalScores[epoch];
            uint256 epochRewards = epochRewardPools[epoch];
            
            if (epochTotal > 0 && epochScore > 0 && epochRewards > 0) {
                pending += (epochRewards * epochScore) / epochTotal;
            }
        }
        
        return pending;
    }

    /**
     * @notice Gets total validated score for a contributor
     */
    function totalScore(address contributor) external view override returns (uint256) {
        return _totalScores[contributor];
    }

    /**
     * @notice Checks if an address is a validator
     */
    function isValidator(address validator) external view override returns (bool) {
        return _validators.contains(validator);
    }

    /**
     * @notice Gets the DLP address
     */
    function dlpAddress() external view override returns (address) {
        return _dlpAddress;
    }

    /**
     * @notice Checks if contract is active
     */
    function isActive() external view override returns (bool) {
        return _isActive && !paused();
    }

    /**
     * @notice Gets all validators
     */
    function getValidators() external view returns (address[] memory) {
        return _validators.values();
    }

    /**
     * @notice Gets validator count
     */
    function getValidatorCount() external view returns (uint256) {
        return _validators.length();
    }

    /**
     * @notice Gets epoch score for a contributor
     */
    function getEpochScore(address contributor, uint256 epoch) external view returns (uint256) {
        return _epochScores[contributor][epoch];
    }

    /**
     * @notice Gets current epoch info
     */
    function getCurrentEpochInfo() external view returns (
        uint256 epoch,
        uint256 startTime,
        uint256 endTime,
        uint256 epochScore
    ) {
        return (
            currentEpoch,
            epochStartTime,
            epochStartTime + EPOCH_DURATION,
            totalEpochScore
        );
    }

    // ========== INTERNAL FUNCTIONS ==========

    /**
     * @dev Advances to the next epoch
     */
    function _advanceEpoch() internal {
        // Store current epoch data
        epochTotalScores[currentEpoch] = totalEpochScore;
        
        emit EpochAdvanced(currentEpoch + 1, totalEpochScore);
        
        // Reset for new epoch
        currentEpoch++;
        epochStartTime = block.timestamp;
        totalEpochScore = 0;
    }

    /**
     * @dev Updates pending rewards for a contributor
     */
    function _updatePendingRewards(address contributor) internal {
        uint256 lastClaimed = _lastClaimedEpoch[contributor];
        if (lastClaimed == 0) lastClaimed = 1;
        
        // Calculate rewards for all unclaimed epochs
        for (uint256 epoch = lastClaimed; epoch < currentEpoch; epoch++) {
            uint256 epochScore = _epochScores[contributor][epoch];
            uint256 epochTotal = epochTotalScores[epoch];
            uint256 epochRewards = epochRewardPools[epoch];
            
            if (epochTotal > 0 && epochScore > 0 && epochRewards > 0) {
                _pendingRewards[contributor] += (epochRewards * epochScore) / epochTotal;
            }
        }
    }

    /**
     * @dev Override for AccessControl support
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}