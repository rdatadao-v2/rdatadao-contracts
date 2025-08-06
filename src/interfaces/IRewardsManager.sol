// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @title IRewardsManager
 * @author r/datadao
 * @notice Interface for the RewardsManager that orchestrates multiple reward modules
 * @dev This contract is upgradeable and manages the registration and coordination of reward modules
 */
interface IRewardsManager {
    /**
     * @notice Information about a registered reward program
     */
    struct RewardProgram {
        address rewardModule;    // Address of the reward module contract
        address rewardToken;     // Token distributed by this program
        string name;             // Human-readable name
        uint256 startTime;       // When program starts
        uint256 endTime;         // When program ends (0 for perpetual)
        bool active;             // Whether program is currently active
        bool emergency;          // Emergency pause state
    }

    /**
     * @notice Reward claim information
     */
    struct ClaimInfo {
        uint256 programId;       // Program that provided the reward
        address token;           // Token claimed
        uint256 amount;          // Amount claimed
    }

    // Events
    event ProgramRegistered(
        uint256 indexed programId,
        address indexed rewardModule,
        address indexed rewardToken,
        string name
    );
    
    event ProgramStatusUpdated(
        uint256 indexed programId,
        bool active
    );
    
    event RewardsClaimed(
        address indexed user,
        uint256 indexed stakeId,
        ClaimInfo[] claims
    );
    
    event StakeNotified(
        address indexed user,
        uint256 indexed stakeId,
        uint256 amount,
        uint256 lockPeriod
    );
    
    event UnstakeNotified(
        address indexed user,
        uint256 indexed stakeId,
        bool emergency
    );

    event EmergencyPauseTriggered(uint256 indexed programId);
    event EmergencyPauseLifted(uint256 indexed programId);

    // Errors
    error ProgramNotFound();
    error ProgramNotActive();
    error ModuleNotAuthorized();
    error InvalidModule();
    error InvalidToken();
    error ClaimFailed();
    error NotStakingManager();
    error ZeroAddress();
    error EmergencyPaused();

    // Program management (admin functions)
    function registerProgram(
        address rewardModule,
        string calldata name,
        uint256 startTime,
        uint256 duration
    ) external returns (uint256 programId);
    
    function updateProgramStatus(uint256 programId, bool active) external;
    function emergencyPauseProgram(uint256 programId) external;
    function emergencyUnpauseProgram(uint256 programId) external;
    
    // Staking integration (only callable by StakingManager)
    function notifyStake(
        address user,
        uint256 stakeId,
        uint256 amount,
        uint256 lockPeriod
    ) external;
    
    function notifyUnstake(
        address user,
        uint256 stakeId,
        bool emergency
    ) external;
    
    // Reward operations (user functions)
    function claimRewards(uint256 stakeId) external returns (ClaimInfo[] memory);
    function claimRewardsFor(address user, uint256 stakeId) external returns (ClaimInfo[] memory);
    function claimAllRewards() external returns (ClaimInfo[] memory);
    
    // View functions
    function calculateRewards(
        address user,
        uint256 stakeId
    ) external view returns (uint256[] memory amounts, address[] memory tokens);
    
    function calculateAllRewards(
        address user
    ) external view returns (uint256[] memory amounts, address[] memory tokens);
    
    function getProgram(uint256 programId) external view returns (RewardProgram memory);
    function getProgramCount() external view returns (uint256);
    function getActivePrograms() external view returns (uint256[] memory);
    function getUserClaimablePrograms(address user, uint256 stakeId) external view returns (uint256[] memory);
    
    // Configuration
    function stakingManager() external view returns (address);
    function setStakingManager(address _stakingManager) external;
}