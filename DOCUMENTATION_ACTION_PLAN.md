# Documentation Action Plan - RDAT V2

**Generated**: August 6, 2025  
**Purpose**: Specific actions to resolve documentation inconsistencies before audit  
**Timeline**: 3-5 days total effort  

---

## 🚨 Priority 1: Critical Documentation Fixes (Day 1)

### 1. Update SPECIFICATIONS_REVIEW.md
**File**: `SPECIFICATIONS_REVIEW.md`
**Issue**: Claims minting infrastructure exists
**Fix**: 
- Line 44: Change to "No minting infrastructure - mint() always reverts"
- Line 50: Remove "Implementation: Full minting capability exists but disabled"
- Add note: "Fixed supply model implemented - all 100M tokens minted at deployment"

### 2. Standardize Contract Count
**Files**: `SPECIFICATIONS.md`, `DEPLOYMENT_GUIDE.md`
**Issue**: Shows 14, 13, and 11 contracts in different places
**Fix**:
- Change all references to "11 core contracts"
- Update SPECIFICATIONS.md line 8: "14 total" → "11 core contracts"
- Update SPECIFICATIONS.md line 316: "13 Total" → "11 core contracts"
- Add clarification: "TreasuryWallet and TokenVesting are deployment helpers, not core protocol"

### 3. Fix vRDAT Distribution Formula
**Files**: `WHITEPAPER.md`, `SPECIFICATIONS.md`
**Issue**: Shows proportional formula that doesn't match implementation
**Fix in WHITEPAPER.md line 123**:
```markdown
#### Distribution Formula
vRDAT distributed based on lock period:
- 30 days: 1x multiplier (1:1 RDAT:vRDAT)
- 90 days: 1.15x multiplier 
- 180 days: 1.35x multiplier
- 365 days: 1.75x multiplier

Example: Staking 1000 RDAT for 365 days = 1750 vRDAT
```

### 4. Clarify Governance Status
**Files**: `WHITEPAPER.md`, `SPECIFICATIONS.md`
**Issue**: Claims on-chain governance is implemented
**Fix**: Add to governance sections:
```markdown
**Current Implementation**: Off-chain governance via Snapshot
- vRDAT tokens tracked on-chain
- Voting happens on Snapshot using vRDAT balances
- Execution via multisig based on Snapshot results
- On-chain governance planned for Phase 3
```

---

## 📋 Priority 2: Design Clarifications (Day 2-3)

### 5. Create Access Control Matrix
**New File**: `docs/ACCESS_CONTROL_MATRIX.md`
**Content**:
```markdown
# Access Control Matrix - RDAT V2

## Role Assignments

### RDATUpgradeable
- DEFAULT_ADMIN_ROLE: Multisig (Vana: 0x29Ce..., Base: 0x9001...)
- PAUSER_ROLE: Multisig + Emergency Response Team
- UPGRADER_ROLE: Multisig only (3/5 signatures)

### vRDAT
- DEFAULT_ADMIN_ROLE: Multisig
- MINTER_ROLE: vRDATRewardModule ONLY
- BURNER_ROLE: vRDATRewardModule ONLY

### StakingPositions
- ADMIN_ROLE: Multisig
- REWARDS_MANAGER_ROLE: RewardsManager contract

### RewardsManager
- DEFAULT_ADMIN_ROLE: Multisig
- STAKING_NOTIFIER_ROLE: StakingPositions contract

### MigrationBridge
- VALIDATOR_ROLE: 3 validators (addresses TBD)
- ADMIN_ROLE: Multisig

### Emergency Contacts
- Technical Lead: [TBD]
- Security Team: [TBD]
- Multisig Signers: [List of 5]
```

### 6. Document Phase 3 Activation
**File**: `SPECIFICATIONS.md`
**Add new section**:
```markdown
## Phase 3 Activation Process

The 30M RDAT "Future Rewards" allocation requires governance approval:

1. **Proposal Creation**: Any holder with 1000+ vRDAT can propose
2. **Voting Period**: 7 days on Snapshot
3. **Approval Threshold**: 
   - 65% approval required
   - 10% quorum of total vRDAT supply
4. **Execution**: Multisig executes based on vote
5. **Unlock Mechanism**: 
   - Multisig calls `unlockPhase3Rewards()` on TreasuryWallet
   - Transfers 30M RDAT to RewardsManager
   - Enables RDAT staking rewards

**Fallback**: If not activated within 2 years, converts to treasury funds
```

### 7. Document Manual Revenue Distribution
**File**: `SPECIFICATIONS.md` 
**Update Revenue Distribution section**:
```markdown
### Revenue Distribution (Current Implementation)

**V2 Beta**: Semi-automated with manual triggers
- RevenueCollector receives all protocol revenue
- Admin calls `distributeRevenue()` (weekly basis)
- 50/30/20 split for RDAT only
- Non-RDAT tokens accumulate in treasury

**Future (V3)**: Fully automated
- Automatic distribution on threshold
- DEX integration for token swaps
- Multi-token reward support
```

### 8. Revise Migration Incentives
**File**: `SPECIFICATIONS.md`
**Update migration bonus structure**:
```markdown
### Migration Incentives (Revised)

To prevent rush and ensure gradual migration:
- Week 1-4: 3% bonus (steady incentive)
- Week 5-8: 2% bonus (maintaining momentum)  
- Week 9-12: 1% bonus (late adopters)
- After Week 12: No bonus

Rationale: Flatter curve prevents week 1 rush while maintaining incentives
```

---

## 🔧 Priority 3: Technical Documentation (Day 4-5)

### 9. Add VRC-20 Compliance Status
**File**: `docs/VRC20_COMPLIANCE_STATUS.md`
**Create new file**:
```markdown
# VRC-20 Compliance Status

## Current Implementation (V2 Beta)
✅ Basic compliance flags
✅ PoC contract pointer
✅ Fixed supply model
⚠️ Stub implementation only

## Missing Features
- Data licensing hooks
- Reward calculation methods
- DLP registry integration
- Automated fee processing

## Timeline
- V2 Beta: Basic compliance for deployment
- V3: Full DLP integration
- V4: Advanced data marketplace features
```

### 10. Update StakingPositions References
**Files**: All documentation
**Issue**: Sometimes called "StakingManager"
**Fix**: Find/replace all instances to "StakingPositions"

### 11. Create Emergency Response Playbook
**New File**: `docs/EMERGENCY_RESPONSE.md`
**Content**: Detailed procedures for various emergency scenarios

### 12. Integration Test Documentation
**File**: `docs/TESTING_REQUIREMENTS.md`
**Add section on cross-contract integration tests needed

---

## 📊 Quick Reference Fixes

### Numbers to Standardize
- Total Contracts: **11**
- Total Supply: **100M RDAT**
- Migration Allocation: **30M RDAT**
- Treasury Operations: **70M RDAT**
- vRDAT Multipliers: **1x, 1.15x, 1.35x, 1.75x**

### Key Clarifications
- Minting: **DISABLED - fixed supply only**
- Governance: **Off-chain via Snapshot (for now)**
- Revenue Distribution: **Manual trigger (for now)**
- VRC-20: **Basic stub (full integration later)**

### Consistent Terminology
- Use "StakingPositions" (not StakingManager)
- Use "11 core contracts" (not 13 or 14)
- Use "fixed supply model" (emphasize no minting)
- Use "off-chain governance" (be honest)

---

## ✅ Validation Checklist

After making changes, verify:
- [ ] All files show 11 contracts
- [ ] No references to minting capability
- [ ] vRDAT formula matches implementation
- [ ] Governance clearly marked as off-chain
- [ ] Phase 3 activation process documented
- [ ] Access control matrix complete
- [ ] Revenue distribution marked as manual

---

## 🎯 Expected Outcome

After completing these actions:
- Documentation will accurately reflect implementation
- Auditors will have clear understanding of system
- No confusion about features vs. promises
- Honest representation of V2 Beta vs. future phases

**Total Effort**: 3-5 days with 1-2 developers
**Result**: Audit-ready documentation matching implementation