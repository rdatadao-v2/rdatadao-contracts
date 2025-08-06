# 🏗️ Architecture Decisions Document

**Date**: August 6, 2025  
**Version**: 1.0  
**Purpose**: Document key architectural decisions and rationale

## 🎯 Overview

This document captures important architectural decisions made during the RDAT V2 development to provide clarity and prevent confusion.

## 📋 Key Decisions

### 1. Staking Architecture: StakingManager vs StakingPositions

**Decision**: Use StakingManager for V2 Beta

**Context**:
- Two implementations were created during development
- StakingManager: Simple mapping-based staking
- StakingPositions: NFT-based multiple positions

**Rationale**:
1. **Simplicity**: StakingManager is simpler to audit and deploy
2. **Integration**: Already integrated with modular rewards system
3. **Timeline**: NFT positions add complexity without immediate benefit
4. **Migration**: Easier to migrate from simple to complex than reverse

**Trade-offs**:
- ✅ Faster time to market
- ✅ Simpler security model
- ✅ Lower gas costs
- ❌ Users limited to one stake position
- ❌ Less flexibility for users

**Future Path**:
- Phase 2: Implement NFT positions
- Migration path: StakingManager → StakingPositions
- Users can migrate when ready

### 2. Data Pool Location: In RDAT vs Separate Contract

**Decision**: Keep data pools in RDATUpgradeable

**Context**:
- VRC-20 requires data pool functionality
- Could be in token or separate DataPoolManager

**Rationale**:
1. **Simplicity**: One less contract to deploy and manage
2. **Gas Efficiency**: No cross-contract calls for basic operations
3. **Upgrade Path**: Can migrate to separate contract later if needed
4. **VRC Compliance**: Meets requirements either way

**Implementation**:
```solidity
// In RDATUpgradeable
mapping(bytes32 => DataPool) private _dataPools;

// Future: Can delegate to external contract
function createDataPool(...) external {
    if (dataPoolManager != address(0)) {
        return IDataPoolManager(dataPoolManager).createDataPool(...);
    }
    // Current: Internal implementation
}
```

### 3. Rewards Architecture: Modular vs Monolithic

**Decision**: Modular rewards with separate manager

**Context**:
- Could have put all rewards logic in staking contract
- Chose to separate into RewardsManager + modules

**Rationale**:
1. **Flexibility**: Add new rewards without changing staking
2. **Security**: Immutable staking, upgradeable rewards
3. **Composability**: Mix and match reward programs
4. **Testing**: Easier to test in isolation

**Benefits Realized**:
- ✅ vRDAT rewards separate from RDAT rewards
- ✅ VRC14 liquidity module pluggable
- ✅ Future partner rewards easy to add

### 4. VRC-20 Implementation: Full vs Stub

**Decision**: Start with stubs, implement progressively

**Context**:
- VRC-20 requires many functions
- Could implement all upfront or progressively

**Rationale**:
1. **Time to Market**: Get basic functionality first
2. **Learning**: Understand requirements better over time
3. **Flexibility**: Adjust implementation based on Vana feedback

**Current Status**:
- ✅ Interface defined
- ✅ Basic functions stubbed
- 🔄 Implementation in progress
- ⏳ Full compliance in Phase 2

### 5. Migration Bridge: Multi-validator vs Multi-sig

**Decision**: Start with 2-of-3 multi-sig

**Context**:
- Spec calls for multi-validator consensus
- Simpler to start with multi-sig

**Rationale**:
1. **Proven Pattern**: Multi-sig well understood
2. **Security**: 2-of-3 provides good security
3. **Simplicity**: Easier to implement and audit
4. **Upgrade Path**: Can add validators later

**Security Model**:
```solidity
// Current: Multi-sig
mapping(address => bool) public validators;
mapping(bytes32 => uint256) public migrationApprovals;

// Future: Full consensus
struct Validation {
    address validator;
    uint256 timestamp;
    bytes signature;
}
```

### 6. Revenue Distribution: Automatic vs Manual

**Decision**: Manual triggers for V2 Beta

**Context**:
- Could automate distribution in contracts
- Chose manual triggers via multi-sig

**Rationale**:
1. **Control**: Better control over distribution timing
2. **Gas**: Avoid expensive automatic distributions
3. **Flexibility**: Can adjust distribution logic off-chain
4. **Safety**: Reduce attack surface

**Future**:
- Phase 2: Add Keeper automation
- Phase 3: Fully autonomous distribution

### 7. Contract Upgradeability Strategy

**Decision**: Hybrid approach

**Upgradeable**:
- RDATUpgradeable (token)
- RewardsManager (orchestrator)

**Immutable**:
- StakingManager (user funds)
- Reward Modules (isolated risk)
- EmergencyPause (security critical)

**Rationale**:
1. **Security**: Protect user funds with immutable staking
2. **Flexibility**: Allow token and rewards evolution
3. **Risk Management**: Isolate upgrade risks
4. **Best Practices**: Follow established patterns

## 📊 Decision Matrix

| Component | Architecture Choice | Alternative | Why |
|-----------|-------------------|-------------|-----|
| Staking | StakingManager | StakingPositions | Simplicity |
| Data Pools | In RDAT | Separate Contract | Fewer contracts |
| Rewards | Modular | Monolithic | Flexibility |
| VRC-20 | Progressive | Full upfront | Time to market |
| Bridge | Multi-sig | Validators | Proven pattern |
| Revenue | Manual | Automatic | Control |
| Upgrades | Hybrid | All upgradeable | Security |

## 🔄 Migration Strategies

### StakingManager → StakingPositions
```solidity
// Future migration function
function migrateToPositions(address newStaking) external {
    // 1. Pause old staking
    // 2. Deploy new contract
    // 3. User triggers migration
    // 4. Mint NFT for position
    // 5. Transfer stake
}
```

### Manual → Automatic Revenue
```solidity
// Phase 2: Add keeper
function enableAutomation(address keeper) external onlyAdmin {
    automationEnabled = true;
    authorizedKeeper = keeper;
}
```

## ✅ Validation Checklist

For each decision:
- [ ] Solves immediate need
- [ ] Has upgrade path
- [ ] Reduces complexity
- [ ] Improves security
- [ ] Enables fast delivery

## 📝 Lessons Learned

1. **Start Simple**: Complex features can always be added
2. **Document Early**: Confusion wastes time
3. **Plan Migrations**: Always have upgrade path
4. **Isolate Risk**: Use immutability strategically
5. **Be Pragmatic**: Perfect is enemy of good

## 🎯 Next Decisions Needed

1. **Liquidity Strategy**: Uniswap V2 vs V3 on Vana
2. **Oracle Selection**: Chainlink vs Pyth vs internal
3. **Keeper Network**: Gelato vs Chainlink vs custom
4. **Frontend Hosting**: Centralized vs IPFS
5. **Indexing**: The Graph vs custom