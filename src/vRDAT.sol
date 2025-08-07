// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";
import "./interfaces/IvRDAT.sol";
import "./interfaces/IvRDATGovernance.sol";

/**
 * @title vRDAT - Soul-bound Governance Token
 * @author r/datadao
 * @notice Non-transferable governance token earned through staking RDAT
 * @dev Implements soul-bound tokens with voting power delegation
 * 
 * Key Features:
 * - Non-transferable (soul-bound)
 * - Minted based on staking positions
 * - Voting power delegation without transfer
 * - Quadratic voting support
 * - Anti-gaming protections
 */
contract vRDAT is 
    ERC20,
    ERC20Votes,
    ERC20Permit,
    AccessControl,
    ReentrancyGuard,
    IvRDAT,
    IvRDATGovernance
{
    // Roles
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    
    // Constants
    uint256 public constant override MAX_PER_ADDRESS = 10_000_000 * 10**18; // 10M vRDAT max per address
    
    // State
    mapping(address => uint256) public totalMinted; // Track total minted per address
    mapping(address => uint256) public totalBurned; // Track total burned per address
    
    // Events are already defined in ERC20Votes, no need to redefine
    
    /**
     * @dev Constructor sets up ERC20 with governance extensions
     * @param admin Address to receive admin role
     */
    constructor(address admin) 
        ERC20("r/datadao Voting", "vRDAT") 
        ERC20Permit("r/datadao Voting") 
    {
        require(admin != address(0), "Invalid admin");
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(BURNER_ROLE, admin);
    }
    
    /**
     * @dev Mint vRDAT tokens to an address
     * @param to Address to receive tokens
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external override onlyRole(MINTER_ROLE) nonReentrant {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Invalid amount");
        
        // Check max balance
        uint256 newBalance = balanceOf(to) + amount;
        if (newBalance > MAX_PER_ADDRESS) {
            revert ExceedsMaxBalance();
        }
        
        // Update state
        totalMinted[to] += amount;
        
        // Mint tokens
        _mint(to, amount);
        emit Mint(to, amount);
    }
    
    /**
     * @dev Burn vRDAT tokens from an address
     * @param from Address to burn from
     * @param amount Amount to burn
     */
    function burn(address from, uint256 amount) external override onlyRole(BURNER_ROLE) nonReentrant {
        require(from != address(0), "Invalid address");
        require(amount > 0, "Invalid amount");
        require(balanceOf(from) >= amount, "Insufficient balance");
        
        totalBurned[from] += amount;
        _burn(from, amount);
        emit Burn(from, amount);
    }
    
    /**
     * @dev Burn vRDAT tokens for governance voting
     * @param from Address to burn from
     * @param amount Amount to burn
     */
    function burnForGovernance(address from, uint256 amount) external override onlyRole(GOVERNANCE_ROLE) nonReentrant {
        require(from != address(0), "Invalid address");
        require(amount > 0, "Invalid amount");
        require(balanceOf(from) >= amount, "Insufficient balance");
        
        totalBurned[from] += amount;
        _burn(from, amount);
        emit Burn(from, amount);
    }
    
    /**
     * @dev Transfer function - always reverts as tokens are non-transferable
     */
    function transfer(address, uint256) public pure override(ERC20, IvRDAT) returns (bool) {
        revert NonTransferableToken();
    }
    
    /**
     * @dev TransferFrom function - always reverts as tokens are non-transferable
     */
    function transferFrom(address, address, uint256) public pure override(ERC20, IvRDAT) returns (bool) {
        revert NonTransferableToken();
    }
    
    /**
     * @dev Approve function - always reverts as tokens are non-transferable
     */
    function approve(address, uint256) public pure override(ERC20, IvRDAT) returns (bool) {
        revert NonTransferableToken();
    }
    
    /**
     * @dev Internal transfer function - blocks all transfers except minting and burning
     */
    function _update(address from, address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        // Only allow minting (from == address(0)) and burning (to == address(0))
        if (from != address(0) && to != address(0)) {
            revert NonTransferableToken();
        }
        super._update(from, to, amount);
    }
    
    /**
     * @dev Delegate votes to another address
     * @notice This allows vote delegation without transferring tokens
     * @param delegatee Address to delegate votes to
     */
    function delegate(address delegatee) public override {
        address currentDelegate = delegates(msg.sender);
        uint256 balance = balanceOf(msg.sender);
        
        _delegate(msg.sender, delegatee);
        
        emit DelegateChanged(msg.sender, currentDelegate, delegatee);
        
        if (currentDelegate != address(0)) {
            emit DelegateVotesChanged(currentDelegate, getVotes(currentDelegate) + balance, getVotes(currentDelegate));
        }
        
        if (delegatee != address(0)) {
            emit DelegateVotesChanged(delegatee, getVotes(delegatee) - balance, getVotes(delegatee));
        }
    }
    
    /**
     * @dev Calculate quadratic voting cost
     * @param votes Number of votes desired
     * @return cost The vRDAT cost for that many votes
     */
    function calculateQuadraticCost(uint256 votes) external pure returns (uint256 cost) {
        // Cost = votes^2
        // This makes it exponentially expensive to accumulate votes
        cost = votes * votes;
    }
    
    /**
     * @dev Calculate votes from vRDAT amount using quadratic formula
     * @param amount Amount of vRDAT tokens
     * @return votes Number of votes (square root of amount)
     */
    function calculateQuadraticVotes(uint256 amount) external pure returns (uint256 votes) {
        // Votes = sqrt(amount)
        // Using Babylonian method for square root
        if (amount == 0) return 0;
        
        uint256 x = amount;
        uint256 y = (x + 1) / 2;
        
        while (y < x) {
            x = y;
            y = (x + amount / x) / 2;
        }
        
        votes = x;
    }
    
    /**
     * @dev Get user statistics
     * @param account Address to check
     * @return balance Current vRDAT balance
     * @return minted Total vRDAT minted to this address
     * @return burned Total vRDAT burned from this address
     * @return votingPower Current voting power (including delegations)
     */
    function getUserStats(address account) external view returns (
        uint256 balance,
        uint256 minted,
        uint256 burned,
        uint256 votingPower
    ) {
        balance = balanceOf(account);
        minted = totalMinted[account];
        burned = totalBurned[account];
        votingPower = getVotes(account);
    }
    
    /**
     * @dev Check if an address can mint (only checks max balance)
     * @param account Address to check
     * @return canMintNow Whether the address can mint now based on balance limit
     * @return remainingCapacity How much more can be minted before hitting max
     */
    function canMint(address account) external view returns (bool canMintNow, uint256 remainingCapacity) {
        uint256 currentBalance = balanceOf(account);
        if (currentBalance >= MAX_PER_ADDRESS) {
            canMintNow = false;
            remainingCapacity = 0;
        } else {
            canMintNow = true;
            remainingCapacity = MAX_PER_ADDRESS - currentBalance;
        }
    }
    
    /**
     * @dev Required override for ERC20Votes
     */
    function _getVotingUnits(address account) internal view override returns (uint256) {
        return balanceOf(account);
    }
    
    /**
     * @dev Override balanceOf to satisfy ERC20, IvRDAT, and IvRDATGovernance
     */
    function balanceOf(address account) public view override(ERC20, IvRDAT, IvRDATGovernance) returns (uint256) {
        return super.balanceOf(account);
    }
    
    /**
     * @dev Override totalSupply to satisfy both ERC20 and IvRDAT
     */
    function totalSupply() public view override(ERC20, IvRDAT) returns (uint256) {
        return super.totalSupply();
    }
    
    /**
     * @dev Override nonces from ERC20Permit
     */
    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
    
    /**
     * @dev See {IERC165-supportsInterface}
     */
    function supportsInterface(bytes4 interfaceId) public view override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}