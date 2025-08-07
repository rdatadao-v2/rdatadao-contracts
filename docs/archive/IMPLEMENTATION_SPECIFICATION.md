# 📐 RDAT V2 Implementation Specification

**Version**: 1.0 - Authoritative Source  
**Date**: August 6, 2025  
**Purpose**: Single source of truth for all implementation parameters  
**Status**: Resolves all documentation conflicts

## 🎯 Core Parameters (Final)

### Token Economics
- **Total Supply**: 100,000,000 RDAT (fixed forever)
- **Initial Distribution**:
  - TreasuryWallet: 70,000,000 RDAT (70%)
  - Migration Contract: 30,000,000 RDAT (30%)
- **Minting**: Disabled permanently (mint() always reverts)

### DAO-Approved Allocations (from 70M in TreasuryWallet)
Per DAO vote 0xa0c701b7f26855b3861e150fb31d637f70ae6f50cb4e1c92e2b5675a048a54bb:

- **Migration Reserve**: 30,000,000 RDAT (30%)
  - 100% unlocked at TGE
  - Already allocated to MigrationBridge contract
  
- **Future Rewards**: 30,000,000 RDAT (30%)
  - 0% unlocked at TGE
  - Unlocks when Phase 3 is activated
  - Split determined by future DAO vote between:
    - Staking rewards (via RDATRewardModule)
    - Data contributor rewards
    - Other future incentive programs
  - Note: vRDAT activation requires 50% migration + 3 epoch cooldown per snapshot vote
  
- **Treasury & Ecosystem Development**: 25,000,000 RDAT (25%)
  - Breakdown:
    - 10M for team allocation (requires DAO vote to transfer to TokenVesting)
    - 2.5M unlocked at TGE (10%)
    - 12.5M for general treasury operations, partnerships, ecosystem grants
  - 10% unlocked at TGE (2.5M RDAT)
  - 6-month cliff, then 5% monthly (1.25M/month)
  
- **Liquidity & Staking**: 15,000,000 RDAT (15%)
  - 33% unlocked at TGE for liquidity (exactly 4.95M RDAT)
  - Remaining 67% for staking incentives (10.05M RDAT)
    - Separate from Future Rewards staking allocation
    - Used for: LP incentives, vRDAT boost campaigns, early staker bonuses
    - Distributed at admin/DAO discretion during Phase 1-2

### Staking Parameters
**Lock Periods & Multipliers**:
- 30 days: 1.00x rewards, 0.083x vRDAT (8.3%)
- 90 days: 1.15x rewards, 0.247x vRDAT (24.7%)
- 180 days: 1.35x rewards, 0.493x vRDAT (49.3%)
- 365 days: 1.75x rewards, 1.000x vRDAT (100%)

**Security Limits**:
- Minimum stake: 1 RDAT (1e18 wei)
- Maximum positions per user: 100
- Maximum vRDAT per address: 10,000,000

## 🏗️ Contract Architecture

### 1. **RDATUpgradeable.sol** (UUPS Upgradeable)
- **Purpose**: Main ERC-20 token with VRC-20 compliance
- **Initialize Parameters**: `(address treasuryWallet, address admin, address migrationContract)`
- **Roles**: DEFAULT_ADMIN_ROLE, PAUSER_ROLE, UPGRADER_ROLE
- **No MINTER_ROLE**: This role does not exist
- **Initial Mint**: 70M to TreasuryWallet, 30M to MigrationBridge

### 2. **vRDAT.sol** (Non-upgradeable)
- **Purpose**: Soul-bound governance token
- **Roles**: MINTER_ROLE, BURNER_ROLE, PAUSER_ROLE
- **Mint Delay**: None (soul-bound tokens can't be flash loaned)
- **Transfer**: Always reverts (soul-bound)

### 3. **StakingPositions.sol** (Non-upgradeable)
**Official Name**: StakingPositions (not StakingManager)
- **Purpose**: NFT-based position tracking
- **Rewards**: Does NOT calculate or distribute rewards
- **Migration**: Manual migration pattern for upgrades
- **Dependencies**: None required (can operate independently)

### 4. **RewardsManager.sol** (UUPS Upgradeable)
- **Purpose**: Orchestrates all reward distributions
- **Module Registration**: Immediate (no timelock currently)
- **Batch Claims**: Supported across all programs
- **Emergency**: Can pause individual programs

### 5. **Reward Modules** (Non-upgradeable)
**vRDATRewardModule**:
- Mints vRDAT proportionally on stake
- Formula: `vRDAT = stakedAmount * (lockDays / 365)`
- Requires MINTER_ROLE on vRDAT
- Active at launch

**RDATRewardModule** (Phase 3 only):
- Distributes RDAT from pre-allocated pool
- Time-based accumulation with multipliers
- Funded from Future Rewards allocation (amount per future DAO vote)
- Deployed when Phase 3 activates

### 6. **TreasuryWallet.sol** (UUPS Upgradeable) 
- **Purpose**: Manages DAO-approved token allocations and vesting
- **Initial Balance**: 70,000,000 RDAT from deployment
- **Vesting Schedules**: Automatic unlock based on time and phase
- **Key Functions**:
  - `checkAndRelease()`: Processes time-based unlocks
  - `setPhase3Active()`: Unlocks Future Rewards allocation
  - `distribute()`: DAO-approved transfers
  - `executeDAOProposal()`: On-chain proposal execution
- **Initial Distribution Process**:
  - TreasuryWallet holds all funds until admin manually triggers distributions
  - Admin calls `distribute()` after migration verification
  - 4.95M RDAT to liquidity provision
  - 2.5M RDAT available for ecosystem

### 7. **MigrationBridge.sol** (Not Yet Implemented)
- **Allocation**: 30,000,000 RDAT pre-minted
- **Deadline**: 365 days from deployment (1 year)
- **Unclaimed**: Returns to TreasuryWallet after deadline
- **Security**: 2-of-3 validator signatures required

### 8. **RevenueCollector.sol** (Implementation Complete)
- **Fee Distribution**: 50% stakers, 30% treasury, 20% contributors
- **Fee Tokens**: VANA, USDC, USDT, or RDAT
- **Distribution Method**: 
  - Collects fees in original tokens
  - Admin triggers swap to RDAT (via Vana DEX)
  - Distributes RDAT: 50% to stakers, 30% to treasury, 20% to contributors
- **NO BURNING**: Fixed supply means no burn mechanism

### 9. **EmergencyPause.sol** (Simple Implementation)
- **Duration**: 72 hours fixed (auto-expires)
- **Extension**: Not implemented (upgradeable later if needed)
- **Scope**: Individual contracts check pause state

### 10. **ProofOfContribution.sol** (Stub Implementation)
- **Current**: Minimal stub for VRC-20 compliance
- **Future**: Full Vana DLP integration (post-launch)
- **Required For**: Mainnet Vana deployment only

## 📋 Deployment Sequence

### Phase 1: Core Infrastructure
1. Deploy EmergencyPause contract
2. Deploy CREATE2 factory (for deterministic addresses)
3. Calculate future contract addresses

### Phase 2: Token Deployment
```solidity
// 1. Deploy vRDAT (non-upgradeable)
vRDAT = new vRDAT(admin);

// 2. Calculate RDAT address using CREATE2
rdatAddress = computeCreate2Address(
    keccak256(bytecode),
    salt,
    factory
);

// 3. Deploy TreasuryWallet implementation and proxy
treasuryImpl = new TreasuryWallet();
treasuryProxy = new ERC1967Proxy(
    treasuryImpl,
    abi.encodeCall(initialize, (admin, rdatAddress))
);

// 4. Deploy MigrationBridge (regular deployment)
migrationBridge = new MigrationBridge();
migrationBridge.initialize(rdatAddress, validators);

// 5. Deploy RDAT via CREATE2 with calculated address
rdatImpl = new RDATUpgradeable();
rdatProxy = deployWithCreate2(
    bytecode,
    salt,
    abi.encodeCall(initialize, (treasuryProxy, admin, migrationBridge))
);
// Verifies: address(rdatProxy) == rdatAddress
```

### Phase 3: Staking System
```solidity
// 1. Deploy StakingPositions (non-upgradeable)
stakingPositions = new StakingPositions();
stakingPositions.initialize(rdat, vrdat, admin);

// 2. Deploy RewardsManager
rewardsManagerImpl = new RewardsManager();
rewardsProxy = new ERC1967Proxy(
    rewardsManagerImpl,
    abi.encodeCall(initialize, (stakingPositions, admin))
);

// 3. Deploy reward modules
vrdatModule = new vRDATRewardModule(vrdat, stakingPositions, emergencyPause, admin);
rdatModule = new RDATRewardModule(rdat, stakingPositions, rewardsManager, admin);
```

### Phase 4: Configuration
```solidity
// 1. Grant roles
vrdat.grantRole(MINTER_ROLE, vrdatModule);
vrdat.grantRole(BURNER_ROLE, vrdatModule);

// 2. Configure TreasuryWallet vesting schedules
treasuryWallet.setupVestingSchedule(
    FUTURE_REWARDS, 
    30_000_000e18, 
    0, // No TGE unlock
    0, // No cliff
    0, // No vesting until Phase 3
    true // Phase 3 gated
);

treasuryWallet.setupVestingSchedule(
    TREASURY_ECOSYSTEM,
    25_000_000e18,
    2_500_000e18, // 10% TGE
    6 * 30 days, // 6 month cliff
    18 // 18 months vesting
    false // Time-based
);

// 3. Execute TGE distributions (admin manually triggers after migration verification)
treasuryWallet.checkAndRelease(); // Process TGE unlocks
treasuryWallet.distribute(liquidityProvider, 4_950_000e18); // Exactly 4.95M for liquidity

// 4. Register vRDAT program (RDAT rewards wait for Phase 3)
rewardsManager.registerProgram(vrdatModule, "vRDAT Governance", 0, 0);

// 5. Connect contracts
stakingPositions.setRewardsManager(rewardsManager);
vrdatModule.updateRewardsManager(rewardsManager);
```

## 🔐 Security Model

### Access Control Hierarchy
```
Admin (Multisig)
├── Can pause contracts
├── Can upgrade RDAT and RewardsManager
├── Can register new reward programs
├── Cannot mint tokens
└── Cannot modify staked positions

Stakers
├── Can create/view positions
├── Can claim rewards
├── Can emergency migrate
└── Cannot transfer positions

Modules
├── vRDATModule can mint/burn vRDAT
├── RDATModule can transfer its balance
└── Cannot modify staking positions
```

### Critical Invariants
1. RDAT total supply always equals 100M
2. vRDAT is always soul-bound (non-transferable)
3. Staking positions are immutable once created
4. Reward calculations are deterministic
5. Emergency pause auto-expires after 72 hours

## 🚦 Migration Path

### From V1 to V2
1. V1 holders initiate bridge transaction on Base
2. Validators confirm and sign attestation
3. V2 tokens released from pre-allocated pool
4. 1:1 conversion rate (V1 supply ⊂ V2 supply)

### Future Staking Upgrades
1. Deploy new StakingPositionsV2 contract
2. Enable emergency migration on V1
3. Users withdraw with proportional rewards
4. Users restake in V2 contract
5. Disable V1 after migration period

## 📊 Economic Sustainability

### Reward Distribution Timeline
- **Year 1**: ~10M RDAT distributed (high APR)
- **Year 2**: ~7M RDAT distributed (medium APR)
- **Year 3**: ~3M RDAT distributed (low APR)
- **Year 4+**: Fee-based rewards only

### Fee-Based Model (Post-Depletion)
1. Protocol generates fees in various tokens
2. RevenueCollector receives all fees
3. 50% converted to RDAT (market buy)
4. Distributed to stakers proportionally
5. Creates sustainable buy pressure

## ✅ Resolved Conflicts

1. **Naming**: StakingPositions (not StakingManager)
2. **vRDAT Formula**: Discrete multipliers (not continuous)
3. **Reward Pool**: Future Rewards split determined by DAO vote
4. **Deployment**: CREATE2 for RDAT to resolve circular dependency
5. **Module Security**: Future timelock implementation
6. **Fee Burning**: No burning (contributor pool instead)
7. **PoC Status**: Stub for now, full implementation later
8. **Liquidity Amount**: Exactly 4.95M RDAT (not rounded to 5M)
9. **Team Tokens**: Requires DAO vote to transfer from Treasury to TokenVesting
10. **Initial Distributions**: Admin manually triggers after migration verification

## 🎯 Success Criteria

### Pre-Mainnet Checklist
- [ ] All contracts deployed to testnet
- [ ] Future Rewards allocation ready (split TBD by DAO)
- [ ] Migration bridge tested with mock V1
- [ ] Emergency pause tested across contracts
- [ ] Reward distribution verified
- [ ] Gas optimization completed
- [ ] Security audit passed
- [ ] TokenVesting contract implemented for team allocation

### Post-Launch Metrics
- [ ] 10M+ RDAT staked in first month
- [ ] 1000+ unique stakers
- [ ] Zero security incidents
- [ ] <$0.10 gas per transaction
- [ ] 95%+ uptime

---

**This document supersedes all previous specifications and serves as the authoritative source for implementation details.**