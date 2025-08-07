// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title TreasuryWallet
 * @author r/datadao
 * @notice Manages DAO token allocations with vesting schedules
 * @dev UUPS upgradeable contract that receives 70M RDAT at deployment
 *
 * Key Features:
 * - Manages 70M RDAT allocation from initial mint
 * - Implements vesting schedules per DAO vote
 * - Phase 3 gated release for Future Rewards
 * - Manual distribution triggers for safety
 * - On-chain transparency for all distributions
 */
contract TreasuryWallet is Initializable, UUPSUpgradeable, AccessControlUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    // Roles
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");
    bytes32 public constant DAO_ROLE = keccak256("DAO_ROLE");

    // Allocation identifiers
    bytes32 public constant FUTURE_REWARDS = keccak256("FUTURE_REWARDS");
    bytes32 public constant TREASURY_ECOSYSTEM = keccak256("TREASURY_ECOSYSTEM");
    bytes32 public constant LIQUIDITY_STAKING = keccak256("LIQUIDITY_STAKING");

    struct VestingSchedule {
        uint256 total; // Total allocation
        uint256 released; // Amount already released
        uint256 tgeUnlock; // Amount unlocked at TGE
        uint256 cliffDuration; // Cliff period in seconds
        uint256 vestingDuration; // Total vesting duration after cliff
        uint256 vestingStart; // Timestamp when vesting starts
        uint256 lastRelease; // Last release timestamp
        bool isPhase3Gated; // Whether this requires Phase 3
        bool initialized; // Whether schedule is set up
    }

    // State variables
    mapping(bytes32 => VestingSchedule) public vestingSchedules;
    mapping(address => uint256) public distributionHistory;
    bool public phase3Active;
    IERC20 public rdat;
    uint256 public totalDistributed;

    // Events
    event VestingScheduleCreated(bytes32 indexed allocation, uint256 total, uint256 tgeUnlock);
    event TokensReleased(bytes32 indexed allocation, uint256 amount);
    event TokensDistributed(address indexed recipient, uint256 amount, string reason);
    event Phase3Activated(uint256 timestamp);
    event DAOProposalExecuted(uint256 indexed proposalId);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the TreasuryWallet
     * @param _admin Admin address for initial role setup
     * @param _rdat RDAT token address
     */
    function initialize(address _admin, address _rdat) public initializer {
        require(_admin != address(0), "Invalid admin");
        require(_rdat != address(0), "Invalid RDAT");

        __UUPSUpgradeable_init();
        __AccessControl_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(UPGRADER_ROLE, _admin);
        _grantRole(DISTRIBUTOR_ROLE, _admin);

        rdat = IERC20(_rdat);

        // Setup vesting schedules based on DAO vote
        _setupInitialSchedules();
    }

    /**
     * @dev Set up initial vesting schedules per DAO allocation vote
     */
    function _setupInitialSchedules() private {
        // Future Rewards: 30M, locked until Phase 3
        vestingSchedules[FUTURE_REWARDS] = VestingSchedule({
            total: 30_000_000e18,
            released: 0,
            tgeUnlock: 0,
            cliffDuration: 0,
            vestingDuration: 0,
            vestingStart: block.timestamp,
            lastRelease: 0,
            isPhase3Gated: true,
            initialized: true
        });

        emit VestingScheduleCreated(FUTURE_REWARDS, 30_000_000e18, 0);

        // Treasury & Ecosystem: 25M total
        // - 10M for team (requires DAO vote to transfer to TokenVesting)
        // - 2.5M TGE unlock (10%)
        // - 22.5M vests linearly over 18 months after 6 month cliff
        vestingSchedules[TREASURY_ECOSYSTEM] = VestingSchedule({
            total: 25_000_000e18,
            released: 0,
            tgeUnlock: 2_500_000e18, // 10% at TGE
            cliffDuration: 180 days, // 6 months
            vestingDuration: 540 days, // 18 months after cliff
            vestingStart: block.timestamp,
            lastRelease: block.timestamp,
            isPhase3Gated: false,
            initialized: true
        });

        emit VestingScheduleCreated(TREASURY_ECOSYSTEM, 25_000_000e18, 2_500_000e18);

        // Liquidity & Staking: 15M total
        // - 4.95M at TGE for liquidity (exactly 33%)
        // - 10.05M for staking incentives (LP rewards, vRDAT boosts, etc.)
        vestingSchedules[LIQUIDITY_STAKING] = VestingSchedule({
            total: 15_000_000e18,
            released: 0,
            tgeUnlock: 4_950_000e18, // Exactly 33% at TGE
            cliffDuration: 0,
            vestingDuration: 0, // Remainder available for staking incentives
            vestingStart: block.timestamp,
            lastRelease: block.timestamp,
            isPhase3Gated: false,
            initialized: true
        });

        emit VestingScheduleCreated(LIQUIDITY_STAKING, 15_000_000e18, 4_950_000e18);
    }

    /**
     * @notice Check and release any vested tokens
     * @dev Anyone can call this to process scheduled releases
     */
    function checkAndRelease() external nonReentrant {
        _releaseVested(TREASURY_ECOSYSTEM);
        _releaseVested(LIQUIDITY_STAKING);

        if (phase3Active) {
            _releaseVested(FUTURE_REWARDS);
        }
    }

    /**
     * @dev Internal function to release vested tokens for an allocation
     * @param allocation The allocation identifier
     */
    function _releaseVested(bytes32 allocation) private {
        VestingSchedule storage schedule = vestingSchedules[allocation];

        if (!schedule.initialized || schedule.released >= schedule.total) {
            return;
        }

        if (schedule.isPhase3Gated && !phase3Active) {
            return;
        }

        uint256 available = _calculateAvailable(schedule);
        if (available > 0) {
            schedule.released += available;
            schedule.lastRelease = block.timestamp;
            emit TokensReleased(allocation, available);
        }
    }

    /**
     * @dev Calculate available tokens for a vesting schedule
     * @param schedule The vesting schedule
     * @return available Amount available to release
     */
    function _calculateAvailable(VestingSchedule memory schedule) private view returns (uint256 available) {
        // Phase 3 gated - return 0 if not active
        if (schedule.isPhase3Gated && !phase3Active) {
            return 0;
        }

        // Handle TGE unlock
        if (schedule.released == 0 && schedule.tgeUnlock > 0) {
            return schedule.tgeUnlock;
        }

        // For phase 3 gated allocations with no vesting (instant unlock when activated)
        if (schedule.isPhase3Gated && phase3Active && schedule.vestingDuration == 0) {
            return schedule.total - schedule.released;
        }

        // Check if still in cliff period
        if (schedule.vestingDuration > 0 && block.timestamp < schedule.vestingStart + schedule.cliffDuration) {
            return 0;
        }

        // Calculate vested amount
        if (schedule.vestingDuration == 0) {
            // No vesting, everything available after cliff
            return schedule.total - schedule.released;
        }

        // Linear vesting after cliff
        uint256 elapsedTime = block.timestamp - schedule.vestingStart;
        if (elapsedTime < schedule.cliffDuration) {
            return 0;
        }

        uint256 vestingElapsed = elapsedTime - schedule.cliffDuration;
        if (vestingElapsed >= schedule.vestingDuration) {
            // Fully vested
            return schedule.total - schedule.released;
        }

        // Calculate linear vesting amount
        // Note: TGE amount is part of total, remaining amount vests linearly
        uint256 vestingAmount = schedule.total - schedule.tgeUnlock;
        uint256 vestedAmount = schedule.tgeUnlock + (vestingAmount * vestingElapsed / schedule.vestingDuration);

        if (vestedAmount > schedule.total) {
            vestedAmount = schedule.total;
        }

        return vestedAmount > schedule.released ? vestedAmount - schedule.released : 0;
    }

    /**
     * @notice Distribute tokens to a recipient
     * @param recipient Address to receive tokens
     * @param amount Amount to distribute
     * @param reason Description of distribution
     */
    function distribute(address recipient, uint256 amount, string calldata reason)
        external
        onlyRole(DISTRIBUTOR_ROLE)
        nonReentrant
    {
        require(recipient != address(0), "Invalid recipient");
        require(amount > 0, "Invalid amount");
        require(bytes(reason).length > 0, "Reason required");
        require(rdat.balanceOf(address(this)) >= amount, "Insufficient balance");

        distributionHistory[recipient] += amount;
        totalDistributed += amount;

        rdat.safeTransfer(recipient, amount);

        emit TokensDistributed(recipient, amount, reason);
    }

    /**
     * @notice Activate Phase 3 to unlock Future Rewards
     * @dev Can only be called once by admin after DAO decision
     */
    function setPhase3Active() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!phase3Active, "Already active");
        phase3Active = true;
        emit Phase3Activated(block.timestamp);
    }

    /**
     * @notice Execute a DAO proposal
     * @param proposalId The proposal ID for tracking
     * @param targets Target addresses for calls
     * @param values ETH values for calls
     * @param calldatas Call data for each target
     */
    function executeDAOProposal(
        uint256 proposalId,
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas
    ) external onlyRole(DAO_ROLE) nonReentrant {
        require(targets.length == values.length, "Length mismatch");
        require(targets.length == calldatas.length, "Length mismatch");

        for (uint256 i = 0; i < targets.length; i++) {
            (bool success,) = targets[i].call{value: values[i]}(calldatas[i]);
            require(success, "Call failed");
        }

        emit DAOProposalExecuted(proposalId);
    }

    /**
     * @notice Get vesting information for an allocation
     * @param allocation The allocation identifier
     * @return total Total allocation amount
     * @return released Amount already released
     * @return available Amount currently available
     * @return isActive Whether the allocation is active
     */
    function getVestingInfo(bytes32 allocation)
        external
        view
        returns (uint256 total, uint256 released, uint256 available, bool isActive)
    {
        VestingSchedule memory schedule = vestingSchedules[allocation];
        total = schedule.total;
        released = schedule.released;
        available = _calculateAvailable(schedule);
        isActive = schedule.initialized && (!schedule.isPhase3Gated || phase3Active);
    }

    /**
     * @notice Get all vesting schedules info
     * @return allocations Array of allocation identifiers
     * @return schedules Array of vesting schedules
     */
    function getAllVestingSchedules()
        external
        view
        returns (bytes32[3] memory allocations, VestingSchedule[3] memory schedules)
    {
        allocations[0] = FUTURE_REWARDS;
        allocations[1] = TREASURY_ECOSYSTEM;
        allocations[2] = LIQUIDITY_STAKING;

        schedules[0] = vestingSchedules[FUTURE_REWARDS];
        schedules[1] = vestingSchedules[TREASURY_ECOSYSTEM];
        schedules[2] = vestingSchedules[LIQUIDITY_STAKING];
    }

    /**
     * @dev Authorize contract upgrade
     * @param newImplementation Address of new implementation
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    /**
     * @notice Receive ETH
     */
    receive() external payable {}
}
