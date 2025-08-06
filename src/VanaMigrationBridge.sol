// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IMigrationBridge} from "./interfaces/IMigrationBridge.sol";
import {MigrationBonusVesting} from "./MigrationBonusVesting.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title VanaMigrationBridge
 * @notice Vana chain side of the V1→V2 migration bridge
 * @dev Releases V2 RDAT tokens based on validator consensus
 * 
 * Key features:
 * - Multi-validator consensus (2-of-3 minimum)
 * - Challenge period for security
 * - Daily migration limits
 * - Time-based bonus incentives
 * - Pre-allocated token pool (30M RDAT)
 */
contract VanaMigrationBridge is IMigrationBridge, AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // Roles
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
    
    // Constants
    uint256 public constant override CHALLENGE_PERIOD = 6 hours;
    uint256 public constant override MIN_VALIDATORS = 2;
    uint256 public constant override CONFIRMATION_BLOCKS = 12;
    uint256 public constant override BASIS_POINTS = 10000;
    
    // Bonus rates (in basis points)
    uint256 public constant override WEEK_1_2_BONUS = 500; // 5%
    uint256 public constant override WEEK_3_4_BONUS = 300; // 3%
    uint256 public constant override WEEK_5_8_BONUS = 100; // 1%
    
    // State variables
    IERC20 public immutable v2Token;
    MigrationBonusVesting public bonusVesting;
    uint256 public immutable deploymentTime;
    uint256 public immutable migrationDeadline;
    
    // Migration tracking
    mapping(bytes32 => MigrationRequest) private _migrationRequests;
    mapping(bytes32 => bool) private _processedBurnHashes;
    mapping(address => bool) private _validators;
    mapping(bytes32 => mapping(address => bool)) private _hasValidated;
    mapping(address => uint256) private _userMigrations;
    
    uint256 private _totalMigrated;
    uint256 private _dailyMigrated;
    uint256 private _lastResetTime;
    uint256 private _validatorCount;
    uint256 private _dailyLimit;
    
    // Events
    event DailyLimitUpdated(uint256 newLimit);
    event MigrationCompleted(address indexed user, uint256 amount, uint256 bonus);
    
    // Errors
    error InvalidValidator();
    error AlreadyValidator();
    error NotValidator();
    error InsufficientValidators();
    error AlreadyProcessed();
    error AlreadyValidated();
    error InvalidRequest();
    error ChallengePeriodActive();
    error NotChallenged();
    error DailyLimitExceeded();
    error MigrationDeadlinePassed();
    error InsufficientBalance();
    error ZeroAmount();
    
    /**
     * @dev Constructor
     * @param _v2Token Address of the V2 RDAT token on Vana
     * @param _admin Admin address for role management
     * @param validators_ Initial validator addresses
     */
    constructor(
        address _v2Token,
        address _admin,
        address[] memory validators_
    ) {
        require(_v2Token != address(0), "Invalid V2 token");
        require(_admin != address(0), "Invalid admin");
        require(validators_.length >= MIN_VALIDATORS, "Insufficient validators");
        
        v2Token = IERC20(_v2Token);
        deploymentTime = block.timestamp;
        migrationDeadline = block.timestamp + 365 days;
        _lastResetTime = block.timestamp;
        
        // Set initial daily limit (1% of allocation = 300,000 RDAT)
        _dailyLimit = 300_000 * 10**18;
        
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _admin);
        
        // Add initial validators
        for (uint256 i = 0; i < validators_.length; i++) {
            _addValidator(validators_[i]);
        }
    }
    
    /**
     * @notice Submit validation for a migration request
     * @param user User address from Base chain
     * @param amount Amount burned on Base
     * @param burnTxHash Transaction hash from Base burn
     * @param burnBlockNumber Block number of Base burn
     */
    function submitValidation(
        address user,
        uint256 amount,
        bytes32 burnTxHash,
        uint256 burnBlockNumber
    ) external override nonReentrant whenNotPaused onlyRole(VALIDATOR_ROLE) {
        if (amount == 0) revert ZeroAmount();
        if (block.timestamp > migrationDeadline) revert MigrationDeadlinePassed();
        if (_processedBurnHashes[burnTxHash]) revert AlreadyProcessed();
        
        // Generate request ID
        bytes32 requestId = keccak256(abi.encodePacked(user, amount, burnTxHash));
        
        // Check if validator already validated this request
        if (_hasValidated[requestId][msg.sender]) revert AlreadyValidated();
        
        MigrationRequest storage request = _migrationRequests[requestId];
        
        // Initialize request if first validation
        if (request.validatorApprovals == 0) {
            uint256 bonus = calculateBonus(amount);
            
            request.user = user;
            request.amount = amount;
            request.bonus = bonus;
            request.burnTxHash = burnTxHash;
            request.burnBlockNumber = burnBlockNumber;
            request.challengeEndTime = block.timestamp + CHALLENGE_PERIOD;
        } else {
            // Verify consistent data
            require(request.user == user, "User mismatch");
            require(request.amount == amount, "Amount mismatch");
            require(request.burnTxHash == burnTxHash, "Burn hash mismatch");
        }
        
        // Record validation
        _hasValidated[requestId][msg.sender] = true;
        request.validatorApprovals++;
        
        emit MigrationValidated(requestId, msg.sender);
        
        // Auto-execute if enough validators
        if (request.validatorApprovals >= MIN_VALIDATORS && 
            block.timestamp >= request.challengeEndTime &&
            !request.challenged) {
            _executeMigration(requestId);
        }
    }
    
    /**
     * @notice Challenge a migration request
     * @param requestId Request to challenge
     * @dev Only validators can challenge
     */
    function challengeMigration(bytes32 requestId) 
        external 
        override 
        onlyRole(VALIDATOR_ROLE) 
        whenNotPaused 
    {
        MigrationRequest storage request = _migrationRequests[requestId];
        if (request.validatorApprovals == 0) revert InvalidRequest();
        if (request.executed) revert AlreadyProcessed();
        if (request.challenged) revert AlreadyProcessed();
        
        request.challenged = true;
        emit MigrationChallenged(requestId, msg.sender);
    }
    
    /**
     * @notice Execute a validated migration
     * @param requestId Request to execute
     */
    function executeMigration(bytes32 requestId) external override nonReentrant whenNotPaused {
        _executeMigration(requestId);
    }
    
    /**
     * @dev Internal function to execute migration
     */
    function _executeMigration(bytes32 requestId) private {
        MigrationRequest storage request = _migrationRequests[requestId];
        
        if (request.validatorApprovals < MIN_VALIDATORS) revert InsufficientValidators();
        if (request.executed) revert AlreadyProcessed();
        if (request.challenged) revert NotChallenged();
        if (block.timestamp < request.challengeEndTime) revert ChallengePeriodActive();
        
        // For daily limit, we only count the base amount (not bonus)
        // as bonus comes from a different allocation
        _checkAndUpdateDailyLimit(request.amount);
        
        // Check contract balance for base amount only
        uint256 contractBalance = v2Token.balanceOf(address(this));
        if (contractBalance < request.amount) revert InsufficientBalance();
        
        // Mark as executed
        request.executed = true;
        _processedBurnHashes[request.burnTxHash] = true;
        
        // Update tracking
        _userMigrations[request.user] += request.amount;
        _totalMigrated += request.amount;
        
        // Transfer base migration amount (1:1 from migration allocation)
        v2Token.safeTransfer(request.user, request.amount);
        
        // Handle bonus through vesting contract if set and bonus > 0
        if (address(bonusVesting) != address(0) && request.bonus > 0) {
            // Grant bonus through vesting contract (12-month linear vesting)
            bonusVesting.grantMigrationBonus(request.user, request.bonus);
        }
        
        emit MigrationExecuted(requestId, request.user, request.amount, request.bonus);
        emit MigrationCompleted(request.user, request.amount, request.bonus);
    }
    
    /**
     * @notice Calculate migration bonus based on timing
     * @param amount Base amount to calculate bonus for
     * @return bonus Bonus amount in tokens
     */
    function calculateBonus(uint256 amount) public view override returns (uint256) {
        uint256 weeksSinceDeployment = (block.timestamp - deploymentTime) / 1 weeks;
        uint256 bonusRate;
        
        if (weeksSinceDeployment < 2) {
            bonusRate = WEEK_1_2_BONUS;
        } else if (weeksSinceDeployment < 4) {
            bonusRate = WEEK_3_4_BONUS;
        } else if (weeksSinceDeployment < 8) {
            bonusRate = WEEK_5_8_BONUS;
        } else {
            bonusRate = 0;
        }
        
        return (amount * bonusRate) / BASIS_POINTS;
    }
    
    /**
     * @notice Add a new validator
     * @param validator Address to add as validator
     */
    function addValidator(address validator) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        _addValidator(validator);
    }
    
    /**
     * @dev Internal function to add validator
     */
    function _addValidator(address validator) private {
        if (validator == address(0)) revert InvalidValidator();
        if (_validators[validator]) revert AlreadyValidator();
        
        _validators[validator] = true;
        _validatorCount++;
        _grantRole(VALIDATOR_ROLE, validator);
        
        emit ValidatorAdded(validator);
    }
    
    /**
     * @notice Remove a validator
     * @param validator Address to remove
     */
    function removeValidator(address validator) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (!_validators[validator]) revert NotValidator();
        if (_validatorCount <= MIN_VALIDATORS) revert InsufficientValidators();
        
        _validators[validator] = false;
        _validatorCount--;
        _revokeRole(VALIDATOR_ROLE, validator);
        
        emit ValidatorRemoved(validator);
    }
    
    /**
     * @notice Update daily migration limit
     * @param newLimit New daily limit in tokens
     */
    function updateDailyLimit(uint256 newLimit) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _dailyLimit = newLimit;
        emit DailyLimitUpdated(newLimit);
    }
    
    /**
     * @dev Check and update daily limit tracking
     */
    function _checkAndUpdateDailyLimit(uint256 amount) private {
        // Reset daily counter if new day
        if (block.timestamp >= _lastResetTime + 1 days) {
            _dailyMigrated = 0;
            _lastResetTime = block.timestamp;
            emit DailyLimitReset(block.timestamp);
        }
        
        if (_dailyMigrated + amount > _dailyLimit) revert DailyLimitExceeded();
        _dailyMigrated += amount;
    }
    
    /**
     * @notice Pause the migration bridge
     */
    function pause() external override onlyRole(PAUSER_ROLE) {
        _pause();
    }
    
    /**
     * @notice Unpause the migration bridge
     */
    function unpause() external override onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
    
    /**
     * @notice Set the bonus vesting contract
     * @param _bonusVesting Address of the MigrationBonusVesting contract
     * @dev The vesting contract should be pre-funded with bonus allocation
     */
    function setBonusVesting(address _bonusVesting) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_bonusVesting != address(0), "Invalid vesting contract");
        bonusVesting = MigrationBonusVesting(_bonusVesting);
    }
    
    /**
     * @notice Return unclaimed tokens to treasury after deadline
     * @param to Treasury address
     */
    function returnUnclaimedTokens(address to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(block.timestamp > migrationDeadline, "Migration still active");
        require(to != address(0), "Invalid recipient");
        
        uint256 balance = v2Token.balanceOf(address(this));
        if (balance > 0) {
            v2Token.safeTransfer(to, balance);
        }
    }
    
    // ========== View Functions ==========
    
    function migrationRequests(bytes32 requestId) external view override returns (MigrationRequest memory) {
        return _migrationRequests[requestId];
    }
    
    function processedBurnHashes(bytes32 burnHash) external view override returns (bool) {
        return _processedBurnHashes[burnHash];
    }
    
    function validators(address validator) external view override returns (bool) {
        return _validators[validator];
    }
    
    function validatorCount() external view override returns (uint256) {
        return _validatorCount;
    }
    
    function hasValidated(bytes32 requestId, address validator) external view override returns (bool) {
        return _hasValidated[requestId][validator];
    }
    
    function userMigrations(address user) external view override returns (uint256) {
        return _userMigrations[user];
    }
    
    function totalMigrated() external view override returns (uint256) {
        return _totalMigrated;
    }
    
    function dailyMigrated() external view override returns (uint256) {
        return _dailyMigrated;
    }
    
    function lastResetTime() external view override returns (uint256) {
        return _lastResetTime;
    }
    
    function DAILY_LIMIT() external view override returns (uint256) {
        return _dailyLimit;
    }
    
    // ========== Unused Interface Functions (Base-side only) ==========
    
    function initiateMigration(uint256) external pure override {
        revert("Use submitValidation on Vana");
    }
}