# 📚 RDAT V2 Master Reference Document

**Version**: 2.0  
**Date**: August 5, 2025  
**Status**: Living Document (VRC Compliance Update)  
**Purpose**: Single source of truth for all architectural decisions, specifications, and implementation details with full VRC-14/15/20 compliance

## 🎯 Quick Navigation

1. [Core Architecture](#core-architecture)
2. [Contract Specifications](#contract-specifications)
3. [Tokenomics](#tokenomics)
4. [Security Model](#security-model)
5. [Implementation Status](#implementation-status)
6. [Key Decisions](#key-decisions)

---

## 🏗️ Core Architecture

### Triple-Layer Design Pattern
```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│ Token Layer     │────▶│  Staking Layer   │────▶│ Rewards Layer   │
│ (Upgradeable)   │     │   (Immutable)    │     │  (Modular)      │
└─────────────────┘     └──────────────────┘     └─────────────────┘
```

**Benefits**:
- Maximum security for user funds (immutable staking)
- Flexibility for rewards without touching stakes
- Clean separation enables independent development
- No complex migrations for new reward programs

### Contract Count: 14 Total
1. **RDATUpgradeable** ✅ - Full VRC-20 compliant token
2. **vRDAT** ✅ - Soul-bound governance token
3. **StakingPositions** ✅ - Immutable staking logic
4. **RewardsManager** 🔴 - Upgradeable orchestrator
5. **vRDATRewardModule** ✅ - Proportional governance rewards
6. **RDATRewardModule** 🔴 - Time-based staking rewards
7. **MigrationBridge** 🔴 - Cross-chain migration
8. **EmergencyPause** ✅ - Shared emergency system
9. **RevenueCollector** 🔴 - Fee distribution (50/30/20)
10. **ProofOfContribution** 🔴 - Full DLP implementation
11. **Create2Factory** ✅ - Deterministic deployment
12. **VRC14LiquidityModule** 🆕 - VANA liquidity incentives
13. **DataPoolManager** 🆕 - VRC-20 data pools
14. **RDATVesting** 🆕 - Team vesting (6mo cliff)

**Status**: 7/14 complete (50%)

---

## 📋 Contract Specifications

### Token Layer

#### RDATUpgradeable
- **Pattern**: UUPS upgradeable
- **Supply**: 100M fixed (all minted at deployment)
- **Features**: ERC20 + Pausable + Permit
- **Security**: Reentrancy guards, flash loan protection
- **Roles**: PAUSER_ROLE, DEFAULT_ADMIN_ROLE (no MINTER_ROLE)

#### vRDAT
- **Type**: Soul-bound (non-transferable)
- **Supply**: Unlimited (minted as needed)
- **Distribution**: Proportional to lock duration (days/365)
- **Authority**: Only vRDATRewardModule can mint/burn
- **Purpose**: Governance voting power

### Staking Layer

#### StakingPositions
- **Type**: Immutable (no upgrades)
- **Storage**: EnumerableSet for O(1) operations
- **Features**: Multiple stakes per user, emergency migration
- **Lock Periods**: 30, 90, 180, 365 days
- **No Rewards**: Only manages positions, emits events

### Rewards Layer

#### RewardsManager
- **Pattern**: UUPS upgradeable
- **Purpose**: Orchestrates all reward modules
- **Features**: Module registration with 48h timelock
- **Operations**: Batch claiming, emergency pause

#### vRDATRewardModule
- **Distribution**: Immediate on stake
- **Formula**: vRDAT = RDAT × (lock_days / 365)
- **Multipliers**:
  - 30 days: 8.3%
  - 90 days: 24.7%
  - 180 days: 49.3%
  - 365 days: 100%
- **Anti-Gaming**: Sequential short stakes yield less than long stakes

#### RDATRewardModule
- **Type**: Time-based accumulation
- **Multipliers**: 1x, 1.15x, 1.35x, 1.75x
- **Budget**: 20M RDAT over 2 years
- **Feature**: Dynamic rate adjustment for sustainability

---

## 💰 Tokenomics

### Distribution (100M RDAT)
| Allocation | Amount | Purpose | Notes |
|------------|--------|---------|--------|
| Migration | 30M (30%) | V1 holders | 1:1 swap |
| Staking Rewards | 15M (15%) | 2-year program | Dynamic rate |
| VRC-14 Liquidity | 5M (5%) | VANA incentives | 90-day tranches |
| Ecosystem Fund | 10M (10%) | Partnerships | DAO-controlled |
| Treasury | 15M (15%) | Operations | DAO-controlled |
| Team Vesting | 10M (10%) | Team tokens | 6-month cliff |
| Liquidity | 15M (15%) | DEX provision | 6-month vesting |

### Revenue Model
- **Marketplace Fees**: 2-5% on data sales
- **Distribution**: 50% stakers, 30% treasury, 20% contributors
- **Sustainability**: Pre-allocated rewards + fee-based distribution

### vRDAT Economics
- **No Max Supply**: Minted based on staking
- **Burn on Emergency Exit**: Maintains governance integrity
- **Proportional System**: Prevents gaming through math

---

## 🔒 Security Model

### Multi-Layer Security
1. **Smart Contract Security**
   - OpenZeppelin standards
   - Reentrancy guards on all external calls
   - Flash loan protection (48h delays)
   - Module timelock (48h for new rewards)

2. **Economic Security**
   - Proportional vRDAT prevents gaming
   - Dynamic reward rates prevent depletion
   - Slashing for malicious validators

3. **Operational Security**
   - Multi-sig control (3/5 critical, 2/5 pause)
   - Emergency pause (72h auto-expiry)
   - Manual migration for staking upgrades

### Access Control
```solidity
// Critical Roles
DEFAULT_ADMIN_ROLE → Gnosis Safe
MINTER_ROLE → vRDATRewardModule only (for vRDAT)
BURNER_ROLE → vRDATRewardModule only (for vRDAT)
PAUSER_ROLE → Gnosis Safe + Emergency addresses
VALIDATOR_ROLE → 3-5 independent validators
```

---

## 📈 Implementation Status

### Completed ✅
1. **Architecture Design**: Triple-layer modular system
2. **Token Contracts**: RDAT (UUPS) and vRDAT (soul-bound)
3. **Staking Core**: Immutable with EnumerableSet optimization
4. **First Reward Module**: vRDAT proportional distribution
5. **Emergency Systems**: Pause with auto-expiry
6. **Deployment Infrastructure**: CREATE2 + scripts
7. **Documentation**: Updated for modular architecture

### In Progress 🔄
1. **RewardsManager**: Implementing orchestrator
2. **RDATRewardModule**: Time-based rewards with multipliers
3. **Testing**: Integration tests for modular system
4. **Gas Optimization**: Batch claiming implementation

### Remaining 🔴
1. **MigrationBridge**: Enhanced security (3-of-5 validators)
2. **RevenueCollector**: 50/30/20 distribution
3. **Dynamic Rewards**: Sustainability mechanism
4. **Security Audit**: Schedule for days 12-13

---

## 🎯 Key Decisions

### Why Modular Architecture?
- **Problem**: Monolithic staking contracts are inflexible
- **Solution**: Separate staking state from reward logic
- **Benefits**: Add rewards without migrations, better security

### Why Immutable Staking?
- **Security**: No upgrade vulnerabilities
- **Trust**: Users know rules can't change
- **Migration**: Clean upgrade path when needed

### Why Proportional vRDAT?
- **Problem**: Equal vRDAT for all locks enables gaming
- **Solution**: vRDAT = RDAT × (days/365)
- **Result**: Optimal strategy is maximum commitment

### Why EnumerableSet?
- **Problem**: Arrays get expensive as users increase
- **Solution**: O(1) operations with EnumerableSet
- **Trade-off**: Slightly more complex, much more scalable

### Why No NFTs?
- **Gas Cost**: NFT minting is expensive
- **Complexity**: Transfer logic not needed
- **Future**: Can add NFT wrapper later if desired

---

## 📊 Critical Metrics

### Technical
- Gas per stake: < 150k target
- Test coverage: 100% requirement
- Audit readiness: 75% complete

### Economic
- APR sustainability: 2+ years
- vRDAT inflation: < 50% annually
- Migration target: > 80% of V1 holders

### Timeline
- Sprint: August 5-18, 2025
- Audit: Days 12-13
- Testnet: Complete by Day 11
- Mainnet: 3-week delay recommended

---

## 🚀 Next Steps

### Immediate (Week 1)
1. Complete RewardsManager implementation
2. Implement dynamic reward rate mechanism
3. Add module registration timelock
4. Write comprehensive integration tests

### Short-term (Week 2)
1. Complete MigrationBridge with enhanced security
2. Implement RevenueCollector
3. Run economic simulations
4. Prepare for security audit

### Pre-Launch (Week 3)
1. Deploy to testnet
2. Security audit
3. Fix any findings
4. Community testing

---

## 📝 Reference Links

### Technical Documents
- [Contract Specifications](./CONTRACTS_SPEC.md)
- [Modular Rewards Architecture](./MODULAR_REWARDS_ARCHITECTURE.md)
- [Technical FAQ](./TECHNICAL_FAQ.md)
- [Testing Requirements](./TESTING_REQUIREMENTS.md)

### Governance Documents
- [Specifications](./SPECIFICATIONS.md)
- [Whitepaper](./WHITEPAPER.md)
- [Deployment Guide](./DEPLOYMENT_GUIDE.md)

### Analysis Documents
- [Comprehensive Review](../COMPREHENSIVE_SPECIFICATION_REVIEW.md)
- [Final Recommendations](../FINAL_RECOMMENDATIONS_V2.md)
- [Architecture Decision](./ARCHITECTURAL_PIVOT_DECISION.md)

---

**Document Maintenance**
- Review weekly during development
- Update after each major decision
- Version control all changes
- Keep as single source of truth