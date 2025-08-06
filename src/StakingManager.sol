// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IStakingManager.sol";
import "./interfaces/IRewardsManager.sol";
import "./interfaces/IRDAT.sol";

/**
 * @title StakingManager
 * @author r/datadao
 * @notice Immutable contract that handles core staking logic only - no rewards
 * @dev This contract is designed to be immutable with emergency migration as the upgrade path
 * 
 * Key Design Principles:
 * - No reward logic whatsoever - only tracks stakes
 * - Emits events for all state changes for reward tracking
 * - Supports multiple stakes per user with unique IDs
 * - Emergency migration allows penalty-free exit when needed
 * - Immutable for maximum security of user funds
 */
contract StakingManager is IStakingManager, AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // Roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    // Lock period constants (in seconds)
    uint256 public constant override MONTH_1 = 30 days;
    uint256 public constant override MONTH_3 = 90 days;
    uint256 public constant override MONTH_6 = 180 days;
    uint256 public constant override MONTH_12 = 365 days;
    
    // Staking limits
    uint256 public constant override MIN_STAKE_AMOUNT = 100 * 10**18; // 100 RDAT minimum
    uint256 public constant override MAX_STAKE_AMOUNT = 10_000_000 * 10**18; // 10M RDAT maximum per stake
    uint256 public constant override EMERGENCY_WITHDRAW_PENALTY = 5000; // 50% penalty in basis points
    
    // State variables
    IERC20 private immutable rdatToken;
    IRewardsManager private rewardsManager;
    
    uint256 private nextStakeId;
    uint256 private _totalStaked;
    bool private emergencyMigrationEnabled;
    
    // User stake tracking
    mapping(address => uint256[]) private userStakeIds;
    mapping(address => mapping(uint256 => StakeInfo)) private stakes;
    mapping(address => uint256) private userTotalStakedAmount;
    
    // Lock period multipliers (for view functions only - not used for rewards)
    mapping(uint256 => uint256) private lockMultipliers;
    
    constructor(address _rdatToken, address _rewardsManager) {
        if (_rdatToken == address(0) || _rewardsManager == address(0)) {
            revert InvalidAmount();
        }
        
        rdatToken = IERC20(_rdatToken);
        rewardsManager = IRewardsManager(_rewardsManager);
        
        // Set up roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        
        // Initialize lock period multipliers (for reference only)
        lockMultipliers[MONTH_1] = 10000;   // 1.0x
        lockMultipliers[MONTH_3] = 15000;   // 1.5x
        lockMultipliers[MONTH_6] = 20000;   // 2.0x
        lockMultipliers[MONTH_12] = 40000;  // 4.0x
    }
    
    /**
     * @notice Stake RDAT tokens for a specified lock period
     * @param amount Amount of RDAT to stake
     * @param lockPeriod Lock period in seconds (must be 30, 90, 180, or 365 days)
     * @return stakeId Unique identifier for this stake
     */
    function stake(uint256 amount, uint256 lockPeriod) 
        external 
        override 
        whenNotPaused 
        nonReentrant 
        returns (uint256 stakeId) 
    {
        // Validate inputs
        if (amount < MIN_STAKE_AMOUNT || amount > MAX_STAKE_AMOUNT) {
            revert InvalidAmount();
        }
        if (!isValidLockPeriod(lockPeriod)) {
            revert InvalidLockPeriod();
        }
        
        // Transfer tokens from user
        uint256 balanceBefore = rdatToken.balanceOf(address(this));
        rdatToken.safeTransferFrom(msg.sender, address(this), amount);
        uint256 actualAmount = rdatToken.balanceOf(address(this)) - balanceBefore;
        
        // Create stake
        stakeId = nextStakeId++;
        uint256 endTime = block.timestamp + lockPeriod;
        
        stakes[msg.sender][stakeId] = StakeInfo({
            amount: actualAmount,
            startTime: block.timestamp,
            endTime: endTime,
            lockPeriod: lockPeriod,
            active: true,
            emergencyUnlocked: false
        });
        
        // Update tracking
        userStakeIds[msg.sender].push(stakeId);
        userTotalStakedAmount[msg.sender] += actualAmount;
        _totalStaked += actualAmount;
        
        // Emit event
        emit Staked(msg.sender, stakeId, actualAmount, lockPeriod, endTime);
        
        // Notify rewards manager
        try rewardsManager.notifyStake(msg.sender, stakeId, actualAmount, lockPeriod) {
            // Success
        } catch {
            // RewardsManager notification failed, but staking continues
            // This ensures staking works even if rewards system has issues
        }
        
        return stakeId;
    }
    
    /**
     * @notice Unstake tokens after lock period has ended
     * @param stakeId Unique identifier of the stake
     * @return amount Amount of RDAT returned
     */
    function unstake(uint256 stakeId) 
        external 
        override 
        nonReentrant 
        returns (uint256 amount) 
    {
        StakeInfo storage stakeInfo = stakes[msg.sender][stakeId];
        
        // Validate stake
        if (!stakeInfo.active) {
            revert StakeNotActive();
        }
        if (block.timestamp < stakeInfo.endTime && !emergencyMigrationEnabled && !stakeInfo.emergencyUnlocked) {
            revert StakeStillLocked();
        }
        
        amount = stakeInfo.amount;
        
        // Update state
        stakeInfo.active = false;
        userTotalStakedAmount[msg.sender] -= amount;
        _totalStaked -= amount;
        
        // Transfer tokens back to user
        rdatToken.safeTransfer(msg.sender, amount);
        
        // Emit event
        emit Unstaked(msg.sender, stakeId, amount, false);
        
        // Notify rewards manager
        try rewardsManager.notifyUnstake(msg.sender, stakeId, false) {
            // Success
        } catch {
            // Continue even if notification fails
        }
        
        return amount;
    }
    
    /**
     * @notice Emergency withdraw with penalty
     * @param stakeId Unique identifier of the stake
     * @return amount Amount of RDAT returned (after penalty)
     */
    function emergencyWithdraw(uint256 stakeId) 
        external 
        override 
        nonReentrant 
        returns (uint256 amount) 
    {
        StakeInfo storage stakeInfo = stakes[msg.sender][stakeId];
        
        // Validate stake
        if (!stakeInfo.active) {
            revert StakeNotActive();
        }
        
        uint256 fullAmount = stakeInfo.amount;
        
        // Calculate amount after penalty (unless emergency migration is enabled)
        if (emergencyMigrationEnabled || stakeInfo.emergencyUnlocked) {
            amount = fullAmount; // No penalty during migration
        } else {
            amount = fullAmount * (10000 - EMERGENCY_WITHDRAW_PENALTY) / 10000;
        }
        
        // Update state
        stakeInfo.active = false;
        userTotalStakedAmount[msg.sender] -= fullAmount;
        _totalStaked -= fullAmount;
        
        // Transfer tokens back to user
        if (amount > 0) {
            rdatToken.safeTransfer(msg.sender, amount);
        }
        
        // Send penalty to treasury if applicable
        uint256 penalty = fullAmount - amount;
        if (penalty > 0) {
            // For now, send to the contract itself as treasury
            // In production, this should be configurable
            rdatToken.safeTransfer(address(this), penalty);
        }
        
        // Emit event
        emit Unstaked(msg.sender, stakeId, fullAmount, true);
        
        // Notify rewards manager
        try rewardsManager.notifyUnstake(msg.sender, stakeId, true) {
            // Success
        } catch {
            // Continue even if notification fails
        }
        
        return amount;
    }
    
    // View functions
    
    function getStake(address user, uint256 stakeId) 
        external 
        view 
        override 
        returns (StakeInfo memory) 
    {
        return stakes[user][stakeId];
    }
    
    function getUserStakeIds(address user) 
        external 
        view 
        override 
        returns (uint256[] memory) 
    {
        return userStakeIds[user];
    }
    
    function getUserActiveStakeIds(address user) 
        external 
        view 
        override 
        returns (uint256[] memory) 
    {
        uint256[] memory allIds = userStakeIds[user];
        uint256 activeCount = 0;
        
        // Count active stakes
        for (uint256 i = 0; i < allIds.length; i++) {
            if (stakes[user][allIds[i]].active) {
                activeCount++;
            }
        }
        
        // Populate active stakes array
        uint256[] memory activeIds = new uint256[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < allIds.length; i++) {
            if (stakes[user][allIds[i]].active) {
                activeIds[index++] = allIds[i];
            }
        }
        
        return activeIds;
    }
    
    function isStakeActive(address user, uint256 stakeId) 
        external 
        view 
        override 
        returns (bool) 
    {
        return stakes[user][stakeId].active;
    }
    
    function totalStaked() external view override returns (uint256) {
        return _totalStaked;
    }
    
    function userTotalStaked(address user) external view override returns (uint256) {
        return userTotalStakedAmount[user];
    }
    
    function userActiveStakeCount(address user) external view override returns (uint256) {
        uint256[] memory allIds = userStakeIds[user];
        uint256 count = 0;
        
        for (uint256 i = 0; i < allIds.length; i++) {
            if (stakes[user][allIds[i]].active) {
                count++;
            }
        }
        
        return count;
    }
    
    function isValidLockPeriod(uint256 lockPeriod) public pure override returns (bool) {
        return lockPeriod == MONTH_1 || 
               lockPeriod == MONTH_3 || 
               lockPeriod == MONTH_6 || 
               lockPeriod == MONTH_12;
    }
    
    function getMultiplier(uint256 lockPeriod) external view override returns (uint256) {
        return lockMultipliers[lockPeriod];
    }
    
    function isEmergencyMigrationEnabled() external view override returns (bool) {
        return emergencyMigrationEnabled;
    }
    
    // Admin functions
    
    function enableEmergencyMigration() external override onlyRole(ADMIN_ROLE) {
        emergencyMigrationEnabled = true;
        emit EmergencyMigrationEnabled(block.timestamp);
    }
    
    function disableEmergencyMigration() external override onlyRole(ADMIN_ROLE) {
        emergencyMigrationEnabled = false;
        emit EmergencyMigrationDisabled(block.timestamp);
    }
    
    function setRewardsManager(address _rewardsManager) external onlyRole(ADMIN_ROLE) {
        if (_rewardsManager == address(0)) {
            revert InvalidAmount();
        }
        rewardsManager = IRewardsManager(_rewardsManager);
    }
    
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
}