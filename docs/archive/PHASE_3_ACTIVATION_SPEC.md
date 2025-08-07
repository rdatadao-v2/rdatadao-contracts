# 🚀 Phase 3 Activation Specification

**Version**: 1.0  
**Date**: August 6, 2025  
**Purpose**: Define the community-driven process for Phase 3 activation

## Overview

Phase 3 activation is a critical milestone that unlocks 30M RDAT from the Future Rewards allocation. This decision is intentionally deferred to the DAO, empowering the community to determine the optimal timing and allocation strategy.

## What Phase 3 Unlocks

### 1. **Future Rewards Pool (30M RDAT)**
- Currently locked in TreasuryWallet
- Requires admin to call `setPhase3Active()`
- Enables distribution for various reward programs

### 2. **RDAT Staking Rewards**
- Activation of RDATRewardModule
- Time-based reward accumulation
- Staking multipliers (1x-1.75x) apply

### 3. **Data Contributor Rewards**
- Funding for data marketplace incentives
- Merit-based distribution system
- Integration with ProofOfContribution

## DAO Decision Framework

### Key Decisions Required

1. **Activation Timing**
   - When should Phase 3 activate?
   - What criteria must be met?
   - How to balance early activation vs. system maturity?

2. **Allocation Split**
   - How much for staking rewards?
   - How much for data contributors?
   - Reserve for future programs?

3. **Distribution Parameters**
   - Reward rates and duration
   - Vesting or immediate distribution
   - Adjustment mechanisms

### Proposed Activation Criteria Options

#### Option A: Time-Based
```solidity
// Activate after fixed period
if (block.timestamp >= deploymentTime + 90 days) {
    // Eligible for Phase 3
}
```
**Pros**: Simple, predictable
**Cons**: Ignores market conditions

#### Option B: Migration-Based
```solidity
// Activate after significant migration
if (migrationBridge.totalMigrated() >= 15_000_000e18) { // 50% of V1 supply
    // Eligible for Phase 3
}
```
**Pros**: Ensures user adoption
**Cons**: Could delay if migration slow

#### Option C: TVL/Staking-Based
```solidity
// Activate after staking threshold
if (stakingPositions.totalStaked() >= 10_000_000e18) { // 10M RDAT staked
    // Eligible for Phase 3
}
```
**Pros**: Proves ecosystem engagement
**Cons**: Circular dependency (need rewards to incentivize staking)

#### Option D: Combined Criteria
```solidity
// Multiple conditions with DAO override
bool timeElapsed = block.timestamp >= deploymentTime + 60 days;
bool sufficientMigration = migrationBridge.totalMigrated() >= 10_000_000e18;
bool daoApproval = proposal.hasPassedVote();

if ((timeElapsed && sufficientMigration) || daoApproval) {
    // Eligible for Phase 3
}
```
**Pros**: Balanced approach
**Cons**: More complex

### Recommended Allocation Framework

Based on whitepaper goals and tokenomics design:

**Suggested Initial Split**:
- **Staking Rewards**: 20M RDAT (67%)
  - 2-year distribution schedule
  - Sustainable APY targets
  - Multiplier incentives
  
- **Data Contributors**: 8M RDAT (27%)
  - Merit-based distribution
  - Quality incentives
  - 2-3 year timeline
  
- **Reserve**: 2M RDAT (6%)
  - Future programs
  - Emergency allocations
  - Partnership incentives

## Implementation Process

### 1. **Community Discussion Phase** (2-4 weeks)
- Forum discussions on activation criteria
- Community proposals for allocation splits
- Technical feasibility assessment

### 2. **Proposal Creation**
```solidity
// Example proposal structure
proposal = {
    title: "Phase 3 Activation and Allocation",
    activationCriteria: "90 days + 10M staked",
    allocationSplit: {
        staking: 20_000_000e18,
        dataContributors: 8_000_000e18,
        reserve: 2_000_000e18
    },
    distributionSchedule: "2 years linear"
}
```

### 3. **Voting Period** (1 week)
- vRDAT holders vote using quadratic voting
- Minimum participation threshold
- Clear majority required

### 4. **Execution**
```solidity
// Admin executes based on DAO decision
treasuryWallet.setPhase3Active();

// Distribute according to vote
treasuryWallet.distribute(
    rdatRewardModule,
    20_000_000e18,
    "Phase 3 staking rewards per DAO proposal #1"
);

treasuryWallet.distribute(
    dataContributorRewards,
    8_000_000e18,
    "Data contributor rewards per DAO proposal #1"
);
```

## Security Considerations

### 1. **Proposal Validation**
- Ensure total allocation ≤ 30M RDAT
- Verify recipient contracts are deployed
- Check distribution parameters are reasonable

### 2. **Time Locks**
- 48-hour delay after proposal passes
- Allows security review
- Emergency pause available

### 3. **Multi-sig Approval**
- Admin (multi-sig) must execute
- Cannot override DAO decision
- Provides additional security layer

## Monitoring and Adjustment

### Key Metrics
- Migration progress
- Staking participation rate
- vRDAT distribution
- Market conditions
- Protocol TVL

### Adjustment Mechanisms
- DAO can modify distribution rates
- Emergency pause if issues detected
- Regular reviews (quarterly)

## Example Timeline

**Month 1-2**: System launch, initial staking
**Month 2-3**: Migration progress assessment
**Month 3**: Community discussions begin
**Month 3-4**: Proposal creation and voting
**Month 4**: Phase 3 activation (if approved)

## Benefits of DAO Control

1. **True Decentralization**: Community controls major decisions
2. **Market Responsiveness**: Activate when conditions optimal
3. **Flexibility**: Adjust to unforeseen circumstances
4. **Legitimacy**: Decisions have community mandate
5. **Alignment**: Token holders decide token distribution

## Conclusion

Phase 3 activation represents a critical transition from admin-controlled to community-controlled protocol. By deferring this decision to vRDAT holders, we ensure that the protocol's evolution reflects the will of its stakeholders, not just its creators.

The 30M RDAT Future Rewards allocation is a powerful tool for ecosystem growth - placing it under DAO control from the start demonstrates our commitment to democratic governance and sustainable tokenomics.