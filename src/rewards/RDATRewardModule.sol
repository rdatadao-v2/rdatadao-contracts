// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IRewardModule.sol";
import "../interfaces/IStakingPositions.sol";

/**
 * @title RDATRewardModule
 * @author r/datadao
 * @notice Reward module for time-based RDAT staking rewards
 * @dev Accumulates rewards over time based on stake amount and duration
 *
 * Key Features:
 * - Time-based reward accumulation
 * - Multipliers based on lock period
 * - Fixed reward rate per RDAT staked
 * - Slashing on emergency withdrawal
 * - Lazy calculation on claim
 */
contract RDATRewardModule is IRewardModule, AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant REWARDS_MANAGER_ROLE = keccak256("REWARDS_MANAGER_ROLE");
    bytes32 public constant TREASURER_ROLE = keccak256("TREASURER_ROLE");

    // Reward tracking
    struct RewardState {
        uint256 accumulated; // Rewards accumulated but not claimed
        uint256 claimed; // Total rewards claimed
        uint256 lastUpdateTime; // Last time rewards were calculated
        uint256 stakeAmount; // Amount staked (cached for calculations)
        uint256 lockMultiplier; // Lock period multiplier (cached)
        bool active; // Whether stake is active
    }

    // State variables
    IERC20 public immutable rdatToken;
    IStakingPositions public immutable stakingManager;
    address public rewardsManager;

    bool public isActiveFlag;
    uint256 public totalAllocation;
    uint256 public totalDistributedAmount;
    uint256 public rewardRate; // Rewards per second per RDAT staked (with precision)

    uint256 public constant PRECISION = 1e18;
    uint256 public constant RATE_PRECISION = 1e27; // Higher precision for rate calculations

    // Lock period to reward multiplier (in basis points)
    mapping(uint256 => uint256) public lockMultipliers;

    // User reward tracking
    mapping(address => mapping(uint256 => RewardState)) public rewards;

    // Module info
    string public constant NAME = "RDAT Staking Rewards";
    string public constant VERSION = "1.0.0";

    // Events
    event RewardRateUpdated(uint256 newRate);
    event AllocationAdded(uint256 amount);
    event MultiplierUpdated(uint256 lockPeriod, uint256 multiplier);

    modifier onlyRewardsManager() {
        if (msg.sender != rewardsManager) {
            revert NotRewardsManager();
        }
        _;
    }

    constructor(
        address _rdatToken,
        address _stakingManager,
        address _rewardsManager,
        address _admin,
        uint256 _totalAllocation,
        uint256 _rewardRate
    ) {
        if (
            _rdatToken == address(0) || _stakingManager == address(0) || _rewardsManager == address(0)
                || _admin == address(0)
        ) {
            revert InvalidStakeData();
        }

        rdatToken = IERC20(_rdatToken);
        stakingManager = IStakingPositions(_stakingManager);
        rewardsManager = _rewardsManager;
        totalAllocation = _totalAllocation;
        rewardRate = _rewardRate;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
        _grantRole(TREASURER_ROLE, _admin);
        _grantRole(REWARDS_MANAGER_ROLE, _rewardsManager);

        // Initialize default multipliers (same as StakingManager)
        lockMultipliers[30 days] = 10000; // 1.0x
        lockMultipliers[90 days] = 15000; // 1.5x
        lockMultipliers[180 days] = 20000; // 2.0x
        lockMultipliers[365 days] = 40000; // 4.0x

        isActiveFlag = true;
    }

    /**
     * @notice Called when a stake is created
     * @param user Address of the staker
     * @param stakeId Unique stake identifier
     * @param amount Amount staked
     * @param lockPeriod Lock duration
     */
    function onStake(address user, uint256 stakeId, uint256 amount, uint256 lockPeriod)
        external
        override
        onlyRewardsManager
    {
        if (!isActiveFlag) {
            revert ModuleInactive();
        }

        uint256 multiplier = lockMultipliers[lockPeriod];
        if (multiplier == 0) {
            multiplier = 10000; // Default 1x
        }

        rewards[user][stakeId] = RewardState({
            accumulated: 0,
            claimed: 0,
            lastUpdateTime: block.timestamp,
            stakeAmount: amount,
            lockMultiplier: multiplier,
            active: true
        });
    }

    /**
     * @notice Called when a stake is removed
     * @param user Address of the staker
     * @param stakeId Unique stake identifier
     * @param emergency Whether this is an emergency withdrawal
     */
    function onUnstake(address user, uint256 stakeId, uint256, bool emergency) external override onlyRewardsManager {
        RewardState storage reward = rewards[user][stakeId];

        if (!reward.active) {
            return;
        }

        // Update accumulated rewards before deactivating
        _updateRewards(user, stakeId);

        if (emergency) {
            // Slash unclaimed rewards on emergency withdrawal
            uint256 unclaimed = reward.accumulated;
            if (unclaimed > 0) {
                reward.accumulated = 0;
                emit RewardSlashed(user, stakeId, unclaimed, address(rdatToken));
            }
        }

        reward.active = false;
    }

    /**
     * @notice Calculate pending rewards for a stake
     * @param user Address of the staker
     * @param stakeId Unique stake identifier
     * @return amount Pending reward amount
     */
    function calculateRewards(address user, uint256 stakeId) public view override returns (uint256) {
        RewardState memory reward = rewards[user][stakeId];

        if (!reward.active || reward.stakeAmount == 0) {
            return reward.accumulated;
        }

        // Check if stake still exists by trying to get position data
        try stakingManager.getPosition(stakeId) returns (IStakingPositions.Position memory) {
            // Position exists, continue with calculation
        } catch {
            // Position doesn't exist, return accumulated only
            return reward.accumulated;
        }

        uint256 timeDelta = block.timestamp - reward.lastUpdateTime;
        if (timeDelta == 0) {
            return reward.accumulated;
        }

        // Calculate new rewards
        // Formula: (stakeAmount * rewardRate * timeDelta * multiplier) / (RATE_PRECISION * 10000)
        uint256 baseReward = (reward.stakeAmount * rewardRate * timeDelta) / RATE_PRECISION;
        uint256 multipliedReward = (baseReward * reward.lockMultiplier) / 10000;

        return reward.accumulated + multipliedReward;
    }

    /**
     * @notice Claim rewards for a stake
     * @param user Address of the staker
     * @param stakeId Unique stake identifier
     * @return amount Amount of rewards claimed
     */
    function claimRewards(address user, uint256 stakeId)
        external
        override
        onlyRewardsManager
        nonReentrant
        returns (uint256)
    {
        _updateRewards(user, stakeId);

        RewardState storage reward = rewards[user][stakeId];
        uint256 claimable = reward.accumulated;

        if (claimable == 0) {
            return 0;
        }

        // Check allocation
        if (totalDistributedAmount + claimable > totalAllocation) {
            revert InsufficientAllocation();
        }

        // Update state
        reward.accumulated = 0;
        reward.claimed += claimable;
        totalDistributedAmount += claimable;

        // Transfer rewards
        rdatToken.safeTransfer(user, claimable);

        emit RewardDistributed(user, stakeId, claimable, address(rdatToken));

        return claimable;
    }

    /**
     * @notice Update accumulated rewards for a stake
     */
    function _updateRewards(address user, uint256 stakeId) internal {
        RewardState storage reward = rewards[user][stakeId];

        if (!reward.active) {
            return;
        }

        uint256 pending = calculateRewards(user, stakeId);
        reward.accumulated = pending;
        reward.lastUpdateTime = block.timestamp;
    }

    // View functions

    function getModuleInfo() external view override returns (ModuleInfo memory) {
        return ModuleInfo({
            name: NAME,
            version: VERSION,
            rewardToken: address(rdatToken),
            isActive: isActiveFlag,
            supportsHistory: true,
            totalAllocated: totalAllocation,
            totalDistributed: totalDistributedAmount
        });
    }

    function isActive() external view override returns (bool) {
        return isActiveFlag;
    }

    function rewardToken() external view override returns (address) {
        return address(rdatToken);
    }

    function totalAllocated() external view override returns (uint256) {
        return totalAllocation;
    }

    function totalDistributed() external view override returns (uint256) {
        return totalDistributedAmount;
    }

    function remainingAllocation() external view override returns (uint256) {
        return totalAllocation > totalDistributedAmount ? totalAllocation - totalDistributedAmount : 0;
    }

    function getRewardState(address user, uint256 stakeId) external view returns (RewardState memory) {
        return rewards[user][stakeId];
    }

    // Admin functions

    function setRewardRate(uint256 _rewardRate) external onlyRole(ADMIN_ROLE) {
        rewardRate = _rewardRate;
        emit RewardRateUpdated(_rewardRate);
    }

    function addAllocation(uint256 amount) external onlyRole(TREASURER_ROLE) {
        totalAllocation += amount;

        // Transfer tokens to this contract
        rdatToken.safeTransferFrom(msg.sender, address(this), amount);

        emit AllocationAdded(amount);
        emit AllocationIncreased(amount);
    }

    function setMultiplier(uint256 lockPeriod, uint256 multiplier) external onlyRole(ADMIN_ROLE) {
        if (multiplier == 0 || multiplier > 100000) {
            // Max 10x
            revert InvalidStakeData();
        }
        lockMultipliers[lockPeriod] = multiplier;
        emit MultiplierUpdated(lockPeriod, multiplier);
    }

    function setActive(bool active) external onlyRole(ADMIN_ROLE) {
        isActiveFlag = active;
        emit ModuleStatusChanged(active);
    }

    function updateRewardsManager(address _rewardsManager) external onlyRole(ADMIN_ROLE) {
        if (_rewardsManager == address(0)) {
            revert InvalidStakeData();
        }

        // Revoke old manager role
        if (rewardsManager != address(0)) {
            _revokeRole(REWARDS_MANAGER_ROLE, rewardsManager);
        }

        // Grant new manager role
        rewardsManager = _rewardsManager;
        _grantRole(REWARDS_MANAGER_ROLE, _rewardsManager);
    }

    /**
     * @notice Notify module of revenue rewards to distribute
     * @param amount Amount of RDAT tokens to add to allocation
     */
    function notifyRewardAmount(uint256 amount) external onlyRole(REWARDS_MANAGER_ROLE) {
        require(amount > 0, "Zero amount");
        totalAllocation += amount;
        emit AllocationIncreased(amount);
    }

    /**
     * @notice Emergency token recovery
     */
    function emergencyWithdraw(address token, uint256 amount) external override onlyRole(ADMIN_ROLE) {
        uint256 remaining = totalAllocation > totalDistributedAmount ? totalAllocation - totalDistributedAmount : 0;

        if (token == address(rdatToken) && amount > remaining) {
            revert InsufficientAllocation();
        }

        IERC20(token).safeTransfer(msg.sender, amount);
    }
}
