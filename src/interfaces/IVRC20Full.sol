// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "./IVRC20Basic.sol";

/**
 * @title IVRC20Full
 * @notice Full VRC-20 interface for complete Data Autonomy Token compliance
 * @dev Extends basic VRC-20 with data pool management and epoch rewards
 */
interface IVRC20Full is IVRC20Basic {
    // Data pool structures
    struct DataPool {
        address creator;
        string metadata;
        uint256 contributorCount;
        uint256 totalDataPoints;
        bool active;
    }
    
    struct DataPoint {
        address contributor;
        uint256 timestamp;
        uint256 quality;
        bool verified;
    }
    
    // Events
    event DataPoolCreated(bytes32 indexed poolId, address indexed creator, string metadata);
    event DataAdded(bytes32 indexed poolId, bytes32 indexed dataHash, address indexed contributor);
    event DataVerified(bytes32 indexed poolId, bytes32 indexed dataHash, uint256 quality);
    event DLPRegistered(address indexed dlpAddress, uint256 timestamp);
    event EpochRewardsSet(uint256 indexed epoch, uint256 rewards);
    event EpochRewardsClaimed(address indexed user, uint256 indexed epoch, uint256 amount);
    
    // Data pool management
    function createDataPool(
        bytes32 poolId,
        string memory metadata,
        address[] memory initialContributors
    ) external returns (bool);
    
    function addDataToPool(
        bytes32 poolId,
        bytes32 dataHash,
        uint256 quality
    ) external returns (bool);
    
    function verifyDataOwnership(
        bytes32 dataHash, 
        address owner
    ) external view returns (bool);
    
    // Epoch rewards
    function epochRewards(uint256 epoch) external view returns (uint256);
    function claimEpochRewards(uint256 epoch) external returns (uint256);
    function setEpochRewards(uint256 epoch, uint256 amount) external;
    
    // DLP registration
    function registerDLP(address dlpAddress) external returns (bool);
    function isDLPRegistered() external view returns (bool);
    function getDLPAddress() external view returns (address);
    
    // Data pool getters
    function getDataPool(bytes32 poolId) external view returns (
        address creator,
        string memory metadata,
        uint256 contributorCount,
        uint256 totalDataPoints,
        bool active
    );
    
    function getDataPoint(bytes32 poolId, bytes32 dataHash) external view returns (
        address contributor,
        uint256 timestamp,
        uint256 quality,
        bool verified
    );
    
    // Constants
    function vrcVersion() external pure returns (string memory);
}