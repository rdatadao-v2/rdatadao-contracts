// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IRewardModule.sol";
import "../interfaces/IStakingPositions.sol";
import "../interfaces/IUniswapV3.sol";

/**
 * @title VRC14LiquidityModule
 * @author r/datadao
 * @notice Implements VRC-14 liquidity-based DLP incentives using Uniswap V3
 * @dev Converts VANA rewards into liquidity over 90 daily tranches
 * 
 * Key Features:
 * - 90-day liquidity program with daily tranches
 * - Automatic VANA->RDAT swaps and liquidity provision
 * - Proportional LP share distribution to stakers
 * - Configurable Uniswap V3 addresses for different networks
 * - Emergency pause and recovery mechanisms
 */
contract VRC14LiquidityModule is IRewardModule, AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // ========== CONSTANTS ==========
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant REWARDS_MANAGER_ROLE = keccak256("REWARDS_MANAGER_ROLE");
    
    uint256 public constant TRANCHES = 90;
    uint256 public constant TRANCHE_DURATION = 1 days;
    uint24 public constant DEFAULT_POOL_FEE = 3000; // 0.3%
    uint256 public constant MAX_SLIPPAGE = 200; // 2%
    uint256 public constant PRECISION = 10000;
    
    // Full range for initial implementation
    int24 private constant MIN_TICK = -887272;
    int24 private constant MAX_TICK = 887272;
    
    // ========== STATE VARIABLES ==========
    
    // Tokens
    IERC20 public immutable rdatToken;
    IERC20 public vanaToken; // Configurable
    
    // Uniswap V3 contracts (configurable)
    ISwapRouter public swapRouter;
    INonfungiblePositionManager public positionManager;
    IUniswapV3Factory public uniswapFactory;
    IUniswapV3Pool public rdatVanaPool;
    
    // Staking integration
    IStakingPositions public immutable stakingManager;
    address public rewardsManager;
    
    // Program state
    bool public isActiveFlag;
    bool public initialized;
    uint256 public totalVanaAllocated;
    uint256 public vanaPerTranche;
    uint256 public currentTranche;
    uint256 public lastExecutionTime;
    uint256 public programStartTime;
    
    // LP tracking
    uint256[] public tranchePositionIds;
    mapping(uint256 => uint256) public positionLiquidity;
    mapping(uint256 => uint256) public trancheTotalStaked; // Total staked at time of tranche
    mapping(address => mapping(uint256 => bool)) public hasClaimedTranche;
    mapping(address => uint256) public userAccumulatedShares;
    
    // Pool configuration
    uint24 public poolFee = DEFAULT_POOL_FEE;
    bool public poolCreated;
    
    // Module info
    string public constant NAME = "VRC-14 Liquidity Incentives";
    string public constant VERSION = "1.0.0";
    
    // ========== EVENTS ==========
    event ProgramInitialized(uint256 totalVana, uint256 perTranche, uint256 startTime);
    event TrancheExecuted(uint256 indexed tranche, uint256 positionId, uint256 liquidity);
    event LPSharesClaimed(address indexed user, uint256 indexed tranche, uint256 shares);
    event UniswapConfigUpdated(address swapRouter, address positionManager, address factory);
    event PoolCreated(address pool, uint24 fee);
    event EmergencyWithdrawal(address token, uint256 amount);
    
    // ========== ERRORS ==========
    error ProgramNotInitialized();
    error ProgramAlreadyInitialized();
    error TooEarlyForTranche();
    error ProgramComplete();
    error InvalidConfiguration();
    error PoolNotCreated();
    error AlreadyClaimed();
    error NoSharesToClaim();
    error SlippageExceeded();
    
    // ========== CONSTRUCTOR ==========
    constructor(
        address _rdatToken,
        address _stakingManager,
        address _admin
    ) {
        require(_rdatToken != address(0), "Invalid RDAT");
        require(_stakingManager != address(0), "Invalid staking");
        require(_admin != address(0), "Invalid admin");
        
        rdatToken = IERC20(_rdatToken);
        stakingManager = IStakingPositions(_stakingManager);
        
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
        _grantRole(EXECUTOR_ROLE, _admin);
        
        isActiveFlag = true;
    }
    
    // ========== CONFIGURATION FUNCTIONS ==========
    
    /**
     * @notice Configures Uniswap V3 contracts (admin only)
     * @param _vanaToken VANA token address
     * @param _swapRouter Uniswap V3 SwapRouter address
     * @param _positionManager Uniswap V3 NonfungiblePositionManager address
     * @param _factory Uniswap V3 Factory address
     */
    function configureUniswap(
        address _vanaToken,
        address _swapRouter,
        address _positionManager,
        address _factory
    ) external onlyRole(ADMIN_ROLE) {
        require(_vanaToken != address(0), "Invalid VANA");
        require(_swapRouter != address(0), "Invalid router");
        require(_positionManager != address(0), "Invalid position manager");
        require(_factory != address(0), "Invalid factory");
        
        vanaToken = IERC20(_vanaToken);
        swapRouter = ISwapRouter(_swapRouter);
        positionManager = INonfungiblePositionManager(_positionManager);
        uniswapFactory = IUniswapV3Factory(_factory);
        
        emit UniswapConfigUpdated(_swapRouter, _positionManager, _factory);
    }
    
    /**
     * @notice Creates or sets the RDAT-VANA pool
     * @param _poolFee Fee tier for the pool (500, 3000, or 10000)
     */
    function createOrSetPool(uint24 _poolFee) external onlyRole(ADMIN_ROLE) {
        require(address(vanaToken) != address(0), "Configure Uniswap first");
        require(_poolFee == 500 || _poolFee == 3000 || _poolFee == 10000, "Invalid fee");
        
        poolFee = _poolFee;
        
        // Check if pool exists
        address existingPool = uniswapFactory.getPool(
            address(rdatToken),
            address(vanaToken),
            poolFee
        );
        
        if (existingPool != address(0)) {
            rdatVanaPool = IUniswapV3Pool(existingPool);
            poolCreated = true;
        } else {
            // Pool will be created on first liquidity add
            poolCreated = false;
        }
        
        emit PoolCreated(address(rdatVanaPool), poolFee);
    }
    
    // ========== INITIALIZATION ==========
    
    /**
     * @notice Initializes the liquidity program
     * @param _totalVanaAmount Total VANA to distribute over 90 days
     */
    function initializeProgram(uint256 _totalVanaAmount) external onlyRole(ADMIN_ROLE) {
        if (initialized) revert ProgramAlreadyInitialized();
        require(_totalVanaAmount > 0, "Invalid amount");
        require(address(vanaToken) != address(0), "Configure Uniswap first");
        
        totalVanaAllocated = _totalVanaAmount;
        vanaPerTranche = _totalVanaAmount / TRANCHES;
        programStartTime = block.timestamp;
        lastExecutionTime = block.timestamp > TRANCHE_DURATION ? block.timestamp - TRANCHE_DURATION : 0; // Allow immediate first execution
        initialized = true;
        
        // Transfer VANA to contract
        vanaToken.safeTransferFrom(msg.sender, address(this), _totalVanaAmount);
        
        emit ProgramInitialized(_totalVanaAmount, vanaPerTranche, programStartTime);
    }
    
    // ========== CORE FUNCTIONS ==========
    
    /**
     * @notice Executes the daily tranche
     * @dev Can be called by anyone with EXECUTOR_ROLE after time delay
     */
    function executeDailyTranche() external onlyRole(EXECUTOR_ROLE) nonReentrant {
        if (!initialized) revert ProgramNotInitialized();
        if (block.timestamp < lastExecutionTime + TRANCHE_DURATION) revert TooEarlyForTranche();
        if (currentTranche >= TRANCHES) revert ProgramComplete();
        
        uint256 vanaAmount = vanaPerTranche;
        uint256 halfVana = vanaAmount / 2;
        
        // 1. Approve tokens for router/position manager
        vanaToken.approve(address(swapRouter), halfVana);
        vanaToken.approve(address(positionManager), halfVana);
        
        // 2. Swap half VANA for RDAT
        uint256 rdatReceived = _swapVanaForRdat(halfVana);
        
        // 3. Approve RDAT for position manager
        rdatToken.approve(address(positionManager), rdatReceived);
        
        // 4. Add liquidity
        (uint256 tokenId, uint128 liquidity) = _addLiquidity(rdatReceived, halfVana);
        
        // 5. Store position data
        tranchePositionIds.push(tokenId);
        positionLiquidity[tokenId] = liquidity;
        trancheTotalStaked[currentTranche] = stakingManager.totalStaked();
        
        // 6. Update state
        currentTranche++;
        lastExecutionTime = block.timestamp;
        
        emit TrancheExecuted(currentTranche, tokenId, liquidity);
    }
    
    /**
     * @notice Claims LP shares for a user based on their stake
     * @param user Address of the user
     */
    function claimRewards(
        address user,
        uint256
    ) external override onlyRole(REWARDS_MANAGER_ROLE) nonReentrant returns (uint256) {
        uint256 totalShares = 0;
        
        // Calculate claimable shares from all executed tranches
        for (uint256 i = 0; i < currentTranche; i++) {
            if (!hasClaimedTranche[user][i]) {
                // TODO: Calculate user's total staked across all positions
                uint256 userStake = 0; // Placeholder - needs implementation
                uint256 totalStake = trancheTotalStaked[i];
                
                if (totalStake > 0 && userStake > 0) {
                    uint256 trancheLiquidity = positionLiquidity[tranchePositionIds[i]];
                    uint256 userShare = (trancheLiquidity * userStake) / totalStake;
                    
                    totalShares += userShare;
                    hasClaimedTranche[user][i] = true;
                    
                    emit LPSharesClaimed(user, i, userShare);
                }
            }
        }
        
        if (totalShares == 0) revert NoSharesToClaim();
        
        userAccumulatedShares[user] += totalShares;
        
        // Note: Actual LP NFT transfer would happen here in production
        // For now, we track shares internally
        
        return totalShares;
    }
    
    // ========== INTERNAL FUNCTIONS ==========
    
    /**
     * @dev Swaps VANA for RDAT using Uniswap V3
     */
    function _swapVanaForRdat(uint256 vanaAmount) private returns (uint256) {
        // Calculate minimum output with slippage protection
        uint256 minOutput = _calculateMinimumOutput(vanaAmount);
        
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(vanaToken),
            tokenOut: address(rdatToken),
            fee: poolFee,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: vanaAmount,
            amountOutMinimum: minOutput,
            sqrtPriceLimitX96: 0
        });
        
        uint256 amountOut = swapRouter.exactInputSingle(params);
        
        if (amountOut < minOutput) revert SlippageExceeded();
        
        return amountOut;
    }
    
    /**
     * @dev Adds liquidity to the RDAT-VANA pool
     */
    function _addLiquidity(
        uint256 rdatAmount,
        uint256 vanaAmount
    ) private returns (uint256 tokenId, uint128 liquidity) {
        // Determine token order
        (address token0, address token1) = address(rdatToken) < address(vanaToken) 
            ? (address(rdatToken), address(vanaToken))
            : (address(vanaToken), address(rdatToken));
            
        (uint256 amount0, uint256 amount1) = token0 == address(rdatToken)
            ? (rdatAmount, vanaAmount)
            : (vanaAmount, rdatAmount);
        
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: token0,
            token1: token1,
            fee: poolFee,
            tickLower: MIN_TICK,
            tickUpper: MAX_TICK,
            amount0Desired: amount0,
            amount1Desired: amount1,
            amount0Min: (amount0 * (PRECISION - MAX_SLIPPAGE)) / PRECISION,
            amount1Min: (amount1 * (PRECISION - MAX_SLIPPAGE)) / PRECISION,
            recipient: address(this),
            deadline: block.timestamp
        });
        
        (tokenId, liquidity,,) = positionManager.mint(params);
        
        return (tokenId, liquidity);
    }
    
    /**
     * @dev Calculates minimum output amount with slippage protection
     */
    function _calculateMinimumOutput(uint256 inputAmount) private pure returns (uint256) {
        // In production, this would use TWAP or oracle prices
        // For now, use a simple calculation
        // Assume 1:1 ratio with 2% slippage allowed
        return (inputAmount * (PRECISION - MAX_SLIPPAGE)) / PRECISION;
    }
    
    // ========== VIEW FUNCTIONS ==========
    
    function calculateRewards(
        address user,
        uint256 /* stakeId */
    ) public view override returns (uint256) {
        uint256 totalShares = 0;
        // TODO: Calculate user's total staked across all positions
        uint256 userStake = 0; // Placeholder - needs implementation
        
        for (uint256 i = 0; i < currentTranche; i++) {
            if (!hasClaimedTranche[user][i] && trancheTotalStaked[i] > 0 && userStake > 0) {
                uint256 trancheLiquidity = positionLiquidity[tranchePositionIds[i]];
                uint256 userShare = (trancheLiquidity * userStake) / trancheTotalStaked[i];
                totalShares += userShare;
            }
        }
        
        return totalShares;
    }
    
    function getModuleInfo() external view override returns (ModuleInfo memory) {
        return ModuleInfo({
            name: NAME,
            version: VERSION,
            rewardToken: address(vanaToken),
            isActive: isActiveFlag && initialized,
            supportsHistory: true,
            totalAllocated: totalVanaAllocated,
            totalDistributed: currentTranche * vanaPerTranche
        });
    }
    
    function rewardToken() external view override returns (address) {
        return address(vanaToken);
    }
    
    function totalAllocated() external view override returns (uint256) {
        return totalVanaAllocated;
    }
    
    function totalDistributed() external view override returns (uint256) {
        return currentTranche * vanaPerTranche;
    }
    
    function remainingAllocation() external view override returns (uint256) {
        return totalVanaAllocated - (currentTranche * vanaPerTranche);
    }
    
    function isActive() external view override returns (bool) {
        return isActiveFlag && initialized;
    }
    
    // ========== ADMIN FUNCTIONS ==========
    
    function setRewardsManager(address _rewardsManager) external onlyRole(ADMIN_ROLE) {
        require(_rewardsManager != address(0), "Invalid address");
        
        if (rewardsManager != address(0)) {
            _revokeRole(REWARDS_MANAGER_ROLE, rewardsManager);
        }
        
        rewardsManager = _rewardsManager;
        _grantRole(REWARDS_MANAGER_ROLE, _rewardsManager);
    }
    
    function setActive(bool _active) external onlyRole(ADMIN_ROLE) {
        isActiveFlag = _active;
        emit ModuleStatusChanged(_active);
    }
    
    /**
     * @notice Emergency withdrawal of tokens
     * @param token Token to withdraw
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(
        address token,
        uint256 amount
    ) external override onlyRole(ADMIN_ROLE) {
        require(token != address(0), "Invalid token");
        
        IERC20(token).safeTransfer(msg.sender, amount);
        emit EmergencyWithdrawal(token, amount);
    }
    
    // ========== REWARD MODULE INTERFACE ==========
    
    function onStake(
        address user,
        uint256 stakeId,
        uint256 amount,
        uint256 lockPeriod
    ) external override onlyRole(REWARDS_MANAGER_ROLE) {
        // No action needed on stake for this module
        // Shares are calculated based on total stake at tranche execution
    }
    
    function onUnstake(
        address user,
        uint256 stakeId,
        uint256 amount,
        bool emergency
    ) external override onlyRole(REWARDS_MANAGER_ROLE) {
        // No action needed on unstake
        // Users keep their accumulated LP shares
    }
}