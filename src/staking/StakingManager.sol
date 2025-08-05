// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IStakingPositionNFT.sol";
import "./interfaces/IRewardProgramManager.sol";
import "./interfaces/IvRDAT.sol";

/**
 * @title StakingManager
 * @notice Core staking contract for RDAT with NFT-based positions
 * @dev Implements flexible lock periods, rewards, and delegation
 */
contract StakingManager is 
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable 
{
    using SafeERC20 for IERC20;
    
    // Roles
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    
    // Lock periods and multipliers
    uint256 public constant LOCK_30_DAYS = 30 days;
    uint256 public constant LOCK_90_DAYS = 90 days;
    uint256 public constant LOCK_180_DAYS = 180 days;
    uint256 public constant LOCK_365_DAYS = 365 days;
    
    mapping(uint256 => uint256) public lockPeriodMultipliers; // basis points
    mapping(uint256 => uint256) public earlyExitPenalties; // basis points
    
    // Core contracts
    IERC20 public rdatToken;
    IStakingPositionNFT public positionNFT;
    IRewardProgramManager public rewardManager;
    IvRDAT public vRDATToken;
    
    // Staking parameters
    uint256 public minStakeAmount;
    uint256 public maxStakeAmount;
    uint256 public totalStaked;
    
    // Position data
    mapping(uint256 => Position) public positions;
    uint256 public nextPositionId;
    
    struct Position {
        uint256 amount;
        uint256 lockPeriod;
        uint256 startTime;
        uint256 endTime;
        uint256 rewardMultiplier;
        uint256 vRDATMinted;
        address owner;
        bool active;
    }
    
    // Events
    event Staked(
        address indexed user,
        uint256 indexed positionId,
        uint256 amount,
        uint256 lockPeriod
    );
    event Unstaked(
        address indexed user,
        uint256 indexed positionId,
        uint256 amount,
        uint256 reward
    );
    event RewardsClaimed(
        address indexed user,
        uint256 indexed positionId,
        uint256 amount
    );
    event EarlyExit(
        address indexed user,
        uint256 indexed positionId,
        uint256 penalty
    );
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(
        address _rdatToken,
        address _positionNFT,
        address _rewardManager,
        address _vRDATToken
    ) public initializer {
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        
        rdatToken = IERC20(_rdatToken);
        positionNFT = IStakingPositionNFT(_positionNFT);
        rewardManager = IRewardProgramManager(_rewardManager);
        vRDATToken = IvRDAT(_vRDATToken);
        
        // Set up roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
        _grantRole(MANAGER_ROLE, msg.sender);
        
        // Initialize lock period multipliers (basis points)
        lockPeriodMultipliers[LOCK_30_DAYS] = 10000; // 1.0x
        lockPeriodMultipliers[LOCK_90_DAYS] = 15000; // 1.5x
        lockPeriodMultipliers[LOCK_180_DAYS] = 20000; // 2.0x
        lockPeriodMultipliers[LOCK_365_DAYS] = 40000; // 4.0x
        
        // Initialize early exit penalties (basis points)
        earlyExitPenalties[LOCK_30_DAYS] = 1000; // 10%
        earlyExitPenalties[LOCK_90_DAYS] = 1500; // 15%
        earlyExitPenalties[LOCK_180_DAYS] = 2000; // 20%
        earlyExitPenalties[LOCK_365_DAYS] = 2500; // 25%
        
        // Set initial parameters
        minStakeAmount = 100e18; // 100 RDAT minimum
        maxStakeAmount = 10_000_000e18; // 10M RDAT maximum
        nextPositionId = 1;
    }
    
    /**
     * @notice Stake RDAT tokens for a specified lock period
     * @param amount Amount of RDAT to stake
     * @param lockPeriod Lock period in seconds
     * @return positionId The ID of the created position
     */
    function stake(
        uint256 amount,
        uint256 lockPeriod
    ) external whenNotPaused nonReentrant returns (uint256 positionId) {
        require(amount >= minStakeAmount, "Below minimum stake");
        require(amount <= maxStakeAmount, "Above maximum stake");
        require(lockPeriodMultipliers[lockPeriod] > 0, "Invalid lock period");
        
        // Transfer tokens from user
        rdatToken.safeTransferFrom(msg.sender, address(this), amount);
        
        // Create position
        positionId = nextPositionId++;
        positions[positionId] = Position({
            amount: amount,
            lockPeriod: lockPeriod,
            startTime: block.timestamp,
            endTime: block.timestamp + lockPeriod,
            rewardMultiplier: lockPeriodMultipliers[lockPeriod],
            vRDATMinted: 0,
            owner: msg.sender,
            active: true
        });
        
        // Mint position NFT
        positionNFT.mint(msg.sender, positionId);
        
        // Calculate and mint vRDAT
        uint256 vRDATAmount = calculateVRDAT(amount, lockPeriod);
        positions[positionId].vRDATMinted = vRDATAmount;
        vRDATToken.mint(msg.sender, vRDATAmount);
        
        // Update total staked
        totalStaked += amount;
        
        // Register position with reward manager
        rewardManager.registerPosition(positionId, amount, lockPeriod);
        
        emit Staked(msg.sender, positionId, amount, lockPeriod);
    }
    
    /**
     * @notice Unstake position after lock period ends
     * @param positionId The position to unstake
     */
    function unstake(uint256 positionId) external nonReentrant {
        Position storage position = positions[positionId];
        require(position.active, "Position not active");
        require(positionNFT.ownerOf(positionId) == msg.sender, "Not position owner");
        require(block.timestamp >= position.endTime, "Still locked");
        
        uint256 amount = position.amount;
        uint256 rewards = rewardManager.calculateRewards(positionId);
        
        // Mark position as inactive
        position.active = false;
        
        // Burn position NFT
        positionNFT.burn(positionId);
        
        // Burn vRDAT
        vRDATToken.burn(msg.sender, position.vRDATMinted);
        
        // Update total staked
        totalStaked -= amount;
        
        // Unregister from reward manager
        rewardManager.unregisterPosition(positionId);
        
        // Transfer principal + rewards
        rdatToken.safeTransfer(msg.sender, amount + rewards);
        
        emit Unstaked(msg.sender, positionId, amount, rewards);
    }
    
    /**
     * @notice Exit position early with penalty
     * @param positionId The position to exit
     */
    function earlyExit(uint256 positionId) external nonReentrant {
        Position storage position = positions[positionId];
        require(position.active, "Position not active");
        require(positionNFT.ownerOf(positionId) == msg.sender, "Not position owner");
        require(block.timestamp < position.endTime, "Not early exit");
        
        uint256 penalty = (position.amount * earlyExitPenalties[position.lockPeriod]) / 10000;
        uint256 amountAfterPenalty = position.amount - penalty;
        
        // Mark position as inactive
        position.active = false;
        
        // Burn position NFT
        positionNFT.burn(positionId);
        
        // Burn vRDAT
        vRDATToken.burn(msg.sender, position.vRDATMinted);
        
        // Update total staked
        totalStaked -= position.amount;
        
        // Unregister from reward manager
        rewardManager.unregisterPosition(positionId);
        
        // Transfer amount after penalty
        rdatToken.safeTransfer(msg.sender, amountAfterPenalty);
        
        // Transfer penalty to treasury
        if (penalty > 0) {
            rdatToken.safeTransfer(rewardManager.treasury(), penalty);
        }
        
        emit EarlyExit(msg.sender, positionId, penalty);
    }
    
    /**
     * @notice Claim accumulated rewards for a position
     * @param positionId The position to claim rewards for
     */
    function claimRewards(uint256 positionId) external nonReentrant {
        require(positions[positionId].active, "Position not active");
        require(positionNFT.ownerOf(positionId) == msg.sender, "Not position owner");
        
        uint256 rewards = rewardManager.claimRewards(positionId, msg.sender);
        
        emit RewardsClaimed(msg.sender, positionId, rewards);
    }
    
    /**
     * @notice Calculate vRDAT amount for staking position
     * @param amount Staked amount
     * @param lockPeriod Lock period
     * @return vRDAT amount to mint
     */
    function calculateVRDAT(
        uint256 amount,
        uint256 lockPeriod
    ) public view returns (uint256) {
        uint256 multiplier = lockPeriodMultipliers[lockPeriod];
        return (amount * multiplier) / 10000;
    }
    
    /**
     * @notice Update staking parameters
     * @param _minStake New minimum stake amount
     * @param _maxStake New maximum stake amount
     */
    function updateParameters(
        uint256 _minStake,
        uint256 _maxStake
    ) external onlyRole(MANAGER_ROLE) {
        require(_minStake < _maxStake, "Invalid parameters");
        minStakeAmount = _minStake;
        maxStakeAmount = _maxStake;
    }
    
    /**
     * @notice Pause staking operations
     */
    function pause() external onlyRole(MANAGER_ROLE) {
        _pause();
    }
    
    /**
     * @notice Unpause staking operations
     */
    function unpause() external onlyRole(MANAGER_ROLE) {
        _unpause();
    }
    
    /**
     * @notice Authorize contract upgrade
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}
}