# 📋 RDAT Token Smart Contract Specifications

## 🎯 Overview

The RDAT Token is a unified, upgradeable ERC-20 token with built-in VRC (Vana Request for Comments) compliance, designed for deployment on both Vana and Base blockchains. The implementation prioritizes security, gas efficiency, and future extensibility.

**DAO Vote Reference**: [Snapshot Proposal 0xa0c701b7...](https://snapshot.box/#/s:rdatadao.eth/proposal/0xa0c701b7f26855b3861e150fb31d637f70ae6f50cb4e1c92e2b5675a048a54bb)
- **Approved**: New tokenomics with 100M total supply
- **Migration**: 1:1 swap for existing 30M RDAT holders
- **Fixed Supply**: No additional minting after initial distribution

### 📍 Migration from Base Mainnet RDAT

**Existing Base Contract**: `0x4498cd8ba045e00673402353f5a4347562707e7d`  
**Network**: Base Mainnet (Chain ID: 8453)  
**Supply**: 30,000,000 RDAT tokens  
**Block Explorer**: https://basescan.org/token/0x4498cd8ba045e00673402353f5a4347562707e7d#code

**Migration Purpose**: Base blockchain integration is **solely for token holder migration** from the existing 30M RDAT on Base to the new 100M RDAT ecosystem on Vana. Base will not host ongoing RDAT ecosystem operations.

**Base Integration Requirements**:
1. **Migration Contract**: Deploy migration contract on Base for 1:1 token swap
2. **Mock RDAT**: Create local/testnet versions for migration testing
3. **Migration Verification**: Ensure seamless transition for existing holders
4. **Post-Migration**: Base contracts become legacy after migration period

## 📦 Smart Contracts Required

### 1. Core Token Contract: `Rdat.sol`

**Inheritance Structure:**
```solidity
contract Rdat is 
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    VRCRegistry,
    IVRC20,
    IVRC15
```

**Key Features:**
- **Token Parameters:**
  - Name: "r/datadao"
  - Symbol: "RDAT"
  - Total Supply: 100,000,000 (100 million) tokens
  - Decimals: 18
  - **Primary Blockchain: Vana** (Main deployment and ecosystem)
  - *Existing Base RDAT: 30,000,000 (30 million) tokens - Migration only*

- **Core Functionality:**
  - ERC-20 standard compliance
  - Burnable tokens
  - Pausable transfers (emergency mechanism)
  - UUPS upgradeable pattern
  - Meta-transaction support (EIP-2771)

- **VRC-20 Compliance:**
  - Fixed supply (no minting after initialization)
  - Transfer fees: 0-3% (configurable, max 300 basis points)
  - Team vesting: Minimum 6-month cliff (REQUIRED for DLP rewards)
  - Blocklist capability for regulatory compliance
  - No rebasing functionality
  - Public disclosure of team allocations and locking mechanism

- **VRC-15 Compliance:**
  - Data utility hooks
  - Integration with DataDAO ecosystem

### 2. VRC Registry: `VRCRegistry.sol`

**Abstract Contract Features:**
- Multi-VRC standard registration
- Version tracking for each VRC standard
- Off-chain verification queries
- Future VRC support mechanism

**Required Functions:**
```solidity
function registerVRCCompliance(string memory vrcStandard, uint256 version) internal
function isVRCCompliant(string memory vrcStandard) external view returns (bool)
function getVRCVersion(string memory vrcStandard) external view returns (uint256)
```

### 3. Data Contributor Rewards: `DataContributorRewards.sol`

**Key Features:**
- Merkle-based distribution for gas efficiency
- Multiple reward rounds support
- Contribution-based scoring system
- Budget tracking (30M RDAT total)
- Unclaimed token recovery
- Integration with Phase 3 vesting unlock

**Required Functions:**
```solidity
function createRewardRound(
    bytes32 merkleRoot,
    uint256 totalRewards,
    uint256 duration
) external onlyRole(DISTRIBUTOR_ROLE)

function claimRewards(
    uint256 roundId,
    uint256 amount,
    bytes32[] calldata merkleProof
) external

function finalizeRound(uint256 roundId) external
```

**Distribution Strategy:**
- Initial rounds: 5-8M RDAT per round
- Claim windows: 30-90 days
- Quality-based scoring tiers
- Early contributor bonuses

### 4. Vesting Contract: `RDATVesting.sol`

**Key Features:**
- Multi-beneficiary vesting schedules
- Cliff period support (6 months for treasury)
- Linear vesting after cliff
- Phase-based unlock triggers
- Emergency pause mechanism
- Vesting schedule modification (admin only)

**Required Functions:**
```solidity
function createVestingSchedule(
    address beneficiary,
    uint256 totalAmount,
    uint256 startTime,
    uint256 cliffDuration,
    uint256 vestingDuration,
    bool revocable
) external onlyRole(VESTING_ADMIN_ROLE)

function release(address beneficiary) external
function releasable(address beneficiary) external view returns (uint256)
function triggerPhase3Unlock() external onlyRole(VESTING_ADMIN_ROLE)
```

**Vesting Schedules:**
```solidity
// Treasury vesting
createVestingSchedule(
    treasuryAddress,
    25_000_000e18,
    TGE,
    6 months,
    18 months,
    false
);

// Future rewards (locked until Phase 3)
createVestingSchedule(
    rewardsPool,
    30_000_000e18,
    type(uint256).max, // Start time set when Phase 3 triggers
    0,
    0,
    false
);
```

### 4. Factory Contract: `RDATFactory.sol`

**Key Features:**
- CREATE2 deterministic deployment
- Automated proxy + implementation deployment
- Timelock controller integration (48-hour delay)
- Multi-network deployment support
- Deployment tracking and verification

**Required Functions:**
```solidity
function deployRDAT(
    address timelockController,
    address[] memory vestingRecipients,
    uint256[] memory vestingAmounts,
    uint256[] memory vestingSchedules
) external returns (address proxy, address implementation)

function getDeploymentAddress(bytes32 salt) external view returns (address)
```

### 4. Token Allocation (Per DAO Vote)

**Total Supply: 100,000,000 RDAT**

| Allocation | Percentage | Amount | Vesting Schedule |
|------------|------------|--------|------------------|
| Migration Reserve | 30% | 30,000,000 | 100% unlocked at TGE |
| Future Rewards | 30% | 30,000,000 | 0% at TGE, unlocks when Phase 3 initiates |
| Treasury & Ecosystem | 25% | 25,000,000 | 10% at TGE, 6-month cliff, then 5% monthly |
| Liquidity & Staking | 15% | 15,000,000 | 33% at TGE for liquidity, remainder for staking |

**Vesting Implementation Requirements:**
- Migration Reserve: Immediately available for 1:1 token swap
- Future Rewards: Locked until Phase 3 data aggregation begins
- Treasury: 2.5M at TGE, 6-month cliff, then 1.25M monthly for 18 months
- Liquidity: 5M at TGE for DEX liquidity, 10M for staking rewards

**Data Contributor Rewards:**
- Source: Future Rewards allocation (30M RDAT)
- Distribution: Based on quality and quantity of data contributions
- Unlock: Triggered when Phase 3 data aggregation begins
- Management: Through DataDAO governance and contribution scoring
- Initial Phase 3 Budget: Recommended 5-10M RDAT for first contributor cohort

**VRC-20 Team Allocation Compliance:**
- Team/founder/early contributor tokens MUST be allocated from the Treasury & Ecosystem bucket
- Minimum 6-month lockup period starting from DLP reward eligibility date
- Linear vesting after the 6-month cliff
- All team allocations must be locked in verified smart contracts (VestingWallet)
- Public disclosure required for all team allocations including amounts and vesting schedules
- Non-compliance will result in loss of DLP rewards eligibility

### 5. Access Control Roles

**Role Definitions:**
```solidity
bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
bytes32 public constant FEE_SETTER_ROLE = keccak256("FEE_SETTER_ROLE");
bytes32 public constant VESTING_ADMIN_ROLE = keccak256("VESTING_ADMIN_ROLE");
bytes32 public constant BLOCKLIST_ADMIN_ROLE = keccak256("BLOCKLIST_ADMIN_ROLE");
```

## 🧪 Testing Requirements

### 1. Unit Tests

**Token Core Functionality (`test/unit/Rdat.t.sol`):**
- Token initialization with correct parameters
- Transfer functionality
- Approval and transferFrom
- Burn functionality
- Pause/unpause mechanisms
- Access control for all restricted functions

**VRC-20 Compliance (`test/unit/VRC20Compliance.t.sol`):**
- Fixed supply enforcement
- Transfer fee calculations (0%, 1%, 3% scenarios)
- Fee recipient updates
- Blocklist functionality
- Anti-rebasing verification

**Vesting Tests (`test/unit/Vesting.t.sol`):**
- Treasury vesting: 6-month cliff, then 5% monthly releases
- Future rewards: Complete lock until Phase 3 trigger
- Migration reserve: Immediate availability (no vesting)
- Liquidity allocation: 33% immediate, 67% for staking
- Multiple beneficiary support
- Vesting admin controls
- Phase 3 trigger mechanism for rewards unlock

**Data Contributor Rewards Tests (`test/unit/DataContributorRewards.t.sol`):**
- Merkle proof verification for claims
- Reward round creation and budget tracking
- Multiple round support with different parameters
- Claim period enforcement
- Duplicate claim prevention
- Unclaimed token recovery
- Total budget enforcement (30M cap)
- Integration with vesting contract

**Upgrade Tests (`test/unit/Upgrades.t.sol`):**
- UUPS upgrade authorization
- Storage layout preservation
- Upgrade rollback scenarios
- Access control on upgrades

### 2. Integration Tests

**Factory Deployment (`test/integration/FactoryDeployment.t.sol`):**
- Full deployment flow with factory
- Timelock integration
- Multi-recipient vesting setup
- Cross-chain deployment simulation
- Deterministic address verification

**Governance Integration (`test/integration/Governance.t.sol`):**
- Timelock proposal creation
- 48-hour delay enforcement
- Multi-sig execution
- Emergency cancellation
- Role-based execution

### 3. Security Tests

**Edge Cases (`test/security/EdgeCases.t.sol`):**
- Reentrancy protection
- Integer overflow/underflow
- Zero address checks
- Empty array handling
- Maximum value transfers

**Access Control (`test/security/AccessControl.t.sol`):**
- Unauthorized function calls
- Role hierarchy testing
- Admin function restrictions
- Cross-role interference

**Gas Optimization (`test/security/GasOptimization.t.sol`):**
- Deployment gas costs
- Transfer gas costs
- Batch operation efficiency
- Storage optimization verification

### 4. Fuzzing Tests

**Foundry Invariant Tests (`test/invariant/`):**
- Total supply consistency
- Fee calculation boundaries
- Vesting schedule integrity
- Role assignment consistency

**Property-Based Tests:**
- Transfer fee never exceeds 3%
- Vesting always respects cliff
- Total vested amount never exceeds allocation
- Blocklist always prevents transfers

## 🔧 Mock Token Contracts

### MockRDAT Token (`src/mocks/MockRDAT.sol`)

**Purpose**: Exact replica of the existing RDAT token from Base mainnet for testing
- Exact same implementation as Base mainnet RDAT (0x4498cd8ba045e00673402353f5a4347562707e7d)
- Fixed supply of 30 million tokens (matching existing Base RDAT)
- Full feature parity including:
  - ERC20 + ERC20Permit + ERC20Votes
  - Ownable2Step for secure ownership transfer
  - Admin role for blocklist management
  - Address blocklist functionality
  - Mint blocking capability (one-way switch)
  - Timestamp-based governance support

**Deployment Script**: `script/mocks/DeployMockRDAT.s.sol`
```bash
# Deploy to local Base chain
forge script script/mocks/DeployMockRDAT.s.sol:DeployMockRDAT --rpc-url http://localhost:8545 --broadcast

# Deploy to Base Sepolia
forge script script/mocks/DeployMockRDAT.s.sol:DeployMockRDAT --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast
```

## 🚀 Deployment Scripts

### 1. Local Development (`script/local/`)

**`DeployLocal.s.sol`:**
- Deploy to local Anvil instances
- Use test mnemonics
- Skip timelock for faster testing
- Pre-fund test accounts

### 2. Testnet Deployment (`script/testnet/`)

**`DeployVanaMoksha.s.sol`:**
- Deploy to Vana Moksha testnet (Chain ID: 14800)
- Include timelock with reduced delay (1 hour)
- Deploy with test vesting schedules
- Verify on block explorer

**`DeployBaseSepolia.s.sol`:**
- Deploy to Base Sepolia (Chain ID: 84532)
- Same configuration as Vana Moksha
- Cross-chain address consistency check

### 3. Mainnet Deployment (`script/mainnet/`)

**`DeployVanaMainnet.s.sol`:**
- Deploy to Vana mainnet (Chain ID: 1480)
- Production timelock (48 hours)
- Real vesting schedules
- Multi-sig wallet integration

**`DeployBaseMainnet.s.sol`:**
- Deploy to Base mainnet (Chain ID: 8453)
- Identical configuration to Vana
- Cross-chain verification

### 4. Deployment Utilities (`script/utils/`)

**`VerifyDeployment.s.sol`:**
- Verify contract on block explorers
- Check all role assignments
- Validate vesting schedules
- Confirm timelock configuration

**`PostDeploymentSetup.s.sol`:**
- Register with DataDAO
- Set initial fee parameters
- Configure blocklist oracle
- Transfer admin roles to multi-sig

## 🛡️ Audit Strategy

### 1. Pre-Audit Preparation

**Static Analysis:**
- Run Slither with zero high/critical issues
- Mythril vulnerability scanning
- Solhint linting compliance
- Custom error implementation verification

**Documentation:**
- Complete NatSpec comments
- Architecture diagrams
- Known issues documentation
- Gas optimization report

### 2. OpenZeppelin Integration

**Leverage Audited Contracts:**
```solidity
// Use OpenZeppelin's audited implementations
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
```

**Custom Extensions:**
- Minimize custom code
- Inherit security properties
- Focus audit on VRC compliance layer
- Use OpenZeppelin's upgrade plugins

### 3. Testing Coverage Requirements

**Minimum Coverage Targets:**
- Line Coverage: 100%
- Branch Coverage: 100%
- Function Coverage: 100%
- Statement Coverage: 100%

**Critical Path Testing:**
- Every external/public function
- All state transitions
- Emergency scenarios
- Upgrade paths

### 4. Audit Focus Areas

**High Priority:**
1. VRC compliance implementation
2. Vesting logic and cliff enforcement
3. Fee calculation and distribution
4. Upgrade authorization
5. Access control integration

**Medium Priority:**
1. Gas optimization effectiveness
2. Event emission completeness
3. Error message clarity
4. Storage layout efficiency

**Low Priority:**
1. Code style consistency
2. Documentation completeness
3. Test coverage redundancy

## 📊 Success Metrics

### Technical Metrics
- Compilation time: < 0.5 seconds
- Contract size: < 24KB
- Deployment gas: < 5M gas
- Transfer gas: < 65K gas
- Test execution: < 30 seconds

### Security Metrics
- Zero high/critical vulnerabilities
- 100% test coverage
- All fuzzing invariants hold
- Clean audit report

### Business Metrics
- Multi-chain deployment capability
- Regulatory compliance ready
- DataDAO integration complete
- User-friendly fee structure
- Future VRC adaptability

## 🔄 Implementation Timeline

**Phase 1: Core Development (Weeks 1-2)**
- Implement core token contracts
- Set up basic test framework
- Local deployment scripts

**Phase 2: Compliance & Testing (Weeks 3-4)**
- VRC compliance implementation
- Comprehensive test suite
- Security testing framework

**Phase 3: Audit Preparation (Week 5)**
- Static analysis cleanup
- Documentation completion
- Testnet deployments

**Phase 4: Audit & Remediation (Weeks 6-7)**
- Professional audit
- Issue remediation
- Final testing

**Phase 5: Mainnet Deployment (Week 8)**
- Multi-sig setup
- Mainnet deployment
- Post-deployment verification

---

## 🌉 Migration System Specifications

### Overview

The migration system facilitates the **one-time transition** of existing 30M RDAT holders from Base to the new 100M RDAT ecosystem on **Vana blockchain**. This is the **sole purpose** of Base blockchain integration - Vana will host all ongoing RDAT ecosystem operations including staking, governance, and data contributions.

**Migration Goals:**
- Seamless 1:1 token swap for existing Base RDAT holders
- Transition to Vana-native RDAT ecosystem  
- Base contracts become legacy post-migration
- All future development occurs on Vana blockchain

## 📦 Migration Smart Contracts

### 1. Base Chain Contract: `RdatMigration.sol`

**Inheritance Structure:**
```solidity
contract RdatMigration is 
    Pausable,
    AccessControl,
    ReentrancyGuard
```

**Key Features:**
- **Deposit Management:**
  - Accept RDAT token deposits from users
  - Configurable minimum/maximum deposit limits
  - Per-user deposit tracking and limits
  - Batch deposit aggregation for efficiency

- **Whale Whitelist:**
  - Special handling for large token holders
  - Bypass standard deposit limits for whitelisted addresses
  - Admin-controlled whitelist management
  - Event emission for whitelist changes

- **Security Features:**
  - Pausable operations for emergency situations
  - Reentrancy protection on all state-changing functions
  - Comprehensive input validation
  - Event logging for all critical operations

**Required Functions:**
```solidity
function deposit(uint256 amount) external whenNotPaused nonReentrant
function setDepositLimits(uint256 min, uint256 max) external onlyRole(ADMIN_ROLE)
function addWhaleToWhitelist(address whale) external onlyRole(ADMIN_ROLE)
function removeWhaleFromWhitelist(address whale) external onlyRole(ADMIN_ROLE)
function pause() external onlyRole(PAUSER_ROLE)
function unpause() external onlyRole(ADMIN_ROLE)
```

### 2. Vana Chain Contract: `RdatDistributor.sol`

**Inheritance Structure:**
```solidity
contract RdatDistributor is 
    Pausable,
    AccessControl,
    ReentrancyGuard,
    MerkleProof
```

**Key Features:**
- **Merkle Distribution:**
  - Gas-efficient Merkle proof verification
  - Batch claim processing with single Merkle root
  - Double-spend prevention with claim tracking
  - Support for multiple distribution batches

- **Gnosis Safe Integration:**
  - Multi-signature control for batch activation
  - Timelock for batch finalization
  - Emergency batch cancellation
  - Role-based batch management

- **Claim Management:**
  - Individual claim tracking
  - Partial claim support
  - Claim expiration mechanism
  - Emergency withdrawal for unclaimed tokens

**Required Functions:**
```solidity
function submitBatch(bytes32 merkleRoot, uint256 totalAmount) external onlyRole(BATCH_SUBMITTER_ROLE)
function activateBatch(uint256 batchId) external onlyRole(BATCH_ACTIVATOR_ROLE)
function claim(uint256 batchId, uint256 amount, bytes32[] calldata proof) external whenNotPaused nonReentrant
function emergencyWithdraw(address token, uint256 amount) external onlyRole(ADMIN_ROLE)
function cancelBatch(uint256 batchId) external onlyRole(ADMIN_ROLE)
```

### 3. Migration Orchestrator: `MigrationOrchestrator.sol`

**Off-chain Service Components:**
- **Event Monitoring:** Watch for deposit events on Base
- **Batch Creation:** Aggregate deposits into optimized batches
- **Merkle Tree Generation:** Create Merkle trees for distribution
- **Cross-chain Coordination:** Manage state between chains
- **Status Tracking:** Provide real-time migration status

### 4. Access Control Roles

**Role Definitions:**
```solidity
// RdatMigration roles
bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
bytes32 public constant WHALE_MANAGER_ROLE = keccak256("WHALE_MANAGER_ROLE");

// RdatDistributor roles
bytes32 public constant BATCH_SUBMITTER_ROLE = keccak256("BATCH_SUBMITTER_ROLE");
bytes32 public constant BATCH_ACTIVATOR_ROLE = keccak256("BATCH_ACTIVATOR_ROLE");
bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
```

## 🧪 Migration Testing Requirements

### 1. Unit Tests

**Migration Contract Tests (`test/unit/RdatMigration.t.sol`):**
- Deposit functionality with various amounts
- Deposit limit enforcement
- Whale whitelist functionality
- Pause/unpause mechanisms
- Access control restrictions
- Event emission verification

**Distributor Contract Tests (`test/unit/RdatDistributor.t.sol`):**
- Merkle proof verification
- Batch submission and activation
- Claim processing and tracking
- Double-claim prevention
- Emergency functions
- Gnosis Safe integration

**Edge Cases (`test/unit/MigrationEdgeCases.t.sol`):**
- Zero amount deposits
- Maximum uint256 handling
- Empty Merkle proofs
- Batch overflow scenarios
- Gas limit testing

### 2. Integration Tests

**End-to-End Migration (`test/integration/MigrationFlow.t.sol`):**
- Complete migration flow from deposit to claim
- Multi-user batch processing
- Cross-chain state synchronization
- Error recovery scenarios
- Performance under load

**Orchestrator Integration (`test/integration/Orchestrator.t.sol`):**
- Event detection and processing
- Batch optimization logic
- Merkle tree generation
- Status update accuracy
- Failure handling

### 3. Security Tests

**Security Scenarios (`test/security/MigrationSecurity.t.sol`):**
- Reentrancy attack prevention
- Front-running protection
- Merkle proof manipulation attempts
- Access control bypass attempts
- DoS attack resilience

**Gas Optimization (`test/security/MigrationGas.t.sol`):**
- Batch size optimization
- Merkle proof gas costs
- Claim gas efficiency
- Storage optimization

### 4. Fuzzing Tests

**Invariant Tests (`test/invariant/MigrationInvariants.sol`):**
- Total deposited equals total claimable
- No tokens can be created or destroyed
- Claimed amount never exceeds deposited
- Batch totals match individual claims

## 🚀 Migration Deployment Scripts

### 1. Local Development (`script/migration/local/`)

**`DeployMigrationLocal.s.sol`:**
- Deploy MockRDAT first (replicating Base mainnet RDAT)
- Deploy both migration contracts
- Set up test whale whitelist
- Configure minimal delays
- Pre-fund test accounts with MockRDAT tokens

**Testing Flow:**
1. Deploy MockRDAT to local Base chain (port 8545)
2. Deploy RdatMigration contract on local Base
3. Deploy new RDAT token on local Vana chain (port 8546)
4. Deploy RdatDistributor contract on local Vana
5. Fund test accounts with MockRDAT for migration testing

### 2. Testnet Deployment (`script/migration/testnet/`)

**`DeployMigrationTestnet.s.sol`:**
- Deploy to Base Sepolia and Vana Moksha
- Configure realistic limits and delays
- Set up multi-sig controls
- Initialize with test batch

### 3. Mainnet Deployment (`script/migration/mainnet/`)

**`DeployMigrationMainnet.s.sol`:**
- Deploy with production parameters
- Gnosis Safe integration
- Production limits and delays
- Comprehensive verification

### 4. Migration Utilities (`script/migration/utils/`)

**`MigrationHelpers.s.sol`:**
- Merkle tree generation utilities
- Batch optimization calculations
- Gas estimation helpers
- Migration status queries

**`EmergencyActions.s.sol`:**
- Emergency pause procedures
- Batch cancellation scripts
- Token recovery functions
- Admin action utilities

## 🛡️ Migration Audit Strategy

### 1. Security Focus Areas

**High Priority:**
1. Merkle proof verification correctness
2. Cross-chain state consistency
3. Access control and multi-sig integration
4. Reentrancy and front-running protection
5. Emergency mechanism reliability

**Medium Priority:**
1. Gas optimization effectiveness
2. Batch processing efficiency
3. Event emission completeness
4. Error handling robustness

### 2. OpenZeppelin Integration

**Leverage Audited Components:**
```solidity
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
```

### 3. Testing Requirements

**Coverage Targets:**
- Line Coverage: 100%
- Branch Coverage: 100%
- State Machine Coverage: 100%
- Cross-chain Scenario Coverage: 95%

### 4. Performance Benchmarks

**Gas Targets:**
- Deposit: < 100k gas
- Claim: < 150k gas
- Batch submission: < 200k gas
- Merkle proof verification: < 50k gas per proof

## 📊 Migration Success Metrics

### Technical Metrics
- Migration completion time: < 2 hours
- Batch processing efficiency: > 70% gas savings
- System uptime: 99.9% SLA
- Transaction success rate: > 99%

### Security Metrics
- Zero security incidents
- 100% fund recovery capability
- Complete audit trail
- Multi-sig protection on all admin functions

### Business Metrics
- User migration completion: > 90%
- Support ticket reduction: > 80%
- Gas cost savings: > $50k
- Migration timeline: 8 weeks

---

## 🥩 Staking System Specifications

### Overview

The RDAT staking system provides flexible staking options with NFT-based positions, multiple reward programs, and governance integration through vRDAT tokens. **Deployed exclusively on Vana blockchain** as part of the complete RDAT ecosystem. The system is designed for modularity, security, and scalability.

## 📦 Staking Smart Contracts

### 1. Core Staking Contract: `StakingManager.sol`

**Inheritance Structure:**
```solidity
contract StakingManager is 
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
```

**Key Features:**
- **NFT-based Positions**: ERC-721 tokens representing staking positions
- **Flexible Lock Periods**: 30, 90, 180, 365 days with multipliers
- **Early Exit Penalties**: Configurable penalties for early unstaking
- **Compound Options**: Auto-compound or manual claim
- **Position Transfer**: Transferable staking NFTs

**Lock Period Configuration:**
| Period | Multiplier | Early Exit Penalty |
|--------|------------|-------------------|
| 30 days | 1.0x | 10% |
| 90 days | 1.5x | 15% |
| 180 days | 2.0x | 20% |
| 365 days | 4.0x | 25% |

**Required Functions:**
```solidity
function stake(uint256 amount, uint256 lockPeriod) external returns (uint256 positionId)
function unstake(uint256 positionId) external
function claimRewards(uint256 positionId) external
function compound(uint256 positionId) external
function earlyExit(uint256 positionId) external
```

### 2. Staking Position NFT: `StakingPositionNFT.sol`

**Key Features:**
- ERC-721 compliant position tokens
- On-chain metadata storage
- Position data structure:
```solidity
struct Position {
    uint256 amount;
    uint256 lockPeriod;
    uint256 startTime;
    uint256 endTime;
    uint256 rewardMultiplier;
    uint256 accumulatedRewards;
    uint256 lastClaimTime;
    address delegatedTo;
    bool autoCompound;
}
```

### 3. Rewards Distribution: `RewardProgramManager.sol`

**Key Features:**
- **Multi-token Support**: Any ERC-20 as reward token
- **Program Types**: Base, loyalty, event, vRDAT rewards
- **Epoch-based**: Configurable distribution periods
- **Budget Management**: Program funding and tracking

**Reward Program Structure:**
```solidity
struct RewardProgram {
    address rewardToken;
    uint256 totalBudget;
    uint256 distributedAmount;
    uint256 rewardRate;
    uint256 startTime;
    uint256 endTime;
    uint256 minStakeAmount;
    uint256 minLockPeriod;
    bool active;
}
```

**Distribution Models:**
- Linear: Constant rate over time
- Cliff: Lump sum after period
- Bonus: Multipliers for conditions
- Retroactive: Past performance rewards

### 4. Governance Token: `vRDAT.sol`

**Key Features:**
- **Soul-bound**: Non-transferable governance tokens
- **Position-based**: Minted based on staking positions
- **Voting Power**: Quadratic voting support
- **Delegation**: Voting power delegation

**vRDAT Calculation:**
```solidity
vRDAT = stakedAmount * lockPeriodMultiplier * timeStaked
```

**Required Functions:**
```solidity
function mint(address to, uint256 amount) external onlyStakingManager
function burn(address from, uint256 amount) external onlyStakingManager
function delegate(address delegatee) external
function getPastVotes(address account, uint256 blockNumber) external view returns (uint256)
```

### 5. Delegation System: `ValidatorRegistry.sol`

**Key Features:**
- **Validator Management**: Registration and performance tracking
- **Non-custodial**: Users retain control of funds
- **Commission Structure**: Flexible validator fees
- **Slashing Conditions**: Misbehavior penalties

**Validator Structure:**
```solidity
struct Validator {
    address validatorAddress;
    uint256 commission; // Basis points (100 = 1%)
    uint256 totalDelegated;
    uint256 performanceScore;
    bool active;
    string metadata; // IPFS hash
}
```

### 6. Security Module: `StakingSecurityModule.sol`

**Key Features:**
- **Slashing Protection**: Insurance pools for delegators
- **Rate Limiting**: Transaction frequency controls
- **Emergency Functions**: Pause and emergency withdraw
- **Timelock**: Parameter change delays

**Security Parameters:**
```solidity
uint256 constant MIN_STAKE_AMOUNT = 100e18; // 100 RDAT minimum
uint256 constant MAX_STAKE_AMOUNT = 10_000_000e18; // 10M RDAT maximum
uint256 constant WITHDRAWAL_DELAY = 7 days; // Unstaking cooldown
uint256 constant PARAM_UPDATE_DELAY = 48 hours; // Timelock delay
```

## 🧪 Staking Testing Requirements

### 1. Unit Tests

**Core Staking Tests (`test/unit/StakingManager.t.sol`):**
- Staking with different amounts and periods
- Position NFT minting and metadata
- Lock period enforcement
- Early exit penalty calculations
- Reward accumulation accuracy
- Position transfer functionality

**Rewards Tests (`test/unit/RewardProgramManager.t.sol`):**
- Multiple concurrent reward programs
- Epoch-based distribution calculations
- Budget depletion handling
- Eligibility criteria enforcement
- Precision math verification

**vRDAT Tests (`test/unit/vRDAT.t.sol`):**
- Minting based on staking positions
- Non-transferability enforcement
- Voting power calculations
- Delegation mechanics
- Historical voting snapshots

### 2. Integration Tests

**Staking Flow (`test/integration/StakingFlow.t.sol`):**
- Complete stake → wait → claim → unstake flow
- Multiple positions per user
- Reward program interactions
- vRDAT minting and burning
- Delegation and undelegation

**Economic Tests (`test/integration/StakingEconomics.t.sol`):**
- APY calculation accuracy
- Reward sustainability over time
- Multiple reward token distributions
- Slashing impact simulations
- Fee collection and distribution

### 3. Security Tests

**Attack Scenarios (`test/security/StakingAttacks.t.sol`):**
- Reentrancy on claims
- Position manipulation attempts
- Reward calculation exploits
- Delegation vulnerabilities
- Emergency scenario handling

### 4. Load Tests

**Performance Tests (`test/load/StakingLoad.t.sol`):**
- 10,000 concurrent stakers
- Batch operations gas costs
- Reward calculation at scale
- Position enumeration efficiency

## 🚀 Staking Deployment Scripts

### 1. Local Development (`script/staking/local/`)

**`DeployStakingLocal.s.sol`:**
- Deploy all staking contracts
- Set up initial reward programs
- Configure test parameters
- Mint test tokens for staking

### 2. Testnet Deployment (`script/staking/testnet/`)

**`DeployStakingTestnet.s.sol`:**
- Deploy to Vana Moksha and Base Sepolia
- Configure realistic parameters
- Set up multi-sig controls
- Initialize with test rewards

### 3. Mainnet Deployment (`script/staking/mainnet/`)

**`DeployStakingMainnet.s.sol`:**
- Production parameter configuration
- Gnosis Safe integration
- Initial reward program funding
- Comprehensive verification

### 4. Staking Utilities (`script/staking/utils/`)

**`StakingHelpers.s.sol`:**
- Reward program creation helpers
- Validator registration scripts
- Emergency action procedures
- Migration utilities

## 🛡️ Staking Audit Strategy

### 1. Security Focus Areas

**High Priority:**
1. Position NFT security and access control
2. Reward calculation precision
3. Delegation and slashing mechanisms
4. Emergency withdrawal procedures
5. Upgrade authorization

**Medium Priority:**
1. Gas optimization effectiveness
2. Event emission completeness
3. Frontend integration points
4. Economic parameter validation

### 2. OpenZeppelin Integration

**Leverage Audited Components:**
```solidity
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
```

### 3. Economic Auditing

**Sustainability Analysis:**
- Reward rate vs token supply
- Lock period incentive modeling
- Slashing impact on TVL
- Fee structure optimization

### 4. Testing Requirements

**Coverage Targets:**
- Line Coverage: 100%
- Branch Coverage: 100%
- Economic Scenarios: 95%
- Attack Vectors: 100%

## 📊 Staking Success Metrics

### Technical Metrics
- Gas per stake: < 200k
- Gas per claim: < 100k
- Position query time: < 100ms
- Reward calculation accuracy: 18 decimals

### Business Metrics
- TVL target: $10M in 3 months
- Active stakers: 5,000+
- Average lock period: 180 days
- Delegation rate: 30%

### Security Metrics
- Zero critical vulnerabilities
- 100% fund recovery capability
- Complete slashing protection
- Multi-sig on all admin functions

---

# 📊 Data Contribution System Specifications

## 🎯 Overview

The Data Contribution System enables users to contribute Reddit data and earn RDAT rewards through a merit-based scoring system. Built with privacy-first design, GDPR compliance, and decentralized storage using IPFS.

**Epic Reference**: Data Processing & DLP Implementation (#1180)  
**Priority**: P1 - High (Phase 3)  
**Timeline**: 8 weeks (Starting after Staking System)  
**Primary Blockchain**: Vana (all data contribution operations)  
**Architecture**: Reddit data contribution with DLP integration and IPFS storage

## 📦 Smart Contracts Required

### 1. Core Contract: `DataContribution.sol`

**Inheritance Structure:**
```solidity
contract DataContribution is 
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
```

**Key Features:**
- **Proof Submission**: IPFS hash submission with cryptographic verification
- **Duplicate Prevention**: Hash-based deduplication system
- **Reward Calculation**: Base + quality + size bonus rewards
- **Batch Submissions**: Gas-optimized bulk data submission
- **Contribution Types**: New data vs refresh data tracking

**Core Functions:**
```solidity
// Primary submission function
function submitContribution(
    string calldata ipfsHash,
    uint256 dataSize,
    ContributionType contributionType,
    bytes calldata proof
) external whenNotPaused nonReentrant

// Batch submission for gas efficiency
function submitBatchContributions(
    ContributionData[] calldata contributions
) external whenNotPaused nonReentrant

// Calculate rewards based on quality metrics
function calculateReward(
    uint256 contributionId
) external view returns (uint256 reward)

// Claim accumulated rewards
function claimRewards(
    uint256[] calldata contributionIds
) external nonReentrant
```

**Data Structures:**
```solidity
struct Contribution {
    address contributor;
    string ipfsHash;
    uint256 dataSize;
    uint256 timestamp;
    ContributionType contributionType;
    QualityScore qualityScore;
    uint256 baseReward;
    uint256 bonusReward;
    bool rewardClaimed;
    bytes32 proofHash;
}

struct QualityScore {
    uint256 freshnessScore;     // 0-100 based on data recency
    uint256 uniquenessScore;    // 0-100 based on novelty
    uint256 completenessScore;  // 0-100 based on data completeness
    uint256 accuracyScore;      // 0-100 based on validation
    uint256 overallScore;       // Weighted average 0-100
}

enum ContributionType {
    NEW_DATA,
    REFRESH_DATA,
    VERIFICATION_DATA
}
```

**Access Control Roles:**
```solidity
bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
bytes32 public constant REWARD_ADMIN_ROLE = keccak256("REWARD_ADMIN_ROLE");
bytes32 public constant QUALITY_SCORER_ROLE = keccak256("QUALITY_SCORER_ROLE");
```

### 2. Reward Engine: `ContributionRewards.sol`

**Inheritance Structure:**
```solidity
contract ContributionRewards is 
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
```

**Key Features:**
- **Merit-based Scoring**: Quality-based reward multipliers
- **Anti-Gaming**: Sybil resistance and rate limiting
- **Dynamic Rewards**: Adaptive reward based on demand
- **Treasury Integration**: Connection to RDAT treasury
- **Cooldown Periods**: Anti-spam refresh intervals

**Reward Algorithm:**
```solidity
// Base reward calculation
function calculateBaseReward(uint256 dataSize) internal pure returns (uint256) {
    // Base: 1 RDAT per MB of data
    return (dataSize * BASE_REWARD_PER_MB) / 1e6;
}

// Quality bonus calculation
function calculateQualityBonus(
    QualityScore memory score,
    uint256 baseReward
) internal pure returns (uint256) {
    // Bonus: 0-300% based on quality score
    uint256 multiplier = (score.overallScore * 3) / 100;
    return (baseReward * multiplier) / 100;
}

// Size bonus for large contributions
function calculateSizeBonus(
    uint256 dataSize,
    uint256 baseReward
) internal pure returns (uint256) {
    if (dataSize > LARGE_CONTRIBUTION_THRESHOLD) {
        return baseReward / 10; // 10% bonus for large contributions
    }
    return 0;
}
```

### 3. Quality Scoring: `QualityScorer.sol`

**Inheritance Structure:**
```solidity
contract QualityScorer is 
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable
```

**Scoring Components:**
- **Freshness**: Recency-based scoring with decay functions
- **Uniqueness**: Novelty detection using similarity hashing
- **Completeness**: Data structure and field completeness
- **Accuracy**: Cross-reference validation scoring
- **Community**: Peer review and reputation integration

**Core Functions:**
```solidity
// Main scoring function
function scoreContribution(
    string calldata ipfsHash,
    bytes calldata metadata
) external onlyRole(QUALITY_SCORER_ROLE) returns (QualityScore memory)

// Update quality score post-submission
function updateQualityScore(
    uint256 contributionId,
    QualityScore calldata newScore
) external onlyRole(QUALITY_SCORER_ROLE)

// Batch scoring for efficiency
function batchScoreContributions(
    uint256[] calldata contributionIds
) external onlyRole(QUALITY_SCORER_ROLE)
```

### 4. Privacy Manager: `PrivacyManager.sol`

**Inheritance Structure:**
```solidity
contract PrivacyManager is 
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable
```

**Privacy Features:**
- **GDPR Compliance**: Right to deletion, data portability
- **Consent Management**: Granular permission tracking
- **Data Anonymization**: PII removal and hashing
- **Access Controls**: Role-based data access
- **Audit Trails**: Comprehensive compliance logging

**Core Functions:**
```solidity
// GDPR Article 17 - Right to Deletion
function deleteUserData(
    address user
) external onlyRole(PRIVACY_ADMIN_ROLE)

// Data export for portability
function exportUserData(
    address user
) external view returns (bytes memory)

// Consent management
function updateConsent(
    address user,
    ConsentType consentType,
    bool granted
) external

// Anonymization tracking
function markDataAnonymized(
    uint256 contributionId
) external onlyRole(PRIVACY_ADMIN_ROLE)
```

## 🧪 Testing Strategy

### Unit Tests
1. **DataContribution Contract**
   - Contribution submission validation
   - Duplicate prevention testing
   - Reward calculation accuracy
   - Access control verification
   - Pause/unpause functionality

2. **Reward Engine**
   - Quality bonus calculations
   - Size bonus thresholds
   - Anti-gaming mechanisms
   - Treasury integration
   - Cooldown period enforcement

3. **Quality Scorer**
   - Scoring algorithm accuracy
   - Batch processing efficiency
   - Score update mechanisms
   - Edge case handling

4. **Privacy Manager**
   - GDPR deletion compliance
   - Data export functionality
   - Consent management
   - Access control enforcement

### Integration Tests
1. **End-to-End Contribution Flow**
   - Submit → Score → Reward → Claim
   - Batch submission processing
   - Cross-contract interactions
   - Error recovery scenarios

2. **Reddit Integration**
   - OAuth2 authentication flow
   - Data extraction accuracy
   - Rate limit handling
   - Verification code validation

3. **IPFS Storage**
   - Hash generation and validation
   - Data persistence verification
   - Access control testing
   - Redundancy validation

### Performance Tests
1. **Gas Optimization**
   - Submission cost analysis
   - Batch processing efficiency
   - Storage optimization
   - Function call costs

2. **Load Testing**
   - High-volume submissions
   - Concurrent user handling
   - System bottleneck identification
   - Recovery mechanisms

## 🚀 Deployment Strategy

### Local Development
1. **Mock Contracts**
   - MockRedditAPI for testing
   - MockIPFS for storage simulation
   - Test RDAT token distribution
   - Quality scoring simulation

2. **Development Scripts**
   - `DeployDataContribution.s.sol`
   - `ConfigureRewards.s.sol`
   - `SetupTesting.s.sol`
   - `PopulateTestData.s.sol`

### Testnet Deployment
1. **Base Sepolia** (Migration Testing Only)
   - Deploy migration contracts for testing
   - Mock RDAT token for migration simulation
   - Test cross-chain migration flow
   - Validate migration contract functionality

2. **Vana Moksha** (Full Ecosystem Testing)
   - Deploy all RDAT ecosystem contracts
   - Full data contribution system testing
   - Staking system integration testing
   - Performance validation and security audit preparation

### Mainnet Deployment
1. **Vana Mainnet** (Primary Deployment)
   - Production RDAT ecosystem deployment
   - All smart contracts (Token, Staking, Data Contribution)
   - Multi-sig ownership transfer
   - Treasury and governance setup
   - Monitoring and analytics

2. **Base Mainnet** (Migration Only)
   - Migration contract deployment only
   - Token holder transition facilitation
   - Legacy contract maintenance during migration period
   - No ongoing ecosystem operations

## 🔒 Security & Audit Strategy

### OpenZeppelin Integration
- **Upgradeable Contracts**: UUPS pattern for future improvements
- **Access Control**: Role-based permissions
- **Security**: ReentrancyGuard, Pausable
- **Standards**: ERC20 compliance for reward tokens

### Audit Preparation
1. **Code Review Checklist**
   - Integer overflow/underflow protection
   - Reentrancy attack prevention
   - Access control validation
   - Input validation completeness
   - Gas optimization verification

2. **Security Testing**
   - Fuzz testing with Echidna
   - Slither static analysis
   - Mythril symbolic execution
   - Manual code review
   - Economic attack modeling

3. **Formal Verification**
   - Critical function verification
   - Invariant checking
   - Property-based testing
   - Mathematical proof validation

## 💰 Economic Model

### Reward Budget
- **Source**: 30M RDAT from "Future Rewards" allocation
- **Distribution**: Merit-based with quality multipliers
- **Sustainability**: Dynamic reward adjustment
- **Governance**: Community-controlled parameters

### Anti-Gaming Measures
- **Sybil Resistance**: Reddit account verification
- **Rate Limiting**: Submission frequency controls
- **Quality Thresholds**: Minimum score requirements
- **Penalty System**: Reputation-based deductions
- **Appeal Process**: Community dispute resolution

## 🎯 Success Metrics

### Technical KPIs
- **Data Quality**: >98% average quality score
- **Processing Speed**: <30 second submission to reward
- **Uptime**: 99.9% system availability
- **Gas Efficiency**: <$1 average transaction cost
- **Storage**: <$0.01 per MB storage cost

### Business KPIs
- **Active Contributors**: 1,000 verified users
- **Monthly Volume**: 10TB data processed
- **Reward Distribution**: $100k monthly
- **User Retention**: 70% monthly retention
- **Data Utilization**: 80% of contributed data used

## 📋 Deployment Scripts Required

### 1. `DeployDataContribution.s.sol`
```solidity
// Deploy main contribution system
// Configure initial parameters
// Set up role permissions
// Initialize reward pools
```

### 2. `DeployQualityScoring.s.sol`
```solidity
// Deploy scoring contracts
// Configure scoring algorithms
// Set quality thresholds
// Initialize scoring parameters
```

### 3. `DeployPrivacyManager.s.sol`
```solidity
// Deploy privacy contracts
// Configure GDPR compliance
// Set up consent management
// Initialize anonymization tools
```

### 4. `ConfigureSystem.s.sol`
```solidity
// Cross-contract integration
// Role assignment
// Parameter configuration
// Treasury connections
```

---

# 🏛️ Governance System Specifications

## 🎯 Overview

The RDAT Governance System implements quadratic voting with vRDAT tokens, delegation mechanisms, and timelock security for decentralized protocol governance. **Deployed exclusively on Vana blockchain** as the primary governance layer for the RDAT ecosystem.

**Epic Reference**: Complete Governance & Delegation Frontend Support (#568)  
**Priority**: P1 - High (Phase 3)  
**Timeline**: 8 weeks (Starting after Staking System)  
**Primary Blockchain**: Vana (all governance operations)  
**Architecture**: Quadratic voting with vRDAT integration and delegation support

## 📦 Smart Contracts Required

### 1. Core Contract: `QuadraticVoting.sol`

**Inheritance Structure:**
```solidity
contract QuadraticVoting is 
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable,
    IGovernor
```

**Key Features:**
- **Quadratic Cost Formula**: Cost = votes² preventing whale dominance
- **Multi-position Support**: Vote with multiple staking positions
- **vRDAT Integration**: Voting power from staked token positions
- **Gas Optimization**: Batch voting operations
- **Proposal Lifecycle**: Creation, voting, execution, and appeals

**Core Functions:**
```solidity
// Cast quadratic vote on proposal
function castVote(
    uint256 proposalId,
    uint256[] calldata positionIds,
    uint256[] calldata voteAmounts,
    uint8 support
) external whenNotPaused nonReentrant

// Calculate quadratic voting cost
function calculateVotingCost(
    uint256[] calldata voteAmounts
) external pure returns (uint256 totalCost)

// Create new governance proposal
function propose(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    string memory description
) external returns (uint256 proposalId)

// Execute passed proposal
function execute(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
) external payable returns (uint256 proposalId)
```

**Quadratic Voting Formula:**
```solidity
// Core quadratic cost calculation
function _calculateQuadraticCost(uint256 votes) internal pure returns (uint256) {
    return votes * votes; // votes²
}

// Multi-position cost aggregation
function _calculateTotalCost(
    uint256[] memory voteAmounts
) internal pure returns (uint256) {
    uint256 totalCost = 0;
    for (uint256 i = 0; i < voteAmounts.length; i++) {
        totalCost += _calculateQuadraticCost(voteAmounts[i]);
    }
    return totalCost;
}
```

**Access Control Roles:**
```solidity
bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
bytes32 public constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");
bytes32 public constant TIMELOCK_ADMIN_ROLE = keccak256("TIMELOCK_ADMIN_ROLE");
```

### 2. Proposal Manager: `ProposalManager.sol`

**Inheritance Structure:**
```solidity
contract ProposalManager is 
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable
```

**Key Features:**
- **Structured Proposals**: Template-based proposal creation
- **Lifecycle Management**: Draft, review, voting, execution phases
- **Impact Assessment**: Automated proposal impact analysis
- **Category System**: Organized proposal types
- **Execution Queue**: Post-vote implementation coordination

**Proposal Types:**
```solidity
enum ProposalType {
    PARAMETER_CHANGE,
    TREASURY_ALLOCATION,
    PROTOCOL_UPGRADE,
    PARTNERSHIP_AGREEMENT,
    COMMUNITY_INITIATIVE
}

struct Proposal {
    uint256 id;
    address proposer;
    string title;
    string description;
    ProposalType proposalType;
    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    uint256 createdAt;
    uint256 votingStart;
    uint256 votingEnd;
    ProposalState state;
    mapping(address => Vote) votes;
    uint256 forVotes;
    uint256 againstVotes;
    uint256 abstainVotes;
}
```

### 3. Delegation System: `VotingDelegation.sol`

**Inheritance Structure:**
```solidity
contract VotingDelegation is 
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable
```

**Key Features:**
- **Flexible Delegation**: Partial or full voting power delegation
- **Delegate Registry**: Verified representative system
- **Override Voting**: Direct voting on specific proposals
- **Delegation History**: Complete audit trail
- **Performance Tracking**: Delegate effectiveness metrics

**Core Functions:**
```solidity
// Delegate voting power to representative
function delegate(
    address delegatee,
    uint256[] calldata positionIds,
    DelegationType delegationType
) external

// Override delegate vote on specific proposal
function voteOverride(
    uint256 proposalId,
    uint256[] calldata positionIds,
    uint8 support
) external

// Revoke delegation
function revokeDelegation(
    address delegatee,
    uint256[] calldata positionIds
) external

// Get effective voting power (including delegations)
function getVotingPower(
    address account,
    uint256 blockNumber
) external view returns (uint256)
```

**Delegation Types:**
```solidity
enum DelegationType {
    FULL_DELEGATION,        // Delegate all voting power
    CATEGORY_DELEGATION,    // Delegate specific proposal types
    THRESHOLD_DELEGATION,   // Delegate only above certain amounts
    SELECTIVE_DELEGATION    // Manual per-proposal delegation
}
```

### 4. Timelock Controller: `GovernanceTimelock.sol`

**Inheritance Structure:**
```solidity
contract GovernanceTimelock is 
    TimelockControllerUpgradeable,
    UUPSUpgradeable
```

**Key Features:**
- **Security Delay**: 48-hour minimum execution delay
- **Multi-signature Support**: Critical operation protection
- **Emergency Functions**: Fast-track for urgent decisions
- **Role-based Access**: Granular permission management
- **Cancellation Rights**: Emergency proposal cancellation

**Security Parameters:**
```solidity
uint256 public constant MIN_DELAY = 48 hours;
uint256 public constant EMERGENCY_DELAY = 6 hours;
uint256 public constant MAX_DELAY = 30 days;

// Emergency proposal types that can use reduced delay
mapping(bytes32 => bool) public emergencyOperations;
```

### 5. Governance Analytics: `GovernanceMetrics.sol`

**Inheritance Structure:**
```solidity
contract GovernanceMetrics is 
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable
```

**Key Features:**
- **Participation Tracking**: Voter turnout and engagement
- **Voting Pattern Analysis**: Behavior analytics
- **Delegate Performance**: Representative effectiveness
- **Quorum Monitoring**: Participation threshold tracking
- **Governance Health**: Decentralization metrics

**Metrics Functions:**
```solidity
// Track proposal participation
function recordVote(
    uint256 proposalId,
    address voter,
    uint256 votingPower,
    uint8 support
) external onlyRole(GOVERNANCE_ROLE)

// Calculate voter participation rate  
function getParticipationRate(
    uint256 proposalId
) external view returns (uint256)

// Get delegate performance metrics
function getDelegateMetrics(
    address delegate
) external view returns (DelegateMetrics memory)

// Calculate governance decentralization index
function getDecentralizationIndex() external view returns (uint256)
```

## 🧪 Testing Strategy

### Unit Tests
1. **QuadraticVoting Contract**
   - Quadratic cost calculation accuracy
   - Multi-position voting validation
   - Proposal lifecycle testing
   - Access control verification
   - Gas optimization validation

2. **Delegation System**
   - Delegation mechanics testing
   - Override voting functionality
   - Delegate registry management
   - Performance tracking accuracy
   - Revocation mechanisms

3. **Proposal Manager**
   - Proposal creation validation
   - Lifecycle state transitions
   - Category system functionality
   - Impact assessment accuracy
   - Execution queue processing

4. **Timelock Controller**
   - Delay mechanism testing
   - Emergency function validation
   - Multi-signature integration
   - Cancellation functionality
   - Role-based access control

### Economic Model Testing
1. **Quadratic Voting Economics**
   - Cost formula validation
   - Anti-plutocracy effectiveness
   - Game theory attack scenarios
   - Vote buying resistance
   - Economic equilibrium analysis

2. **Delegation Economics**
   - Delegation incentive alignment
   - Representative accountability
   - Delegation concentration analysis
   - Economic attack vectors
   - Delegation market dynamics

### Security Testing
1. **Governance Attack Vectors**
   - Vote manipulation attempts
   - Flash loan governance attacks
   - Sybil resistance testing
   - Collusion detection
   - Governance capture scenarios

2. **Smart Contract Security**
   - Reentrancy attack prevention
   - Integer overflow protection
   - Access control validation
   - Upgrade mechanism security
   - Emergency pause functionality

### Integration Tests
1. **vRDAT Integration**
   - Staking position voting power
   - Multi-position vote aggregation
   - Delegation power calculation
   - Vote weight accuracy
   - Cross-contract interaction

2. **Frontend Integration**
   - Voting interface functionality
   - Delegation dashboard accuracy
   - Proposal creation flow
   - Real-time vote tracking
   - Mobile responsiveness

## 🚀 Deployment Strategy

### Local Development
1. **Mock Contracts**
   - MockvRDAT for testing
   - MockStaking for position simulation
   - Test governance scenarios
   - Economic model validation

2. **Development Scripts**
   - `DeployGovernance.s.sol`
   - `ConfigureVoting.s.sol`
   - `SetupDelegation.s.sol`
   - `PopulateTestProposals.s.sol`

### Testnet Deployment
1. **Vana Moksha** (Full Governance Testing)
   - Deploy complete governance system
   - Integration with testnet vRDAT
   - Full proposal lifecycle testing
   - Delegation system validation
   - Security audit preparation

### Mainnet Deployment
1. **Vana Mainnet** (Production Governance)
   - Production governance system deployment
   - Integration with live vRDAT tokens
   - Multi-sig timelock configuration
   - Monitoring and analytics setup
   - Community governance activation

## 🔒 Security & Audit Strategy

### OpenZeppelin Integration
- **Governor Framework**: Standard governance contract base
- **TimelockController**: Secure execution delays
- **AccessControl**: Role-based permissions
- **Upgradeable Contracts**: UUPS pattern for improvements
- **Security Utils**: ReentrancyGuard, Pausable

### Audit Preparation
1. **Mathematical Verification**
   - Quadratic voting formula correctness
   - Economic model mathematical proofs
   - Game theory analysis
   - Incentive alignment verification
   - Attack vector mathematical modeling

2. **Security Testing**
   - Formal verification of critical functions
   - Economic attack simulation
   - Governance capture analysis
   - Flash loan attack prevention
   - Multi-signature security validation

3. **Code Review Checklist**
   - Governance attack prevention
   - Delegation security validation
   - Timelock mechanism integrity
   - Access control completeness
   - Upgrade path security

## 💰 Economic Model

### Voting Power Calculation
- **Base Power**: Derived from vRDAT token balance
- **Position Multiplier**: Staking position lock period bonus
- **Delegation Aggregation**: Combined delegated voting power
- **Quadratic Cost**: Prevents vote concentration

### Governance Incentives
- **Participation Rewards**: Incentivize active voting
- **Delegate Rewards**: Compensation for representatives
- **Proposal Rewards**: Successful proposal bonuses
- **Long-term Alignment**: Increased power with longer stakes

### Anti-Gaming Measures
- **Quadratic Cost Scaling**: Exponentially expensive vote concentration
- **Sybil Resistance**: vRDAT requirement for participation
- **Flash Loan Protection**: Block-based voting power snapshots
- **Delegation Limits**: Maximum delegation concentration
- **Cooldown Periods**: Prevent rapid vote manipulation

## 🎯 Success Metrics

### Participation Metrics
- **Voter Turnout**: 30% of vRDAT holders actively voting
- **Proposal Success**: 70% of proposals reaching quorum
- **Delegation Rate**: 50% of voting power delegated
- **Voter Retention**: 60% monthly active voters
- **Geographic Distribution**: Global participation

### Governance Health
- **Decentralization Index**: >0.8 (scale 0-1)
- **Voting Power Concentration**: <20% by top 10 holders
- **Delegate Performance**: >80% alignment with delegators
- **Proposal Quality**: >90% well-formed proposals
- **Execution Success**: >95% approved proposals executed

### Technical Performance
- **Gas Efficiency**: <500k gas per vote transaction
- **Response Time**: <2 second UI response
- **Uptime**: 99.9% system availability
- **Security**: Zero critical vulnerabilities
- **Scalability**: Support 10,000+ concurrent voters

## 📋 Deployment Scripts Required

### 1. `DeployGovernance.s.sol`
```solidity
// Deploy complete governance system
// Configure quadratic voting parameters
// Set up proposal management
// Initialize timelock controller
```

### 2. `DeployDelegation.s.sol`
```solidity
// Deploy delegation contracts
// Configure delegate registry
// Set up delegation mechanics
// Initialize performance tracking
```

### 3. `ConfigureGovernance.s.sol`
```solidity
// Cross-contract integration
// Role assignment and permissions
// Parameter configuration
// Security settings
```

### 4. `SetupTimelock.s.sol`
```solidity
// Deploy timelock controller
// Configure execution delays
// Set up multi-signature integration
// Initialize emergency functions
```

---

# 🏭 Token Minting & Allocation System Specifications

## 🎯 Overview

The RDAT Token Minting & Allocation System implements DAO-governed token distribution with automated vesting schedules and comprehensive allocation tracking. **Deployed exclusively on Vana blockchain** as part of the complete RDAT tokenomics framework.

**Epic Reference**: DAO-Governed Token Minting & Allocation System (#1182)  
**Priority**: P1 - High (Phase 2)  
**Timeline**: 6 weeks (Starting after Token Deployment)  
**Primary Blockchain**: Vana (all minting and allocation operations)  
**Architecture**: DAO-governed tokenomics with vesting, allocation tracking, and claim mechanisms

## 📦 Smart Contracts Required

### 1. Core Contract: `MintingController.sol`

**Inheritance Structure:**
```solidity
contract MintingController is 
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
```

**Key Features:**
- **DAO Integration**: Governance-controlled minting through proposal execution
- **Allocation Limits**: Configurable maximum allocations per category
- **Batch Minting**: Gas-efficient batch minting for multiple recipients
- **Mint History**: Complete on-chain minting history and tracking
- **Emergency Controls**: Pause functionality and emergency stop mechanisms

**Core Functions:**
```solidity
// Execute DAO-approved minting
function executeMint(
    AllocationCategory category,
    address[] calldata recipients,
    uint256[] calldata amounts,
    bytes32 proposalHash
) external onlyRole(MINTER_ROLE) whenNotPaused

// Batch mint for gas efficiency
function batchMint(
    MintBatch[] calldata batches
) external onlyRole(MINTER_ROLE) whenNotPaused

// Check allocation remaining for category
function getAllocationRemaining(
    AllocationCategory category
) external view returns (uint256)

// Emergency pause minting
function emergencyPause() external onlyRole(EMERGENCY_ROLE)
```

**Allocation Categories:**
```solidity
enum AllocationCategory {
    MIGRATION,          // 30M RDAT - Base migration
    FUTURE_REWARDS,     // 30M RDAT - Data contributions & staking
    TREASURY,           // 25M RDAT - DAO treasury
    LIQUIDITY          // 15M RDAT - DEX liquidity
}

struct AllocationLimits {
    uint256 totalAllocation;
    uint256 mintedAmount;
    uint256 remainingAmount;
    bool active;
}

mapping(AllocationCategory => AllocationLimits) public allocationLimits;
```

**Access Control Roles:**
```solidity
bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
bytes32 public constant ALLOCATION_ADMIN_ROLE = keccak256("ALLOCATION_ADMIN_ROLE");
bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
```

### 2. Vesting System: `TokenVesting.sol`

**Inheritance Structure:**
```solidity
contract TokenVesting is 
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
```

**Key Features:**
- **Team Vesting**: 6-month minimum cliff with linear vesting (VRC-20 compliance)
- **Advisor Vesting**: Flexible vesting schedules for advisors
- **Community Vesting**: Long-term community allocation vesting
- **Batch Claims**: Gas-optimized batch claim processing
- **Partial Claims**: Allow partial vesting claims before full maturation

**Core Functions:**
```solidity
// Create new vesting schedule
function createVestingSchedule(
    address beneficiary,
    uint256 totalAmount,
    uint256 cliff,
    uint256 duration,
    VestingType vestingType
) external onlyRole(VESTING_ADMIN_ROLE) returns (uint256 scheduleId)

// Claim vested tokens
function claimVestedTokens(
    uint256 scheduleId
) external nonReentrant returns (uint256 claimedAmount)

// Calculate vested amount
function calculateVestedAmount(
    uint256 scheduleId
) external view returns (uint256 vestedAmount)

// Batch claim multiple schedules
function batchClaim(
    uint256[] calldata scheduleIds
) external nonReentrant returns (uint256 totalClaimed)
```

**Vesting Types:**
```solidity
enum VestingType {
    TEAM_VESTING,       // 6-month cliff, 24-month linear
    ADVISOR_VESTING,    // 3-month cliff, 12-month linear  
    COMMUNITY_VESTING,  // No cliff, 36-month linear
    TREASURY_VESTING    // Custom schedules per DAO vote
}

struct VestingSchedule {
    address beneficiary;
    uint256 totalAmount;
    uint256 claimedAmount;
    uint256 startTime;
    uint256 cliff;
    uint256 duration;
    VestingType vestingType;
    bool revocable;
    bool revoked;
}
```

### 3. Allocation Tracker: `AllocationTracker.sol`

**Inheritance Structure:**
```solidity
contract AllocationTracker is 
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable
```

**Key Features:**
- **Category Management**: Treasury, team, advisors, community allocations
- **Real-time Tracking**: Live tracking of allocated vs distributed tokens
- **Budget Controls**: Prevent over-allocation beyond approved limits
- **Audit Trail**: Complete allocation history for compliance
- **Analytics Integration**: Data feeds for dashboard and reporting

**Core Functions:**
```solidity
// Record allocation
function recordAllocation(
    AllocationCategory category,
    address recipient,
    uint256 amount,
    AllocationType allocationType
) external onlyRole(TRACKER_ROLE)

// Get allocation summary
function getAllocationSummary(
    AllocationCategory category
) external view returns (AllocationSummary memory)

// Track distribution
function recordDistribution(
    uint256 allocationId,
    uint256 amount
) external onlyRole(TRACKER_ROLE)

// Generate allocation report
function generateAllocationReport(
    uint256 fromTimestamp,
    uint256 toTimestamp
) external view returns (AllocationReport memory)
```

**Allocation Types:**
```solidity
enum AllocationType {
    DIRECT_ALLOCATION,   // Direct token transfer
    VESTING_ALLOCATION,  // Vesting schedule creation
    STAKING_REWARD,      // Staking reward allocation
    DATA_REWARD,         // Data contribution reward
    LIQUIDITY_PROVISION  // DEX liquidity provision
}

struct AllocationSummary {
    uint256 totalAllocated;
    uint256 totalDistributed;
    uint256 totalVesting;
    uint256 totalClaimed;
    uint256 remainingBudget;
}
```

### 4. Claims Interface: `ClaimsManager.sol`

**Inheritance Structure:**
```solidity
contract ClaimsManager is 
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
```

**Key Features:**
- **Unified Claims**: Single interface for all claim types
- **Batch Processing**: Efficient batch claim processing
- **Gas Optimization**: Optimized claim operations
- **Event Tracking**: Comprehensive claim event logging
- **Error Recovery**: Robust error handling and recovery

**Core Functions:**
```solidity
// Claim all available tokens
function claimAll(address user) external nonReentrant returns (uint256 totalClaimed)

// Claim specific allocation
function claimAllocation(
    uint256 allocationId
) external nonReentrant returns (uint256 claimed)

// Preview claimable amounts
function getClaimableAmounts(
    address user
) external view returns (ClaimableAmounts memory)

// Emergency claim for user
function emergencyClaim(
    address user,
    uint256 amount
) external onlyRole(EMERGENCY_ROLE)
```

### 5. Governance Integration: `MintingGovernance.sol`

**Inheritance Structure:**
```solidity
contract MintingGovernance is 
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable
```

**Key Features:**
- **Proposal Execution**: Direct integration with governance voting results
- **Timelock Integration**: 48-hour delay for critical minting decisions
- **Multi-sig Coordination**: Integration with treasury multi-signature wallets
- **Vote Verification**: Cryptographic verification of governance decisions
- **Emergency Override**: Emergency governance bypass for critical issues

**Core Functions:**
```solidity
// Execute approved minting proposal
function executeProposal(
    uint256 proposalId,
    bytes calldata executionData
) external onlyRole(EXECUTOR_ROLE)

// Queue minting operation
function queueMinting(
    MintingOperation calldata operation
) external onlyRole(GOVERNANCE_ROLE) returns (bytes32 operationHash)

// Execute queued operation
function executeMinting(
    bytes32 operationHash
) external onlyRole(EXECUTOR_ROLE)

// Cancel queued operation
function cancelMinting(
    bytes32 operationHash
) external onlyRole(CANCELLER_ROLE)
```

## 🧪 Testing Strategy

### Unit Tests
1. **MintingController Contract**
   - DAO integration validation
   - Allocation limit enforcement
   - Batch minting efficiency
   - Emergency pause functionality
   - Access control verification

2. **Vesting System**
   - Vesting calculation accuracy
   - Cliff period enforcement
   - Partial claim functionality
   - Batch claim efficiency
   - VRC-20 compliance validation

3. **Allocation Tracker**
   - Real-time tracking accuracy
   - Budget control enforcement
   - Audit trail completeness
   - Report generation accuracy
   - Cross-contract integration

4. **Claims Manager**
   - Unified claim processing
   - Gas optimization validation
   - Error handling robustness
   - Event logging completeness
   - Emergency claim functionality

### Economic Model Testing
1. **Tokenomics Validation**
   - Allocation distribution accuracy
   - Inflation impact modeling
   - Vesting schedule optimization
   - Economic equilibrium analysis
   - Market impact assessment

2. **Allocation Testing**
   - Category allocation accuracy
   - Over-allocation prevention
   - Distribution timeline validation
   - Vesting timeline accuracy
   - Claim timing optimization

### Security Testing
1. **Minting Security**
   - Unauthorized minting prevention
   - Allocation limit bypass attempts
   - Governance bypass attempts
   - Emergency control validation
   - Multi-signature security

2. **Vesting Security**
   - Early claim prevention
   - Vesting manipulation attempts
   - Beneficiary spoofing prevention
   - Schedule tampering protection
   - Emergency revocation security

### Integration Tests
1. **Governance Integration**
   - Proposal-to-execution flow
   - Timelock mechanism validation
   - Multi-signature coordination
   - Vote verification accuracy
   - Emergency override functionality

2. **Cross-System Integration**
   - Staking reward integration
   - Data contribution reward integration
   - Treasury allocation coordination
   - Analytics data integration
   - Frontend integration validation

## 🚀 Deployment Strategy

### Local Development
1. **Mock Contracts**
   - MockGovernance for testing
   - MockRDAT token for allocation testing
   - Test allocation scenarios
   - Vesting simulation
   - Economic model validation

2. **Development Scripts**
   - `DeployMinting.s.sol`
   - `ConfigureAllocations.s.sol`
   - `SetupVesting.s.sol`
   - `PopulateTestData.s.sol`

### Testnet Deployment
1. **Vana Moksha** (Full System Testing)
   - Deploy complete minting system
   - Integration with testnet governance
   - Full allocation lifecycle testing
   - Vesting system validation
   - Security audit preparation

### Mainnet Deployment
1. **Vana Mainnet** (Production Minting)
   - Production minting system deployment
   - Integration with live governance system
   - Treasury multi-sig configuration
   - Monitoring and analytics setup
   - Community allocation activation

## 🔒 Security & Audit Strategy

### OpenZeppelin Integration
- **AccessControl**: Role-based permissions
- **Upgradeable Contracts**: UUPS pattern for improvements
- **Security Utils**: ReentrancyGuard, Pausable
- **VestingWallet**: Proven vesting contract patterns
- **Timelock**: Governance execution delays

### Audit Preparation
1. **Economic Model Verification**
   - Tokenomics mathematical proofs
   - Allocation distribution correctness
   - Vesting formula validation
   - Inflation impact modeling
   - Economic attack vector analysis

2. **Security Testing**
   - Formal verification of critical functions
   - Multi-signature integration testing
   - Emergency control validation
   - Governance integration security
   - Cross-contract interaction security

3. **Code Review Checklist**
   - Unauthorized minting prevention
   - Allocation limit enforcement
   - Vesting calculation accuracy
   - Access control completeness
   - Emergency procedure validation

## 💰 Economic Model

### Allocation Distribution (100M RDAT Total)
- **Migration**: 30M RDAT (30%) - Base holder migration
- **Future Rewards**: 30M RDAT (30%) - Data contributions & staking
- **Treasury**: 25M RDAT (25%) - DAO operations & partnerships
- **Liquidity**: 15M RDAT (15%) - DEX liquidity provision

### Vesting Schedules
- **Team Vesting**: 6-month cliff, 24-month linear (VRC-20 compliant)
- **Advisor Vesting**: 3-month cliff, 12-month linear
- **Community Rewards**: No cliff, 36-month linear release
- **Treasury Allocations**: Custom schedules per DAO vote

### Governance Controls
- **All minting requires DAO approval**
- **48-hour timelock for execution**
- **Multi-signature treasury integration**
- **Emergency pause capabilities**
- **Allocation limit enforcement**

## 🎯 Success Metrics

### Operational Metrics
- **Allocation Accuracy**: 100% accurate allocation tracking
- **Vesting Automation**: 95% of claims processed automatically
- **Governance Integration**: 100% of minting decisions governed by DAO
- **Gas Efficiency**: <200k gas per allocation operation
- **Uptime**: 99.9% system availability

### Business Metrics
- **User Satisfaction**: 90% positive feedback on claiming experience
- **Operational Efficiency**: 80% reduction in manual allocation overhead
- **Compliance**: 100% audit trail completeness
- **Security**: Zero critical vulnerabilities
- **Distribution**: Complete migration of 30M Base RDAT holders

### Economic Metrics
- **Token Distribution**: Fair and transparent allocation
- **Inflation Control**: Predictable token supply growth
- **Vesting Compliance**: 100% VRC-20 compliance
- **Treasury Management**: Efficient fund allocation
- **Market Stability**: Minimal price impact from distributions

## 📋 Deployment Scripts Required

### 1. `DeployMinting.s.sol`
```solidity
// Deploy complete minting system
// Configure allocation categories and limits
// Set up governance integration
// Initialize security controls
```

### 2. `DeployVesting.s.sol`
```solidity
// Deploy vesting contracts
// Configure vesting schedules
// Set up claim mechanisms
// Initialize VRC-20 compliance
```

### 3. `ConfigureAllocations.s.sol`
```solidity
// Set allocation limits per category
// Configure governance integration
// Set up tracking mechanisms
// Initialize reporting systems
```

### 4. `SetupGovernanceIntegration.s.sol`
```solidity
// Connect to governance contracts
// Configure timelock mechanisms
// Set up multi-signature integration
// Initialize emergency controls
```

---

# 🗳️ vRDAT Distribution System Specifications

## 🎯 Overview

The vRDAT Distribution System implements soul-bound (non-transferable) governance tokens distributed based on staking participation with time-weighted loyalty rewards. **Deployed exclusively on Vana blockchain** as the voting power layer for the RDAT governance ecosystem.

**Epic Reference**: Non-Transferable Voting Token Distribution System (#1183)  
**Priority**: P1 - High (Phase 3)  
**Timeline**: 4 weeks (Starting after Staking System)  
**Primary Blockchain**: Vana (all vRDAT operations)  
**Architecture**: Soul-bound voting tokens with staking-based distribution and governance integration

## 📦 Smart Contracts Required

### 1. Core Contract: `vRDAT.sol` (Enhanced)

**Inheritance Structure:**
```solidity
contract vRDAT is 
    Initializable,
    ERC20Upgradeable,
    ERC20VotesUpgradeable,
    ERC20PermitUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
```

**Key Features:**
- **Soul-Bound Implementation**: Non-transferable tokens preventing vote buying
- **Voting Power Integration**: ERC20Votes for governance participation
- **Staking-Based Minting**: Automatic distribution based on staking positions
- **Time-Weighted Rewards**: Loyalty multipliers for long-term stakers
- **Snapshot Support**: Historical balance queries for governance

**Transfer Override (Soul-Bound):**
```solidity
// Override transfer functions to prevent movement
function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
) internal override {
    super._beforeTokenTransfer(from, to, amount);
    
    // Allow minting (from == address(0)) and burning (to == address(0))
    if (from == address(0) || to == address(0)) {
        return;
    }
    
    // Block all transfers between addresses
    revert("vRDAT: non-transferable token");
}

// Allow staking contract to manage vRDAT for governance
function _isTransferAllowed(address from, address to) internal view returns (bool) {
    return hasRole(TRANSFER_ROLE, from) || hasRole(TRANSFER_ROLE, to);
}
```

**Distribution Formula:**
```solidity
// Calculate vRDAT amount based on staking
function calculatevRDATAmount(
    uint256 stakedAmount,
    uint256 stakingDuration,
    uint256 lockPeriod
) public pure returns (uint256) {
    // Base amount: 1 vRDAT per 1 RDAT staked
    uint256 baseAmount = stakedAmount;
    
    // Time multiplier: bonus for longer staking
    uint256 timeMultiplier = _calculateTimeMultiplier(stakingDuration);
    
    // Lock period multiplier: matches staking multipliers
    uint256 lockMultiplier = _getLockPeriodMultiplier(lockPeriod);
    
    // Final calculation: base × time × lock multipliers
    return (baseAmount * timeMultiplier * lockMultiplier) / (10000 * 10000);
}

function _calculateTimeMultiplier(uint256 duration) internal pure returns (uint256) {
    // Linear increase: 10% bonus per month, capped at 100%
    uint256 months = duration / 30 days;
    uint256 bonus = months * 1000; // 10% = 1000 basis points
    return 10000 + (bonus > 10000 ? 10000 : bonus); // Cap at 100% bonus
}
```

**Access Control Roles:**
```solidity
bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");
bytes32 public constant TRANSFER_ROLE = keccak256("TRANSFER_ROLE");
```

### 2. Distribution Manager: `vRDATDistributor.sol`

**Inheritance Structure:**
```solidity
contract vRDATDistributor is 
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
```

**Key Features:**
- **Staking Integration**: Automatic vRDAT distribution when users stake
- **Batch Distribution**: Gas-efficient batch processing
- **Distribution Caps**: Per-address and total supply limits
- **Loyalty Tracking**: Time-based multiplier calculation
- **Event Emission**: Comprehensive logging for analytics

**Core Functions:**
```solidity
// Distribute vRDAT based on new staking position
function distributeForStaking(
    address staker,
    uint256 stakedAmount,
    uint256 lockPeriod,
    uint256 positionId
) external onlyRole(STAKING_MANAGER_ROLE) nonReentrant {
    require(stakedAmount > 0, "Invalid staked amount");
    
    // Calculate vRDAT amount
    uint256 vrdatAmount = calculatevRDATAmount(
        stakedAmount,
        block.timestamp - stakingStartTime[staker],
        lockPeriod
    );
    
    // Apply distribution caps
    require(
        distributedAmounts[staker] + vrdatAmount <= MAX_PER_ADDRESS,
        "Exceeds per-address cap"
    );
    
    // Mint vRDAT tokens
    vRDAT.mint(staker, vrdatAmount);
    
    // Update tracking
    distributedAmounts[staker] += vrdatAmount;
    positionDistributions[positionId] = vrdatAmount;
    
    emit vRDATDistributed(staker, vrdatAmount, positionId);
}

// Handle unstaking - decide whether to burn or retain vRDAT
function handleUnstaking(
    address staker,
    uint256 positionId,
    bool earlyExit
) external onlyRole(STAKING_MANAGER_ROLE) {
    uint256 vrdatAmount = positionDistributions[positionId];
    
    if (earlyExit && BURN_ON_EARLY_EXIT) {
        // Burn vRDAT for early unstaking
        vRDAT.burn(staker, vrdatAmount);
        emit vRDATBurned(staker, vrdatAmount, positionId);
    }
    
    // Clean up tracking
    delete positionDistributions[positionId];
}

// Batch distribute for multiple stakers
function batchDistribute(
    DistributionData[] calldata distributions
) external onlyRole(DISTRIBUTOR_ROLE) nonReentrant {
    for (uint256 i = 0; i < distributions.length; i++) {
        _distributevRDAT(distributions[i]);
    }
}
```

**Distribution Caps & Limits:**
```solidity
// Distribution limits to prevent gaming
uint256 public constant MAX_PER_ADDRESS = 10_000_000e18; // 10M vRDAT max per address
uint256 public constant MAX_TOTAL_SUPPLY = 1_000_000_000e18; // 1B vRDAT max supply
uint256 public constant MIN_STAKING_DURATION = 7 days; // Minimum for vRDAT eligibility

// Time-based distribution tracking
mapping(address => uint256) public stakingStartTime;
mapping(address => uint256) public distributedAmounts;
mapping(uint256 => uint256) public positionDistributions; // positionId => vRDAT amount
```

### 3. Governance Integration: `vRDATGovernance.sol`

**Inheritance Structure:**
```solidity
contract vRDATGovernance is 
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable
```

**Key Features:**
- **Voting Power Calculation**: Real-time voting power from vRDAT balance
- **Quadratic Integration**: Support for quadratic voting mechanics
- **Delegation Support**: Vote delegation without token transfer
- **Multi-position Voting**: Separate voting with different staking positions
- **Snapshot Integration**: Historical voting power queries

**Core Functions:**
```solidity
// Get current voting power for address
function getVotingPower(address account) external view returns (uint256) {
    return vRDAT.getVotes(account);
}

// Get historical voting power at specific block
function getVotingPowerAt(
    address account,
    uint256 blockNumber
) external view returns (uint256) {
    return vRDAT.getPastVotes(account, blockNumber);
}

// Calculate quadratic voting cost
function calculateQuadraticCost(
    address voter,
    uint256 votesToCast
) external view returns (uint256) {
    uint256 votingPower = getVotingPower(voter);
    require(votesToCast <= votingPower, "Insufficient voting power");
    
    // Quadratic cost: votes²
    return votesToCast * votesToCast;
}

// Delegate voting power (without transferring tokens)
function delegateVotes(address delegatee) external {
    vRDAT.delegate(delegatee);
    emit VotesDelegated(msg.sender, delegatee);
}

// Get effective voting power including delegations
function getEffectiveVotingPower(address account) external view returns (uint256) {
    return vRDAT.getVotes(account); // Includes delegated power
}
```

### 4. Anti-Gaming System: `vRDATSecurity.sol`

**Inheritance Structure:**
```solidity
contract vRDATSecurity is 
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable
```

**Key Features:**
- **Sybil Resistance**: Identity-based distribution limits
- **Gaming Detection**: Unusual staking pattern monitoring
- **Rate Limiting**: Distribution frequency controls
- **Circuit Breakers**: Automatic protection mechanisms
- **Penalty Systems**: Penalties for detected gaming

**Core Functions:**
```solidity
// Check if distribution is allowed (anti-gaming)
function isDistributionAllowed(
    address staker,
    uint256 amount
) external view returns (bool, string memory reason) {
    // Check daily limits
    if (dailyDistributions[staker][today()] + amount > DAILY_LIMIT) {
        return (false, "Daily limit exceeded");
    }
    
    // Check for suspicious patterns
    if (_isSuspiciousPattern(staker)) {
        return (false, "Suspicious activity detected");
    }
    
    // Check global rate limits
    if (totalDailyDistributions[today()] + amount > GLOBAL_DAILY_LIMIT) {
        return (false, "Global daily limit exceeded");
    }
    
    return (true, "");
}

// Detect gaming patterns
function _isSuspiciousPattern(address staker) internal view returns (bool) {
    // Check for rapid stake/unstake cycles
    uint256 recentTransactions = stakingTransactionCount[staker][today()];
    if (recentTransactions > SUSPICIOUS_TRANSACTION_THRESHOLD) {
        return true;
    }
    
    // Check for coordinated behavior with other addresses
    if (_isCoordinatedBehavior(staker)) {
        return true;
    }
    
    return false;
}

// Emergency pause distribution
function emergencyPause() external onlyRole(EMERGENCY_ROLE) {
    _pause();
    emit EmergencyPaused(msg.sender);
}
```

### 5. Analytics & Metrics: `vRDATAnalytics.sol`

**Inheritance Structure:**
```solidity
contract vRDATAnalytics is 
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable
```

**Key Features:**
- **Distribution Tracking**: Real-time distribution monitoring
- **Voting Power Analysis**: Concentration and distribution metrics
- **Participation Metrics**: Governance engagement tracking
- **Staking Correlation**: Staking-to-vRDAT relationship analysis
- **Gaming Detection**: Suspicious activity monitoring

**Core Functions:**
```solidity
// Get distribution statistics
function getDistributionStats() external view returns (DistributionStats memory) {
    return DistributionStats({
        totalDistributed: vRDAT.totalSupply(),
        uniqueHolders: holderCount,
        averageBalance: vRDAT.totalSupply() / holderCount,
        concentrationIndex: _calculateConcentrationIndex(),
        dailyDistribution: totalDailyDistributions[today()]
    });
}

// Calculate voting power concentration (Gini coefficient)
function _calculateConcentrationIndex() internal view returns (uint256) {
    // Implementation of Gini coefficient for voting power distribution
    // Returns value from 0 (perfect equality) to 10000 (maximum concentration)
}

// Track governance participation
function recordVote(
    address voter,
    uint256 proposalId,
    uint256 votingPower
) external onlyRole(GOVERNANCE_ROLE) {
    participationHistory[voter].push(ParticipationRecord({
        proposalId: proposalId,
        votingPower: votingPower,
        timestamp: block.timestamp
    }));
    
    emit GovernanceParticipation(voter, proposalId, votingPower);
}
```

## 🧪 Testing Strategy

### Unit Tests
1. **vRDAT Token Contract**
   - Non-transferability enforcement
   - Minting and burning functionality
   - Voting power delegation
   - Snapshot functionality
   - Access control verification

2. **Distribution Manager**
   - Staking-based distribution accuracy
   - Time-weighted multiplier calculation
   - Distribution cap enforcement
   - Batch processing efficiency
   - Anti-gaming mechanism validation

3. **Governance Integration**
   - Voting power calculation accuracy
   - Quadratic cost calculation
   - Delegation mechanics
   - Historical balance queries
   - Multi-position voting support

4. **Security Systems**
   - Gaming pattern detection
   - Rate limiting enforcement
   - Emergency pause functionality
   - Sybil resistance validation
   - Circuit breaker activation

### Economic Model Testing
1. **Distribution Economics**
   - Fair distribution formula validation
   - Time-based multiplier effectiveness
   - Long-term staking incentive analysis
   - Voting power concentration prevention
   - Economic attack scenario modeling

2. **Governance Impact**
   - Voting power distribution fairness
   - Quadratic voting effectiveness
   - Delegation behavior analysis
   - Participation incentive validation
   - Democratic representation testing

### Security Testing
1. **Gaming Resistance**
   - Sybil attack prevention
   - Vote buying resistance (non-transferability)
   - Coordinated gaming detection
   - Flash loan attack prevention
   - Identity spoofing prevention

2. **Smart Contract Security**
   - Transfer function override security
   - Access control validation
   - Emergency function security
   - Upgrade mechanism protection
   - Integration security validation

### Integration Tests
1. **Staking System Integration**
   - Automatic vRDAT distribution
   - Position-based calculation
   - Unstaking behavior validation
   - Multi-pool integration
   - Reward synchronization

2. **Governance System Integration**
   - Voting power integration
   - Proposal participation
   - Delegation functionality
   - Quorum calculation
   - Historical vote tracking

## 🚀 Deployment Strategy

### Local Development
1. **Mock Contracts**
   - MockStaking for distribution testing
   - MockGovernance for voting integration
   - Test distribution scenarios
   - Gaming attempt simulation
   - Economic model validation

2. **Development Scripts**
   - `DeployvRDAT.s.sol`
   - `ConfigureDistribution.s.sol`
   - `SetupGovernanceIntegration.s.sol`
   - `PopulateTestData.s.sol`

### Testnet Deployment
1. **Vana Moksha** (Full System Testing)
   - Deploy complete vRDAT system
   - Integration with testnet staking
   - Governance integration testing
   - Anti-gaming system validation
   - Security audit preparation

### Mainnet Deployment
1. **Vana Mainnet** (Production vRDAT)
   - Production vRDAT system deployment
   - Integration with live staking system
   - Governance system activation
   - Security monitoring setup
   - Community distribution launch

## 🔒 Security & Audit Strategy

### OpenZeppelin Integration
- **ERC20Votes**: Proven governance token patterns
- **AccessControl**: Role-based permissions
- **Upgradeable Contracts**: UUPS pattern for improvements
- **Security Utils**: ReentrancyGuard, Pausable
- **ERC20Permit**: Gasless approvals for enhanced UX

### Audit Preparation
1. **Non-Transferability Verification**
   - Transfer function override correctness
   - Soul-bound implementation security
   - Vote buying prevention validation
   - Delegation without transfer verification
   - Emergency transfer prevention

2. **Distribution Accuracy**
   - Mathematical formula verification
   - Time-weighted calculation accuracy
   - Distribution cap enforcement
   - Gaming resistance validation
   - Economic model integrity

3. **Code Review Checklist**
   - Transfer prevention completeness
   - Access control validation
   - Distribution formula accuracy
   - Anti-gaming mechanism effectiveness
   - Emergency procedure security

## 💰 Economic Model

### Distribution Formula
- **Base Distribution**: 1 vRDAT per 1 RDAT staked
- **Time Multiplier**: 10% bonus per month (capped at 100%)
- **Lock Period Multiplier**: Matches staking multipliers (1x to 4x)
- **Maximum per Address**: 10M vRDAT to prevent concentration
- **Total Supply Cap**: 1B vRDAT maximum

### Staking Integration
- **Automatic Distribution**: vRDAT minted when RDAT is staked
- **Position-Based**: Each staking position generates separate vRDAT
- **Early Exit Penalty**: Optional vRDAT burning for early unstaking
- **Loyalty Rewards**: Increased vRDAT for longer staking duration

### Governance Rights
- **Voting Power**: 1 vRDAT = 1 vote in governance
- **Quadratic Voting**: Support for quadratic cost scaling
- **Delegation**: Vote delegation without token transfer
- **Multi-position**: Vote separately with different positions

## 🎯 Success Metrics

### Distribution Metrics
- **Distribution Accuracy**: 100% accurate formula implementation
- **Gaming Resistance**: Zero successful gaming attempts
- **Fair Distribution**: Gini coefficient <0.5 for voting power
- **Participation Incentive**: 20% increase in average staking duration
- **System Uptime**: 99.9% distribution system availability

### Governance Metrics
- **Voting Participation**: 25% of vRDAT holders actively voting
- **Power Concentration**: <20% voting power held by top 10 addresses
- **Delegation Rate**: 40% of vRDAT delegated to representatives
- **Proposal Quality**: 80% of proposals reach voting threshold
- **Democratic Health**: Balanced proposal outcomes

### Technical Metrics
- **Non-Transferability**: 100% transfer prevention success
- **Gas Efficiency**: <150k gas per distribution operation
- **Query Performance**: <100ms for voting power calculations
- **Security**: Zero critical vulnerabilities
- **Integration**: Seamless staking and governance integration

## 📋 Deployment Scripts Required

### 1. `DeployvRDAT.s.sol`
```solidity
// Deploy vRDAT token with non-transferable features
// Configure voting and governance integration
// Set up access control roles
// Initialize distribution parameters
```

### 2. `DeployDistribution.s.sol`
```solidity
// Deploy distribution manager
// Configure staking integration
// Set up anti-gaming mechanisms
// Initialize security monitoring
```

### 3. `ConfigureGovernanceIntegration.s.sol`
```solidity
// Connect to governance contracts
// Configure voting power calculation
// Set up delegation mechanisms
// Initialize quadratic voting support
```

### 4. `SetupSecurity.s.sol`
```solidity
// Deploy security and anti-gaming contracts
// Configure detection mechanisms
// Set up circuit breakers
// Initialize monitoring systems
```

---

**Document Version**: 2.4  
**Created**: November 2024  
**Last Updated**: November 2024  
**Status**: Ready for Implementation  
**VRC-20 Compliance**: See [VRC20_COMPLIANCE.md](../docs/VRC20_COMPLIANCE.md)