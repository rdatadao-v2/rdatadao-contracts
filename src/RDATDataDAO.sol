// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title RDATDataDAO
 * @notice Data Liquidity Pool (DLP) contract for r/datadao
 * @dev Implements Vana DLP interface for Reddit data contribution and validation
 *
 * This contract serves as the DLP that can be registered with Vana's ecosystem.
 * It manages data contributions, validator rewards, and proof of contribution.
 */
contract RDATDataDAO is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Roles
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant CONTRIBUTOR_ROLE = keccak256("CONTRIBUTOR_ROLE");

    // State variables
    IERC20 public immutable rdatToken;
    address public immutable treasury;
    string public constant DLP_NAME = "r/datadao";
    string public constant VERSION = "1.0.0";

    // Data contribution tracking
    mapping(address => uint256) public contributorScores;
    mapping(address => uint256) public contributorRewards;
    mapping(bytes32 => bool) public validatedData;
    mapping(address => bool) public validators;

    uint256 public totalContributions;
    uint256 public totalValidators;
    uint256 public currentEpoch;
    uint256 public lastEpochTime;
    uint256 public constant EPOCH_DURATION = 21 hours; // Vana epoch duration

    // Events
    event DataContributed(address indexed contributor, bytes32 indexed dataHash, uint256 score);
    event DataValidated(bytes32 indexed dataHash, address indexed validator, bool isValid);
    event RewardDistributed(address indexed recipient, uint256 amount);
    event ValidatorAdded(address indexed validator);
    event ValidatorRemoved(address indexed validator);
    event EpochAdvanced(uint256 indexed epochId, uint256 timestamp);

    // Errors
    error InvalidValidator();
    error AlreadyValidator();
    error NotValidator();
    error InvalidDataHash();
    error DataAlreadyValidated();
    error InsufficientBalance();
    error InvalidAmount();

    constructor(address _rdatToken, address _treasury, address _admin, address[] memory _initialValidators) {
        require(_rdatToken != address(0), "Invalid RDAT token");
        require(_treasury != address(0), "Invalid treasury");
        require(_admin != address(0), "Invalid admin");

        rdatToken = IERC20(_rdatToken);
        treasury = _treasury;
        lastEpochTime = block.timestamp;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _admin);

        // Add initial validators
        for (uint256 i = 0; i < _initialValidators.length; i++) {
            _addValidator(_initialValidators[i]);
        }
    }

    /**
     * @notice Submit data contribution
     * @param dataHash Hash of the contributed data
     * @param score Quality score of the data (0-100)
     */
    function contributeData(bytes32 dataHash, uint256 score) external whenNotPaused nonReentrant {
        require(dataHash != bytes32(0), "Invalid data hash");
        require(score <= 100, "Score must be 0-100");
        require(!validatedData[dataHash], "Data already exists");

        contributorScores[msg.sender] += score;
        totalContributions++;

        emit DataContributed(msg.sender, dataHash, score);
    }

    /**
     * @notice Validate contributed data
     * @param dataHash Hash of data to validate
     * @param isValid Whether the data is valid
     */
    function validateData(bytes32 dataHash, bool isValid) external onlyRole(VALIDATOR_ROLE) whenNotPaused {
        if (dataHash == bytes32(0)) revert InvalidDataHash();
        if (validatedData[dataHash]) revert DataAlreadyValidated();

        validatedData[dataHash] = isValid;
        emit DataValidated(dataHash, msg.sender, isValid);
    }

    /**
     * @notice Distribute rewards to contributors and validators
     * @param recipients List of addresses to reward
     * @param amounts List of reward amounts
     */
    function distributeRewards(address[] calldata recipients, uint256[] calldata amounts)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        whenNotPaused
        nonReentrant
    {
        require(recipients.length == amounts.length, "Arrays length mismatch");

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }

        uint256 contractBalance = rdatToken.balanceOf(address(this));
        if (contractBalance < totalAmount) revert InsufficientBalance();

        for (uint256 i = 0; i < recipients.length; i++) {
            if (amounts[i] > 0) {
                contributorRewards[recipients[i]] += amounts[i];
                rdatToken.safeTransfer(recipients[i], amounts[i]);
                emit RewardDistributed(recipients[i], amounts[i]);
            }
        }
    }

    /**
     * @notice Advance to next epoch
     */
    function advanceEpoch() external {
        require(block.timestamp >= lastEpochTime + EPOCH_DURATION, "Epoch not ready");

        currentEpoch++;
        lastEpochTime = block.timestamp;

        emit EpochAdvanced(currentEpoch, block.timestamp);
    }

    /**
     * @notice Add a new validator
     * @param validator Address to add as validator
     */
    function addValidator(address validator) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _addValidator(validator);
    }

    /**
     * @dev Internal function to add validator
     */
    function _addValidator(address validator) private {
        if (validator == address(0)) revert InvalidValidator();
        if (validators[validator]) revert AlreadyValidator();

        validators[validator] = true;
        totalValidators++;
        _grantRole(VALIDATOR_ROLE, validator);

        emit ValidatorAdded(validator);
    }

    /**
     * @notice Remove a validator
     * @param validator Address to remove
     */
    function removeValidator(address validator) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (!validators[validator]) revert NotValidator();

        validators[validator] = false;
        totalValidators--;
        _revokeRole(VALIDATOR_ROLE, validator);

        emit ValidatorRemoved(validator);
    }

    /**
     * @notice Emergency pause
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @notice Emergency token recovery
     * @param token Token to recover
     * @param amount Amount to recover
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(token).safeTransfer(treasury, amount);
    }

    // ========== View Functions ==========

    /**
     * @notice Get contributor information
     */
    function getContributor(address contributor) external view returns (uint256 score, uint256 rewards) {
        return (contributorScores[contributor], contributorRewards[contributor]);
    }

    /**
     * @notice Get DLP statistics
     */
    function getStats()
        external
        view
        returns (
            uint256 contributions,
            uint256 validatorCount,
            uint256 epoch,
            uint256 nextEpochTime,
            string memory name,
            string memory version
        )
    {
        return (totalContributions, totalValidators, currentEpoch, lastEpochTime + EPOCH_DURATION, DLP_NAME, VERSION);
    }

    /**
     * @notice Check if data is validated
     */
    function isDataValidated(bytes32 dataHash) external view returns (bool) {
        return validatedData[dataHash];
    }

    /**
     * @notice Check if address is validator
     */
    function isValidator(address account) external view returns (bool) {
        return validators[account];
    }
}
