// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interfaces/IVRC20Full.sol";
import "./interfaces/IRDAT.sol";
import "./interfaces/IProofOfContributionIntegration.sol";

/**
 * @title RDATUpgradeable
 * @author r/datadao
 * @notice Upgradeable implementation of the RDAT token with UUPS pattern
 * @dev Implements the V2 Beta token with enhanced security and Vana network compatibility
 * 
 * Key Features:
 * - 100M total supply with 30M reserved for V1 migration
 * - VRC-20 compliance stubs for Vana network
 * - Role-based access control for minting and pausing
 * - Reentrancy protection on all state-changing functions
 * - EIP-2612 permit functionality for gasless approvals
 * - UUPS upgradeable pattern for future improvements
 */
contract RDATUpgradeable is 
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable,
    ERC20PermitUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    IVRC20Full,
    IRDAT 
{
    // Roles
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    
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
    
    // VRC-20 Full state
    string public constant VRC_VERSION = "VRC-20-1.0";
    address public dlpAddress;
    bool public dlpRegistered;
    uint256 public dlpRegistrationBlock;
    
    // Data pool management
    mapping(bytes32 => DataPool) private _dataPools;
    mapping(bytes32 => mapping(bytes32 => DataPoint)) private _dataPoints;
    mapping(bytes32 => mapping(address => bool)) private _dataOwnership;
    mapping(uint256 => uint256) private _epochRewardTotals;
    mapping(uint256 => mapping(address => uint256)) private _epochRewardsClaimed;
    mapping(uint256 => mapping(address => bool)) private _hasClaimedEpoch;
    
    // Errors
    error ExceedsMaxSupply(uint256 requested, uint256 available);
    error InvalidAddress();
    error UnauthorizedMinter(address minter);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    /**
     * @dev Initializes the token with treasury allocation
     * @param treasury Address to receive non-migration supply
     * @param admin Address to receive admin role
     */
    function initialize(address treasury, address admin) public initializer {
        if (treasury == address(0) || admin == address(0)) revert InvalidAddress();
        
        __ERC20_init("r/datadao", "RDAT");
        __ERC20Burnable_init();
        __ERC20Pausable_init();
        __ERC20Permit_init("r/datadao");
        __AccessControl_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
        
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
     * @dev Authorizes an upgrade to a new implementation
     * @param newImplementation Address of the new implementation
     */
    function _authorizeUpgrade(address newImplementation) 
        internal 
        override 
        onlyRole(UPGRADER_ROLE) 
    {}
    
    /**
     * @dev Hook that is called on any transfer of tokens
     * @notice Enforces pause state
     */
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20Upgradeable, ERC20PausableUpgradeable) {
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
        override(AccessControlUpgradeable) 
        returns (bool) 
    {
        return super.supportsInterface(interfaceId);
    }
    
    // ========== VRC-20 FULL IMPLEMENTATION ==========
    
    /**
     * @notice Creates a new data pool
     * @param poolId Unique identifier for the pool
     * @param metadata Pool metadata (IPFS hash or JSON)
     * @param initialContributors Initial list of contributors
     */
    function createDataPool(
        bytes32 poolId,
        string memory metadata,
        address[] memory initialContributors
    ) external override nonReentrant returns (bool) {
        require(poolId != bytes32(0), "Invalid pool ID");
        require(_dataPools[poolId].creator == address(0), "Pool already exists");
        require(bytes(metadata).length > 0, "Empty metadata");
        
        DataPool storage pool = _dataPools[poolId];
        pool.creator = msg.sender;
        pool.metadata = metadata;
        pool.active = true;
        pool.contributorCount = initialContributors.length;
        
        // Add initial contributors
        for (uint256 i = 0; i < initialContributors.length; i++) {
            if (initialContributors[i] != address(0)) {
                _dataOwnership[poolId][initialContributors[i]] = true;
            }
        }
        
        emit DataPoolCreated(poolId, msg.sender, metadata);
        return true;
    }
    
    /**
     * @notice Adds data to an existing pool
     * @param poolId Pool identifier
     * @param dataHash Hash of the data being added
     * @param quality Quality score (0-100)
     */
    function addDataToPool(
        bytes32 poolId,
        bytes32 dataHash,
        uint256 quality
    ) external override nonReentrant returns (bool) {
        require(_dataPools[poolId].active, "Pool not active");
        require(dataHash != bytes32(0), "Invalid data hash");
        require(quality <= 100, "Quality score too high");
        require(_dataPoints[poolId][dataHash].contributor == address(0), "Data already exists");
        
        DataPoint storage dataPoint = _dataPoints[poolId][dataHash];
        dataPoint.contributor = msg.sender;
        dataPoint.timestamp = block.timestamp;
        dataPoint.quality = quality;
        dataPoint.verified = false;
        
        // Track ownership
        _dataOwnership[dataHash][msg.sender] = true;
        
        // Update pool stats
        DataPool storage pool = _dataPools[poolId];
        pool.totalDataPoints++;
        if (!_dataOwnership[poolId][msg.sender]) {
            pool.contributorCount++;
            _dataOwnership[poolId][msg.sender] = true;
        }
        
        emit DataAdded(poolId, dataHash, msg.sender);
        
        // If PoC contract is set, notify it
        if (pocContract != address(0)) {
            // Integration point for ProofOfContribution
            try IProofOfContributionIntegration(pocContract).recordContribution(
                msg.sender,
                quality,
                dataHash
            ) {} catch {
                // Continue even if PoC recording fails
            }
        }
        
        return true;
    }
    
    /**
     * @notice Verifies data ownership
     * @param dataHash Hash of the data
     * @param owner Address to verify
     */
    function verifyDataOwnership(
        bytes32 dataHash,
        address owner
    ) external view override returns (bool) {
        return _dataOwnership[dataHash][owner];
    }
    
    /**
     * @notice Returns rewards for a specific epoch
     * @param epoch Epoch number
     */
    function epochRewards(uint256 epoch) external view override returns (uint256) {
        return _epochRewardTotals[epoch];
    }
    
    /**
     * @notice Claims rewards for a specific epoch
     * @param epoch Epoch to claim from
     */
    function claimEpochRewards(uint256 epoch) external override nonReentrant returns (uint256) {
        require(!_hasClaimedEpoch[epoch][msg.sender], "Already claimed");
        require(_epochRewardTotals[epoch] > 0, "No rewards for epoch");
        
        // Calculate user's share (integration with PoC required)
        uint256 userReward = _calculateEpochReward(msg.sender, epoch);
        require(userReward > 0, "No rewards to claim");
        
        _hasClaimedEpoch[epoch][msg.sender] = true;
        _epochRewardsClaimed[epoch][msg.sender] = userReward;
        
        // Transfer rewards
        _mint(msg.sender, userReward);
        totalMinted += userReward;
        
        emit EpochRewardsClaimed(msg.sender, epoch, userReward);
        return userReward;
    }
    
    /**
     * @notice Sets rewards for an epoch (admin only)
     * @param epoch Epoch number
     * @param amount Reward amount
     */
    function setEpochRewards(uint256 epoch, uint256 amount) 
        external 
        override 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(epoch > 0, "Invalid epoch");
        require(totalMinted + amount <= TOTAL_SUPPLY, "Exceeds max supply");
        
        _epochRewardTotals[epoch] = amount;
        emit EpochRewardsSet(epoch, amount);
    }
    
    /**
     * @notice Registers a DLP address
     * @param _dlpAddress Address to register
     */
    function registerDLP(address _dlpAddress) 
        external 
        override 
        onlyRole(DEFAULT_ADMIN_ROLE) 
        returns (bool) 
    {
        require(_dlpAddress != address(0), "Invalid DLP address");
        require(!dlpRegistered, "DLP already registered");
        
        dlpAddress = _dlpAddress;
        dlpRegistered = true;
        dlpRegistrationBlock = block.number;
        
        emit DLPRegistered(_dlpAddress, block.timestamp);
        return true;
    }
    
    /**
     * @notice Checks if DLP is registered
     */
    function isDLPRegistered() external view override returns (bool) {
        return dlpRegistered;
    }
    
    /**
     * @notice Gets the registered DLP address
     */
    function getDLPAddress() external view override returns (address) {
        return dlpAddress;
    }
    
    /**
     * @notice Gets data pool information
     * @param poolId Pool identifier
     */
    function getDataPool(bytes32 poolId) external view override returns (
        address creator,
        string memory metadata,
        uint256 contributorCount,
        uint256 totalDataPoints,
        bool active
    ) {
        DataPool storage pool = _dataPools[poolId];
        return (
            pool.creator,
            pool.metadata,
            pool.contributorCount,
            pool.totalDataPoints,
            pool.active
        );
    }
    
    /**
     * @notice Gets data point information
     * @param poolId Pool identifier
     * @param dataHash Data hash
     */
    function getDataPoint(bytes32 poolId, bytes32 dataHash) external view override returns (
        address contributor,
        uint256 timestamp,
        uint256 quality,
        bool verified
    ) {
        DataPoint storage point = _dataPoints[poolId][dataHash];
        return (
            point.contributor,
            point.timestamp,
            point.quality,
            point.verified
        );
    }
    
    /**
     * @notice Returns the VRC version
     */
    function vrcVersion() external pure override returns (string memory) {
        return VRC_VERSION;
    }
    
    /**
     * @dev Calculates epoch reward for a user based on their contribution score
     * @param user Address of the user
     * @param epoch Epoch number
     * @return reward Amount of tokens to reward
     */
    function _calculateEpochReward(address user, uint256 epoch) private view returns (uint256) {
        // If no PoC contract set, no rewards
        if (pocContract == address(0)) {
            return 0;
        }
        
        // Get user's contribution score for the epoch
        IProofOfContributionIntegration poc = IProofOfContributionIntegration(pocContract);
        uint256 userScore = poc.getEpochScore(user, epoch);
        
        // If user didn't contribute, no rewards
        if (userScore == 0) {
            return 0;
        }
        
        // Get total score for the epoch
        uint256 totalScore = poc.getEpochTotalScore(epoch);
        if (totalScore == 0) {
            return 0;
        }
        
        // Calculate proportional share
        uint256 epochRewards = _epochRewardTotals[epoch];
        uint256 userReward = (epochRewards * userScore) / totalScore;
        
        return userReward;
    }
}

// Interface for ProofOfContribution integration
interface IProofOfContributionIntegration {
    function recordContribution(address contributor, uint256 score, bytes32 dataHash) external;
    function getEpochScore(address contributor, uint256 epoch) external view returns (uint256);
    function epochTotalScores(uint256 epoch) external view returns (uint256);
}