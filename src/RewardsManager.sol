// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interfaces/IRewardsManager.sol";
import "./interfaces/IRewardModule.sol";
import "./interfaces/IStakingPositions.sol";

/**
 * @title RewardsManager
 * @author r/datadao
 * @notice Orchestrates multiple reward modules for the staking system
 * @dev This contract is upgradeable to allow adding new reward programs
 * 
 * Key Features:
 * - Registers and manages multiple reward modules
 * - Coordinates reward calculations and distributions
 * - Handles batch operations for gas efficiency
 * - Emergency pause functionality per program
 * - Only StakingManager can notify stake/unstake events
 */
contract RewardsManager is 
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    IRewardsManager 
{
    // Roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PROGRAM_MANAGER_ROLE = keccak256("PROGRAM_MANAGER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    
    // State variables
    address public override stakingManager;
    uint256 private nextProgramId;
    
    mapping(uint256 => RewardProgram) private programs;
    uint256[] private programIds;
    
    // Modifiers
    modifier onlyStakingManager() {
        if (msg.sender != stakingManager) {
            revert NotStakingManager();
        }
        _;
    }
    
    modifier validProgram(uint256 programId) {
        if (programId >= nextProgramId) {
            revert ProgramNotFound();
        }
        _;
    }
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    /**
     * @notice Initialize the contract
     * @param _stakingManager Address of the StakingManager contract
     * @param _admin Address to grant admin role
     */
    function initialize(address _stakingManager, address _admin) public initializer {
        if (_stakingManager == address(0) || _admin == address(0)) {
            revert ZeroAddress();
        }
        
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        
        stakingManager = _stakingManager;
        
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
        _grantRole(PROGRAM_MANAGER_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _admin);
        _grantRole(UPGRADER_ROLE, _admin);
    }
    
    // Program Management Functions
    
    /**
     * @notice Register a new reward program
     * @param rewardModule Address of the reward module
     * @param name Human-readable name for the program
     * @param startTime When the program starts (0 for immediate)
     * @param duration Program duration in seconds (0 for perpetual)
     * @return programId Unique identifier for the program
     */
    function registerProgram(
        address rewardModule,
        string calldata name,
        uint256 startTime,
        uint256 duration
    ) external override onlyRole(PROGRAM_MANAGER_ROLE) returns (uint256 programId) {
        if (rewardModule == address(0)) {
            revert InvalidModule();
        }
        
        // Validate module implements interface
        try IRewardModule(rewardModule).getModuleInfo() returns (IRewardModule.ModuleInfo memory info) {
            if (info.rewardToken == address(0)) {
                revert InvalidToken();
            }
        } catch {
            revert InvalidModule();
        }
        
        programId = nextProgramId++;
        uint256 start = startTime == 0 ? block.timestamp : startTime;
        uint256 end = duration == 0 ? 0 : start + duration;
        
        programs[programId] = RewardProgram({
            rewardModule: rewardModule,
            rewardToken: IRewardModule(rewardModule).rewardToken(),
            name: name,
            startTime: start,
            endTime: end,
            active: true,
            emergency: false
        });
        
        programIds.push(programId);
        
        emit ProgramRegistered(programId, rewardModule, programs[programId].rewardToken, name);
        
        return programId;
    }
    
    /**
     * @notice Update program active status
     */
    function updateProgramStatus(uint256 programId, bool active) 
        external 
        override 
        onlyRole(PROGRAM_MANAGER_ROLE) 
        validProgram(programId) 
    {
        programs[programId].active = active;
        emit ProgramStatusUpdated(programId, active);
    }
    
    /**
     * @notice Emergency pause a program
     */
    function emergencyPauseProgram(uint256 programId) 
        external 
        override 
        onlyRole(PAUSER_ROLE) 
        validProgram(programId) 
    {
        programs[programId].emergency = true;
        emit EmergencyPauseTriggered(programId);
    }
    
    /**
     * @notice Unpause a program
     */
    function emergencyUnpauseProgram(uint256 programId) 
        external 
        override 
        onlyRole(PAUSER_ROLE) 
        validProgram(programId) 
    {
        programs[programId].emergency = false;
        emit EmergencyPauseLifted(programId);
    }
    
    // Staking Integration Functions
    
    /**
     * @notice Called by StakingManager when a stake is created
     */
    function notifyStake(
        address user,
        uint256 stakeId,
        uint256 amount,
        uint256 lockPeriod
    ) external override onlyStakingManager whenNotPaused {
        emit StakeNotified(user, stakeId, amount, lockPeriod);
        
        // Notify all active programs
        for (uint256 i = 0; i < programIds.length; i++) {
            uint256 programId = programIds[i];
            RewardProgram memory program = programs[programId];
            
            if (_isProgramActive(program)) {
                try IRewardModule(program.rewardModule).onStake(user, stakeId, amount, lockPeriod) {
                    // Success
                } catch {
                    // Continue even if one module fails
                }
            }
        }
    }
    
    /**
     * @notice Called by StakingManager when a stake is removed
     */
    function notifyUnstake(
        address user,
        uint256 stakeId,
        bool emergency
    ) external override onlyStakingManager {
        emit UnstakeNotified(user, stakeId, emergency);
        
        // Get position info from StakingPositions for amount
        IStakingPositions.Position memory position = IStakingPositions(stakingManager).getPosition(stakeId);
        
        // Notify all active programs
        for (uint256 i = 0; i < programIds.length; i++) {
            uint256 programId = programIds[i];
            RewardProgram memory program = programs[programId];
            
            if (program.rewardModule != address(0)) {
                try IRewardModule(program.rewardModule).onUnstake(user, stakeId, position.amount, emergency) {
                    // Success
                } catch {
                    // Continue even if one module fails
                }
            }
        }
    }
    
    // Reward Claiming Functions
    
    /**
     * @notice Claim rewards for a specific stake
     */
    function claimRewards(uint256 stakeId) 
        external 
        override 
        whenNotPaused 
        nonReentrant 
        returns (ClaimInfo[] memory) 
    {
        return _claimRewards(msg.sender, stakeId);
    }
    
    /**
     * @notice Claim rewards on behalf of a user
     */
    function claimRewardsFor(address user, uint256 stakeId) 
        external 
        override 
        whenNotPaused 
        nonReentrant 
        onlyRole(ADMIN_ROLE)
        returns (ClaimInfo[] memory) 
    {
        return _claimRewards(user, stakeId);
    }
    
    /**
     * @notice Claim all rewards for the caller
     */
    function claimAllRewards() 
        external 
        override 
        whenNotPaused 
        nonReentrant 
        returns (ClaimInfo[] memory) 
    {
        uint256[] memory stakeIds = IStakingPositions(stakingManager).getUserPositions(msg.sender);
        uint256 totalClaims = 0;
        
        // First pass: count total claims
        for (uint256 i = 0; i < stakeIds.length; i++) {
            (uint256[] memory amounts,) = calculateRewards(msg.sender, stakeIds[i]);
            for (uint256 j = 0; j < amounts.length; j++) {
                if (amounts[j] > 0) totalClaims++;
            }
        }
        
        ClaimInfo[] memory allClaims = new ClaimInfo[](totalClaims);
        uint256 claimIndex = 0;
        
        // Second pass: execute claims
        for (uint256 i = 0; i < stakeIds.length; i++) {
            ClaimInfo[] memory stakeClaims = _claimRewards(msg.sender, stakeIds[i]);
            for (uint256 j = 0; j < stakeClaims.length; j++) {
                allClaims[claimIndex++] = stakeClaims[j];
            }
        }
        
        return allClaims;
    }
    
    /**
     * @notice Internal function to claim rewards
     */
    function _claimRewards(address user, uint256 stakeId) private returns (ClaimInfo[] memory) {
        // Count claimable programs
        uint256 claimableCount = 0;
        for (uint256 i = 0; i < programIds.length; i++) {
            uint256 programId = programIds[i];
            RewardProgram memory program = programs[programId];
            
            if (_isProgramActive(program)) {
                try IRewardModule(program.rewardModule).calculateRewards(user, stakeId) returns (uint256 amount) {
                    if (amount > 0) claimableCount++;
                } catch {}
            }
        }
        
        ClaimInfo[] memory claims = new ClaimInfo[](claimableCount);
        uint256 claimIndex = 0;
        
        // Execute claims
        for (uint256 i = 0; i < programIds.length; i++) {
            uint256 programId = programIds[i];
            RewardProgram memory program = programs[programId];
            
            if (_isProgramActive(program)) {
                try IRewardModule(program.rewardModule).claimRewards(user, stakeId) returns (uint256 amount) {
                    if (amount > 0) {
                        claims[claimIndex++] = ClaimInfo({
                            programId: programId,
                            token: program.rewardToken,
                            amount: amount
                        });
                    }
                } catch {
                    // Continue even if one claim fails
                }
            }
        }
        
        // Resize array if needed
        if (claimIndex < claims.length) {
            assembly {
                mstore(claims, claimIndex)
            }
        }
        
        if (claims.length > 0) {
            emit RewardsClaimed(user, stakeId, claims);
        }
        
        return claims;
    }
    
    // View Functions
    
    /**
     * @notice Calculate pending rewards for a stake
     */
    function calculateRewards(address user, uint256 stakeId) 
        public 
        view 
        override 
        returns (uint256[] memory amounts, address[] memory tokens) 
    {
        uint256 activePrograms = _countActivePrograms();
        amounts = new uint256[](activePrograms);
        tokens = new address[](activePrograms);
        
        uint256 index = 0;
        for (uint256 i = 0; i < programIds.length; i++) {
            uint256 programId = programIds[i];
            RewardProgram memory program = programs[programId];
            
            if (_isProgramActive(program)) {
                try IRewardModule(program.rewardModule).calculateRewards(user, stakeId) returns (uint256 amount) {
                    amounts[index] = amount;
                    tokens[index] = program.rewardToken;
                    index++;
                } catch {
                    tokens[index] = program.rewardToken;
                    index++;
                }
            }
        }
        
        return (amounts, tokens);
    }
    
    /**
     * @notice Calculate all pending rewards for a user
     */
    function calculateAllRewards(address user) 
        external 
        view 
        override 
        returns (uint256[] memory amounts, address[] memory tokens) 
    {
        uint256[] memory stakeIds = IStakingPositions(stakingManager).getUserPositions(user);
        uint256 activePrograms = _countActivePrograms();
        
        amounts = new uint256[](activePrograms);
        tokens = new address[](activePrograms);
        
        // Aggregate rewards across all stakes
        for (uint256 i = 0; i < stakeIds.length; i++) {
            (uint256[] memory stakeAmounts, address[] memory stakeTokens) = calculateRewards(user, stakeIds[i]);
            
            for (uint256 j = 0; j < stakeAmounts.length; j++) {
                amounts[j] += stakeAmounts[j];
                tokens[j] = stakeTokens[j];
            }
        }
        
        return (amounts, tokens);
    }
    
    function getProgram(uint256 programId) external view override returns (RewardProgram memory) {
        return programs[programId];
    }
    
    function getProgramCount() external view override returns (uint256) {
        return nextProgramId;
    }
    
    function getActivePrograms() external view override returns (uint256[] memory) {
        uint256 activeCount = _countActivePrograms();
        uint256[] memory activeIds = new uint256[](activeCount);
        
        uint256 index = 0;
        for (uint256 i = 0; i < programIds.length; i++) {
            if (_isProgramActive(programs[programIds[i]])) {
                activeIds[index++] = programIds[i];
            }
        }
        
        return activeIds;
    }
    
    function getUserClaimablePrograms(address user, uint256 stakeId) 
        external 
        view 
        override 
        returns (uint256[] memory) 
    {
        uint256 claimableCount = 0;
        
        // Count claimable programs
        for (uint256 i = 0; i < programIds.length; i++) {
            uint256 programId = programIds[i];
            RewardProgram memory program = programs[programId];
            
            if (_isProgramActive(program)) {
                try IRewardModule(program.rewardModule).calculateRewards(user, stakeId) returns (uint256 amount) {
                    if (amount > 0) claimableCount++;
                } catch {}
            }
        }
        
        uint256[] memory claimableIds = new uint256[](claimableCount);
        uint256 index = 0;
        
        // Populate claimable programs
        for (uint256 i = 0; i < programIds.length; i++) {
            uint256 programId = programIds[i];
            RewardProgram memory program = programs[programId];
            
            if (_isProgramActive(program)) {
                try IRewardModule(program.rewardModule).calculateRewards(user, stakeId) returns (uint256 amount) {
                    if (amount > 0) {
                        claimableIds[index++] = programId;
                    }
                } catch {}
            }
        }
        
        return claimableIds;
    }
    
    // Revenue Distribution Integration
    
    /**
     * @notice Notify the RewardsManager of revenue to distribute
     * @param amount Amount of tokens to distribute to stakers
     * @dev Called by RevenueCollector when distributing fees
     */
    function notifyRevenueReward(uint256 amount) external override {
        // Find the RDAT rewards module and notify it
        for (uint256 i = 0; i < programIds.length; i++) {
            uint256 programId = programIds[i];
            RewardProgram memory program = programs[programId];
            
            // Look for RDAT reward module
            if (_isProgramActive(program) && 
                keccak256(bytes(program.name)) == keccak256(bytes("RDAT Staking Rewards"))) {
                // Use low-level call since notifyRewardAmount is not in base interface
                (bool success,) = program.rewardModule.call(
                    abi.encodeWithSignature("notifyRewardAmount(uint256)", amount)
                );
                if (success) {
                    emit RevenueDistributed(programId, amount);
                    break; // Only notify the first matching module
                }
            }
        }
    }
    
    // Admin Functions
    
    function setStakingManager(address _stakingManager) external override onlyRole(ADMIN_ROLE) {
        if (_stakingManager == address(0)) {
            revert ZeroAddress();
        }
        stakingManager = _stakingManager;
    }
    
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
    
    // Internal Functions
    
    function _isProgramActive(RewardProgram memory program) private view returns (bool) {
        return program.active && 
               !program.emergency &&
               block.timestamp >= program.startTime &&
               (program.endTime == 0 || block.timestamp <= program.endTime);
    }
    
    function _countActivePrograms() private view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < programIds.length; i++) {
            if (_isProgramActive(programs[programIds[i]])) {
                count++;
            }
        }
        return count;
    }
    
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
}