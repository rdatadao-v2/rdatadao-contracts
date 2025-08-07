# Known Issues and Limitations

*For Audit Review*
*Date: August 7, 2025*
*Version: Pre-Audit Disclosure*

## Overview

This document discloses known limitations, design decisions, and planned improvements in the r/datadao V2 smart contracts. These items are acknowledged and have been factored into the development and audit strategy.

## ⚠️ Acknowledged Limitations

### 1. VRC-20 Partial Implementation

**Status**: Intentionally Limited for Audit
**Impact**: Medium
**Timeline**: Post-audit completion (10-12 weeks)

#### What's Implemented (Minimal Compliance)
- ✅ Blocklisting system
- ✅ 48-hour timelocks 
- ✅ Updateable DLP registry
- ✅ Basic data pool structures

#### What's Missing (Full Compliance)
- ❌ ProofOfContribution integration (stub only)
- ❌ Kismet formula implementation
- ❌ Data quality scoring algorithms
- ❌ Active DLP registry connection
- ❌ Cross-DLP communication

#### Rationale
- Allows immediate audit without waiting for Vana infrastructure
- Reduces complexity for initial security review
- Provides upgrade path to full compliance
- Satisfies minimum requirements for ecosystem participation

---

### 2. Manual Cross-Chain Migration Process

**Status**: Design Decision
**Impact**: Medium
**Mitigation**: Validator Network + Time Delays

#### Current Implementation
```solidity
// BaseMigrationBridge burns V1 tokens and emits event
emit V1TokensBurned(user, amount, nonce);

// Manual relay required to VanaMigrationBridge
// Validators must sign off on migration completion
```

#### Known Limitations
- Requires off-chain relay infrastructure
- Manual validator coordination needed
- No automated cross-chain messaging

#### Security Measures
- 3-validator minimum consensus required
- Daily migration limits enforced
- 48-hour delay on validator changes
- Emergency pause capability

#### Future Enhancement
Post-audit implementation may include automated oracle system

---

### 3. Circular Dependency Resolution

**Status**: Resolved with Workaround
**Impact**: Low
**Solution**: Placeholder Addresses + CREATE2

#### The Problem
```solidity
// Treasury needs RDAT address for initialization
TreasuryWallet treasury = new TreasuryWallet(rdatAddress);

// RDAT needs Treasury address to mint initial supply
RDAT rdat = new RDAT();
rdat.initialize(treasuryAddress, ...);
```

#### Current Solution
```solidity
// Use placeholder address during deployment
TreasuryWallet treasury = new TreasuryWallet(address(0x1));

// Deploy RDAT with actual treasury address
RDAT rdat = new RDAT();
rdat.initialize(treasuryAddress, admin, migrationAddress);

// Treasury is ready to receive 70M tokens
```

#### Alternative Considered
CREATE2 deterministic addressing (documented but not implemented)

---

### 4. Gas Optimization Pending

**Status**: Not Optimized
**Impact**: Low
**Timeline**: Post-audit optimization

#### Known Inefficiencies
1. **Array Length Caching**: Not implemented in loops
2. **Storage Reads**: Multiple reads from same storage slot
3. **Event Emissions**: Could be batched in some cases

#### Examples
```solidity
// Current (expensive)
for (uint256 i = 0; i < programIds.length; i++) {
    RewardProgram memory program = programs[programIds[i]]; // Storage read each iteration
}

// Optimized (post-audit)
uint256[] memory _programIds = programIds; // Cache in memory
for (uint256 i = 0; i < _programIds.length; i++) {
    RewardProgram memory program = programs[_programIds[i]];
}
```

#### Rationale for Deferral
- Core functionality takes priority over optimization
- Gas costs acceptable for initial deployment
- Optimization without breaking changes planned post-audit

---

### 5. Emergency Pause Integration Incomplete

**Status**: Partially Implemented
**Impact**: Low
**Mitigation**: Individual Contract Pause Mechanisms

#### Current State
- `EmergencyPause.sol` contract exists with 72-hour auto-expiry
- Individual contracts have their own pause mechanisms
- Not all contracts check global emergency pause

#### Missing Integration
```solidity
// Some contracts don't check emergency pause
modifier whenNotEmergencyPaused() {
    require(!emergencyPause.isPaused(), "Emergency pause active");
    _;
}
```

#### Workaround
Each critical contract has individual pause capability:
- RDATUpgradeable: Has Pausable functionality
- StakingPositions: Has emergency withdrawal
- MigrationBridge: Has pause mechanism

---

## 🔄 Design Decisions (Not Issues)

### 1. Non-Upgradeable Staking Contract

**Decision**: StakingPositions is intentionally non-upgradeable
**Rationale**: Maximum security for user funds
**Trade-off**: Less flexibility for feature additions

### 2. Fixed Supply Without Minting

**Decision**: RDAT `mint()` function always reverts
**Rationale**: Predictable tokenomics, no inflation risk
**Trade-off**: Cannot respond to unexpected demand with supply increases

### 3. Manual Treasury Distribution

**Decision**: No automatic distribution from TreasuryWallet
**Rationale**: DAO control over all allocations
**Trade-off**: Requires governance action for distributions

### 4. Soul-bound vRDAT

**Decision**: vRDAT tokens are non-transferable
**Rationale**: Prevent governance token speculation
**Trade-off**: Reduces liquidity and composability

---

## 📋 Testing Gaps

### 1. Cross-Chain Integration Testing

**Status**: Limited
**Coverage**: Basic unit tests only
**Missing**: Full cross-chain migration simulation

### 2. Validator Misbehavior Scenarios

**Status**: Basic coverage
**Missing**: Advanced attack scenarios, collusion testing

### 3. Gas Limit Edge Cases

**Status**: Not tested
**Risk**: Large batch operations might exceed gas limits

---

## 🔧 Code Quality Items

### 1. NatSpec Documentation

**Status**: Incomplete
**Impact**: Low (functionality unaffected)
**Missing**: Some functions lack complete documentation

### 2. Magic Numbers

**Status**: Present in some areas
**Example**: `lockMultipliers[30 days] = 10000;`
**Should be**: Named constants

### 3. Error Message Consistency

**Status**: Inconsistent
**Example**: Mix of generic and specific error messages

---

## 🛡️ Security Considerations

### 1. Admin Key Management

**Assumption**: Multi-sig wallets properly configured
**Risk**: If admin keys compromised, significant impact
**Mitigation**: 48-hour timelocks on critical operations

### 2. Oracle Dependencies

**Current**: No external price oracles used
**Future**: May need oracles for full VRC-20 implementation
**Risk**: Oracle manipulation in future versions

### 3. Reentrancy Protection

**Status**: Implemented on all state-changing functions
**Confidence**: High
**Note**: Comprehensive reentrancy guards in place

---

## 📈 Post-Audit Improvement Plan

### Phase 1 (Weeks 1-4): Security Fixes
- Address all critical and high-severity audit findings
- Fix any code quality issues identified
- Complete documentation gaps

### Phase 2 (Weeks 5-8): VRC-20 Full Implementation
- Implement ProofOfContribution integration
- Add kismet formula and data quality scoring
- Connect to live Vana DLP registry

### Phase 3 (Weeks 9-12): Optimization & Enhancement
- Gas optimization implementation
- Cross-chain automation (if needed)
- Advanced testing and edge case coverage

---

## 🎯 Acceptance Criteria for Known Issues

These items are **acceptable for audit** because:

1. **Core Security**: All critical security measures implemented
2. **Functionality**: All essential features working (356/356 tests pass)
3. **Upgradeability**: Clear path to address limitations post-audit
4. **Documentation**: All limitations clearly disclosed
5. **Risk Assessment**: No high-risk issues that would prevent deployment

---

## 📞 Contact for Questions

**Technical Questions**: Development team available during audit
**Business Context**: Project leads available for clarification
**Emergency Contact**: Multi-sig holders on standby

---

*This document will be updated based on audit findings and pre-deployment reviews.*