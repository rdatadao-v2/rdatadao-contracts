// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interfaces/IStakingPositions.sol";
import "./interfaces/IRDAT.sol";
import "./interfaces/IvRDAT.sol";
import "./interfaces/IRewardsManager.sol";

/**
 * @title StakingPositions
 * @author r/datadao
 * @notice NFT-based staking contract allowing multiple concurrent positions
 * @dev Each stake creates an ERC-721 NFT with independent state
 *
 * Key Features:
 * - Unlimited concurrent stakes per user
 * - Each position has independent amount, duration, and rewards
 * - Soulbound during lock period (non-transferable)
 * - Transferable after maturity
 * - ERC721Enumerable for easy position queries
 * - Emergency withdrawal with penalty
 */
contract StakingPositions is
    Initializable,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    IStakingPositions
{
    using SafeERC20 for IERC20;

    // Roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant REVENUE_COLLECTOR_ROLE = keccak256("REVENUE_COLLECTOR_ROLE");
    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");

    // Events
    event RevenueRewardsReceived(uint256 amount, uint256 totalPending);
    event PenaltiesWithdrawn(address indexed recipient, uint256 amount);

    // Constants
    uint256 public constant MONTH_1 = 30 days;
    uint256 public constant MONTH_3 = 90 days;
    uint256 public constant MONTH_6 = 180 days;
    uint256 public constant MONTH_12 = 365 days;

    uint256 public constant EMERGENCY_WITHDRAW_PENALTY = 50; // 50% penalty
    uint256 public constant PRECISION = 10000; // For percentage calculations
    uint256 public constant MIN_STAKE_AMOUNT = 1e18; // 1 RDAT minimum to prevent dust attacks
    uint256 public constant MAX_POSITIONS_PER_USER = 100; // Maximum positions per user to prevent DoS

    // State variables
    IERC20 private _rdatToken;
    IvRDAT private _vrdatToken;

    uint256 private _nextPositionId;
    mapping(uint256 => Position) private _positions;
    mapping(uint256 => uint256) public lockMultipliers;

    uint256 public totalStaked;
    uint256 public totalRewardsDistributed;
    uint256 public rewardRate; // DEPRECATED: Rewards now handled by RewardsManager
    uint256 public pendingRevenueRewards; // Revenue rewards from RevenueCollector
    address public rewardsManager; // RewardsManager contract for notifications
    uint256 public accumulatedPenalties; // Track penalties from emergency withdrawals

    // Storage gap for upgradeability
    uint256[39] private __gap; // Reduced by 1 for accumulatedPenalties

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initialize the contract
     * @param rdatToken_ RDAT token address
     * @param vrdatToken_ vRDAT token address
     * @param admin_ Admin address
     */
    function initialize(address rdatToken_, address vrdatToken_, address admin_) public initializer {
        require(rdatToken_ != address(0), "Invalid RDAT");
        require(vrdatToken_ != address(0), "Invalid vRDAT");
        require(admin_ != address(0), "Invalid admin");

        __ERC721_init("r/datadao Staking Position", "rdatSTAKE");
        __ERC721Enumerable_init();
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _rdatToken = IERC20(rdatToken_);
        _vrdatToken = IvRDAT(vrdatToken_);

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(ADMIN_ROLE, admin_);
        _grantRole(PAUSER_ROLE, admin_);
        _grantRole(UPGRADER_ROLE, admin_);

        // Start position IDs at 1
        _nextPositionId = 1;

        // Initialize default multipliers (with PRECISION factor)
        lockMultipliers[MONTH_1] = 10000; // 1x = 100%
        lockMultipliers[MONTH_3] = 15000; // 1.5x = 150%
        lockMultipliers[MONTH_6] = 20000; // 2x = 200%
        lockMultipliers[MONTH_12] = 40000; // 4x = 400%

        // Default reward rate: 0.1 RDAT per second per 1000 RDAT staked
        // rewardRate = 100; // DEPRECATED: Rewards now handled by RewardsManager
    }

    /**
     * @dev Stake RDAT tokens for a specified lock period
     * @param amount Amount of RDAT to stake
     * @param lockPeriod Lock duration (must be one of the predefined periods)
     * @return positionId The ID of the created position NFT
     */
    function stake(uint256 amount, uint256 lockPeriod)
        external
        override
        nonReentrant
        whenNotPaused
        returns (uint256 positionId)
    {
        if (amount == 0) revert ZeroAmount();
        if (amount < MIN_STAKE_AMOUNT) revert BelowMinimumStake();
        if (lockMultipliers[lockPeriod] == 0) revert InvalidLockDuration();
        if (balanceOf(msg.sender) >= MAX_POSITIONS_PER_USER) revert TooManyPositions();

        // Transfer RDAT tokens from user
        _rdatToken.safeTransferFrom(msg.sender, address(this), amount);

        // Calculate vRDAT amount
        uint256 vrdatAmount = (amount * lockMultipliers[lockPeriod]) / PRECISION;

        // Create position
        positionId = _nextPositionId++;
        _positions[positionId] = Position({
            amount: amount,
            startTime: block.timestamp,
            lockPeriod: lockPeriod,
            multiplier: lockMultipliers[lockPeriod],
            vrdatMinted: vrdatAmount,
            lastRewardTime: block.timestamp,
            rewardsClaimed: 0
        });

        totalStaked += amount;

        // Mint position NFT
        _safeMint(msg.sender, positionId);

        // vRDAT minting is now handled by RewardsManager/vRDATRewardModule

        emit Staked(msg.sender, positionId, amount, lockPeriod, lockMultipliers[lockPeriod]);

        // Notify rewards manager if set
        if (rewardsManager != address(0)) {
            IRewardsManager(rewardsManager).notifyStake(msg.sender, positionId, amount, lockPeriod);
        }
    }

    /**
     * @dev Unstake a position after lock period ends
     * @param positionId The position NFT to unstake
     */
    function unstake(uint256 positionId) external override nonReentrant {
        if (_ownerOf(positionId) == address(0)) revert PositionDoesNotExist();
        if (ownerOf(positionId) != msg.sender) revert NotPositionOwner();
        if (!canUnstake(positionId)) revert StakeStillLocked();

        Position memory position = _positions[positionId];

        // Rewards are now claimed through RewardsManager, not here
        // vRDAT burning is now handled by RewardsManager/vRDATRewardModule

        // Notify rewards manager BEFORE deleting position data
        if (rewardsManager != address(0)) {
            IRewardsManager(rewardsManager).notifyUnstake(msg.sender, positionId, false);
        }

        // Delete position data
        delete _positions[positionId];
        totalStaked -= position.amount;

        // Burn the NFT
        _burn(positionId);

        // Transfer RDAT back to user
        _rdatToken.safeTransfer(msg.sender, position.amount);

        emit Unstaked(msg.sender, positionId, position.amount, position.vrdatMinted);
    }

    /**
     * @dev Claim accumulated rewards for a position
     * @param positionId The position to claim rewards for
     */
    function claimRewards(uint256 positionId) external virtual override nonReentrant whenNotPaused {
        if (_ownerOf(positionId) == address(0)) revert PositionDoesNotExist();
        if (ownerOf(positionId) != msg.sender) revert NotPositionOwner();

        // Users should claim rewards directly from RewardsManager
        revert("Use RewardsManager.claimRewards directly");
    }

    /**
     * @dev Claim rewards for all positions owned by the caller
     */
    function claimAllRewards() external override nonReentrant whenNotPaused {
        // Users should claim rewards directly from RewardsManager
        revert("Use RewardsManager.claimAllRewards directly");
    }

    /**
     * @dev Emergency withdrawal with penalty
     * @param positionId The position to emergency withdraw
     */
    function emergencyWithdraw(uint256 positionId) external override nonReentrant {
        if (_ownerOf(positionId) == address(0)) revert PositionDoesNotExist();
        if (ownerOf(positionId) != msg.sender) revert NotPositionOwner();

        Position storage position = _positions[positionId];
        uint256 stakedAmount = position.amount;

        // Calculate penalty
        uint256 penalty = (stakedAmount * EMERGENCY_WITHDRAW_PENALTY) / 100;
        uint256 withdrawAmount = stakedAmount - penalty;

        // vRDAT burning is now handled by RewardsManager/vRDATRewardModule

        // Notify rewards manager BEFORE deleting position data
        if (rewardsManager != address(0)) {
            IRewardsManager(rewardsManager).notifyUnstake(msg.sender, positionId, true);
        }

        // Clear the vRDAT amount to enable transfers
        position.vrdatMinted = 0;

        // Clear position amount but keep NFT for now (enables transfer)
        position.amount = 0;
        totalStaked -= stakedAmount;

        // Option 1: Keep NFT alive but empty (allows transfer)
        // Option 2: Burn NFT immediately (current behavior)
        _burn(positionId);

        // Track the penalty for treasury withdrawal
        accumulatedPenalties += penalty;

        // Transfer reduced amount back to user
        _rdatToken.safeTransfer(msg.sender, withdrawAmount);

        // Penalty stays in contract for treasury withdrawal

        emit EmergencyWithdraw(msg.sender, positionId, withdrawAmount, penalty);
    }

    /**
     * @dev Calculate pending rewards for a position
     * @param positionId The position to calculate rewards for
     * @return pendingRewards Amount of pending rewards
     */
    function calculatePendingRewards(uint256 positionId) external view override returns (uint256) {
        if (_ownerOf(positionId) == address(0)) return 0;
        return _calculateRewards(positionId);
    }

    /**
     * @dev Get all pending rewards for a user across all positions
     * @param user User address
     * @return totalPending Total pending rewards
     */
    function getUserTotalRewards(address user) external view override returns (uint256 totalPending) {
        uint256 balance = balanceOf(user);
        for (uint256 i = 0; i < balance; i++) {
            uint256 positionId = tokenOfOwnerByIndex(user, i);
            totalPending += _calculateRewards(positionId);
        }
    }

    /**
     * @dev Check if position can be unstaked
     * @param positionId Position ID
     * @return canUnstakeNow Whether the position can be unstaked
     */
    function canUnstake(uint256 positionId) public view override returns (bool) {
        if (_ownerOf(positionId) == address(0)) return false;
        Position memory position = _positions[positionId];
        return block.timestamp >= position.startTime + position.lockPeriod;
    }

    /**
     * @dev Get position details
     * @param positionId Position ID
     * @return position Position struct
     */
    function getPosition(uint256 positionId) external view override returns (Position memory) {
        if (_ownerOf(positionId) == address(0)) revert PositionDoesNotExist();
        return _positions[positionId];
    }

    /**
     * @dev Get all position IDs for a user
     * @param user User address
     * @return positionIds Array of position IDs
     */
    function getUserPositions(address user) external view override returns (uint256[] memory positionIds) {
        uint256 balance = balanceOf(user);
        positionIds = new uint256[](balance);
        for (uint256 i = 0; i < balance; i++) {
            positionIds[i] = tokenOfOwnerByIndex(user, i);
        }
    }

    /**
     * @dev Internal function to calculate rewards (protected for upgrades)
     * @return rewards Calculated rewards
     * @dev DEPRECATED: Rewards are now calculated by RewardsManager modules
     */
    function _calculateRewards(uint256) internal view virtual returns (uint256) {
        // StakingPositions no longer calculates rewards directly
        // This is now handled by RewardsManager and its modules
        return 0;
    }

    /**
     * @dev Override transfer to implement conditional transfer logic
     *
     * Transfer Rules:
     * 1. Position must be unlocked (time period expired)
     * 2. Position must not have active vRDAT rewards OR must be emergency exited
     *
     * This prevents creating "zombie" positions where the NFT is owned by one wallet
     * but the vRDAT needed to emergency exit is in another wallet.
     */
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        returns (address)
    {
        address from = _ownerOf(tokenId);

        // Allow minting and burning
        if (from != address(0) && to != address(0)) {
            Position memory position = _positions[tokenId];

            // Check 1: Position must be unlocked
            if (!canUnstake(tokenId)) revert TransferWhileLocked();

            // Check 2: Position must not have active vRDAT rewards
            // User must emergency exit first to burn vRDAT before transfer
            if (position.vrdatMinted > 0) {
                revert TransferWithActiveRewards();
            }
        }

        return super._update(to, tokenId, auth);
    }

    /**
     * @dev Override to resolve multiple inheritance
     */
    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        super._increaseBalance(account, value);
    }

    // Admin functions

    /**
     * @dev Set new reward rate
     * @param newRate New reward rate (with PRECISION factor)
     * @dev DEPRECATED: Reward rates are now set in RewardsManager modules
     */
    function setRewardRate(uint256 newRate) external override onlyRole(ADMIN_ROLE) {
        // No longer used - kept for interface compatibility
        emit RewardRateUpdated(rewardRate, newRate);
    }

    /**
     * @dev Update lock period multipliers
     * @param month1 1-month multiplier
     * @param month3 3-month multiplier
     * @param month6 6-month multiplier
     * @param month12 12-month multiplier
     */
    function setMultipliers(uint256 month1, uint256 month3, uint256 month6, uint256 month12)
        external
        override
        onlyRole(ADMIN_ROLE)
    {
        if (month1 == 0 || month3 == 0 || month6 == 0 || month12 == 0) {
            revert InvalidMultiplier();
        }

        lockMultipliers[MONTH_1] = month1;
        lockMultipliers[MONTH_3] = month3;
        lockMultipliers[MONTH_6] = month6;
        lockMultipliers[MONTH_12] = month12;

        emit MultipliersUpdated(month1, month3, month6, month12);
    }

    /**
     * @dev Rescue accidentally sent tokens (not RDAT)
     * @param token Token address
     * @param amount Amount to rescue
     */
    function rescueTokens(address token, uint256 amount) external override onlyRole(ADMIN_ROLE) {
        require(token != address(_rdatToken), "Cannot rescue RDAT");
        IERC20(token).safeTransfer(msg.sender, amount);
    }

    /**
     * @dev Set the rewards manager address
     * @param _rewardsManager New rewards manager address
     */
    function setRewardsManager(address _rewardsManager) external onlyRole(ADMIN_ROLE) {
        require(_rewardsManager != address(0), "Invalid rewards manager");
        rewardsManager = _rewardsManager;
        emit RewardsManagerUpdated(_rewardsManager);
    }

    /**
     * @dev Withdraw accumulated penalties from emergency withdrawals
     * @notice Only callable by treasury role
     * @param recipient Address to receive the penalties
     */
    function withdrawPenalties(address recipient) external onlyRole(TREASURY_ROLE) {
        require(recipient != address(0), "Invalid recipient");
        uint256 penalties = accumulatedPenalties;
        require(penalties > 0, "No penalties to withdraw");
        
        // Reset accumulated penalties before transfer (reentrancy protection)
        accumulatedPenalties = 0;
        
        // Transfer penalties to recipient (typically treasury)
        _rdatToken.safeTransfer(recipient, penalties);
        
        emit PenaltiesWithdrawn(recipient, penalties);
    }

    /**
     * @dev Pause the contract
     */
    function pause() external override onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause the contract
     */
    function unpause() external override onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev Notify contract of revenue rewards from RevenueCollector
     * @param amount Amount of rewards to distribute to stakers
     */
    function notifyRewardAmount(uint256 amount) external {
        // Only allow admin or a designated revenue collector to notify rewards
        require(hasRole(ADMIN_ROLE, msg.sender) || hasRole(REVENUE_COLLECTOR_ROLE, msg.sender), "Not authorized");

        // Transfer RDAT rewards from RevenueCollector to this contract
        require(_rdatToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        pendingRevenueRewards += amount;
        totalRewardsDistributed += amount;

        emit RevenueRewardsReceived(amount, pendingRevenueRewards);
    }

    /**
     * @dev Authorize upgrade
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    // View functions

    /**
     * @dev Get RDAT token address
     * @return RDAT token address
     */
    function rdatToken() external view override returns (address) {
        return address(_rdatToken);
    }

    /**
     * @dev Get vRDAT token address
     * @return vRDAT token address
     */
    function vrdatToken() external view override returns (address) {
        return address(_vrdatToken);
    }

    /**
     * @dev Required override for ERC721Enumerable
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
