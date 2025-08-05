# Data Contributor Rewards System

**Version**: 2.1 (Updated for V2 Beta)  
**Last Updated**: August 2025

## Overview

The RDAT V2 token allocation includes 30 million tokens (30% of 100M total supply) specifically reserved for rewarding data contributors. This document outlines how these rewards are managed and distributed through the ProofOfContribution system and integrated with revenue distribution.

## Token Allocation

**Future Rewards Pool**: 30,000,000 RDAT (30% of 100M supply)
- **Purpose**: Reward users who contribute high-quality data to r/datadao
- **Lock Period**: 
  - V2 Beta: Basic rewards via ProofOfContribution
  - Phase 2: Enhanced rewards with Kismet integration
  - Phase 3: Full data marketplace with automated distribution
- **Distribution**: Merit-based through ProofOfContribution scoring
- **Revenue Integration**: Additional rewards from 20% of RevenueCollector distributions

## Reward Distribution Mechanism

### 1. Phase 3 Trigger
When the DAO determines that Phase 3 data aggregation should begin:
```solidity
// Admin triggers Phase 3 unlock
vestingContract.triggerPhase3Unlock(dataRewardsContract);
```

This:
- Unlocks the 30M RDAT future rewards pool
- Approves the rewards contract to distribute tokens
- Enables creation of reward rounds

### 2. Reward Rounds
Data contributor rewards are distributed in rounds:
- Each round has a specific budget (e.g., 5M RDAT)
- Contributors are assigned rewards based on contribution metrics
- Claims are managed via Merkle proofs for gas efficiency

### 3. Contribution Scoring (V2 Beta)
Rewards are calculated through ProofOfContribution based on:
- **Data Quality**: Score 0-100 validated by authorized validators
- **Data Quantity**: Tracked via totalContributions counter
- **Contributor Status**: Must be registered via registerContributor()
- **Duplicate Prevention**: processedDataHashes mapping prevents double rewards

### 4. Revenue-Based Rewards (NEW)
In addition to emission rewards, contributors receive:
- Share of 20% RevenueCollector distribution allocated to contributors
- Distribution proportional to contribution scores
- Creates sustainable reward mechanism beyond initial 30M pool

## Implementation Details

### V2 Beta Smart Contracts (7 Total)

**ProofOfContribution.sol** (NEW):
- Manages contributor registration and validation
- Tracks contribution scores (0-100 per submission)
- Integrates with Vana DLP requirements
- Provides upgrade path to full implementation

**RevenueCollector.sol** (NEW):
- Distributes 20% of revenue to contributor rewards
- Creates sustainable reward mechanism
- Integrates with staking (50%) and treasury (30%)

### Phase 2-3 Contracts (Future)
**DataContributorRewards.sol**:
- Enhanced reward distribution with Merkle trees
- Kismet reputation score integration
- Automated quality validation consensus
- Cross-chain reward claims

### Reward Round Creation
```solidity
createRewardRound(
    merkleRoot,      // Root of contributor/amount tree
    5_000_000e18,    // 5M RDAT for this round
    30 days          // Claim window
);
```

### Claiming Rewards
Contributors claim their rewards by providing:
1. Round ID
2. Reward amount
3. Merkle proof of inclusion

```solidity
claimRewards(
    roundId,
    amount,
    merkleProof
);
```

## Distribution Strategy

### Phase 3 Initial Distribution
**Recommended Approach**:
1. **Round 1** (Months 1-3): 5M RDAT
   - Early adopter bonus
   - Focus on data quality establishment
   
2. **Round 2** (Months 4-6): 7M RDAT
   - Scale up as more contributors join
   - Refined scoring metrics

3. **Round 3** (Months 7-12): 8M RDAT
   - Mature ecosystem rewards
   - Long-term contributor incentives

4. **Reserve**: 10M RDAT
   - Future rounds
   - Special campaigns
   - Emergency allocations

### Contribution Tiers

| Tier | Data Points | Quality Score | Estimated Reward |
|------|-------------|---------------|------------------|
| Bronze | 100-500 | 60-70% | 100-500 RDAT |
| Silver | 500-2000 | 70-85% | 500-2000 RDAT |
| Gold | 2000-5000 | 85-95% | 2000-5000 RDAT |
| Platinum | 5000+ | 95%+ | 5000+ RDAT |

## Governance

### Reward Parameters
The DAO governs:
- Round budgets
- Scoring criteria
- Distribution frequency
- Quality thresholds

### Appeals Process
Contributors can appeal reward decisions through:
1. DAO governance proposals
2. Dispute resolution committee
3. On-chain voting

## Security Considerations

1. **Merkle Proof Verification**: Prevents unauthorized claims
2. **Round Time Limits**: Unclaimed tokens return to pool
3. **Budget Controls**: Cannot exceed 30M total allocation
4. **Pause Mechanism**: Emergency stop for security issues

## Integration with DataDAO

The rewards system integrates with r/datadao's data aggregation:
1. Data submission through DataDAO portal
2. Automated quality scoring
3. Merkle tree generation for each round
4. IPFS storage of contribution proofs

## Example Workflow

1. **User Contributes Data**:
   - Submits Reddit data export
   - Data validated and scored
   - Contribution recorded

2. **Round Creation**:
   - DAO aggregates contributions
   - Calculates rewards per contributor
   - Generates Merkle tree
   - Creates reward round

3. **Claiming Process**:
   - User notified of rewards
   - Connects wallet to claim portal
   - Submits claim with proof
   - Receives RDAT tokens

## Budget Management

**Total Budget**: 30,000,000 RDAT
**Recommended Distribution Timeline**: 2-3 years
**Emergency Reserve**: 10% (3M RDAT)

### Monitoring
- Track distribution rate
- Analyze contributor retention
- Adjust rewards based on participation
- Report to DAO quarterly

---

**Last Updated**: November 2024  
**Status**: Pending Phase 3 Activation