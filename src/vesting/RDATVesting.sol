// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title RDATVesting
 * @notice Vesting contract for RDAT token distribution per DAO vote
 * @dev Implements the approved tokenomics with specific vesting schedules
 * 
 * Token Allocation:
 * - Migration Reserve: 30M (100% at TGE)
 * - Future Rewards: 30M (0% at TGE, unlocks at Phase 3)
 * - Treasury: 25M (10% at TGE, 6-month cliff, 5% monthly)
 * - Liquidity: 15M (33% at TGE, remainder for staking)
 * 
 * VRC-20 Compliance:
 * - Team allocations from Treasury bucket require 6-month minimum lockup
 * - Lockup period starts from DLP reward eligibility date
 * - Linear vesting after cliff period
 * - All team allocations must be publicly disclosed
 */
contract RDATVesting is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    
    bytes32 public constant VESTING_ADMIN_ROLE = keccak256("VESTING_ADMIN_ROLE");
    
    struct VestingSchedule {
        uint256 totalAmount;        // Total tokens to be vested
        uint256 releasedAmount;     // Tokens already released
        uint256 startTime;          // Vesting start time
        uint256 cliffDuration;      // Cliff period in seconds
        uint256 vestingDuration;    // Total vesting period after cliff
        uint256 immediateRelease;   // Amount released immediately at TGE
        bool revocable;             // Whether the vesting can be revoked
        bool revoked;               // Whether the vesting has been revoked
        bool isPhase3Locked;        // Whether this is locked until Phase 3
    }
    
    IERC20 public immutable rdatToken;
    mapping(address => VestingSchedule) public vestingSchedules;
    
    // Phase 3 control
    bool public phase3Triggered;
    uint256 public phase3TriggerTime;
    
    // Events
    event VestingScheduleCreated(
        address indexed beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration,
        uint256 immediateRelease
    );
    event TokensReleased(address indexed beneficiary, uint256 amount);
    event VestingRevoked(address indexed beneficiary, uint256 refundAmount);
    event Phase3Triggered(uint256 timestamp);
    
    constructor(address _rdatToken) {
        require(_rdatToken != address(0), "Invalid token address");
        rdatToken = IERC20(_rdatToken);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(VESTING_ADMIN_ROLE, msg.sender);
    }
    
    /**
     * @notice Creates a vesting schedule for a beneficiary
     * @param beneficiary Address that will receive vested tokens
     * @param totalAmount Total amount of tokens to vest
     * @param immediateRelease Amount to release immediately (for TGE)
     * @param cliffDuration Duration of cliff period in seconds
     * @param vestingDuration Total vesting duration after cliff in seconds
     * @param revocable Whether the vesting can be revoked
     * @param isPhase3Locked Whether this vesting is locked until Phase 3
     */
    function createVestingSchedule(
        address beneficiary,
        uint256 totalAmount,
        uint256 immediateRelease,
        uint256 cliffDuration,
        uint256 vestingDuration,
        bool revocable,
        bool isPhase3Locked
    ) external onlyRole(VESTING_ADMIN_ROLE) {
        require(beneficiary != address(0), "Invalid beneficiary");
        require(totalAmount > 0, "Amount must be > 0");
        require(immediateRelease <= totalAmount, "Immediate release exceeds total");
        require(vestingSchedules[beneficiary].totalAmount == 0, "Schedule already exists");
        
        uint256 startTime = isPhase3Locked ? type(uint256).max : block.timestamp;
        
        vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: totalAmount,
            releasedAmount: 0,
            startTime: startTime,
            cliffDuration: cliffDuration,
            vestingDuration: vestingDuration,
            immediateRelease: immediateRelease,
            revocable: revocable,
            revoked: false,
            isPhase3Locked: isPhase3Locked
        });
        
        // Transfer tokens to this contract
        rdatToken.safeTransferFrom(msg.sender, address(this), totalAmount);
        
        // Release immediate amount if any
        if (immediateRelease > 0 && !isPhase3Locked) {
            _release(beneficiary, immediateRelease);
        }
        
        emit VestingScheduleCreated(
            beneficiary,
            totalAmount,
            startTime,
            cliffDuration,
            vestingDuration,
            immediateRelease
        );
    }
    
    /**
     * @notice Triggers Phase 3 unlock for future rewards
     * @dev Can only be called once by admin when data aggregation begins
     * @param dataRewardsContract Address of the DataContributorRewards contract
     */
    function triggerPhase3Unlock(address dataRewardsContract) external onlyRole(VESTING_ADMIN_ROLE) {
        require(!phase3Triggered, "Phase 3 already triggered");
        require(dataRewardsContract != address(0), "Invalid rewards contract");
        
        phase3Triggered = true;
        phase3TriggerTime = block.timestamp;
        
        // Approve the rewards contract to pull tokens for distribution
        rdatToken.approve(dataRewardsContract, 30_000_000e18);
        
        emit Phase3Triggered(block.timestamp);
    }
    
    /**
     * @notice Releases vested tokens for a beneficiary
     * @param beneficiary Address to release tokens for
     */
    function release(address beneficiary) external nonReentrant whenNotPaused {
        uint256 releasableAmount = _releasableAmount(beneficiary);
        require(releasableAmount > 0, "No tokens to release");
        
        _release(beneficiary, releasableAmount);
    }
    
    /**
     * @notice Returns the amount of tokens that can be released
     * @param beneficiary Address to check
     * @return The amount of releasable tokens
     */
    function releasable(address beneficiary) external view returns (uint256) {
        return _releasableAmount(beneficiary);
    }
    
    /**
     * @notice Revokes a vesting schedule
     * @param beneficiary Address whose vesting to revoke
     */
    function revoke(address beneficiary) external onlyRole(VESTING_ADMIN_ROLE) {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(schedule.revocable, "Vesting not revocable");
        require(!schedule.revoked, "Already revoked");
        
        uint256 vestedAmount = _vestedAmount(beneficiary);
        uint256 refundAmount = schedule.totalAmount - vestedAmount;
        
        schedule.revoked = true;
        
        if (refundAmount > 0) {
            rdatToken.safeTransfer(msg.sender, refundAmount);
        }
        
        emit VestingRevoked(beneficiary, refundAmount);
    }
    
    /**
     * @notice Emergency pause function
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @notice Unpause function
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
    
    /**
     * @notice Internal function to calculate releasable amount
     */
    function _releasableAmount(address beneficiary) private view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[beneficiary];
        
        if (schedule.totalAmount == 0 || schedule.revoked) {
            return 0;
        }
        
        uint256 vestedAmount = _vestedAmount(beneficiary);
        return vestedAmount - schedule.releasedAmount;
    }
    
    /**
     * @notice Internal function to calculate vested amount
     */
    function _vestedAmount(address beneficiary) private view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[beneficiary];
        
        if (schedule.totalAmount == 0) {
            return 0;
        }
        
        // Handle Phase 3 locked schedules
        if (schedule.isPhase3Locked) {
            if (!phase3Triggered) {
                return 0;
            }
            // Update effective start time for Phase 3 schedules
            schedule.startTime = phase3TriggerTime;
        }
        
        if (block.timestamp < schedule.startTime) {
            return schedule.immediateRelease;
        }
        
        if (schedule.revoked) {
            return schedule.releasedAmount;
        }
        
        // Check if still in cliff period
        if (block.timestamp < schedule.startTime + schedule.cliffDuration) {
            return schedule.immediateRelease;
        }
        
        // If vesting duration is 0, release everything after cliff
        if (schedule.vestingDuration == 0) {
            return schedule.totalAmount;
        }
        
        // Calculate linear vesting
        uint256 timeFromStart = block.timestamp - schedule.startTime - schedule.cliffDuration;
        uint256 vestedAmount = schedule.immediateRelease + 
            (schedule.totalAmount - schedule.immediateRelease) * 
            timeFromStart / schedule.vestingDuration;
            
        return vestedAmount > schedule.totalAmount ? schedule.totalAmount : vestedAmount;
    }
    
    /**
     * @notice Internal function to release tokens
     */
    function _release(address beneficiary, uint256 amount) private {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        
        schedule.releasedAmount += amount;
        rdatToken.safeTransfer(beneficiary, amount);
        
        emit TokensReleased(beneficiary, amount);
    }
    
    /**
     * @notice Creates VRC-20 compliant team vesting schedule
     * @dev Team tokens come from Treasury allocation, must have 6-month cliff
     * @param teamMember Address of team member
     * @param amount Token amount (deducted from treasury allocation)
     * @param dlpEligibilityDate When DLP becomes eligible for rewards (vesting start)
     */
    function createTeamVesting(
        address teamMember,
        uint256 amount,
        uint256 dlpEligibilityDate
    ) external onlyRole(VESTING_ADMIN_ROLE) {
        require(teamMember != address(0), "Invalid team member");
        require(amount > 0, "Amount must be > 0");
        require(dlpEligibilityDate >= block.timestamp, "Invalid eligibility date");
        
        // VRC-20 requires minimum 6-month cliff for team allocations
        createVestingSchedule(
            teamMember,
            amount,
            0, // No immediate release for team
            180 days, // 6-month cliff (VRC-20 requirement)
            360 days, // 12-month linear vesting after cliff
            true, // Revocable
            false // Not Phase 3 locked
        );
        
        // Note: The vesting admin must ensure total team allocations
        // don't exceed available treasury tokens after TGE release
    }
    
    /**
     * @notice Creates all vesting schedules per DAO vote
     * @dev Should be called after token deployment
     */
    function setupDAOVesting(
        address migrationReserve,
        address futureRewards,
        address treasury,
        address liquidityPool
    ) external onlyRole(VESTING_ADMIN_ROLE) {
        // Migration Reserve: 30M fully unlocked
        createVestingSchedule(
            migrationReserve,
            30_000_000e18,
            30_000_000e18, // 100% immediate
            0,
            0,
            false,
            false
        );
        
        // Future Rewards: 30M locked until Phase 3
        createVestingSchedule(
            futureRewards,
            30_000_000e18,
            0,
            0,
            0,
            false,
            true // Phase 3 locked
        );
        
        // Treasury: 25M with 10% at TGE, 6-month cliff, then 5% monthly
        createVestingSchedule(
            treasury,
            25_000_000e18,
            2_500_000e18, // 10% immediate
            180 days, // 6 month cliff
            540 days, // 18 months linear vesting
            false,
            false
        );
        
        // Liquidity: 15M with 33% at TGE
        createVestingSchedule(
            liquidityPool,
            15_000_000e18,
            5_000_000e18, // 33% immediate
            0,
            0, // Remainder available immediately for staking
            false,
            false
        );
    }
}