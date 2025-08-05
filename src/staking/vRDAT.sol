// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title vRDAT
 * @notice Non-transferable governance token for RDAT stakers
 * @dev Soul-bound token that represents voting power from staking positions
 */
contract vRDAT is ERC20, ERC20Votes, ERC20Permit, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    
    // Make token non-transferable (soul-bound)
    mapping(address => bool) public transferAllowlist;
    
    event TransferAllowlistUpdated(address indexed account, bool allowed);
    
    constructor() ERC20("vRDAT", "vRDAT") ERC20Permit("vRDAT") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
    }
    
    /**
     * @notice Mint vRDAT to a staker
     * @dev Only callable by StakingManager
     * @param to Address to mint to
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }
    
    /**
     * @notice Burn vRDAT from a staker
     * @dev Only callable by StakingManager
     * @param from Address to burn from
     * @param amount Amount to burn
     */
    function burn(address from, uint256 amount) external onlyRole(BURNER_ROLE) {
        _burn(from, amount);
    }
    
    /**
     * @notice Update transfer allowlist
     * @dev Used to allow specific contracts like StakingManager
     * @param account Address to update
     * @param allowed Whether transfers are allowed
     */
    function updateTransferAllowlist(
        address account,
        bool allowed
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        transferAllowlist[account] = allowed;
        emit TransferAllowlistUpdated(account, allowed);
    }
    
    /**
     * @notice Override transfer to make token non-transferable
     * @dev Only allowed for allowlisted addresses (like StakingManager)
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
        
        // Allow minting and burning
        if (from == address(0) || to == address(0)) {
            return;
        }
        
        // Only allow transfers from/to allowlisted addresses
        require(
            transferAllowlist[from] || transferAllowlist[to],
            "vRDAT: non-transferable"
        );
    }
    
    /**
     * @notice Get current voting power
     * @param account Address to check
     * @return Current voting power
     */
    function votingPower(address account) external view returns (uint256) {
        return getVotes(account);
    }
    
    /**
     * @notice Get voting power at specific block
     * @param account Address to check
     * @param blockNumber Block number
     * @return Voting power at block
     */
    function votingPowerAt(
        address account,
        uint256 blockNumber
    ) external view returns (uint256) {
        return getPastVotes(account, blockNumber);
    }
    
    // Required overrides
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }
    
    function _mint(
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._mint(to, amount);
    }
    
    function _burn(
        address account,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._burn(account, amount);
    }
}