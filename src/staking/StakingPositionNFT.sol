// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title StakingPositionNFT
 * @notice ERC721 NFT representing staking positions
 * @dev Each NFT represents a unique staking position with its parameters
 */
contract StakingPositionNFT is ERC721, ERC721Enumerable, AccessControl {
    using Counters for Counters.Counter;
    
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    
    Counters.Counter private _tokenIdCounter;
    
    // Position metadata
    struct Position {
        uint256 amount;
        uint256 lockPeriod;
        uint256 startTime;
        uint256 endTime;
        address originalOwner;
    }
    
    mapping(uint256 => Position) public positions;
    
    event PositionCreated(
        uint256 indexed tokenId,
        address indexed owner,
        uint256 amount,
        uint256 lockPeriod
    );
    
    event PositionBurned(uint256 indexed tokenId);
    
    constructor() ERC721("RDAT Staking Position", "RDAT-STAKE") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
    }
    
    /**
     * @notice Mint a new staking position NFT
     * @dev Only callable by StakingManager
     * @param to Address to mint to
     * @param amount Staked amount
     * @param lockPeriod Lock period in seconds
     * @return tokenId The ID of the minted NFT
     */
    function mintPosition(
        address to,
        uint256 amount,
        uint256 lockPeriod
    ) external onlyRole(MINTER_ROLE) returns (uint256) {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        
        _safeMint(to, tokenId);
        
        positions[tokenId] = Position({
            amount: amount,
            lockPeriod: lockPeriod,
            startTime: block.timestamp,
            endTime: block.timestamp + lockPeriod,
            originalOwner: to
        });
        
        emit PositionCreated(tokenId, to, amount, lockPeriod);
        
        return tokenId;
    }
    
    /**
     * @notice Burn a staking position NFT
     * @dev Only callable by StakingManager when unstaking
     * @param tokenId The ID of the NFT to burn
     */
    function burn(uint256 tokenId) external onlyRole(BURNER_ROLE) {
        _burn(tokenId);
        delete positions[tokenId];
        emit PositionBurned(tokenId);
    }
    
    /**
     * @notice Get position details
     * @param tokenId The position ID
     * @return Position struct with all details
     */
    function getPosition(uint256 tokenId) external view returns (Position memory) {
        require(_exists(tokenId), "Position does not exist");
        return positions[tokenId];
    }
    
    /**
     * @notice Check if position lock period has ended
     * @param tokenId The position ID
     * @return bool True if lock period has ended
     */
    function isUnlocked(uint256 tokenId) external view returns (bool) {
        require(_exists(tokenId), "Position does not exist");
        return block.timestamp >= positions[tokenId].endTime;
    }
    
    /**
     * @notice Get all position IDs owned by an address
     * @param owner The address to query
     * @return tokenIds Array of position IDs
     */
    function getPositionsByOwner(address owner) external view returns (uint256[] memory) {
        uint256 balance = balanceOf(owner);
        uint256[] memory tokenIds = new uint256[](balance);
        
        for (uint256 i = 0; i < balance; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(owner, i);
        }
        
        return tokenIds;
    }
    
    // Required overrides
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }
    
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, ERC721Enumerable, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
    
    // Simplified interface functions for StakingManager
    function mint(address to, uint256 tokenId) external onlyRole(MINTER_ROLE) {
        _safeMint(to, tokenId);
    }
}