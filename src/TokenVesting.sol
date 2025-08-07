// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/finance/VestingWalletCliff.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title TokenVesting
 * @author r/datadao
 * @notice VRC-20 compliant team token vesting with 6-month cliff
 * @dev Uses OpenZeppelin's VestingWalletCliff for Vana compliance
 *
 * Key Requirements:
 * - 6-month cliff from DLP eligibility date
 * - 18-month linear vesting after cliff
 * - Admin-controlled start date (cannot start before DLP eligibility)
 * - Multiple beneficiaries with individual allocations
 * - Public transparency for all vesting data
 */
contract TokenVesting is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ Constants ============

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice 6-month cliff period (Vana requirement)
    uint256 public constant CLIFF_DURATION = 180 days;

    /// @notice 18-month vesting period after cliff
    uint256 public constant VESTING_DURATION = 540 days;

    /// @notice Total vesting period (cliff + vesting)
    uint256 public constant TOTAL_DURATION = CLIFF_DURATION + VESTING_DURATION; // 720 days = 24 months

    // ============ Storage ============

    /// @notice The RDAT token contract
    IERC20 public immutable rdatToken;

    /// @notice DLP eligibility start date (set by admin when confirmed)
    uint256 public eligibilityDate;

    /// @notice Whether the eligibility date has been set (immutable once set)
    bool public eligibilitySet;

    /// @notice Total tokens allocated to all beneficiaries
    uint256 public totalAllocated;

    /// @notice Total tokens already claimed by beneficiaries
    uint256 public totalClaimed;

    // ============ Beneficiary Management ============

    /// @notice Individual beneficiary allocation amounts
    mapping(address => uint256) public beneficiaryAllocations;

    /// @notice Amount already claimed by each beneficiary
    mapping(address => uint256) public beneficiaryClaimed;

    /// @notice List of all beneficiaries for enumeration
    address[] public beneficiaries;

    /// @notice Check if address is a beneficiary
    mapping(address => bool) public isBeneficiary;

    // ============ Events ============

    /// @notice Emitted when DLP eligibility date is set
    event EligibilityDateSet(uint256 indexed date, address indexed admin);

    /// @notice Emitted when a beneficiary is added
    event BeneficiaryAdded(address indexed beneficiary, uint256 allocation);

    /// @notice Emitted when tokens are claimed
    event TokensClaimed(address indexed beneficiary, uint256 amount, uint256 totalClaimedByBeneficiary);

    /// @notice Emitted when tokens are received by the contract
    event TokensReceived(uint256 amount, uint256 newBalance);

    // ============ Errors ============

    error EligibilityAlreadySet();
    error EligibilityDateTooFarFuture();
    error EligibilityDateTooFarPast();
    error BeneficiaryAlreadyExists();
    error InvalidBeneficiary();
    error InvalidAllocation();
    error NoTokensToClaim();
    error InsufficientTokenBalance();
    error TransferFailed();
    error NotABeneficiary();
    error EligibilityNotSet();

    // ============ Constructor ============

    /**
     * @notice Initialize the TokenVesting contract
     * @param _rdatToken The RDAT token contract address
     * @param _admin The admin address with control permissions
     */
    constructor(address _rdatToken, address _admin) {
        require(_rdatToken != address(0), "Invalid token");
        require(_admin != address(0), "Invalid admin");

        rdatToken = IERC20(_rdatToken);

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
    }

    // ============ Admin Functions ============

    /**
     * @notice Set the DLP eligibility date (starts the vesting clock)
     * @dev Can only be set once, must be reasonable timeframe
     * @param _date The eligibility timestamp
     */
    function setEligibilityDate(uint256 _date) external onlyRole(ADMIN_ROLE) {
        if (eligibilitySet) revert EligibilityAlreadySet();
        if (_date > block.timestamp + 30 days) revert EligibilityDateTooFarFuture();
        if (block.timestamp >= 7 days && _date < block.timestamp - 7 days) revert EligibilityDateTooFarPast();

        eligibilityDate = _date;
        eligibilitySet = true;

        emit EligibilityDateSet(_date, msg.sender);
    }

    /**
     * @notice Add a team member beneficiary with token allocation
     * @dev Must be called before tokens are received. One-time only per address.
     * @param beneficiary The beneficiary address
     * @param allocation The number of tokens allocated (in wei, e.g., 1M = 1_000_000e18)
     */
    function addBeneficiary(address beneficiary, uint256 allocation) external onlyRole(ADMIN_ROLE) {
        if (beneficiary == address(0)) revert InvalidBeneficiary();
        if (allocation == 0) revert InvalidAllocation();
        if (isBeneficiary[beneficiary]) revert BeneficiaryAlreadyExists();

        beneficiaryAllocations[beneficiary] = allocation;
        beneficiaries.push(beneficiary);
        isBeneficiary[beneficiary] = true;
        totalAllocated += allocation;

        emit BeneficiaryAdded(beneficiary, allocation);
    }

    // ============ View Functions ============

    /**
     * @notice Get the number of beneficiaries
     * @return The total number of beneficiaries added
     */
    function getBeneficiaryCount() external view returns (uint256) {
        return beneficiaries.length;
    }

    /**
     * @notice Get all beneficiaries and their allocations
     * @return addresses Array of beneficiary addresses
     * @return allocations Array of corresponding allocations
     */
    function getAllBeneficiaries() external view returns (address[] memory addresses, uint256[] memory allocations) {
        uint256 length = beneficiaries.length;
        addresses = new address[](length);
        allocations = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            addresses[i] = beneficiaries[i];
            allocations[i] = beneficiaryAllocations[beneficiaries[i]];
        }
    }

    /**
     * @notice Calculate the vested amount for a beneficiary at current time
     * @param beneficiary The beneficiary address
     * @return The amount of tokens vested (available for claiming)
     */
    function vestedAmount(address beneficiary) public view returns (uint256) {
        return vestedAmountAt(beneficiary, block.timestamp);
    }

    /**
     * @notice Calculate the vested amount for a beneficiary at a specific time
     * @param beneficiary The beneficiary address
     * @param timestamp The timestamp to check vesting at
     * @return The amount of tokens vested at the given timestamp
     */
    function vestedAmountAt(address beneficiary, uint256 timestamp) public view returns (uint256) {
        if (!eligibilitySet) return 0;
        if (!isBeneficiary[beneficiary]) return 0;

        uint256 allocation = beneficiaryAllocations[beneficiary];
        if (allocation == 0) return 0;

        // If before eligibility date, no tokens vested
        if (timestamp < eligibilityDate) {
            return 0;
        }

        uint256 timeElapsed = timestamp - eligibilityDate;

        // During cliff period: no tokens vested
        if (timeElapsed < CLIFF_DURATION) {
            return 0;
        }

        // After full vesting period: all tokens vested
        if (timeElapsed >= TOTAL_DURATION) {
            return allocation;
        }

        // During linear vesting period: calculate proportional amount
        uint256 vestingElapsed = timeElapsed - CLIFF_DURATION;
        return (allocation * vestingElapsed) / VESTING_DURATION;
    }

    /**
     * @notice Get the claimable amount for a beneficiary (vested - already claimed)
     * @param beneficiary The beneficiary address
     * @return The amount available to claim
     */
    function claimableAmount(address beneficiary) external view returns (uint256) {
        uint256 vested = vestedAmount(beneficiary);
        uint256 claimed = beneficiaryClaimed[beneficiary];
        return vested > claimed ? vested - claimed : 0;
    }

    /**
     * @notice Get comprehensive vesting info for a beneficiary
     * @param beneficiary The beneficiary address
     * @return allocation Total tokens allocated
     * @return vested Amount currently vested
     * @return claimed Amount already claimed
     * @return claimable Amount available to claim
     */
    function getBeneficiaryInfo(address beneficiary)
        external
        view
        returns (uint256 allocation, uint256 vested, uint256 claimed, uint256 claimable)
    {
        allocation = beneficiaryAllocations[beneficiary];
        vested = vestedAmount(beneficiary);
        claimed = beneficiaryClaimed[beneficiary];
        claimable = vested > claimed ? vested - claimed : 0;
    }

    /**
     * @notice Get vesting schedule milestones
     * @return eligibility DLP eligibility timestamp
     * @return cliffEnd When cliff period ends (first tokens become available)
     * @return vestingEnd When vesting completes (all tokens available)
     */
    function getVestingSchedule() external view returns (uint256 eligibility, uint256 cliffEnd, uint256 vestingEnd) {
        eligibility = eligibilityDate;
        cliffEnd = eligibilitySet ? eligibilityDate + CLIFF_DURATION : 0;
        vestingEnd = eligibilitySet ? eligibilityDate + TOTAL_DURATION : 0;
    }

    /**
     * @notice Get overall contract statistics
     * @return tokenBalance Current token balance in contract
     * @return totalAllocated_ Total tokens allocated to beneficiaries
     * @return totalClaimed_ Total tokens claimed by all beneficiaries
     * @return totalVested Total tokens currently vested across all beneficiaries
     */
    function getContractStats()
        external
        view
        returns (uint256 tokenBalance, uint256 totalAllocated_, uint256 totalClaimed_, uint256 totalVested)
    {
        tokenBalance = rdatToken.balanceOf(address(this));
        totalAllocated_ = totalAllocated;
        totalClaimed_ = totalClaimed;

        // Calculate total vested across all beneficiaries
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            totalVested += vestedAmount(beneficiaries[i]);
        }
    }

    // ============ Beneficiary Functions ============

    /**
     * @notice Claim all available vested tokens for the caller
     * @dev Transfers vested tokens minus already claimed amount
     */
    function claim() external nonReentrant {
        address beneficiary = msg.sender;

        if (!isBeneficiary[beneficiary]) revert NotABeneficiary();
        if (!eligibilitySet) revert EligibilityNotSet();

        uint256 vested = vestedAmount(beneficiary);
        uint256 alreadyClaimed = beneficiaryClaimed[beneficiary];

        if (vested <= alreadyClaimed) revert NoTokensToClaim();

        uint256 claimable = vested - alreadyClaimed;

        // Check contract has enough tokens
        uint256 contractBalance = rdatToken.balanceOf(address(this));
        if (contractBalance < claimable) revert InsufficientTokenBalance();

        // Update claimed amount before transfer (reentrancy protection)
        beneficiaryClaimed[beneficiary] = vested;
        totalClaimed += claimable;

        // Transfer tokens
        rdatToken.safeTransfer(beneficiary, claimable);

        emit TokensClaimed(beneficiary, claimable, vested);
    }

    // ============ Token Management ============

    /**
     * @notice Handle token deposits to the contract
     * @dev Called when tokens are transferred to this contract
     */
    function onTokensReceived() external {
        uint256 balance = rdatToken.balanceOf(address(this));
        emit TokensReceived(balance - (balance - rdatToken.balanceOf(address(this))), balance);
    }

    // ============ Emergency Functions ============

    /**
     * @notice Emergency function to recover non-RDAT tokens sent by mistake
     * @dev Only admin can call, cannot touch RDAT tokens
     * @param token The token contract to recover
     * @param to Address to send recovered tokens to
     */
    function recoverToken(IERC20 token, address to) external onlyRole(ADMIN_ROLE) {
        require(address(token) != address(rdatToken), "Cannot recover RDAT");
        require(to != address(0), "Invalid recipient");

        uint256 balance = token.balanceOf(address(this));
        if (balance > 0) {
            token.safeTransfer(to, balance);
        }
    }
}
