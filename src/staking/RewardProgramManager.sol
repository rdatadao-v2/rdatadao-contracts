// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title RewardProgramManager
 * @notice Manages multiple reward programs for staking positions
 * @dev Handles reward calculations, distributions, and program management
 */
contract RewardProgramManager is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    bytes32 public constant PROGRAM_ADMIN_ROLE = keccak256("PROGRAM_ADMIN_ROLE");
    bytes32 public constant STAKING_MANAGER_ROLE = keccak256("STAKING_MANAGER_ROLE");
    
    struct RewardProgram {
        IERC20 rewardToken;
        uint256 totalAllocated;
        uint256 totalDistributed;
        uint256 startTime;
        uint256 endTime;
        uint256 baseAPR; // Basis points (10000 = 100%)
        bool active;
        mapping(uint256 => uint256) lockPeriodMultipliers; // Lock period => multiplier in basis points
    }
    
    struct PositionRewards {
        uint256 lastClaimTime;
        uint256 accumulatedRewards;
        mapping(uint256 => uint256) programRewards; // programId => accumulated rewards
    }
    
    mapping(uint256 => RewardProgram) public rewardPrograms;
    mapping(uint256 => PositionRewards) public positionRewards;
    mapping(uint256 => bool) public registeredPositions;
    
    uint256 public nextProgramId;
    address public treasury;
    
    // Position data cached from StakingManager
    struct CachedPosition {
        uint256 amount;
        uint256 lockPeriod;
        uint256 startTime;
        bool active;
    }
    
    mapping(uint256 => CachedPosition) public cachedPositions;
    
    event RewardProgramCreated(
        uint256 indexed programId,
        address indexed rewardToken,
        uint256 totalAllocated,
        uint256 baseAPR
    );
    
    event PositionRegistered(uint256 indexed positionId, uint256 amount, uint256 lockPeriod);
    event PositionUnregistered(uint256 indexed positionId);
    event RewardsClaimed(uint256 indexed positionId, address indexed recipient, uint256 amount);
    
    constructor(address _treasury) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PROGRAM_ADMIN_ROLE, msg.sender);
        treasury = _treasury;
    }
    
    /**
     * @notice Create a new reward program
     * @param rewardToken Token to distribute as rewards
     * @param totalAllocated Total tokens allocated to this program
     * @param duration Program duration in seconds
     * @param baseAPR Base APR in basis points (10000 = 100%)
     */
    function createRewardProgram(
        IERC20 rewardToken,
        uint256 totalAllocated,
        uint256 duration,
        uint256 baseAPR
    ) external onlyRole(PROGRAM_ADMIN_ROLE) returns (uint256) {
        uint256 programId = nextProgramId++;
        
        RewardProgram storage program = rewardPrograms[programId];
        program.rewardToken = rewardToken;
        program.totalAllocated = totalAllocated;
        program.startTime = block.timestamp;
        program.endTime = block.timestamp + duration;
        program.baseAPR = baseAPR;
        program.active = true;
        
        // Set default lock period multipliers
        program.lockPeriodMultipliers[30 days] = 10000; // 1.0x
        program.lockPeriodMultipliers[90 days] = 15000; // 1.5x
        program.lockPeriodMultipliers[180 days] = 20000; // 2.0x
        program.lockPeriodMultipliers[365 days] = 40000; // 4.0x
        
        // Transfer tokens to this contract
        rewardToken.safeTransferFrom(msg.sender, address(this), totalAllocated);
        
        emit RewardProgramCreated(programId, address(rewardToken), totalAllocated, baseAPR);
        
        return programId;
    }
    
    /**
     * @notice Register a staking position for rewards
     * @dev Only callable by StakingManager
     * @param positionId The position ID
     * @param amount Staked amount
     * @param lockPeriod Lock period in seconds
     */
    function registerPosition(
        uint256 positionId,
        uint256 amount,
        uint256 lockPeriod
    ) external onlyRole(STAKING_MANAGER_ROLE) {
        require(!registeredPositions[positionId], "Position already registered");
        
        registeredPositions[positionId] = true;
        cachedPositions[positionId] = CachedPosition({
            amount: amount,
            lockPeriod: lockPeriod,
            startTime: block.timestamp,
            active: true
        });
        
        positionRewards[positionId].lastClaimTime = block.timestamp;
        
        emit PositionRegistered(positionId, amount, lockPeriod);
    }
    
    /**
     * @notice Unregister a staking position
     * @dev Only callable by StakingManager when unstaking
     * @param positionId The position ID
     */
    function unregisterPosition(uint256 positionId) external onlyRole(STAKING_MANAGER_ROLE) {
        require(registeredPositions[positionId], "Position not registered");
        
        cachedPositions[positionId].active = false;
        
        emit PositionUnregistered(positionId);
    }
    
    /**
     * @notice Calculate pending rewards for a position
     * @param positionId The position ID
     * @return totalRewards Total pending rewards across all programs
     */
    function calculateRewards(uint256 positionId) external view returns (uint256) {
        if (!registeredPositions[positionId] || !cachedPositions[positionId].active) {
            return 0;
        }
        
        CachedPosition memory position = cachedPositions[positionId];
        uint256 totalRewards = 0;
        
        // Calculate rewards from all active programs
        for (uint256 i = 0; i < nextProgramId; i++) {
            if (rewardPrograms[i].active) {
                uint256 programRewards = _calculateProgramRewards(i, positionId, position);
                totalRewards += programRewards;
            }
        }
        
        return totalRewards;
    }
    
    /**
     * @notice Claim rewards for a position
     * @param positionId The position ID
     * @param recipient Address to receive rewards
     * @return totalClaimed Total rewards claimed
     */
    function claimRewards(
        uint256 positionId,
        address recipient
    ) external onlyRole(STAKING_MANAGER_ROLE) nonReentrant returns (uint256) {
        require(registeredPositions[positionId], "Position not registered");
        
        uint256 totalClaimed = 0;
        CachedPosition memory position = cachedPositions[positionId];
        
        // Claim from all programs
        for (uint256 i = 0; i < nextProgramId; i++) {
            if (rewardPrograms[i].active) {
                uint256 programRewards = _calculateProgramRewards(i, positionId, position);
                
                if (programRewards > 0) {
                    rewardPrograms[i].totalDistributed += programRewards;
                    positionRewards[positionId].programRewards[i] += programRewards;
                    
                    rewardPrograms[i].rewardToken.safeTransfer(recipient, programRewards);
                    totalClaimed += programRewards;
                }
            }
        }
        
        positionRewards[positionId].lastClaimTime = block.timestamp;
        positionRewards[positionId].accumulatedRewards += totalClaimed;
        
        emit RewardsClaimed(positionId, recipient, totalClaimed);
        
        return totalClaimed;
    }
    
    /**
     * @notice Calculate rewards for a specific program
     * @dev Internal function to calculate program-specific rewards
     */
    function _calculateProgramRewards(
        uint256 programId,
        uint256 positionId,
        CachedPosition memory position
    ) internal view returns (uint256) {
        RewardProgram storage program = rewardPrograms[programId];
        
        if (!program.active || block.timestamp < program.startTime) {
            return 0;
        }
        
        uint256 endTime = block.timestamp > program.endTime ? program.endTime : block.timestamp;
        uint256 lastClaim = positionRewards[positionId].lastClaimTime;
        
        if (lastClaim >= endTime) {
            return 0;
        }
        
        uint256 startTime = lastClaim > program.startTime ? lastClaim : program.startTime;
        uint256 duration = endTime - startTime;
        
        // Get lock period multiplier
        uint256 multiplier = program.lockPeriodMultipliers[position.lockPeriod];
        if (multiplier == 0) {
            multiplier = 10000; // Default 1.0x if not set
        }
        
        // Calculate rewards: (amount * baseAPR * multiplier * duration) / (365 days * 10000 * 10000)
        uint256 rewards = (position.amount * program.baseAPR * multiplier * duration) / 
                         (365 days * 10000 * 10000);
        
        return rewards;
    }
    
    /**
     * @notice Set lock period multiplier for a program
     * @param programId Program ID
     * @param lockPeriod Lock period in seconds
     * @param multiplier Multiplier in basis points (10000 = 1.0x)
     */
    function setLockPeriodMultiplier(
        uint256 programId,
        uint256 lockPeriod,
        uint256 multiplier
    ) external onlyRole(PROGRAM_ADMIN_ROLE) {
        rewardPrograms[programId].lockPeriodMultipliers[lockPeriod] = multiplier;
    }
    
    /**
     * @notice Deactivate a reward program
     * @param programId Program ID to deactivate
     */
    function deactivateProgram(uint256 programId) external onlyRole(PROGRAM_ADMIN_ROLE) {
        rewardPrograms[programId].active = false;
    }
    
    /**
     * @notice Emergency withdraw tokens from inactive programs
     * @param programId Program ID
     * @param recipient Address to receive tokens
     */
    function emergencyWithdraw(
        uint256 programId,
        address recipient
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        RewardProgram storage program = rewardPrograms[programId];
        require(!program.active, "Program still active");
        
        uint256 remaining = program.totalAllocated - program.totalDistributed;
        if (remaining > 0) {
            program.rewardToken.safeTransfer(recipient, remaining);
        }
    }
}