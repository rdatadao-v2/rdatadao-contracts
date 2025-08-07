// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "../StakingPositions.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title StakingPositionsV2Example
 * @notice Example upgrade demonstrating safe upgrade patterns
 * @dev Shows how to add new features while preserving NFT positions
 */
contract StakingPositionsV2Example is StakingPositions {
    using SafeERC20 for IERC20;
    
    // New state variables (using storage gap space)
    uint256 public constant VERSION = 2;
    
    // New feature: Boost multipliers for long-term stakers
    mapping(address => uint256) public loyaltyPoints;
    mapping(uint256 => uint256) public positionBoosts; // positionId => boost percentage
    uint256 public globalBoostEnabled;
    
    // New feature: Referral system
    mapping(address => address) public referrers;
    mapping(address => uint256) public referralRewards;
    uint256 public referralBonusRate; // basis points
    
    // Reduce storage gap by number of slots used (5 slots used)
    uint256[36] private __gap;
    
    // Events for new features
    event LoyaltyPointsEarned(address indexed user, uint256 points);
    event PositionBoosted(uint256 indexed positionId, uint256 boostPercentage);
    event ReferralSet(address indexed user, address indexed referrer);
    event ReferralRewardsClaimed(address indexed referrer, uint256 amount);
    
    /**
     * @dev Initialize V2 features
     * @notice Call this after upgrade to initialize new features
     */
    function initializeV2() public reinitializer(2) {
        globalBoostEnabled = 1;
        referralBonusRate = 500; // 5% referral bonus
    }
    
    /**
     * @dev Enhanced stake function with referral support
     * @param amount Amount to stake
     * @param lockPeriod Lock duration
     * @param referrer Optional referrer address
     */
    function stakeWithReferral(
        uint256 amount,
        uint256 lockPeriod,
        address referrer
    ) external whenNotPaused returns (uint256 positionId) {
        // Set referrer if not already set
        if (referrers[msg.sender] == address(0) && referrer != address(0) && referrer != msg.sender) {
            referrers[msg.sender] = referrer;
            emit ReferralSet(msg.sender, referrer);
        }
        
        // For this example, we'll just track the referral but user needs to call stake separately
        // In production, you would make stake() virtual in StakingPositions to properly override it
        
        // Award loyalty points based on the amount they're planning to stake
        uint256 points = calculateLoyaltyPoints(amount, lockPeriod);
        loyaltyPoints[msg.sender] += points;
        emit LoyaltyPointsEarned(msg.sender, points);
        
        // Return 0 as position will be created separately
        return 0;
    }
    
    /**
     * @dev Enhanced claim with loyalty boost calculation
     * @notice This is a simplified example - production would need more sophisticated reward handling
     */
    function claimRewardsWithBoost(uint256 positionId) external nonReentrant whenNotPaused {
        require(ownerOf(positionId) == msg.sender, "Not position owner");
        
        // Calculate base rewards
        uint256 baseRewards = _calculateRewards(positionId);
        
        // Apply boost if exists
        uint256 boost = positionBoosts[positionId];
        if (boost > 0 && baseRewards > 0) {
            uint256 boostAmount = (baseRewards * boost) / 10000;
            emit PositionBoosted(positionId, boostAmount);
            
            // In production, would mint additional boost rewards here
            // For example purposes, we just log the boost
        }
        
        // In the new architecture, rewards are handled by RewardsManager
        // This would revert with "Use RewardsManager.claimRewards directly"
        // For the example, we just emit the boost event
    }
    
    /**
     * @dev Claim referral rewards
     */
    function claimReferralRewards() external nonReentrant {
        uint256 rewards = referralRewards[msg.sender];
        require(rewards > 0, "No referral rewards");
        
        referralRewards[msg.sender] = 0;
        
        // Mint referral rewards (would need MINTER_ROLE in production)
        // For this example, we assume the rewards are handled by treasury
        emit ReferralRewardsClaimed(msg.sender, rewards);
    }
    
    /**
     * @dev Calculate loyalty points based on stake parameters
     */
    function calculateLoyaltyPoints(uint256 amount, uint256 lockPeriod) 
        public 
        pure 
        returns (uint256) 
    {
        // Simple formula: amount * lock period multiplier
        uint256 multiplier = 1;
        if (lockPeriod >= 365 days) multiplier = 4;
        else if (lockPeriod >= 180 days) multiplier = 3;
        else if (lockPeriod >= 90 days) multiplier = 2;
        
        return (amount * multiplier) / 1e18;
    }
    
    /**
     * @dev Calculate position boost based on loyalty
     */
    function calculatePositionBoost(address user, uint256, uint256) 
        public 
        view 
        returns (uint256) 
    {
        uint256 userLoyalty = loyaltyPoints[user];
        
        // Boost tiers based on loyalty points
        if (userLoyalty >= 10000) return 2000; // 20% boost
        if (userLoyalty >= 5000) return 1500;  // 15% boost
        if (userLoyalty >= 1000) return 1000;  // 10% boost
        if (userLoyalty >= 500) return 500;    // 5% boost
        return 0;
    }
    
    /**
     * @dev Admin function to enable/disable global boosts
     */
    function setGlobalBoostEnabled(bool enabled) external onlyRole(ADMIN_ROLE) {
        globalBoostEnabled = enabled ? 1 : 0;
    }
    
    /**
     * @dev Admin function to update referral rate
     */
    function setReferralBonusRate(uint256 rate) external onlyRole(ADMIN_ROLE) {
        require(rate <= 2000, "Rate too high"); // Max 20%
        referralBonusRate = rate;
    }
    
    /**
     * @dev Get enhanced position info including boosts
     */
    function getPositionWithBoost(uint256 positionId) 
        external 
        view 
        returns (
            IStakingPositions.Position memory position,
            uint256 boost,
            uint256 projectedRewards
        ) 
    {
        position = this.getPosition(positionId);
        boost = positionBoosts[positionId];
        
        uint256 baseRewards = _calculateRewards(positionId);
        projectedRewards = baseRewards + (baseRewards * boost) / 10000;
    }
    
    /**
     * @dev Override to ensure version compatibility
     */
    function version() external pure returns (uint256) {
        return VERSION;
    }
}