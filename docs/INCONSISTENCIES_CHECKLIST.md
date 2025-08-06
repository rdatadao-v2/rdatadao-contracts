# 📋 Inconsistencies Checklist & Resolution Q&A

**Date**: August 6, 2025  
**Purpose**: Resolve all documentation inconsistencies before TreasuryWallet implementation

## 🔍 Inconsistencies Requiring Resolution

### 1. ✅ Future Rewards Allocation Split (30M RDAT) - RESOLVED
**Current State**: 
- Total: 30M RDAT for "Future Rewards"
- Mentioned uses: staking rewards, data contributions, other incentives
- No explicit split defined

**Inconsistency**: 
- `IMPLEMENTATION_SPECIFICATION.md` line 292: "20M RDAT transferred to reward module"
- `DATA_CONTRIBUTOR_REWARDS.md`: Implies all 30M for data contributors
- No clear breakdown

**Resolution**: Split will be determined by future DAO vote once vRDAT is activated. The vRDAT activation requires 50% migration + 3 epoch cooldown per snapshot vote.

---

### 2. ✅ Team Token Transfer Process - RESOLVED
**Current State**: 
- 10M RDAT allocated for team (from 25M Treasury & Ecosystem)
- Separate TokenVesting.sol contract planned
- Admin-settable start date for Vana compliance

**Gap**: 
- No specification for when/how TreasuryWallet transfers to TokenVesting

**Resolution**: Team allocation (10M from Treasury & Ecosystem) requires DAO vote to transfer to TokenVesting contract. Transfer happens after DAO approval, not automatically.

---

### 3. ✅ Liquidity Amount Discrepancy - RESOLVED
**Current State**: 
- Allocation: 15M RDAT for "Liquidity & Staking"
- TGE unlock: 33% for liquidity

**Inconsistency**: 
- Most docs: "4.95M RDAT" (exactly 33% of 15M)
- Some places: "5M RDAT" (rounded)

**Resolution**: Use exact 4.95M RDAT (exactly 33% of 15M). Precision matters for accounting.

---

### 4. ❓ Phase 3 Activation Criteria
**Current State**: 
- Admin can call `setPhase3Active()`
- Unlocks 30M Future Rewards
- No defined trigger criteria

**Questions**:
- [ ] Time-based trigger (e.g., 3 months post-launch)?
- [ ] Metric-based trigger (e.g., 10M RDAT staked)?
- [ ] DAO vote required?
- [ ] Combination of above?

---

### 5. ✅ Staking Incentives Allocation - RESOLVED
**Current State**: 
- 15M total for "Liquidity & Staking"
- 33% (4.95M) for liquidity at TGE
- Remaining 67% (10.05M) for "staking incentives"

**Confusion**: 
- What are "staking incentives" vs Future Rewards staking?
- Is this for vRDAT rewards or something else?

**Resolution**: The 10.05M "staking incentives" are the remaining 67% of Liquidity & Staking allocation. These are SEPARATE from Future Rewards and can be used for LP incentives, vRDAT boost campaigns, or early staker bonuses. Distributed at admin/DAO discretion during Phase 1-2.

---

### 6. ✅ TreasuryWallet Initial Distributions - RESOLVED
**Current State**: 
- TreasuryWallet receives 70M at deployment
- Must process TGE distributions immediately

**Unclear Sequence**:
1. RDAT mints 70M to TreasuryWallet
2. TreasuryWallet must distribute at TGE:
   - 4.95M to liquidity provider
   - 2.5M unlocked for ecosystem
   - 10M to team vesting (when?)

**Resolution**: TreasuryWallet holds all funds until admin manually triggers distributions. This allows verification of migration setup before releasing funds. Admin calls distribute() after verification.

---

### 7. ✅ Treasury & Ecosystem Breakdown - RESOLVED
**Current State**: 
- Total: 25M RDAT
- Includes 10M for team
- 10% TGE (2.5M), then vesting

**Unclear**:
- After 10M team and 2.5M TGE, only 12.5M remains
- How is remaining 12.5M allocated?

**Resolution**: 25M total = 10M team + 2.5M TGE unlock + 12.5M general treasury. The 12.5M is for DAO operations, partnerships, and ecosystem grants.

---

### 8. ❓ RewardsManager Integration Status
**Current State**: 
- Contract exists and has tests
- Not fully integrated with StakingPositions
- Documentation says incomplete

**Questions**:
- [ ] Is RewardsManager ready for production?
- [ ] What integration work remains?
- [ ] Should we use it for Phase 1 launch?

---

### 9. ✅ vRDATRewardModule Funding - RESOLVED
**Current State**: 
- Mints vRDAT (no RDAT needed)
- Active at launch
- No funding required

**Resolution**: Confirmed - vRDATRewardModule only mints vRDAT, needs no RDAT funding.

---

### 10. ✅ Deployment Address Dependencies - RESOLVED
**Current State**: 
- RDAT needs TreasuryWallet and MigrationBridge addresses at deployment
- TreasuryWallet needs RDAT address
- MigrationBridge needs RDAT address

**Resolution**: Use CREATE2 for RDAT to get deterministic address. Deploy order: TreasuryWallet → MigrationBridge → RDAT (via CREATE2). Liquidity provider address can be set post-deployment via admin.

---

## 🎯 Resolution Priority

**Must Resolve Before TreasuryWallet Implementation**:
1. Future Rewards split (#1)
2. Team token transfer process (#2)
3. TreasuryWallet initial distributions (#6)
4. Deployment dependencies (#10)

**Can Resolve During/After Implementation**:
- Phase 3 criteria (#4)
- Minor amount discrepancies (#3)
- Staking incentives clarity (#5)

---

## 📝 Additional Questions

### Implementation Questions:
- [ ] Should TreasuryWallet be pausable?
- [ ] Who can call checkAndRelease() - anyone or admin only?
- [ ] Should distributions emit events for indexing?
- [ ] Need slippage protection for time-based releases?

### Security Questions:
- [ ] What if TreasuryWallet is deployed to wrong address?
- [ ] Recovery mechanism for stuck tokens?
- [ ] Upgrade path for vesting schedule changes?

---

**Next Steps**: Let's go through these questions systematically to resolve all inconsistencies before proceeding with implementation.