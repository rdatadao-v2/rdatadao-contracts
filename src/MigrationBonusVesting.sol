// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title MigrationBonusVesting
 * @notice Special vesting contract for migration bonuses with 12-month linear vesting
 * @dev Standalone contract for managing migration bonus vesting
 * 
 * Key features:
 * - No cliff period (immediate vesting start)
 * - 12-month linear vesting
 * - Automatic beneficiary setup on bonus grant
 * - Integration with VanaMigrationBridge
 */
contract MigrationBonusVesting is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // Constants
    uint256 public constant VESTING_DURATION = 365 days; // 12 months
    uint256 public constant CLIFF_DURATION = 0; // No cliff for migration bonuses
    
    // Roles
    bytes32 public constant MIGRATION_BRIDGE_ROLE = keccak256("MIGRATION_BRIDGE_ROLE");
    
    // State variables
    IERC20 public immutable rdatToken;
    mapping(address => uint256) public allocations;
    mapping(address => uint256) public beneficiaryClaimed;
    mapping(address => uint256) public beneficiaryEligibilityDates;
    address[] public beneficiaries;
    uint256 public totalAllocations;
    
    // Events
    event MigrationBonusGranted(address indexed beneficiary, uint256 amount, uint256 vestingStart);
    event BeneficiaryAdded(address indexed beneficiary, uint256 allocation);
    event TokensClaimed(address indexed beneficiary, uint256 amount, uint256 totalClaimedByBeneficiary);
    
    // Errors
    error InvalidVestingStart();
    error InsufficientFunds();
    error InvalidBeneficiary();
    error InvalidAmount();
    error NoTokensToClaim();
    error NotABeneficiary();
    
    /**
     * @dev Constructor
     * @param _rdatToken Address of the RDAT token
     * @param _admin Admin address for role management
     */
    constructor(address _rdatToken, address _admin) {
        require(_rdatToken != address(0), "Invalid token");
        require(_admin != address(0), "Invalid admin");
        
        rdatToken = IERC20(_rdatToken);
        
        // Grant admin the ability to set migration bridge
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }
    
    /**
     * @notice Grant migration bonus with automatic vesting setup
     * @param beneficiary Address to receive the vested bonus
     * @param amount Amount of bonus tokens to vest
     * @dev Only callable by migration bridge
     */
    function grantMigrationBonus(address beneficiary, uint256 amount) 
        external 
        onlyRole(MIGRATION_BRIDGE_ROLE) 
    {
        if (beneficiary == address(0)) revert InvalidBeneficiary();
        if (amount == 0) revert InvalidAmount();
        
        // Check contract has sufficient balance
        uint256 contractBalance = rdatToken.balanceOf(address(this));
        uint256 availableBalance = contractBalance > totalAllocations ? 
            contractBalance - totalAllocations : 0;
            
        if (availableBalance < amount) revert InsufficientFunds();
        
        // Add beneficiary if not already added
        if (allocations[beneficiary] == 0) {
            beneficiaries.push(beneficiary);
        }
        
        // Add to their allocation
        allocations[beneficiary] += amount;
        totalAllocations += amount;
        
        // Set vesting start to now (no cliff for migration bonuses)
        if (beneficiaryEligibilityDates[beneficiary] == 0) {
            beneficiaryEligibilityDates[beneficiary] = block.timestamp;
        }
        
        emit MigrationBonusGranted(beneficiary, amount, block.timestamp);
        emit BeneficiaryAdded(beneficiary, amount);
    }
    
    /**
     * @notice Calculate vested amount for migration bonus
     * @param beneficiary Address to check
     * @return vestedAmount Amount vested so far
     * @dev Implements 12-month linear vesting without cliff
     */
    function calculateVestedAmount(address beneficiary) public view returns (uint256) {
        uint256 allocation = allocations[beneficiary];
        if (allocation == 0) return 0;
        
        uint256 vestingStart = beneficiaryEligibilityDates[beneficiary];
        if (vestingStart == 0 || block.timestamp < vestingStart) return 0;
        
        // Linear vesting over 12 months
        uint256 elapsed = block.timestamp - vestingStart;
        if (elapsed >= VESTING_DURATION) {
            return allocation;
        }
        
        return (allocation * elapsed) / VESTING_DURATION;
    }
    
    /**
     * @notice Get vesting schedule details
     * @return cliff Always 0 for migration bonuses
     * @return duration Always 365 days
     */
    function getVestingSchedule() external pure returns (uint256 cliff, uint256 duration) {
        return (CLIFF_DURATION, VESTING_DURATION);
    }
    
    /**
     * @notice Get the claimable amount for a beneficiary
     * @param beneficiary Address to check
     * @return Amount available to claim
     */
    function getClaimableAmount(address beneficiary) public view returns (uint256) {
        uint256 vested = calculateVestedAmount(beneficiary);
        uint256 claimed = beneficiaryClaimed[beneficiary];
        return vested > claimed ? vested - claimed : 0;
    }
    
    /**
     * @notice Claim vested tokens
     * @dev Anyone can call, but only claims for msg.sender
     */
    function claim() external nonReentrant {
        address beneficiary = msg.sender;
        uint256 allocation = allocations[beneficiary];
        
        if (allocation == 0) revert NotABeneficiary();
        
        uint256 vested = calculateVestedAmount(beneficiary);
        uint256 alreadyClaimed = beneficiaryClaimed[beneficiary];
        
        if (vested <= alreadyClaimed) revert NoTokensToClaim();
        
        uint256 claimable = vested - alreadyClaimed;
        
        // Update claimed amount before transfer
        beneficiaryClaimed[beneficiary] = vested;
        
        // Transfer tokens
        rdatToken.safeTransfer(beneficiary, claimable);
        
        emit TokensClaimed(beneficiary, claimable, vested);
    }
    
    /**
     * @notice Calculate total allocated across all beneficiaries
     * @return total Total amount allocated
     */
    function getTotalAllocated() public view returns (uint256) {
        return totalAllocations;
    }
    
    /**
     * @notice Set the migration bridge address
     * @param bridge Address of the VanaMigrationBridge
     * @dev Only callable by admin
     */
    function setMigrationBridge(address bridge) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(bridge != address(0), "Invalid bridge address");
        _grantRole(MIGRATION_BRIDGE_ROLE, bridge);
    }
    
    /**
     * @notice Override to prevent eligibility date changes for migration bonuses
     * @dev Migration bonuses always start vesting immediately
     */
    function setEligibilityDate(uint256) external pure {
        revert("Eligibility date is automatic for migration bonuses");
    }
    
    /**
     * @notice Override to prevent manual beneficiary addition
     * @dev Beneficiaries are only added through grantMigrationBonus
     */
    function addBeneficiary(address, uint256) external pure {
        revert("Use grantMigrationBonus instead");
    }
}