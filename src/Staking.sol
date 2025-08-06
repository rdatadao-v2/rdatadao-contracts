// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IStaking.sol";
import "./interfaces/IRDAT.sol";
import "./interfaces/IvRDAT.sol";

/**
 * @title Staking
 * @author r/datadao
 * @notice Staking contract with time-lock multipliers and vRDAT minting
 * @dev Implements staking rewards with 1x-4x multipliers based on lock duration
 * 
 * Key Features:
 * - Time-lock staking with 1, 3, 6, and 12 month options
 * - Multiplier rewards: 1x, 1.5x, 2x, 4x respectively
 * - vRDAT minting for governance participation
 * - Emergency withdrawal with penalty
 * - Compound rewards through re-staking
 */
contract Staking is IStaking, AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // Roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    // Constants
    uint256 public constant override MONTH_1 = 30 days;
    uint256 public constant override MONTH_3 = 90 days;
    uint256 public constant override MONTH_6 = 180 days;
    uint256 public constant override MONTH_12 = 365 days;
    
    uint256 public constant override MAX_STAKE_PER_USER = 10_000_000 * 10**18; // 10M RDAT
    uint256 public constant override EMERGENCY_WITHDRAW_PENALTY = 50; // 50% penalty
    uint256 public constant PRECISION = 10000; // For percentage calculations
    
    // State variables
    IERC20 private immutable _rdatToken;
    IvRDAT private immutable _vrdatToken;
    
    mapping(address => StakeInfo) private _stakes;
    mapping(uint256 => uint256) public override lockMultipliers;
    
    uint256 public override totalStaked;
    uint256 public override totalRewardsDistributed;
    uint256 public override rewardRate; // Rewards per second per token staked (with precision)
    
    // Storage gap for upgradeability
    uint256[50] private __gap;
    
    /**
     * @dev Constructor sets up immutable token references and initial roles
     * @param rdatToken_ RDAT token address
     * @param vrdatToken_ vRDAT token address  
     * @param admin_ Admin address
     */
    constructor(
        address rdatToken_,
        address vrdatToken_,
        address admin_
    ) {
        require(rdatToken_ != address(0), "Invalid RDAT");
        require(vrdatToken_ != address(0), "Invalid vRDAT");
        require(admin_ != address(0), "Invalid admin");
        
        _rdatToken = IERC20(rdatToken_);
        _vrdatToken = IvRDAT(vrdatToken_);
        
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(ADMIN_ROLE, admin_);
        _grantRole(PAUSER_ROLE, admin_);
        
        // Initialize default multipliers (with PRECISION factor)
        lockMultipliers[MONTH_1] = 10000;   // 1x = 100%
        lockMultipliers[MONTH_3] = 15000;   // 1.5x = 150%
        lockMultipliers[MONTH_6] = 20000;   // 2x = 200%
        lockMultipliers[MONTH_12] = 40000;  // 4x = 400%
        
        // Default reward rate: 0.1 RDAT per second per 1000 RDAT staked
        rewardRate = 100; // 0.01% per second with PRECISION
    }
    
    /**
     * @dev Stake RDAT tokens for a specified lock period
     * @param amount Amount of RDAT to stake
     * @param lockPeriod Lock duration (must be one of the predefined periods)
     */
    function stake(uint256 amount, uint256 lockPeriod) external override nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        if (lockMultipliers[lockPeriod] == 0) revert InvalidLockDuration();
        
        StakeInfo storage userStake = _stakes[msg.sender];
        
        // If user has existing stake, claim pending rewards first
        if (userStake.amount > 0) {
            _claimRewards(msg.sender);
        }
        
        // Check max stake limit
        if (userStake.amount + amount > MAX_STAKE_PER_USER) {
            revert ExceedsMaxStakePerUser();
        }
        
        // Transfer RDAT tokens from user
        _rdatToken.safeTransferFrom(msg.sender, address(this), amount);
        
        // Update stake info
        if (userStake.amount == 0) {
            // New stake
            userStake.startTime = block.timestamp;
            userStake.lockPeriod = lockPeriod;
            userStake.multiplier = lockMultipliers[lockPeriod];
        } else {
            // Adding to existing stake - keep existing lock period
            // Can only add to stake, not change lock period
            require(
                block.timestamp < userStake.startTime + userStake.lockPeriod,
                "Existing stake expired"
            );
        }
        
        userStake.amount += amount;
        userStake.lastRewardTime = block.timestamp;
        totalStaked += amount;
        
        // Mint vRDAT for governance (1:1 ratio)
        _vrdatToken.mint(msg.sender, amount);
        userStake.vrdatMinted += amount;
        
        emit Staked(msg.sender, amount, lockPeriod, userStake.multiplier);
    }
    
    /**
     * @dev Unstake tokens after lock period ends
     */
    function unstake() external override nonReentrant {
        StakeInfo storage userStake = _stakes[msg.sender];
        uint256 stakedAmount = userStake.amount;
        
        if (stakedAmount == 0) revert InsufficientBalance();
        if (!canUnstake(msg.sender)) revert StakeStillLocked();
        
        // Claim any pending rewards
        _claimRewards(msg.sender);
        
        // Burn vRDAT tokens
        uint256 vrdatToBurn = userStake.vrdatMinted;
        if (vrdatToBurn > 0) {
            _vrdatToken.burn(msg.sender, vrdatToBurn);
        }
        
        // Reset stake info
        delete _stakes[msg.sender];
        totalStaked -= stakedAmount;
        
        // Transfer RDAT back to user
        _rdatToken.safeTransfer(msg.sender, stakedAmount);
        
        emit Unstaked(msg.sender, stakedAmount, vrdatToBurn);
    }
    
    /**
     * @dev Claim accumulated rewards
     */
    function claimRewards() external override nonReentrant whenNotPaused {
        _claimRewards(msg.sender);
    }
    
    /**
     * @dev Emergency withdrawal with penalty
     */
    function emergencyWithdraw() external override nonReentrant {
        StakeInfo storage userStake = _stakes[msg.sender];
        uint256 stakedAmount = userStake.amount;
        
        if (stakedAmount == 0) revert InsufficientBalance();
        
        // Calculate penalty
        uint256 penalty = (stakedAmount * EMERGENCY_WITHDRAW_PENALTY) / 100;
        uint256 withdrawAmount = stakedAmount - penalty;
        
        // Burn vRDAT tokens
        uint256 vrdatToBurn = userStake.vrdatMinted;
        if (vrdatToBurn > 0) {
            _vrdatToken.burn(msg.sender, vrdatToBurn);
        }
        
        // Reset stake info
        delete _stakes[msg.sender];
        totalStaked -= stakedAmount;
        
        // Transfer reduced amount back to user
        _rdatToken.safeTransfer(msg.sender, withdrawAmount);
        
        // Penalty stays in contract and can be rescued by admin
        // This avoids complexity of finding treasury address
        
        emit EmergencyWithdraw(msg.sender, withdrawAmount, penalty);
    }
    
    /**
     * @dev Calculate pending rewards for a user
     * @param user User address
     * @return pendingRewards Amount of pending rewards
     */
    function calculatePendingRewards(address user) external view override returns (uint256) {
        return _calculateRewards(user);
    }
    
    /**
     * @dev Check if user can unstake
     * @param user User address
     * @return canUnstakeNow Whether the user can unstake
     */
    function canUnstake(address user) public view override returns (bool) {
        StakeInfo memory userStake = _stakes[user];
        return userStake.amount > 0 && 
               block.timestamp >= userStake.startTime + userStake.lockPeriod;
    }
    
    /**
     * @dev Get stake end time for a user
     * @param user User address
     * @return endTime Timestamp when stake unlocks
     */
    function getStakeEndTime(address user) external view override returns (uint256) {
        StakeInfo memory userStake = _stakes[user];
        if (userStake.amount == 0) return 0;
        return userStake.startTime + userStake.lockPeriod;
    }
    
    /**
     * @dev Internal function to calculate rewards
     * @param user User address
     * @return rewards Calculated rewards
     */
    function _calculateRewards(address user) internal view returns (uint256) {
        StakeInfo memory userStake = _stakes[user];
        if (userStake.amount == 0) return 0;
        
        uint256 timeElapsed = block.timestamp - userStake.lastRewardTime;
        if (timeElapsed == 0) return 0;
        
        // Rewards = staked * rate * time * multiplier / precision^2
        uint256 rewards = (userStake.amount * rewardRate * timeElapsed * userStake.multiplier) 
                         / (PRECISION * PRECISION);
        
        return rewards;
    }
    
    /**
     * @dev Internal function to claim rewards
     * @param user User address
     */
    function _claimRewards(address user) internal {
        uint256 rewards = _calculateRewards(user);
        if (rewards == 0) revert NoRewardsToClaim();
        
        StakeInfo storage userStake = _stakes[user];
        userStake.lastRewardTime = block.timestamp;
        userStake.rewardsClaimed += rewards;
        totalRewardsDistributed += rewards;
        
        // Mint rewards from RDAT token (requires MINTER_ROLE on RDAT)
        IRDAT(address(_rdatToken)).mint(user, rewards);
        
        emit RewardsClaimed(user, rewards);
    }
    
    // Admin functions
    
    /**
     * @dev Set new reward rate
     * @param newRate New reward rate (with PRECISION factor)
     */
    function setRewardRate(uint256 newRate) external override onlyRole(ADMIN_ROLE) {
        uint256 oldRate = rewardRate;
        rewardRate = newRate;
        emit RewardRateUpdated(oldRate, newRate);
    }
    
    /**
     * @dev Update lock period multipliers
     * @param month1 1-month multiplier
     * @param month3 3-month multiplier
     * @param month6 6-month multiplier
     * @param month12 12-month multiplier
     */
    function setMultipliers(
        uint256 month1,
        uint256 month3,
        uint256 month6,
        uint256 month12
    ) external override onlyRole(ADMIN_ROLE) {
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
    
    // Additional getter functions to satisfy interface
    
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
     * @dev Get stake info for a user
     * @param user User address
     * @return Stake information
     */
    function stakes(address user) external view override returns (StakeInfo memory) {
        return _stakes[user];
    }
    
    /**
     * @dev Notify contract of revenue rewards (stub for compatibility)
     * @param amount Amount of rewards (unused in this version)
     */
    function notifyRewardAmount(uint256 amount) external override {
        // This is a stub implementation for interface compatibility
        // The old Staking contract doesn't support external reward distribution
        // Use StakingPositions for full functionality
    }
}