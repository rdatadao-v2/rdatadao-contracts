# 📋 RDAT V2 VRC-Compliant Specifications

**Version**: 3.0 (Full VRC Compliance Update)  
**Date**: August 5, 2025  
**Status**: Updated for VRC-14, VRC-15, and VRC-20 Full Compliance  
**Architecture**: 14 Core Contracts (expanded from 11)

## 🎯 Overview

This specification extends our modular rewards architecture to achieve full compliance with Vana's VRC standards while maintaining our core design principles. The update adds 3 new contracts and enhances existing ones to meet all Data Autonomy Token requirements.

## 📊 Updated Contract Architecture (14 Total)

### Core Contracts (Original 11)
1. **RDATUpgradeable** ✅ - Enhanced with full VRC-20 compliance
2. **vRDAT** ✅ - Soul-bound governance token
3. **StakingManager** ✅ - Immutable staking logic
4. **RewardsManager** 🔴 - Upgradeable orchestrator
5. **vRDATRewardModule** ✅ - Proportional governance rewards
6. **RDATRewardModule** 🔴 - Time-based staking rewards
7. **MigrationBridge** 🔴 - Cross-chain migration
8. **EmergencyPause** ✅ - Shared emergency system
9. **RevenueCollector** 🔴 - Fee distribution (50/30/20)
10. **ProofOfContribution** 🔴 - Full implementation (was stub)
11. **Create2Factory** ✅ - Deterministic deployment

### New VRC Compliance Contracts (+3)
12. **VRC14LiquidityModule** 🆕 - VANA liquidity incentives
13. **DataPoolManager** 🆕 - VRC-20 data pool management
14. **RDATVesting** 🆕 - Team token vesting enforcement

**Status**: 7/14 complete (50%)

## 🔧 Enhanced VRC-20 Compliance

### Updated IVRC20 Interface
```solidity
interface IVRC20Full is IERC20 {
    // Basic VRC-20 identification
    function isVRC20() external view returns (bool);
    function vrcVersion() external view returns (string memory);
    
    // DLP integration
    function pocContract() external view returns (address);
    function dataRefiner() external view returns (address);
    function dlpAddress() external view returns (address);
    function dlpRegistered() external view returns (bool);
    
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
    
    // Events
    event DataPoolCreated(bytes32 indexed poolId, address indexed creator);
    event DataAdded(bytes32 indexed poolId, bytes32 indexed dataHash, address indexed contributor);
    event DLPRegistered(address indexed dlpAddress, uint256 timestamp);
}
```

### RDATUpgradeable Enhancement
```solidity
contract RDATUpgradeable is 
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable,
    ERC20PermitUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    IVRC20Full,  // Full VRC-20 compliance
    IRDAT
{
    // VRC-20 state variables
    bool public constant isVRC20 = true;
    string public constant vrcVersion = "VRC-20-1.0";
    address public pocContract;
    address public dataRefiner;
    address public dlpAddress;
    bool public dlpRegistered;
    uint256 public dlpRegistrationBlock;
    
    // Data pool management
    mapping(bytes32 => DataPool) public dataPools;
    mapping(bytes32 => mapping(address => bool)) public dataOwnership;
    mapping(uint256 => uint256) public epochRewardTotals;
    mapping(uint256 => mapping(address => uint256)) public epochRewardsClaimed;
    
    struct DataPool {
        address creator;
        string metadata;
        uint256 contributorCount;
        uint256 totalDataPoints;
        mapping(address => bool) contributors;
        mapping(bytes32 => DataPoint) data;
    }
    
    struct DataPoint {
        address contributor;
        uint256 timestamp;
        uint256 quality;
        bool verified;
    }
}
```

## 📦 New Contract Specifications

### 12. VRC14LiquidityModule

**Purpose**: Implements VRC-14 liquidity-based DLP incentives

**Key Features**:
- Converts VANA rewards into 90 daily tranches
- Automatically purchases RDAT tokens
- Adds liquidity to RDAT-VANA pools
- Distributes LP tokens to stakers

```solidity
contract VRC14LiquidityModule is IRewardModule, AccessControl {
    using SafeERC20 for IERC20;
    
    // Constants
    uint256 public constant TRANCHES = 90;
    uint256 public constant TRANCHE_DURATION = 1 days;
    
    // State
    IERC20 public immutable vanaToken;
    IERC20 public immutable rdatToken;
    IUniswapV3Router public immutable router;
    IUniswapV3Pool public immutable rdatVanaPool;
    
    uint256 public totalVANAAllocation;
    uint256 public dailyVANAAmount;
    uint256 public currentTranche;
    uint256 public lastExecutionTime;
    
    mapping(address => uint256) public stakerLPBalances;
    mapping(uint256 => uint256) public trancheLPTokens;
    
    // Functions
    function initializeProgram(uint256 vanaAmount) external onlyRole(ADMIN_ROLE) {
        totalVANAAllocation = vanaAmount;
        dailyVANAAmount = vanaAmount / TRANCHES;
        lastExecutionTime = block.timestamp;
    }
    
    function executeDailyTranche() external {
        require(block.timestamp >= lastExecutionTime + TRANCHE_DURATION, "Too early");
        require(currentTranche < TRANCHES, "Program complete");
        
        // 1. Calculate VANA amount for this tranche
        uint256 vanaAmount = dailyVANAAmount;
        
        // 2. Swap half VANA for RDAT (random execution time)
        uint256 halfVana = vanaAmount / 2;
        uint256 rdatReceived = _swapVANAForRDAT(halfVana);
        
        // 3. Add liquidity to RDAT-VANA pool
        uint256 lpTokensReceived = _addLiquidity(rdatReceived, halfVana);
        
        // 4. Record LP tokens for this tranche
        trancheLPTokens[currentTranche] = lpTokensReceived;
        
        // 5. Update state
        currentTranche++;
        lastExecutionTime = block.timestamp;
        
        emit TrancheExecuted(currentTranche, lpTokensReceived);
    }
    
    function claimLPRewards(address user, uint256 stakeId) external returns (uint256) {
        // Calculate user's share of LP tokens based on stake
        uint256 userShare = _calculateUserShare(user, stakeId);
        stakerLPBalances[user] += userShare;
        return userShare;
    }
}
```

### 13. DataPoolManager

**Purpose**: Manages data pools for VRC-20 compliance

**Key Features**:
- Creates and manages data pools
- Tracks data ownership cryptographically
- Integrates with ProofOfContribution
- Manages data quality scores

```solidity
contract DataPoolManager is IDataPoolManager, AccessControl {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    
    // State
    mapping(bytes32 => DataPool) public pools;
    mapping(address => EnumerableSet.Bytes32Set) private userDataHashes;
    mapping(bytes32 => DataRecord) public dataRecords;
    
    struct DataPool {
        string name;
        string metadata;
        address creator;
        uint256 createdAt;
        uint256 totalData;
        uint256 totalQuality;
        bool active;
    }
    
    struct DataRecord {
        bytes32 poolId;
        address contributor;
        uint256 timestamp;
        uint256 quality;
        bytes32 proofHash;
        bool verified;
    }
    
    // Functions
    function createPool(
        bytes32 poolId,
        string memory name,
        string memory metadata
    ) external returns (bool) {
        require(pools[poolId].createdAt == 0, "Pool exists");
        
        pools[poolId] = DataPool({
            name: name,
            metadata: metadata,
            creator: msg.sender,
            createdAt: block.timestamp,
            totalData: 0,
            totalQuality: 0,
            active: true
        });
        
        emit PoolCreated(poolId, msg.sender, name);
        return true;
    }
    
    function submitData(
        bytes32 poolId,
        bytes32 dataHash,
        bytes32 proofHash,
        uint256 quality
    ) external returns (bool) {
        require(pools[poolId].active, "Pool inactive");
        require(dataRecords[dataHash].timestamp == 0, "Data exists");
        
        dataRecords[dataHash] = DataRecord({
            poolId: poolId,
            contributor: msg.sender,
            timestamp: block.timestamp,
            quality: quality,
            proofHash: proofHash,
            verified: false
        });
        
        userDataHashes[msg.sender].add(dataHash);
        pools[poolId].totalData++;
        
        // Notify ProofOfContribution
        IProofOfContribution(pocContract).recordContribution(
            msg.sender,
            quality,
            dataHash
        );
        
        emit DataSubmitted(poolId, dataHash, msg.sender, quality);
        return true;
    }
    
    function verifyDataOwnership(
        bytes32 dataHash,
        address owner,
        bytes32 proof
    ) external view returns (bool) {
        DataRecord memory record = dataRecords[dataHash];
        if (record.contributor != owner) return false;
        
        // Verify cryptographic proof
        bytes32 expectedProof = keccak256(abi.encodePacked(dataHash, owner));
        return record.proofHash == expectedProof;
    }
}
```

### 14. RDATVesting

**Purpose**: Enforces team token vesting for VRC-20 compliance

**Key Features**:
- 6-month cliff period (mandatory)
- Linear vesting after cliff
- Non-revocable vesting
- Public transparency

```solidity
contract RDATVesting is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    IERC20 public immutable rdatToken;
    
    struct VestingSchedule {
        uint256 totalAmount;
        uint256 startTime;
        uint256 cliffDuration;
        uint256 vestingDuration;
        uint256 releasedAmount;
        bool revocable;
        bool revoked;
    }
    
    mapping(address => VestingSchedule) public vestingSchedules;
    uint256 public totalVestingAmount;
    
    // Events
    event VestingScheduleCreated(address indexed beneficiary, uint256 amount);
    event TokensReleased(address indexed beneficiary, uint256 amount);
    
    constructor(address _rdatToken) {
        rdatToken = IERC20(_rdatToken);
    }
    
    function createVestingSchedule(
        address beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration,
        bool revocable
    ) external onlyRole(ADMIN_ROLE) {
        require(vestingSchedules[beneficiary].totalAmount == 0, "Schedule exists");
        require(cliffDuration >= 180 days, "Cliff must be >= 6 months"); // VRC-20 requirement
        require(vestingDuration >= cliffDuration, "Invalid duration");
        
        vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: amount,
            startTime: startTime,
            cliffDuration: cliffDuration,
            vestingDuration: vestingDuration,
            releasedAmount: 0,
            revocable: revocable,
            revoked: false
        });
        
        totalVestingAmount += amount;
        rdatToken.safeTransferFrom(msg.sender, address(this), amount);
        
        emit VestingScheduleCreated(beneficiary, amount);
    }
    
    function release(address beneficiary) external nonReentrant {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(schedule.totalAmount > 0, "No schedule");
        require(!schedule.revoked, "Revoked");
        
        uint256 releasable = _computeReleasableAmount(schedule);
        require(releasable > 0, "Nothing to release");
        
        schedule.releasedAmount += releasable;
        rdatToken.safeTransfer(beneficiary, releasable);
        
        emit TokensReleased(beneficiary, releasable);
    }
    
    function _computeReleasableAmount(VestingSchedule memory schedule) 
        private 
        view 
        returns (uint256) 
    {
        if (block.timestamp < schedule.startTime + schedule.cliffDuration) {
            return 0; // Still in cliff period
        }
        
        if (block.timestamp >= schedule.startTime + schedule.vestingDuration) {
            return schedule.totalAmount - schedule.releasedAmount; // Fully vested
        }
        
        // Linear vesting after cliff
        uint256 timeFromStart = block.timestamp - schedule.startTime;
        uint256 vestedAmount = (schedule.totalAmount * timeFromStart) / schedule.vestingDuration;
        return vestedAmount - schedule.releasedAmount;
    }
}
```

## 📊 Enhanced ProofOfContribution Implementation

```solidity
contract ProofOfContribution is IProofOfContribution, AccessControl, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.AddressSet;
    
    // Roles
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");
    
    // State
    mapping(address => Contribution[]) public contributions;
    mapping(address => uint256) public contributionCount;
    mapping(address => uint256) public totalScore;
    mapping(address => uint256) public pendingRewards;
    mapping(address => bool) public registeredContributors;
    
    EnumerableSet.AddressSet private validators;
    address public dlpAddress;
    bool public isActive;
    
    // Epoch tracking for VRC-15
    uint256 public currentEpoch;
    uint256 public epochDuration = 1 days;
    mapping(uint256 => uint256) public epochTotalScore;
    mapping(uint256 => mapping(address => uint256)) public epochScores;
    
    // Events
    event ContributionRecorded(address indexed contributor, uint256 score, bytes32 dataHash);
    event EpochAdvanced(uint256 indexed epoch, uint256 totalScore);
    event RewardsDistributed(address indexed contributor, uint256 amount);
    
    function recordContribution(
        address contributor,
        uint256 score,
        bytes32 dataHash
    ) external onlyRole(VALIDATOR_ROLE) {
        require(registeredContributors[contributor], "Not registered");
        require(score <= 100, "Invalid score");
        
        contributions[contributor].push(Contribution({
            timestamp: block.timestamp,
            score: score,
            dataHash: dataHash,
            validated: true
        }));
        
        contributionCount[contributor]++;
        totalScore[contributor] += score;
        epochScores[currentEpoch][contributor] += score;
        epochTotalScore[currentEpoch] += score;
        
        emit ContributionRecorded(contributor, score, dataHash);
    }
    
    function advanceEpoch() external {
        require(block.timestamp >= (currentEpoch + 1) * epochDuration, "Too early");
        
        // Calculate and distribute epoch rewards
        uint256 epochRewardPool = _calculateEpochRewards();
        _distributeEpochRewards(epochRewardPool);
        
        currentEpoch++;
        emit EpochAdvanced(currentEpoch, epochTotalScore[currentEpoch - 1]);
    }
    
    function _distributeEpochRewards(uint256 rewardPool) private {
        uint256 totalEpochScore = epochTotalScore[currentEpoch];
        if (totalEpochScore == 0) return;
        
        // Distribute proportionally based on epoch scores
        for (uint256 i = 0; i < registeredContributors.length(); i++) {
            address contributor = registeredContributors.at(i);
            uint256 contributorScore = epochScores[currentEpoch][contributor];
            
            if (contributorScore > 0) {
                uint256 reward = (rewardPool * contributorScore) / totalEpochScore;
                pendingRewards[contributor] += reward;
            }
        }
    }
    
    function claimRewards(address contributor) external nonReentrant returns (uint256) {
        uint256 rewards = pendingRewards[contributor];
        require(rewards > 0, "No rewards");
        
        pendingRewards[contributor] = 0;
        
        // Transfer through RevenueCollector
        IRevenueCollector(revenueCollector).distributeContributorRewards(
            contributor,
            rewards
        );
        
        emit RewardsDistributed(contributor, rewards);
        return rewards;
    }
}
```

## 🔄 Integration Updates

### RewardsManager Enhancement
```solidity
// Add VRC-14 module registration
function registerVRC14Module(address module) external onlyRole(ADMIN_ROLE) {
    require(IRewardModule(module).rewardToken() == address(vanaToken), "Must reward VANA");
    _registerModule(module, "VRC14_LIQUIDITY");
}
```

### RevenueCollector Enhancement
```solidity
// Add contributor reward distribution
function distributeContributorRewards(address contributor, uint256 amount) 
    external 
    onlyRole(POC_ROLE) 
{
    require(rdatToken.transfer(contributor, amount), "Transfer failed");
    emit ContributorRewardDistributed(contributor, amount);
}
```

## 📊 Updated Token Distribution

| Allocation | Amount | Purpose | VRC Compliance |
|------------|--------|---------|----------------|
| Migration | 30M (30%) | V1 holders | N/A |
| Staking Rewards | 15M (15%) | 2-year program | Reduced for VRC-14 |
| VRC-14 Liquidity | 5M (5%) | VANA liquidity incentives | NEW |
| Ecosystem Fund | 10M (10%) | Partnerships | No change |
| Treasury | 15M (15%) | Operations | Reduced for vesting |
| Team Vesting | 10M (10%) | Team tokens (6mo cliff) | VRC-20 required |
| Liquidity | 15M (15%) | DEX provision | No change |

## 🚀 Implementation Timeline

### Week 1: Core VRC Compliance
1. Update RDATUpgradeable with full IVRC20Full interface
2. Implement ProofOfContribution contract
3. Deploy RDATVesting with team allocations
4. Implement DataPoolManager

### Week 2: Liquidity & Integration
1. Implement VRC14LiquidityModule
2. Integrate with Uniswap V3
3. Test daily tranche execution
4. Register with RewardsManager

### Week 3: Testing & Deployment
1. Full integration testing
2. VRC compliance audit
3. DLP registration
4. Mainnet deployment

## ✅ Compliance Checklist

### Before DLP Registration:
- [ ] Deploy all 14 contracts
- [ ] Create team vesting schedules (6-month cliff)
- [ ] Implement full VRC-20 interface
- [ ] Deploy VRC-14 liquidity module
- [ ] Complete ProofOfContribution implementation
- [ ] Register data pools
- [ ] Pass Vana compliance audit

### Ongoing Requirements:
- [ ] Execute daily VANA liquidity tranches
- [ ] Process epoch rewards
- [ ] Maintain data quality standards
- [ ] Publish transparency reports

## 🔒 Security Considerations

1. **Liquidity Module Security**
   - Use Chainlink VRF for random execution times
   - Implement slippage protection
   - Multi-sig control for parameters

2. **Data Pool Security**
   - Cryptographic proof verification
   - Duplicate data prevention
   - Quality score validation

3. **Vesting Security**
   - Non-revocable by default
   - Cliff period enforcement
   - Public transparency

## 📝 Summary

This specification extends our modular architecture from 11 to 14 contracts to achieve full VRC compliance:
- **VRC-20**: Full Data Autonomy Token implementation
- **VRC-14**: Automated liquidity incentives
- **VRC-15**: Complete data verification system

The modular design allows these additions without disrupting existing functionality, maintaining our core principles of security, flexibility, and gas efficiency.