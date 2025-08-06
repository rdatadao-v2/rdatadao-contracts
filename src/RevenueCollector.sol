// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IRevenueCollector.sol";
import "./interfaces/IStakingPositions.sol";

/**
 * @title RevenueCollector
 * @author r/datadao
 * @notice Collects and distributes protocol revenue according to tokenomics
 * @dev Implements 50/30/20 distribution: Stakers/Treasury/Contributors
 * 
 * Key Features:
 * - Automated revenue collection from protocol operations
 * - Fair distribution based on tokenomics ratios
 * - Threshold-based distribution to optimize gas costs
 * - Integration with StakingPositions for staker rewards
 * - Multi-token support for diverse revenue streams
 */
contract RevenueCollector is 
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    IRevenueCollector
{
    using SafeERC20 for IERC20;

    // Roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant REVENUE_REPORTER_ROLE = keccak256("REVENUE_REPORTER_ROLE");

    // Distribution ratios (out of 10000 = 100%)
    uint256 public constant STAKING_SHARE = 5000;     // 50% to stakers
    uint256 public constant TREASURY_SHARE = 3000;    // 30% to treasury
    uint256 public constant CONTRIBUTOR_SHARE = 2000; // 20% to contributors
    uint256 public constant PRECISION = 10000;        // 100% in basis points

    // Core contracts
    IStakingPositions public stakingPositions;
    address public treasury;
    address public contributorPool;

    // Revenue tracking
    mapping(address => uint256) public pendingRevenue;
    mapping(address => uint256) public totalRevenueCollected;
    mapping(address => uint256) public totalDistributed;
    
    // Distribution settings
    mapping(address => uint256) public distributionThreshold;
    address[] public supportedTokens;
    mapping(address => bool) public isSupportedToken;

    // Statistics
    uint256 public totalDistributions;
    uint256 public lastDistributionTime;

    // Storage gap for upgradeability
    uint256[40] private __gap;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initialize the contract
     * @param stakingPositions_ StakingPositions contract address
     * @param treasury_ Treasury address for receiving treasury share
     * @param contributorPool_ Contributor pool address
     * @param admin_ Admin address
     */
    function initialize(
        address stakingPositions_,
        address treasury_,
        address contributorPool_,
        address admin_
    ) public initializer {
        require(stakingPositions_ != address(0), "Invalid staking positions");
        require(treasury_ != address(0), "Invalid treasury");
        require(contributorPool_ != address(0), "Invalid contributor pool");
        require(admin_ != address(0), "Invalid admin");

        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        stakingPositions = IStakingPositions(stakingPositions_);
        treasury = treasury_;
        contributorPool = contributorPool_;

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(ADMIN_ROLE, admin_);
        _grantRole(PAUSER_ROLE, admin_);
        _grantRole(UPGRADER_ROLE, admin_);
        _grantRole(REVENUE_REPORTER_ROLE, admin_);

        lastDistributionTime = block.timestamp;
    }

    /**
     * @dev Report revenue from protocol operations
     * @param token Token address of the revenue
     * @param amount Amount of revenue to report
     */
    function notifyRevenue(address token, uint256 amount) 
        external 
        override 
        onlyRole(REVENUE_REPORTER_ROLE) 
        whenNotPaused 
    {
        require(token != address(0), "Invalid token");
        require(amount > 0, "Zero amount");

        // Transfer tokens to this contract
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // Update revenue tracking
        pendingRevenue[token] += amount;
        totalRevenueCollected[token] += amount;

        // Add to supported tokens if new
        if (!isSupportedToken[token]) {
            supportedTokens.push(token);
            isSupportedToken[token] = true;
            // Set default threshold: 1000 tokens (scaled by decimals would be better)
            distributionThreshold[token] = 1000 * 10**18; // Assume 18 decimals
        }

        emit RevenueReported(token, amount, msg.sender);

        // Check if automatic distribution should trigger
        if (pendingRevenue[token] >= distributionThreshold[token]) {
            _distribute(token);
        }
    }

    /**
     * @dev Manually trigger distribution for a specific token
     * @param token Token to distribute
     * @return stakingAmount Amount sent to stakers
     * @return treasuryAmount Amount sent to treasury
     * @return contributorAmount Amount sent to contributors
     */
    function distribute(address token) 
        external 
        override 
        nonReentrant 
        whenNotPaused 
        returns (uint256 stakingAmount, uint256 treasuryAmount, uint256 contributorAmount) 
    {
        require(isSupportedToken[token], "Token not supported");
        require(pendingRevenue[token] > 0, "No revenue to distribute");

        return _distribute(token);
    }

    /**
     * @dev Distribute all pending revenue across all tokens
     * @return tokens Array of tokens distributed
     * @return stakingAmounts Amounts sent to stakers for each token
     * @return treasuryAmounts Amounts sent to treasury for each token
     * @return contributorAmounts Amounts sent to contributors for each token
     */
    function distributeAll() 
        external 
        nonReentrant 
        whenNotPaused 
        returns (
            address[] memory tokens,
            uint256[] memory stakingAmounts,
            uint256[] memory treasuryAmounts,
            uint256[] memory contributorAmounts
        ) 
    {
        uint256 tokenCount = 0;
        
        // Count tokens with pending revenue
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            if (pendingRevenue[supportedTokens[i]] > 0) {
                tokenCount++;
            }
        }

        require(tokenCount > 0, "No revenue to distribute");

        // Allocate arrays
        tokens = new address[](tokenCount);
        stakingAmounts = new uint256[](tokenCount);
        treasuryAmounts = new uint256[](tokenCount);
        contributorAmounts = new uint256[](tokenCount);

        uint256 index = 0;
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            address token = supportedTokens[i];
            if (pendingRevenue[token] > 0) {
                tokens[index] = token;
                (stakingAmounts[index], treasuryAmounts[index], contributorAmounts[index]) = _distribute(token);
                index++;
            }
        }
    }

    /**
     * @dev Internal distribution logic
     * @param token Token to distribute
     * @return stakingAmount Amount sent to stakers
     * @return treasuryAmount Amount sent to treasury
     * @return contributorAmount Amount sent to contributors
     */
    function _distribute(address token) 
        internal 
        returns (uint256 stakingAmount, uint256 treasuryAmount, uint256 contributorAmount) 
    {
        uint256 totalAmount = pendingRevenue[token];
        require(totalAmount > 0, "No revenue to distribute");

        // Calculate distribution amounts
        stakingAmount = (totalAmount * STAKING_SHARE) / PRECISION;
        treasuryAmount = (totalAmount * TREASURY_SHARE) / PRECISION;
        contributorAmount = (totalAmount * CONTRIBUTOR_SHARE) / PRECISION;

        // Handle rounding - any remainder goes to treasury
        uint256 distributed = stakingAmount + treasuryAmount + contributorAmount;
        if (distributed < totalAmount) {
            treasuryAmount += (totalAmount - distributed);
        }

        // Clear pending revenue
        pendingRevenue[token] = 0;
        totalDistributed[token] += totalAmount;

        // Distribute to stakers via StakingPositions
        IERC20(token).approve(address(stakingPositions), stakingAmount);
        stakingPositions.notifyRewardAmount(stakingAmount);

        // Distribute to treasury
        if (treasuryAmount > 0) {
            IERC20(token).safeTransfer(treasury, treasuryAmount);
        }

        // Distribute to contributors
        if (contributorAmount > 0) {
            IERC20(token).safeTransfer(contributorPool, contributorAmount);
        }

        // Update statistics
        totalDistributions++;
        lastDistributionTime = block.timestamp;

        emit RevenueDistributed(token, totalAmount, stakingAmount, treasuryAmount, contributorAmount);
    }

    // ============ Admin Functions ============

    /**
     * @dev Set distribution threshold for a token
     * @param token Token address
     * @param threshold Minimum amount required before automatic distribution
     */
    function setDistributionThreshold(address token, uint256 threshold) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        require(isSupportedToken[token], "Token not supported");
        require(threshold > 0, "Invalid threshold");

        uint256 oldThreshold = distributionThreshold[token];
        distributionThreshold[token] = threshold;

        emit ThresholdUpdated(token, oldThreshold, threshold);
    }

    /**
     * @dev Update treasury address
     * @param newTreasury New treasury address
     */
    function setTreasury(address newTreasury) external onlyRole(ADMIN_ROLE) {
        require(newTreasury != address(0), "Invalid treasury");
        
        address oldTreasury = treasury;
        treasury = newTreasury;

        emit TreasuryUpdated(oldTreasury, newTreasury);
    }

    /**
     * @dev Update contributor pool address
     * @param newContributorPool New contributor pool address
     */
    function setContributorPool(address newContributorPool) external onlyRole(ADMIN_ROLE) {
        require(newContributorPool != address(0), "Invalid contributor pool");
        
        address oldContributorPool = contributorPool;
        contributorPool = newContributorPool;

        emit ContributorPoolUpdated(oldContributorPool, newContributorPool);
    }

    /**
     * @dev Add support for a new revenue token
     * @param token Token address to support
     * @param threshold Distribution threshold for this token
     */
    function addSupportedToken(address token, uint256 threshold) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        require(token != address(0), "Invalid token");
        require(!isSupportedToken[token], "Token already supported");
        require(threshold > 0, "Invalid threshold");

        supportedTokens.push(token);
        isSupportedToken[token] = true;
        distributionThreshold[token] = threshold;

        emit TokenSupported(token, threshold);
    }

    /**
     * @dev Remove support for a revenue token (after distributing any pending revenue)
     * @param token Token address to remove
     */
    function removeSupportedToken(address token) external onlyRole(ADMIN_ROLE) {
        require(isSupportedToken[token], "Token not supported");
        require(pendingRevenue[token] == 0, "Distribute pending revenue first");

        // Find and remove from array
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            if (supportedTokens[i] == token) {
                supportedTokens[i] = supportedTokens[supportedTokens.length - 1];
                supportedTokens.pop();
                break;
            }
        }

        isSupportedToken[token] = false;
        distributionThreshold[token] = 0;

        emit TokenRemoved(token);
    }

    /**
     * @dev Pause the contract
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause the contract
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev Emergency recovery function for stuck tokens
     * @param token Token to recover
     * @param amount Amount to recover
     */
    function emergencyRecoverToken(address token, uint256 amount) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        require(token != address(0), "Invalid token");
        require(amount > 0, "Zero amount");

        // This should only be used for tokens that got stuck, not normal revenue
        IERC20(token).safeTransfer(msg.sender, amount);

        emit EmergencyRecovery(token, amount, msg.sender);
    }

    // ============ View Functions ============

    /**
     * @dev Get supported tokens list
     * @return Array of supported token addresses
     */
    function getSupportedTokens() external view returns (address[] memory) {
        return supportedTokens;
    }

    /**
     * @dev Get pending revenue for all supported tokens
     * @return tokens Array of token addresses
     * @return amounts Array of pending amounts
     */
    function getPendingRevenue() 
        external 
        view 
        returns (address[] memory tokens, uint256[] memory amounts) 
    {
        tokens = new address[](supportedTokens.length);
        amounts = new uint256[](supportedTokens.length);

        for (uint256 i = 0; i < supportedTokens.length; i++) {
            tokens[i] = supportedTokens[i];
            amounts[i] = pendingRevenue[supportedTokens[i]];
        }
    }

    /**
     * @dev Check if distribution is needed for any token
     * @return needed Whether distribution is needed
     * @return tokensReady Array of tokens ready for distribution
     */
    function isDistributionNeeded() 
        external 
        view 
        returns (bool needed, address[] memory tokensReady) 
    {
        uint256 readyCount = 0;
        
        // Count tokens ready for distribution
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            address token = supportedTokens[i];
            if (pendingRevenue[token] >= distributionThreshold[token] && pendingRevenue[token] > 0) {
                readyCount++;
            }
        }

        if (readyCount == 0) {
            return (false, new address[](0));
        }

        tokensReady = new address[](readyCount);
        uint256 index = 0;
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            address token = supportedTokens[i];
            if (pendingRevenue[token] >= distributionThreshold[token] && pendingRevenue[token] > 0) {
                tokensReady[index] = token;
                index++;
            }
        }

        return (true, tokensReady);
    }

    /**
     * @dev Get distribution statistics
     * @return totalDistributions_ Total number of distributions
     * @return lastDistributionTime_ Timestamp of last distribution
     * @return supportedTokenCount Number of supported tokens
     */
    function getStats() 
        external 
        view 
        returns (uint256 totalDistributions_, uint256 lastDistributionTime_, uint256 supportedTokenCount) 
    {
        return (totalDistributions, lastDistributionTime, supportedTokens.length);
    }

    /**
     * @dev Authorize upgrade
     */
    function _authorizeUpgrade(address newImplementation) 
        internal 
        override 
        onlyRole(UPGRADER_ROLE) 
    {}
}