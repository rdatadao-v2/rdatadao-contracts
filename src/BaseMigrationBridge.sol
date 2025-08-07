// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IMigrationBridge} from "./interfaces/IMigrationBridge.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title BaseMigrationBridge
 * @notice Base chain side of the V1→V2 migration bridge
 * @dev Burns V1 RDAT tokens and emits events for validators to process on Vana
 *
 * Key features:
 * - Burns V1 tokens upon migration initiation
 * - Emits events for cross-chain validation
 * - Tracks migration amounts per user
 * - Emergency pause functionality
 * - No daily limits on Base side (enforced on Vana side)
 */
contract BaseMigrationBridge is IMigrationBridge, AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Roles
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // State variables
    IERC20 public immutable v1Token;
    uint256 public totalBurned;
    mapping(address => uint256) public userBurnedAmounts;

    // Migration deadline (1 year from deployment)
    uint256 public immutable migrationDeadline;

    // Events
    event TokensBurned(address indexed user, uint256 amount, bytes32 indexed burnTxHash);

    // Errors
    error ZeroAmount();
    error MigrationDeadlinePassed();
    error InsufficientBalance();

    /**
     * @dev Constructor
     * @param _v1Token Address of the V1 RDAT token on Base
     * @param _admin Admin address for role management
     */
    constructor(address _v1Token, address _admin) {
        require(_v1Token != address(0), "Invalid V1 token");
        require(_admin != address(0), "Invalid admin");

        v1Token = IERC20(_v1Token);
        migrationDeadline = block.timestamp + 365 days;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _admin);
    }

    /**
     * @notice Initiate migration by burning V1 tokens
     * @param amount Amount of V1 tokens to migrate
     * @dev Burns tokens and emits event for validators
     */
    function initiateMigration(uint256 amount) external override nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        if (block.timestamp > migrationDeadline) revert MigrationDeadlinePassed();

        // Check user balance
        uint256 userBalance = v1Token.balanceOf(msg.sender);
        if (userBalance < amount) revert InsufficientBalance();

        // Transfer tokens to this contract
        v1Token.safeTransferFrom(msg.sender, address(this), amount);

        // Update state
        userBurnedAmounts[msg.sender] += amount;
        totalBurned += amount;

        // Generate unique burn transaction hash
        bytes32 burnTxHash = keccak256(abi.encodePacked(msg.sender, amount, block.timestamp, block.number, totalBurned));

        // Emit events for validators
        emit TokensBurned(msg.sender, amount, burnTxHash);
        emit MigrationInitiated(burnTxHash, msg.sender, amount, burnTxHash);
    }

    /**
     * @notice Pause the migration bridge
     * @dev Only callable by PAUSER_ROLE
     */
    function pause() external override onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause the migration bridge
     * @dev Only callable by DEFAULT_ADMIN_ROLE
     */
    function unpause() external override onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @notice Rescue tokens sent by mistake after deadline
     * @param token Token address to rescue
     * @param to Recipient address
     * @param amount Amount to rescue
     * @dev Only callable by admin after migration deadline
     */
    function rescueTokens(address token, address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(block.timestamp > migrationDeadline, "Migration still active");
        require(to != address(0), "Invalid recipient");

        if (token == address(v1Token)) {
            // For V1 tokens, only rescue what wasn't burned
            uint256 contractBalance = v1Token.balanceOf(address(this));
            require(amount <= contractBalance, "Amount exceeds balance");
        }

        IERC20(token).safeTransfer(to, amount);
    }

    // ========== View Functions ==========

    /**
     * @notice Get user migration details
     * @param user User address
     * @return burnedAmount Total amount burned by user
     * @return remainingBalance Remaining V1 balance
     */
    function getUserMigrationInfo(address user)
        external
        view
        returns (uint256 burnedAmount, uint256 remainingBalance)
    {
        burnedAmount = userBurnedAmounts[user];
        remainingBalance = v1Token.balanceOf(user);
    }

    /**
     * @notice Check if migration deadline has passed
     * @return bool True if deadline passed
     */
    function isMigrationExpired() external view returns (bool) {
        return block.timestamp > migrationDeadline;
    }

    /**
     * @notice Time remaining until migration deadline
     * @return uint256 Seconds until deadline (0 if passed)
     */
    function timeUntilDeadline() external view returns (uint256) {
        if (block.timestamp > migrationDeadline) return 0;
        return migrationDeadline - block.timestamp;
    }

    // ========== Unused Interface Functions (Vana-side only) ==========

    function submitValidation(address, uint256, bytes32, uint256) external pure override {
        revert("Not implemented on Base");
    }

    function challengeMigration(bytes32) external pure override {
        revert("Not implemented on Base");
    }

    function executeMigration(bytes32) external pure override {
        revert("Not implemented on Base");
    }

    function addValidator(address) external pure override {
        revert("Not implemented on Base");
    }

    function removeValidator(address) external pure override {
        revert("Not implemented on Base");
    }

    function calculateBonus(uint256) external pure override returns (uint256) {
        revert("Not implemented on Base");
    }

    function migrationRequests(bytes32) external pure override returns (MigrationRequest memory) {
        revert("Not implemented on Base");
    }

    function processedBurnHashes(bytes32) external pure override returns (bool) {
        revert("Not implemented on Base");
    }

    function validators(address) external pure override returns (bool) {
        revert("Not implemented on Base");
    }

    function validatorCount() external pure override returns (uint256) {
        revert("Not implemented on Base");
    }

    function hasValidated(bytes32, address) external pure override returns (bool) {
        revert("Not implemented on Base");
    }

    function userMigrations(address user) external view override returns (uint256) {
        return userBurnedAmounts[user];
    }

    function totalMigrated() external view override returns (uint256) {
        return totalBurned;
    }

    function dailyMigrated() external pure override returns (uint256) {
        revert("Not implemented on Base");
    }

    function lastResetTime() external pure override returns (uint256) {
        revert("Not implemented on Base");
    }

    // Constants (return dummy values for Base side)
    function CHALLENGE_PERIOD() external pure override returns (uint256) {
        return 0;
    }

    function MIN_VALIDATORS() external pure override returns (uint256) {
        return 0;
    }

    function CONFIRMATION_BLOCKS() external pure override returns (uint256) {
        return 0;
    }

    function DAILY_LIMIT() external pure override returns (uint256) {
        return 0;
    }

    function WEEK_1_2_BONUS() external pure override returns (uint256) {
        return 0;
    }

    function WEEK_3_4_BONUS() external pure override returns (uint256) {
        return 0;
    }

    function WEEK_5_8_BONUS() external pure override returns (uint256) {
        return 0;
    }

    function BASIS_POINTS() external pure override returns (uint256) {
        return 10000;
    }
}
