// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/IRewardModule.sol";
import "../interfaces/IvRDAT.sol";
import "../interfaces/IStakingPositions.sol";

/**
 * @title vRDATRewardModule
 * @author r/datadao
 * @notice Reward module for immediate vRDAT governance token distribution
 * @dev Mints soul-bound vRDAT tokens immediately upon staking
 * 
 * Key Features:
 * - Immediate distribution upon stake
 * - Soul-bound tokens (non-transferable)
 * - Multipliers based on lock period
 * - Burns tokens on emergency withdrawal
 * - No claiming needed - automatic distribution
 */
contract vRDATRewardModule is IRewardModule, AccessControl, ReentrancyGuard {
    // Roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant REWARDS_MANAGER_ROLE = keccak256("REWARDS_MANAGER_ROLE");
    
    // State variables
    IvRDAT public immutable vrdatToken;
    IStakingPositions public immutable stakingManager;
    address public rewardsManager;
    
    bool public isActiveFlag;
    uint256 public constant PRECISION = 10000;
    
    // Lock period to vRDAT multiplier (in basis points)
    mapping(uint256 => uint256) public lockMultipliers;
    
    // Track vRDAT minted per stake
    mapping(address => mapping(uint256 => uint256)) public mintedAmounts;
    
    // Module info
    string public constant NAME = "vRDAT Governance Rewards";
    string public constant VERSION = "1.0.0";
    
    // Events
    event MultiplierUpdated(uint256 lockPeriod, uint256 multiplier);
    event ModuleActivated();
    event ModuleDeactivated();
    
    modifier onlyRewardsManager() {
        if (msg.sender != rewardsManager) {
            revert NotRewardsManager();
        }
        _;
    }
    
    constructor(
        address _vrdatToken,
        address _stakingManager,
        address _rewardsManager,
        address _admin
    ) {
        if (_vrdatToken == address(0) || 
            _stakingManager == address(0) || 
            _rewardsManager == address(0) ||
            _admin == address(0)) {
            revert InvalidStakeData();
        }
        
        vrdatToken = IvRDAT(_vrdatToken);
        stakingManager = IStakingPositions(_stakingManager);
        rewardsManager = _rewardsManager;
        
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
        _grantRole(REWARDS_MANAGER_ROLE, _rewardsManager);
        
        // Initialize multipliers matching StakingPositions
        lockMultipliers[30 days] = 10000;   // 1x = 100%
        lockMultipliers[90 days] = 15000;   // 1.5x = 150%
        lockMultipliers[180 days] = 20000;  // 2x = 200%
        lockMultipliers[365 days] = 40000;  // 4x = 400%
        
        isActiveFlag = true;
    }
    
    /**
     * @notice Called when a stake is created - mints vRDAT immediately
     * @param user Address of the staker
     * @param stakeId Unique stake identifier
     * @param amount Amount staked
     * @param lockPeriod Lock duration
     */
    function onStake(
        address user,
        uint256 stakeId,
        uint256 amount,
        uint256 lockPeriod
    ) external override onlyRewardsManager nonReentrant {
        if (!isActiveFlag) {
            revert ModuleInactive();
        }
        
        // Calculate vRDAT amount based on stake amount and lock period
        uint256 multiplier = lockMultipliers[lockPeriod];
        if (multiplier == 0) {
            multiplier = PRECISION; // Default 1x if not set
        }
        
        uint256 vrdatAmount = (amount * multiplier) / PRECISION;
        
        // Record minted amount
        mintedAmounts[user][stakeId] = vrdatAmount;
        
        // Mint vRDAT to user (soul-bound tokens)
        vrdatToken.mint(user, vrdatAmount);
        
        emit RewardDistributed(user, stakeId, vrdatAmount, address(vrdatToken));
    }
    
    /**
     * @notice Called when a stake is removed - burns vRDAT on emergency withdrawal
     * @param user Address of the staker
     * @param stakeId Unique stake identifier
     * @param emergency Whether this is an emergency withdrawal
     */
    function onUnstake(
        address user,
        uint256 stakeId,
        uint256,
        bool emergency
    ) external override onlyRewardsManager nonReentrant {
        uint256 vrdatAmount = mintedAmounts[user][stakeId];
        
        if (vrdatAmount > 0 && emergency) {
            // Burn vRDAT on emergency withdrawal
            try vrdatToken.burn(user, vrdatAmount) {
                emit RewardSlashed(user, stakeId, vrdatAmount, address(vrdatToken));
            } catch {
                // If burn fails (e.g., user already transferred despite soul-bound),
                // we continue anyway
            }
        }
        
        // Clear the record
        delete mintedAmounts[user][stakeId];
    }
    
    /**
     * @notice Calculate rewards - always returns 0 as vRDAT is distributed immediately
     * @return amount Always 0 (no pending rewards)
     */
    function calculateRewards(
        address,
        uint256
    ) external pure override returns (uint256) {
        // vRDAT is minted immediately, so no pending rewards
        return 0;
    }
    
    /**
     * @notice Claim rewards - always returns 0 as vRDAT is distributed immediately
     * @return amount Always 0 (nothing to claim)
     */
    function claimRewards(
        address,
        uint256
    ) external view override onlyRewardsManager returns (uint256) {
        // vRDAT is minted immediately, so nothing to claim
        return 0;
    }
    
    // View functions
    
    function getModuleInfo() external view override returns (ModuleInfo memory) {
        return ModuleInfo({
            name: NAME,
            version: VERSION,
            rewardToken: address(vrdatToken),
            isActive: isActiveFlag,
            supportsHistory: false,
            totalAllocated: type(uint256).max, // Unlimited minting
            totalDistributed: vrdatToken.totalSupply()
        });
    }
    
    function isActive() external view override returns (bool) {
        return isActiveFlag;
    }
    
    function rewardToken() external view override returns (address) {
        return address(vrdatToken);
    }
    
    function totalAllocated() external pure override returns (uint256) {
        return type(uint256).max; // Unlimited
    }
    
    function totalDistributed() external view override returns (uint256) {
        return vrdatToken.totalSupply();
    }
    
    function remainingAllocation() external pure override returns (uint256) {
        return type(uint256).max; // Unlimited
    }
    
    function getVRDATMinted(address user, uint256 stakeId) external view returns (uint256) {
        return mintedAmounts[user][stakeId];
    }
    
    // Admin functions
    
    function setMultiplier(uint256 lockPeriod, uint256 multiplier) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        if (multiplier == 0 || multiplier > 100000) { // Max 10x
            revert InvalidStakeData();
        }
        lockMultipliers[lockPeriod] = multiplier;
        emit MultiplierUpdated(lockPeriod, multiplier);
    }
    
    function setActive(bool active) external onlyRole(ADMIN_ROLE) {
        isActiveFlag = active;
        
        if (active) {
            emit ModuleActivated();
        } else {
            emit ModuleDeactivated();
        }
        
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
     * @notice Emergency token recovery
     * @dev Only for recovering accidentally sent tokens, not vRDAT
     */
    function emergencyWithdraw(address token, uint256 amount) 
        external 
        override 
        onlyRole(ADMIN_ROLE) 
    {
        if (token == address(vrdatToken)) {
            revert InvalidStakeData(); // Cannot withdraw vRDAT
        }
        
        if (token != address(0)) {
            // Use low-level call to handle both ERC20 and native transfers
            (bool success, ) = token.call(abi.encodeWithSignature("transfer(address,uint256)", msg.sender, amount));
            if (!success) {
                revert DistributionFailed();
            }
        }
    }
}