// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title SimpleVanaDLP
 * @notice Simplified Vana-compatible DLP for r/datadao registry registration
 * @dev Minimal implementation that satisfies registry requirements while integrating with RDAT ecosystem
 */
contract SimpleVanaDLP is UUPSUpgradeable, AccessControlUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    bytes32 public constant MAINTAINER_ROLE = keccak256("MAINTAINER_ROLE");

    // Core DLP properties
    string public name;
    IERC20 public token;
    string public publicKey;
    string public proofInstruction;
    uint256 public fileRewardFactor;
    uint256 public totalContributorsRewardAmount;
    uint256 public version = 1;

    // Data tracking
    mapping(uint256 => FileInfo) public files;
    mapping(address => ContributorInfo) public contributors;
    uint256[] public filesList;
    address[] public contributorsList;

    struct FileInfo {
        uint256 timestamp;
        uint256 proofIndex;
        uint256 rewardAmount;
        address contributor;
    }

    struct ContributorInfo {
        uint256[] fileIds;
        uint256 totalRewardAmount;
    }

    // Events
    event RewardRequested(
        address indexed contributorAddress, uint256 indexed fileId, uint256 indexed proofIndex, uint256 rewardAmount
    );

    event FileAdded(uint256 indexed fileId, address indexed contributor, uint256 rewardAmount);

    struct InitParams {
        address ownerAddress;
        address tokenAddress;
        string dlpName;
        string dlpPublicKey;
        string dlpProofInstruction;
        uint256 dlpFileRewardFactor;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the DLP
     */
    function initialize(InitParams memory params) external initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, params.ownerAddress);
        _grantRole(MAINTAINER_ROLE, params.ownerAddress);

        name = params.dlpName;
        token = IERC20(params.tokenAddress);
        publicKey = params.dlpPublicKey;
        proofInstruction = params.dlpProofInstruction;
        fileRewardFactor = params.dlpFileRewardFactor;
    }

    /**
     * @notice Add rewards for contributors (fund the DLP)
     */
    function addRewardsForContributors(uint256 contributorsRewardAmount)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        nonReentrant
    {
        require(contributorsRewardAmount > 0, "Invalid amount");

        // Transfer tokens from caller to this contract
        token.safeTransferFrom(msg.sender, address(this), contributorsRewardAmount);
        totalContributorsRewardAmount += contributorsRewardAmount;
    }

    /**
     * @notice Request reward for a file (simplified version)
     * @dev In a real implementation, this would verify with DataRegistry
     */
    function requestReward(uint256 registryFileId, uint256 proofIndex) external whenNotPaused nonReentrant {
        require(files[registryFileId].timestamp == 0, "File already processed");

        uint256 rewardAmount = calculateReward();
        require(rewardAmount <= token.balanceOf(address(this)), "Insufficient rewards");

        // Record file
        files[registryFileId] = FileInfo({
            timestamp: block.timestamp,
            proofIndex: proofIndex,
            rewardAmount: rewardAmount,
            contributor: msg.sender
        });

        filesList.push(registryFileId);

        // Update contributor info
        if (contributors[msg.sender].fileIds.length == 0) {
            contributorsList.push(msg.sender);
        }
        contributors[msg.sender].fileIds.push(registryFileId);
        contributors[msg.sender].totalRewardAmount += rewardAmount;

        // Transfer reward
        token.safeTransfer(msg.sender, rewardAmount);

        emit RewardRequested(msg.sender, registryFileId, proofIndex, rewardAmount);
        emit FileAdded(registryFileId, msg.sender, rewardAmount);
    }

    /**
     * @notice Calculate reward for a file
     */
    function calculateReward() public view returns (uint256) {
        // Simple calculation: fixed amount based on fileRewardFactor
        return fileRewardFactor * 1e18; // fileRewardFactor as RDAT tokens
    }

    /**
     * @notice Get files list count
     */
    function filesListCount() external view returns (uint256) {
        return filesList.length;
    }

    /**
     * @notice Get file ID at index
     */
    function filesListAt(uint256 index) external view returns (uint256) {
        return filesList[index];
    }

    /**
     * @notice Get contributors count
     */
    function contributorsCount() external view returns (uint256) {
        return contributorsList.length;
    }

    /**
     * @notice Get contributor info
     */
    function contributorInfo(address contributorAddress) external view returns (address, uint256) {
        return (contributorAddress, contributors[contributorAddress].fileIds.length);
    }

    /**
     * @notice Get contributor files count
     */
    function contributorFilesCount(address contributorAddress) external view returns (uint256) {
        return contributors[contributorAddress].fileIds.length;
    }

    /**
     * @notice Get contributor file at index
     */
    function contributorFiles(address contributorAddress, uint256 index)
        external
        view
        returns (uint256 fileId, uint256 timestamp, uint256 proofIndex, uint256 rewardAmount)
    {
        uint256 fileId = contributors[contributorAddress].fileIds[index];
        FileInfo memory file = files[fileId];
        return (fileId, file.timestamp, file.proofIndex, file.rewardAmount);
    }

    // Admin functions
    function updateFileRewardFactor(uint256 newFileRewardFactor) external onlyRole(DEFAULT_ADMIN_ROLE) {
        fileRewardFactor = newFileRewardFactor;
    }

    function updateProofInstruction(string calldata newProofInstruction) external onlyRole(DEFAULT_ADMIN_ROLE) {
        proofInstruction = newProofInstruction;
    }

    function updatePublicKey(string calldata newPublicKey) external onlyRole(DEFAULT_ADMIN_ROLE) {
        publicKey = newPublicKey;
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @notice Emergency withdraw
     */
    function emergencyWithdraw(address tokenAddress, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(tokenAddress).safeTransfer(msg.sender, amount);
    }

    /**
     * @notice Required for UUPS upgrades
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    // Compatibility functions for registry
    function dataRegistry() external pure returns (address) {
        return address(0); // Placeholder
    }

    function teePool() external pure returns (address) {
        return address(0); // Placeholder
    }
}
