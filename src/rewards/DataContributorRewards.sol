// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title DataContributorRewards
 * @notice Manages RDAT rewards distribution to data contributors
 * @dev Distributes tokens from the Future Rewards allocation (30M RDAT)
 * 
 * Reward Distribution:
 * - Total Budget: 30M RDAT (locked until Phase 3)
 * - Distribution: Based on contribution quality/quantity scores
 * - Claims: Via Merkle proof for gas efficiency
 * - Phases: Multiple distribution rounds as data aggregation progresses
 */
contract DataContributorRewards is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    
    bytes32 public constant REWARDS_ADMIN_ROLE = keccak256("REWARDS_ADMIN_ROLE");
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");
    
    struct RewardRound {
        bytes32 merkleRoot;
        uint256 totalRewards;
        uint256 claimedRewards;
        uint256 startTime;
        uint256 endTime;
        bool active;
        mapping(address => bool) hasClaimed;
    }
    
    IERC20 public immutable rdatToken;
    address public immutable vestingContract; // Source of reward tokens
    
    uint256 public constant TOTAL_REWARDS_BUDGET = 30_000_000e18; // 30M RDAT
    uint256 public totalDistributed;
    uint256 public currentRound;
    
    mapping(uint256 => RewardRound) public rewardRounds;
    mapping(address => uint256) public totalUserRewards;
    
    // Events
    event RewardRoundCreated(
        uint256 indexed roundId,
        bytes32 merkleRoot,
        uint256 totalRewards,
        uint256 startTime,
        uint256 endTime
    );
    event RewardsClaimed(
        address indexed contributor,
        uint256 indexed roundId,
        uint256 amount
    );
    event RewardRoundFinalized(uint256 indexed roundId, uint256 unclaimedRewards);
    
    constructor(address _rdatToken, address _vestingContract) {
        require(_rdatToken != address(0), "Invalid token address");
        require(_vestingContract != address(0), "Invalid vesting address");
        
        rdatToken = IERC20(_rdatToken);
        vestingContract = _vestingContract;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(REWARDS_ADMIN_ROLE, msg.sender);
        _grantRole(DISTRIBUTOR_ROLE, msg.sender);
    }
    
    /**
     * @notice Creates a new reward distribution round
     * @param merkleRoot Merkle root of contributor addresses and amounts
     * @param totalRewards Total RDAT to distribute in this round
     * @param duration How long the round stays open for claims
     */
    function createRewardRound(
        bytes32 merkleRoot,
        uint256 totalRewards,
        uint256 duration
    ) external onlyRole(DISTRIBUTOR_ROLE) whenNotPaused {
        require(merkleRoot != bytes32(0), "Invalid merkle root");
        require(totalRewards > 0, "Rewards must be > 0");
        require(totalDistributed + totalRewards <= TOTAL_REWARDS_BUDGET, "Exceeds budget");
        require(duration > 0, "Invalid duration");
        
        // Pull tokens from vesting contract (must be approved)
        rdatToken.safeTransferFrom(vestingContract, address(this), totalRewards);
        
        uint256 roundId = currentRound++;
        RewardRound storage round = rewardRounds[roundId];
        
        round.merkleRoot = merkleRoot;
        round.totalRewards = totalRewards;
        round.startTime = block.timestamp;
        round.endTime = block.timestamp + duration;
        round.active = true;
        
        totalDistributed += totalRewards;
        
        emit RewardRoundCreated(
            roundId,
            merkleRoot,
            totalRewards,
            block.timestamp,
            round.endTime
        );
    }
    
    /**
     * @notice Claims rewards for a data contributor
     * @param roundId The reward round to claim from
     * @param amount The amount of RDAT rewards
     * @param merkleProof Proof of inclusion in the merkle tree
     */
    function claimRewards(
        uint256 roundId,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external nonReentrant whenNotPaused {
        RewardRound storage round = rewardRounds[roundId];
        
        require(round.active, "Round not active");
        require(block.timestamp >= round.startTime, "Round not started");
        require(block.timestamp <= round.endTime, "Round ended");
        require(!round.hasClaimed[msg.sender], "Already claimed");
        
        // Verify merkle proof
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, amount));
        require(
            MerkleProof.verify(merkleProof, round.merkleRoot, leaf),
            "Invalid proof"
        );
        
        // Mark as claimed
        round.hasClaimed[msg.sender] = true;
        round.claimedRewards += amount;
        totalUserRewards[msg.sender] += amount;
        
        // Transfer rewards
        rdatToken.safeTransfer(msg.sender, amount);
        
        emit RewardsClaimed(msg.sender, roundId, amount);
    }
    
    /**
     * @notice Finalizes a reward round and returns unclaimed tokens
     * @param roundId The round to finalize
     */
    function finalizeRound(uint256 roundId) external onlyRole(REWARDS_ADMIN_ROLE) {
        RewardRound storage round = rewardRounds[roundId];
        
        require(round.active, "Round not active");
        require(block.timestamp > round.endTime, "Round not ended");
        
        round.active = false;
        
        // Return unclaimed rewards to vesting contract
        uint256 unclaimedRewards = round.totalRewards - round.claimedRewards;
        if (unclaimedRewards > 0) {
            totalDistributed -= unclaimedRewards;
            rdatToken.safeTransfer(vestingContract, unclaimedRewards);
        }
        
        emit RewardRoundFinalized(roundId, unclaimedRewards);
    }
    
    /**
     * @notice Checks if a contributor can claim rewards
     * @param contributor Address to check
     * @param roundId Round to check
     * @param amount Claimed amount
     * @param merkleProof Merkle proof
     * @return Whether the claim is valid
     */
    function canClaim(
        address contributor,
        uint256 roundId,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external view returns (bool) {
        RewardRound storage round = rewardRounds[roundId];
        
        if (!round.active || 
            block.timestamp < round.startTime || 
            block.timestamp > round.endTime ||
            round.hasClaimed[contributor]) {
            return false;
        }
        
        bytes32 leaf = keccak256(abi.encodePacked(contributor, amount));
        return MerkleProof.verify(merkleProof, round.merkleRoot, leaf);
    }
    
    /**
     * @notice Returns remaining budget for future rewards
     * @return The amount of RDAT still available for distribution
     */
    function remainingBudget() external view returns (uint256) {
        return TOTAL_REWARDS_BUDGET - totalDistributed;
    }
    
    /**
     * @notice Emergency pause
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @notice Unpause
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}