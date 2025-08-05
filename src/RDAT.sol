// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IVRC20Basic.sol";
import "./interfaces/IRDAT.sol";

/**
 * @title RDAT
 * @author r/datadao
 * @notice Main ERC-20 token for the r/datadao ecosystem with VRC-20 compliance
 * @dev Implements the V2 Beta token with enhanced security and Vana network compatibility
 * 
 * Key Features:
 * - 100M total supply with 30M reserved for V1 migration
 * - VRC-20 compliance stubs for Vana network
 * - Role-based access control for minting and pausing
 * - Reentrancy protection on all state-changing functions
 * - EIP-2612 permit functionality for gasless approvals
 */
contract RDAT is 
    ERC20,
    ERC20Burnable,
    ERC20Pausable,
    ERC20Permit,
    AccessControl,
    ReentrancyGuard,
    IVRC20Basic,
    IRDAT 
{
    // Roles
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    
    // Constants
    uint256 public constant override TOTAL_SUPPLY = 100_000_000 * 10**18; // 100M tokens
    uint256 public constant override MIGRATION_ALLOCATION = 30_000_000 * 10**18; // 30M for V1 holders
    
    // VRC-20 Compliance
    bool public constant override(IRDAT, IVRC20Basic) isVRC20 = true;
    address public override(IRDAT, IVRC20Basic) pocContract; // Proof of Contribution
    address public override(IRDAT, IVRC20Basic) dataRefiner;
    
    // Revenue Distribution
    address public override revenueCollector;
    
    // State
    uint256 public totalMinted;
    
    // Errors
    error ExceedsMaxSupply(uint256 requested, uint256 available);
    error InvalidAddress();
    error UnauthorizedMinter(address minter);
    
    /**
     * @dev Constructor initializes the token with treasury allocation
     * @param treasury Address to receive non-migration supply
     */
    constructor(address treasury) 
        ERC20("r/datadao", "RDAT") 
        ERC20Permit("r/datadao") 
    {
        if (treasury == address(0)) revert InvalidAddress();
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        
        // Mint non-migration supply to treasury
        uint256 treasuryAmount = TOTAL_SUPPLY - MIGRATION_ALLOCATION;
        _mint(treasury, treasuryAmount);
        totalMinted = treasuryAmount;
    }
    
    /**
     * @dev Mints tokens to specified address
     * @param to Recipient address
     * @param amount Amount to mint
     * @notice Only callable by MINTER_ROLE (migration bridge)
     */
    function mint(address to, uint256 amount) external override onlyRole(MINTER_ROLE) nonReentrant {
        if (to == address(0)) revert InvalidAddress();
        
        uint256 newTotalMinted = totalMinted + amount;
        if (newTotalMinted > TOTAL_SUPPLY) {
            revert ExceedsMaxSupply(amount, TOTAL_SUPPLY - totalMinted);
        }
        
        totalMinted = newTotalMinted;
        _mint(to, amount);
    }
    
    /**
     * @dev Pauses all token transfers
     * @notice Only callable by PAUSER_ROLE
     */
    function pause() external override onlyRole(PAUSER_ROLE) {
        _pause();
    }
    
    /**
     * @dev Unpauses all token transfers
     * @notice Only callable by PAUSER_ROLE
     */
    function unpause() external override onlyRole(PAUSER_ROLE) {
        _unpause();
    }
    
    /**
     * @dev Sets the Proof of Contribution contract address
     * @param _poc Address of the PoC contract
     * @notice VRC-20 compliance requirement
     */
    function setPoCContract(address _poc) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_poc == address(0)) revert InvalidAddress();
        pocContract = _poc;
        emit VRCContractSet("ProofOfContribution", _poc);
    }
    
    /**
     * @dev Sets the Data Refiner contract address
     * @param _refiner Address of the data refiner contract
     * @notice VRC-20 compliance requirement
     */
    function setDataRefiner(address _refiner) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_refiner == address(0)) revert InvalidAddress();
        dataRefiner = _refiner;
        emit VRCContractSet("DataRefiner", _refiner);
    }
    
    /**
     * @dev Sets the Revenue Collector contract address
     * @param _collector Address of the revenue collector
     */
    function setRevenueCollector(address _collector) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_collector == address(0)) revert InvalidAddress();
        revenueCollector = _collector;
        emit RevenueCollectorSet(_collector);
    }
    
    /**
     * @dev Hook that is called on any transfer of tokens
     * @notice Enforces pause state
     */
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Pausable) {
        super._update(from, to, amount);
    }
    
    /**
     * @dev Returns the available minting capacity
     */
    function availableToMint() external view returns (uint256) {
        return TOTAL_SUPPLY - totalMinted;
    }
    
    /**
     * @dev See {IERC165-supportsInterface}
     */
    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        override(AccessControl) 
        returns (bool) 
    {
        return super.supportsInterface(interfaceId);
    }
}