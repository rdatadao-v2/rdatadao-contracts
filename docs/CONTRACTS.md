# Smart Contract Reference

**Last Updated**: September 20, 2025
**Audit Status**: Hashlock Audited ✅

## 📝 Contract Overview

### Deployed Contracts (Mainnet)

| Contract | Address | Network | Status |
|----------|---------|---------|--------|
| RDATUpgradeable | `0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E` | Vana | Live ✅ |
| TreasuryWallet | `0x77D2713972af12F1E3EF39b5395bfD65C862367C` | Vana | Live ✅ |
| VanaMigrationBridge | `0x9d4aB2d3fb25D414dba1d9D22200356b5984D35E` | Vana | Live ✅ |
| RDATDataDAO | `0xBbB0B59163b850dDC5139e98118774557c5d9F92` | Vana | Live ✅ |
| BaseMigrationBridge | `0xa4435b45035a483d364de83B9494BDEFA8322626` | Base | Live ✅ |

### Phase 2 Contracts (Ready for Deployment)

| Contract | Purpose | Upgrade | Status |
|----------|---------|---------|--------|
| StakingPositions | NFT-based staking | No | Tested ✅ |
| vRDAT | Governance token | No | Tested ✅ |
| RewardsManager | Reward orchestration | Yes (UUPS) | Tested ✅ |
| GovernanceCore | Proposal management | No | Tested ✅ |
| RevenueCollector | Fee distribution | No | Tested ✅ |

## 🪙 RDATUpgradeable

**Purpose**: Main ERC-20/VRC-20 compliant token with fixed 100M supply

### Key Features
- Fixed supply: 100,000,000 RDAT (no minting)
- UUPS upgradeable pattern
- Pausable for emergencies
- DLP integration (ID: 40)
- Blacklist capability (VRC-20 compliance)

### Constructor Parameters
```solidity
initialize(
    address _treasury,      // Treasury contract address
    address _admin,         // Admin multisig address
    address _migrationBridge // Migration bridge address
)
```

### Core Functions

#### User Functions
```solidity
// Standard ERC-20
function transfer(address to, uint256 amount) external returns (bool)
function approve(address spender, uint256 amount) external returns (bool)
function transferFrom(address from, address to, uint256 amount) external returns (bool)
function balanceOf(address account) external view returns (uint256)
function allowance(address owner, address spender) external view returns (uint256)

// VRC-20 Compliance
function blacklist(address account) external onlyRole(DEFAULT_ADMIN_ROLE)
function unblacklist(address account) external onlyRole(DEFAULT_ADMIN_ROLE)
function isBlacklisted(address account) external view returns (bool)
```

#### Admin Functions
```solidity
// Emergency controls
function pause() external onlyRole(PAUSER_ROLE)
function unpause() external onlyRole(PAUSER_ROLE)

// DLP management
function setDlpId(uint256 _dlpId) external onlyRole(DEFAULT_ADMIN_ROLE)
function setDlpRegistry(address _registry) external onlyRole(DEFAULT_ADMIN_ROLE)

// Upgrade function (UUPS)
function upgradeTo(address newImplementation) external onlyRole(UPGRADER_ROLE)
```

### Events
```solidity
event Transfer(address indexed from, address indexed to, uint256 value)
event Approval(address indexed owner, address indexed spender, uint256 value)
event Blacklisted(address indexed account)
event Unblacklisted(address indexed account)
event DlpIdUpdated(uint256 oldId, uint256 newId)
event Paused(address account)
event Unpaused(address account)
```

### Security Features
- ReentrancyGuard on all external calls
- Role-based access control
- 72-hour auto-expiry on pause
- No minting capability (mint() always reverts)

## 💼 TreasuryWallet

**Purpose**: Manages 70M RDAT with vesting schedules and DAO proposals

### Allocation Structure
```solidity
struct Allocation {
    string name;           // "Team", "Development", etc.
    uint256 totalAmount;   // Total allocated
    uint256 released;      // Amount released
    uint256 cliff;         // Cliff period
    uint256 vestingPeriod; // Total vesting duration
    uint256 startTime;     // Vesting start
}
```

### Core Functions

#### View Functions
```solidity
function getBalance() external view returns (uint256)
function getAllocation(string memory name) external view returns (Allocation memory)
function getAvailableAmount(string memory name) external view returns (uint256)
function totalAllocated() external view returns (uint256)
function totalReleased() external view returns (uint256)
```

#### Admin Functions
```solidity
// Execute DAO proposals
function executeDAOProposal(
    address to,
    uint256 amount,
    string memory reason
) external onlyRole(DEFAULT_ADMIN_ROLE)

// Recover slashed tokens
function withdrawPenalties() external onlyRole(DEFAULT_ADMIN_ROLE)

// Update vesting parameters
function updateVesting(
    string memory allocation,
    uint256 newCliff,
    uint256 newVestingPeriod
) external onlyRole(DEFAULT_ADMIN_ROLE)
```

### Vesting Schedules
| Allocation | Amount | Cliff | Vesting | Total Period |
|------------|--------|-------|---------|--------------|
| Team | 10M | 6 months | 18 months | 24 months |
| Development | 20M | None | Immediate | Immediate |
| Community | 30M | Phase 3 | TBD | TBD |
| Reserve | 10M | None | As needed | Flexible |

## 🌉 VanaMigrationBridge

**Purpose**: Processes V1→V2 token migration with validator signatures

### Key Features
- Requires 2/3 validator signatures
- 6-hour challenge period
- 7-day admin override
- One-time migration per address
- 30M RDAT allocation

### Core Functions

#### User Functions
```solidity
// Complete migration with signatures
function processMigration(
    address user,
    uint256 amount,
    bytes32 migrationId,
    bytes[] memory signatures
) external returns (bool)

// Check migration status
function hasMigrated(address user) external view returns (bool)
function getMigrationAmount(address user) external view returns (uint256)
```

#### View Functions
```solidity
function totalMigrated() external view returns (uint256)
function remainingAllocation() external view returns (uint256)
function isValidator(address account) external view returns (bool)
function requiredSignatures() external view returns (uint256)
```

#### Admin Functions
```solidity
// Validator management
function addValidator(address validator) external onlyRole(DEFAULT_ADMIN_ROLE)
function removeValidator(address validator) external onlyRole(DEFAULT_ADMIN_ROLE)
function setRequiredSignatures(uint256 count) external onlyRole(DEFAULT_ADMIN_ROLE)

// Emergency override (after 7 days)
function adminOverrideMigration(
    address user,
    uint256 amount,
    bytes32 migrationId
) external onlyRole(DEFAULT_ADMIN_ROLE)
```

### Migration Process
1. User initiates on Base (burns V1)
2. Backend collects validator signatures
3. User submits signatures to Vana bridge
4. Bridge verifies and mints V2 tokens

## 🌉 BaseMigrationBridge

**Purpose**: Initiates migration by locking and burning V1 tokens

### Core Functions

```solidity
// Initiate migration
function initiateMigration(uint256 amount) external returns (bytes32)

// View migration status
function getMigrationStatus(bytes32 migrationId) external view returns (
    address user,
    uint256 amount,
    uint256 timestamp,
    bool processed
)

// Emergency functions
function pause() external onlyRole(PAUSER_ROLE)
function unpause() external onlyRole(PAUSER_ROLE)
```

### Events
```solidity
event MigrationInitiated(
    address indexed user,
    uint256 amount,
    bytes32 indexed migrationId
)
event TokensBurned(address indexed user, uint256 amount)
```

## 📊 RDATDataDAO

**Purpose**: Vana DLP integration for data contribution rewards

### Key Features
- DLP ID: 40
- Registered with Vana network
- Distributes rewards to data contributors

### Core Functions

```solidity
// Data contribution tracking
function recordContribution(
    address contributor,
    uint256 dataPoints,
    string memory dataType
) external onlyRole(VALIDATOR_ROLE)

// Reward distribution
function distributeRewards(
    address[] memory contributors,
    uint256[] memory amounts
) external onlyRole(DEFAULT_ADMIN_ROLE)

// View functions
function getContribution(address contributor) external view returns (uint256)
function totalContributions() external view returns (uint256)
function dlpId() external view returns (uint256)
```

## 🔒 StakingPositions (Phase 2)

**Purpose**: NFT-based staking with time-lock multipliers

### Position Structure
```solidity
struct Position {
    uint256 amount;        // RDAT staked
    uint256 startTime;     // When staked
    uint256 lockDuration;  // 30/90/180/365 days
    uint256 multiplier;    // 100/115/135/175 (1x-1.75x)
    address owner;         // Position owner
    bool active;           // Is active
}
```

### Staking Parameters
| Duration | Multiplier | vRDAT Ratio |
|----------|------------|-------------|
| 30 days | 1.00x | 1:1 |
| 90 days | 1.15x | 1:1.15 |
| 180 days | 1.35x | 1:1.35 |
| 365 days | 1.75x | 1:1.75 |

### Core Functions

```solidity
// Create staking position
function stake(uint256 amount, uint256 lockDuration) external returns (uint256 positionId)

// View position details
function getPosition(uint256 positionId) external view returns (Position memory)

// Withdraw after lock period
function withdraw(uint256 positionId) external

// Emergency withdraw (50% penalty)
function emergencyWithdraw(uint256 positionId) external

// Admin migration function
function enableEmergencyMigration() external onlyRole(DEFAULT_ADMIN_ROLE)
```

### Security Features
- Maximum 50 positions per user (DoS protection)
- Non-upgradeable for security
- EnumerableSet for efficient enumeration
- Reentrancy protection

## 🗳️ vRDAT (Phase 2)

**Purpose**: Soul-bound governance token for voting power

### Key Features
- Non-transferable (soul-bound)
- Minted proportionally to staking
- Burned for quadratic voting
- No max supply

### Core Functions

```solidity
// Minting (only by RewardModule)
function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE)

// Burning for voting
function burn(uint256 amount) external
function burnFrom(address account, uint256 amount) external

// View functions
function balanceOf(address account) external view returns (uint256)
function totalSupply() external view returns (uint256)

// Transfer functions (all revert - soul-bound)
function transfer(address, uint256) external pure returns (bool) {
    revert("vRDAT: soul-bound token");
}
```

## 💎 RewardsManager (Phase 2)

**Purpose**: Orchestrates modular reward distribution

### Architecture
- UUPS upgradeable for flexibility
- Supports multiple reward modules
- Lazy reward calculation
- Gas-optimized batch claims

### Core Functions

```solidity
// Module management
function registerModule(address module) external onlyRole(DEFAULT_ADMIN_ROLE)
function removeModule(address module) external onlyRole(DEFAULT_ADMIN_ROLE)
function setModuleActive(address module, bool active) external onlyRole(DEFAULT_ADMIN_ROLE)

// Staking notifications
function notifyStake(address user, uint256 positionId, uint256 amount, uint256 duration) external
function notifyUnstake(address user, uint256 positionId) external

// User functions
function claimRewards(uint256 positionId) external
function claimAllRewards() external
function getClaimableRewards(address user) external view returns (uint256)
```

## 🏛️ GovernanceCore (Phase 2)

**Purpose**: On-chain governance with timelock execution

### Proposal Structure
```solidity
struct Proposal {
    uint256 id;
    address proposer;
    string description;
    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    uint256 startTime;
    uint256 endTime;
    uint256 forVotes;
    uint256 againstVotes;
    uint256 abstainVotes;
    ProposalState state;
}
```

### Governance Parameters
```solidity
uint256 constant PROPOSAL_THRESHOLD = 10000e18;  // 10k vRDAT
uint256 constant VOTING_PERIOD = 3 days;
uint256 constant TIMELOCK_DELAY = 48 hours;
uint256 constant QUORUM = 4;  // 4% of total vRDAT
```

### Core Functions

```solidity
// Create proposal
function propose(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    string memory description
) external returns (uint256 proposalId)

// Vote on proposal
function castVote(uint256 proposalId, uint8 support) external
function castVoteWithReason(uint256 proposalId, uint8 support, string memory reason) external

// Execute proposal
function queue(uint256 proposalId) external
function execute(uint256 proposalId) external

// View functions
function getProposal(uint256 proposalId) external view returns (Proposal memory)
function state(uint256 proposalId) external view returns (ProposalState)
function hasVoted(uint256 proposalId, address account) external view returns (bool)
```

## 💰 RevenueCollector (Phase 2)

**Purpose**: Collects and distributes protocol revenue

### Distribution Model
```solidity
uint256 constant STAKERS_SHARE = 50;      // 50%
uint256 constant TREASURY_SHARE = 30;     // 30%
uint256 constant CONTRIBUTORS_SHARE = 20; // 20%
```

### Core Functions

```solidity
// Collect revenue
function collectRevenue(address token) external

// Distribute revenue
function distributeRevenue(address token) external

// Update distribution targets
function setStakingRewardsPool(address pool) external onlyRole(DEFAULT_ADMIN_ROLE)
function setTreasuryAddress(address treasury) external onlyRole(DEFAULT_ADMIN_ROLE)
function setContributorPool(address pool) external onlyRole(DEFAULT_ADMIN_ROLE)

// View functions
function getPendingRevenue(address token) external view returns (uint256)
function getDistributionTargets() external view returns (
    address staking,
    address treasury,
    address contributors
)
```

## 🚨 EmergencyPause

**Purpose**: Shared emergency pause functionality

### Features
- 72-hour auto-expiry
- Multi-contract coordination
- Role-based activation

### Core Functions

```solidity
// Pause operations
function pause() external onlyRole(PAUSER_ROLE)

// Unpause operations
function unpause() external onlyRole(PAUSER_ROLE)

// Check pause status
function paused() external view returns (bool)
function pauseExpiry() external view returns (uint256)

// Auto-expiry check
function checkAutoExpiry() external
```

## 🏭 Create2Factory

**Purpose**: Deterministic contract deployment

### Core Function

```solidity
function deploy(
    bytes32 salt,
    bytes memory bytecode
) external returns (address)

// Compute deployment address
function computeAddress(
    bytes32 salt,
    bytes memory bytecode
) external view returns (address)
```

## 📦 TokenVesting

**Purpose**: Vesting contracts for team and advisors

### Vesting Structure
```solidity
struct VestingSchedule {
    address beneficiary;
    uint256 totalAmount;
    uint256 cliff;
    uint256 duration;
    uint256 startTime;
    uint256 released;
    bool revocable;
}
```

### Core Functions

```solidity
// Create vesting schedule
function createVesting(
    address beneficiary,
    uint256 amount,
    uint256 cliff,
    uint256 duration,
    bool revocable
) external onlyRole(DEFAULT_ADMIN_ROLE)

// Claim vested tokens
function claim(uint256 scheduleId) external

// View vesting details
function getVestingSchedule(uint256 scheduleId) external view returns (VestingSchedule memory)
function getVestedAmount(uint256 scheduleId) external view returns (uint256)

// Admin functions
function revoke(uint256 scheduleId) external onlyRole(DEFAULT_ADMIN_ROLE)
```

## 🔐 Access Control Roles

### Role Definitions

| Role | Permissions | Holders |
|------|------------|---------|
| DEFAULT_ADMIN_ROLE | Full control | Multisig (3/5) |
| PAUSER_ROLE | Pause/unpause | Multisig (2/5) |
| UPGRADER_ROLE | Contract upgrades | Multisig (3/5) |
| TREASURY_ROLE | Treasury operations | Treasury contract |
| MINTER_ROLE | Mint vRDAT | RewardModule only |
| VALIDATOR_ROLE | Sign migrations | 3 validators |

## ⚡ Gas Optimization

### Gas Costs (Estimated)

| Operation | Gas Cost | USD (@50 gwei) |
|-----------|----------|----------------|
| Transfer | ~65,000 | ~$3.25 |
| Stake | ~150,000 | ~$7.50 |
| Claim Rewards | ~80,000 | ~$4.00 |
| Vote | ~100,000 | ~$5.00 |
| Migration | ~200,000 | ~$10.00 |

### Optimization Techniques
- Packed structs for storage efficiency
- EnumerableSet for O(1) operations
- Lazy reward calculation
- Batch operations support
- Minimal storage writes

## 🔍 Event Monitoring

### Critical Events to Monitor

```solidity
// Financial events
event Transfer(address indexed from, address indexed to, uint256 value)
event Staked(address indexed user, uint256 amount, uint256 duration)
event Withdrawn(address indexed user, uint256 amount)
event RewardsClaimed(address indexed user, uint256 amount)

// Governance events
event ProposalCreated(uint256 indexed proposalId)
event VoteCast(address indexed voter, uint256 indexed proposalId, uint8 support)
event ProposalExecuted(uint256 indexed proposalId)

// Security events
event Paused(address account)
event Unpaused(address account)
event RoleGranted(bytes32 indexed role, address indexed account)
event RoleRevoked(bytes32 indexed role, address indexed account)
```

## 📝 Integration Checklist

### For Frontend Developers
- [ ] Import contract ABIs
- [ ] Configure network connections
- [ ] Implement wallet connection
- [ ] Add transaction handlers
- [ ] Handle contract events
- [ ] Implement error handling
- [ ] Add loading states
- [ ] Test on testnet
- [ ] Monitor gas costs

### For Backend Developers
- [ ] Set up event listeners
- [ ] Implement signature collection
- [ ] Create API endpoints
- [ ] Add database schemas
- [ ] Implement caching
- [ ] Set up monitoring
- [ ] Configure alerts
- [ ] Document API

## 🛡️ Security Considerations

### Best Practices
1. Always verify addresses before transactions
2. Use multicall for batch operations
3. Implement proper error handling
4. Monitor for unusual patterns
5. Keep private keys secure
6. Use hardware wallets for admin operations
7. Test thoroughly on testnet
8. Maintain upgrade keys securely
9. Document all admin actions
10. Regular security audits