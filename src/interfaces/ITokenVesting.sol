// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ITokenVesting
 * @notice Interface for the TokenVesting contract
 * @dev VRC-20 compliant team token vesting with 6-month cliff
 */
interface ITokenVesting {
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

    // ============ View Functions ============

    /// @notice The RDAT token contract
    function rdatToken() external view returns (IERC20);

    /// @notice DLP eligibility start date
    function eligibilityDate() external view returns (uint256);

    /// @notice Whether the eligibility date has been set
    function eligibilitySet() external view returns (bool);

    /// @notice Total tokens allocated to all beneficiaries
    function totalAllocated() external view returns (uint256);

    /// @notice Total tokens already claimed by beneficiaries
    function totalClaimed() external view returns (uint256);

    /// @notice Individual beneficiary allocation amounts
    function beneficiaryAllocations(address beneficiary) external view returns (uint256);

    /// @notice Amount already claimed by each beneficiary
    function beneficiaryClaimed(address beneficiary) external view returns (uint256);

    /// @notice Get beneficiary by index
    function beneficiaries(uint256 index) external view returns (address);

    /// @notice Check if address is a beneficiary
    function isBeneficiary(address account) external view returns (bool);

    /// @notice 6-month cliff period (Vana requirement)
    function CLIFF_DURATION() external view returns (uint256);

    /// @notice 18-month vesting period after cliff
    function VESTING_DURATION() external view returns (uint256);

    /// @notice Total vesting period (cliff + vesting)
    function TOTAL_DURATION() external view returns (uint256);

    // ============ Admin Functions ============

    /**
     * @notice Set the DLP eligibility date (starts the vesting clock)
     * @param _date The eligibility timestamp
     */
    function setEligibilityDate(uint256 _date) external;

    /**
     * @notice Add a team member beneficiary with token allocation
     * @param beneficiary The beneficiary address
     * @param allocation The number of tokens allocated
     */
    function addBeneficiary(address beneficiary, uint256 allocation) external;

    // ============ Query Functions ============

    /**
     * @notice Get the number of beneficiaries
     * @return The total number of beneficiaries added
     */
    function getBeneficiaryCount() external view returns (uint256);

    /**
     * @notice Get all beneficiaries and their allocations
     * @return addresses Array of beneficiary addresses
     * @return allocations Array of corresponding allocations
     */
    function getAllBeneficiaries() external view returns (address[] memory addresses, uint256[] memory allocations);

    /**
     * @notice Calculate the vested amount for a beneficiary at current time
     * @param beneficiary The beneficiary address
     * @return The amount of tokens vested (available for claiming)
     */
    function vestedAmount(address beneficiary) external view returns (uint256);

    /**
     * @notice Calculate the vested amount for a beneficiary at a specific time
     * @param beneficiary The beneficiary address
     * @param timestamp The timestamp to check vesting at
     * @return The amount of tokens vested at the given timestamp
     */
    function vestedAmountAt(address beneficiary, uint256 timestamp) external view returns (uint256);

    /**
     * @notice Get the claimable amount for a beneficiary
     * @param beneficiary The beneficiary address
     * @return The amount available to claim
     */
    function claimableAmount(address beneficiary) external view returns (uint256);

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
        returns (uint256 allocation, uint256 vested, uint256 claimed, uint256 claimable);

    /**
     * @notice Get vesting schedule milestones
     * @return eligibility DLP eligibility timestamp
     * @return cliffEnd When cliff period ends
     * @return vestingEnd When vesting completes
     */
    function getVestingSchedule() external view returns (uint256 eligibility, uint256 cliffEnd, uint256 vestingEnd);

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
        returns (uint256 tokenBalance, uint256 totalAllocated_, uint256 totalClaimed_, uint256 totalVested);

    // ============ Beneficiary Functions ============

    /**
     * @notice Claim all available vested tokens for the caller
     */
    function claim() external;

    // ============ Token Management ============

    /**
     * @notice Handle token deposits to the contract
     */
    function onTokensReceived() external;

    // ============ Emergency Functions ============

    /**
     * @notice Emergency function to recover non-RDAT tokens sent by mistake
     * @param token The token contract to recover
     * @param to Address to send recovered tokens to
     */
    function recoverToken(IERC20 token, address to) external;
}
