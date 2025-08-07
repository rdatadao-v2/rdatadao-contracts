# Known Issues and Limitations

## Acknowledged Design Decisions

### 1. Centralized Oracle for Cross-Chain Migration

**Issue**: Single point of failure in the migration process  
**Severity**: Medium  
**Status**: Accepted with mitigation plan

**Description**: 
The cross-chain migration from Base to Vana relies on a centralized oracle service to relay migration events between chains. This creates a trust assumption and potential availability risk.

**Mitigation**:
- Multi-validator consensus ready for deployment
- Event logs provide cryptographic proof of migration
- Manual recovery process documented
- Decentralized oracle upgrade planned Q4 2024

**Justification**:
Launching with centralized oracle allows faster time to market while decentralized solution is developed. Risk is acceptable given temporary nature and manual recovery options.

---

### 2. Upgradeable Core Contracts

**Issue**: Malicious upgrade potential  
**Severity**: Medium  
**Status**: Accepted with controls

**Description**:
Core contracts (RDAT, TreasuryWallet, RewardsManager) use UUPS upgradeable pattern, allowing logic changes post-deployment.

**Mitigation**:
- Upgrades require multisig approval (3/5 signers)
- 48-hour timelock on critical upgrades
- Upgrade capability can be renounced
- Community governance transition planned

**Justification**:
Upgradeability necessary for bug fixes and feature additions during early protocol development. Will transition to DAO governance.

---

### 3. Fixed Supply with No Burn Mechanism

**Issue**: Cannot reduce circulating supply  
**Severity**: Low  
**Status**: By Design

**Description**:
100M RDAT tokens minted at deployment with no burn function, meaning supply cannot be reduced even if tokens are sent to zero address.

**Mitigation**:
- Tokens sent to zero address effectively removed from circulation
- Treasury can vote to lock tokens permanently
- Staking mechanism reduces liquid supply

**Justification**:
Fixed supply provides economic certainty and prevents supply manipulation. Burn functionality adds complexity without clear benefit.

---

### 4. Soul-Bound vRDAT Cannot Be Recovered

**Issue**: Tokens locked if wallet compromised  
**Severity**: Low  
**Status**: Accepted

**Description**:
vRDAT governance tokens are non-transferable. If a wallet is compromised, the vRDAT cannot be moved to a safe address.

**Mitigation**:
- Emergency exit allows burning vRDAT to recover staked RDAT
- Hardware wallet usage recommended
- Social recovery planned for v3

**Justification**:
Soul-bound design prevents governance attacks via token accumulation. Risk acceptable given emergency exit option.

---

### 5. ProofOfContribution Stub Implementation

**Issue**: Placeholder contract for DLP integration  
**Severity**: Low  
**Status**: Planned Development

**Description**:
ProofOfContribution contract is currently a stub, awaiting Vana DLP specifications.

**Mitigation**:
- Interface defined and stable
- Stub allows testing of integration points
- Full implementation planned Q4 2024

**Justification**:
Vana DLP specifications still evolving. Stub pattern allows parallel development.

---

## Test Suite Issues

### 1. DataContributionJourney Test Failures

**Issue**: 3 tests failing in scenario suite  
**Severity**: Informational  
**Status**: Test infrastructure issue

**Tests Failing**:
- `test_CompleteDataContributionFlow()`
- `test_EpochBasedRewardDistribution()`
- `test_KismetFormulaGovernanceUpdate()`

**Root Cause**:
Test setup doesn't properly fund reward contracts and doesn't advance time for governance voting.

**Impact**:
No impact on production code. Tests need setup fixes.

**Resolution Plan**:
Update test fixtures in next sprint.

---

## Gas Optimization Opportunities

### 1. Storage Packing

**Current State**: Some structs not optimally packed  
**Potential Savings**: ~2,000 gas per transaction  
**Priority**: Low

**Locations**:
- `StakingPosition` struct could pack better
- `VestingSchedule` has alignment gaps

---

### 2. Batch Operations

**Current State**: No batch mint/stake functions  
**Potential Savings**: ~30% for multiple operations  
**Priority**: Medium

**Planned Implementation**:
- `batchStake()` for multiple positions
- `batchClaim()` for vesting claims

---

## External Dependencies

### 1. OpenZeppelin Contracts

**Version**: 5.0.2  
**Risk**: Low  
**Monitoring**: Automated dependency scanning

**Known Issues**:
- None in used components

---

### 2. Vana Network

**Dependency**: DLP Registry, VRC-20 standard  
**Risk**: Medium  
**Status**: Specifications stabilizing

**Considerations**:
- VRC-20 standard still evolving
- DLP registry interface may change
- Network launch timeline dependent

---

## Deployment Considerations

### 1. Constructor vs Initializer Pattern

**Issue**: Mixed patterns used  
**Impact**: Slightly higher deployment cost  
**Status**: Intentional design

Some contracts use constructors (non-upgradeable) while others use initializers (upgradeable). This is intentional for security/flexibility tradeoff.

---

### 2. CREATE2 Deployment Complexity

**Issue**: Complex deployment sequence  
**Impact**: Deployment risk  
**Status**: Mitigated with scripts

Cross-chain address matching requires careful deployment orchestration.

---

## Economic Considerations

### 1. Large Treasury Allocation

**Issue**: 70% of supply in treasury  
**Risk**: Centralization, market manipulation  
**Status**: Governance controlled

**Mitigation**:
- Phased vesting schedule
- Multisig control
- Community governance transition

---

### 2. Migration Bridge Funding

**Issue**: 30M tokens locked in bridge  
**Risk**: Unused tokens if migration low  
**Status**: Accepted

**Plan**:
- Unused tokens returnable after deadline
- Can be redistributed via governance

---

## Recommendations for Auditors

1. **Focus on bridge security** - Highest risk component
2. **Review upgrade patterns** - Storage collision risks
3. **Analyze economic attacks** - Large treasury implications
4. **Test emergency procedures** - Pause/unpause flows
5. **Verify access controls** - Role management robustness

---

## Contact for Clarifications

**Technical Lead**: [contact]  
**Email**: security@rdatadao.org  
**Discord**: [security channel]

*Last Updated: August 7, 2024*  
*Version: 1.0*