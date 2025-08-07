# 📅 Sprint 2 Roadmap: VRC-20 Compliance & Pre-Audit Preparation

**Sprint Duration**: 21 days (Extended by 1 week)  
**Start Date**: December 20, 2024  
**End Date**: January 10, 2025  
**Sprint Goal**: Achieve full VRC-20 compliance BEFORE audit to ensure clean audit results

## 🔄 Major Changes from Original Plan

### Timeline Adjustments
- **Sprint extended**: 14 days → 21 days
- **Audit postponed**: Now scheduled for January 11, 2025
- **VRC-20 compliance**: Moved from "post-audit" to "pre-audit" priority

### Rationale for Changes
1. **Audit efficiency**: Better to audit compliant code than fix compliance after
2. **Cost savings**: One audit vs. audit + re-audit for compliance
3. **Risk reduction**: Avoid deployment delays due to non-compliance
4. **DLP eligibility**: Can register immediately after mainnet launch

## Priority Levels

- 🔴 **P0 (Blocker)**: Must complete before audit
- 🟡 **P1 (Critical)**: Must complete before mainnet  
- 🟢 **P2 (Important)**: Can complete post-mainnet

---

## Week 1: VRC-20 Critical Features (Dec 20-26)

### Day 1-2: Sprint Planning & Setup
**Owner**: Full Team

🔴 **P0 Tasks**:
- [ ] Review VRC-20 compliance gaps from analysis
- [ ] Setup development branches for V2 upgrade
- [ ] Review DATFactory implementation patterns
- [ ] Plan upgrade strategy for existing contracts
- [ ] Document breaking changes

### Day 3-4: Implement Blocklisting System
**Owner**: Developer 1

🔴 **P0 Tasks - Blocklisting**:
- [ ] Implement blocklist mapping and storage
  ```solidity
  mapping(address => bool) private _blacklist;
  mapping(address => uint256) private _blacklistTimestamp;
  ```
- [ ] Add blocklist modifiers and checks
- [ ] Implement admin functions:
  - `blacklist(address account)`
  - `unBlacklist(address account)`
  - `isBlacklisted(address account)`
- [ ] Override transfer functions to check blocklist
- [ ] Write comprehensive tests for blocklist
- [ ] Test gas impact of blocklist checks

### Day 5-6: Complete 48-Hour Timelocks
**Owner**: Developer 2

🔴 **P0 Tasks - Timelocks**:
- [ ] Implement timelock system for all critical functions:
  ```solidity
  struct PendingAction {
      address target;
      bytes data;
      uint256 executeTime;
      bool executed;
  }
  mapping(bytes32 => PendingAction) public pendingActions;
  ```
- [ ] Add timelock to:
  - Contract upgrades
  - Fee changes (if implementing)
  - Critical parameter updates
  - Admin role transfers
- [ ] Implement schedule/execute/cancel pattern
- [ ] Write tests for timelock scenarios
- [ ] Document timelock procedures

### Day 7: Integration Testing
**Owner**: Full Team

🔴 **P0 Tasks**:
- [ ] Merge blocklist and timelock features
- [ ] Run full test suite
- [ ] Deploy to local testnet
- [ ] Test upgrade from V1 to V2
- [ ] Document any breaking changes

---

## Week 2: Admin Controls & DLP Integration (Dec 27 - Jan 2)

### Day 8-9: Enhanced Admin Controls
**Owner**: Developer 1

🔴 **P0 Tasks - Admin Transfer**:
- [ ] Implement admin transfer with 48-hour delay:
  ```solidity
  function initiateAdminTransfer(address newAdmin)
  function completeAdminTransfer()
  function cancelAdminTransfer()
  ```
- [ ] Add role management safeguards
- [ ] Implement emergency admin recovery
- [ ] Test admin transfer scenarios
- [ ] Document admin procedures

### Day 10-11: Compliance Tracking System
**Owner**: Developer 2

🔴 **P0 Tasks - Compliance Flags**:
- [ ] Implement compliance tracking:
  ```solidity
  mapping(string => bool) public complianceChecks;
  mapping(string => uint256) public complianceTimestamps;
  ```
- [ ] Set initial compliance flags:
  - `VRC20_COMPLIANT`
  - `BLOCKLIST_ENABLED`
  - `VESTING_CONFIGURED`
  - `TIMELOCK_ENABLED`
  - `AUDIT_PASSED`
- [ ] Create compliance verification functions
- [ ] Write compliance check tests

### Day 12-13: DLP Registration Enhancement
**Owner**: Developer 1

🔴 **P0 Tasks - DLP Integration**:
- [ ] Upgrade DLP registration from stub:
  ```solidity
  function registerWithDLPRegistry(
      address registryAddress,
      string memory metadata,
      address[] memory validators
  ) external returns (uint256)
  ```
- [ ] Implement data pool management functions
- [ ] Add epoch reward tracking
- [ ] Enhance ProofOfContribution from stub
- [ ] Test DLP registration flow

### Day 14: Holiday Buffer / Catch-up
**Owner**: Available Team Members

🟡 **P1 Tasks**:
- [ ] Address any incomplete P0 tasks
- [ ] Code review backlog
- [ ] Documentation updates
- [ ] Prepare for Week 3

---

## Week 3: Testing, Deployment & Audit Prep (Jan 3-10)

### Day 15-16: Comprehensive Testing
**Owner**: Full Team

🔴 **P0 Tasks - Testing**:
- [ ] Deploy V2 to Moksha testnet
- [ ] Run full compliance verification:
  ```bash
  forge script script/VerifyCompliance.s.sol --rpc-url moksha
  ```
- [ ] Test all VRC-20 required functions
- [ ] Test upgrade path from current contracts
- [ ] Verify gas costs are acceptable
- [ ] Run Slither and fix any issues

### Day 17-18: Optional Features & Optimization
**Owner**: Developer 2

🟡 **P1 Tasks - Nice to Have**:
- [ ] Implement fee management (if needed):
  ```solidity
  uint256 public feePercentage;
  address public feeRecipient;
  ```
- [ ] Add batch operations for gas efficiency
- [ ] Optimize storage layout
- [ ] Enhanced event emissions

### Day 19: Documentation Sprint
**Owner**: Full Team

🔴 **P0 Tasks - Documentation**:
- [ ] Update all contract NatSpec comments
- [ ] Document breaking changes from V1
- [ ] Create upgrade guide for users
- [ ] Update technical architecture docs
- [ ] Prepare audit documentation package:
  - Contract descriptions
  - Access control matrix
  - State transition diagrams
  - Known issues/limitations

### Day 20: Final Deployment & Verification
**Owner**: DevOps + Developer 1

🔴 **P0 Tasks - Pre-Audit Deployment**:
- [ ] Deploy final V2 to Moksha testnet
- [ ] Deploy final V2 to Base Sepolia
- [ ] Verify all contracts on explorers
- [ ] Run final compliance check
- [ ] Create deployment report
- [ ] Tag release candidate: `v2.0.0-rc1`

### Day 21: Audit Handoff
**Owner**: Project Manager + Tech Lead

🔴 **P0 Tasks - Audit Preparation**:
- [ ] Compile audit package:
  - Source code (frozen commit)
  - Test suite
  - Documentation
  - Deployment addresses
  - Previous audit reports (if any)
- [ ] Schedule audit kick-off call
- [ ] Assign point of contact for auditors
- [ ] Create private channel for audit Q&A
- [ ] Begin audit (January 11, 2025)

---

## Parallel Workstreams

### Security Track (Throughout Sprint)
**Owner**: Security Engineer

🔴 **P0 Tasks**:
- [ ] Run Mythril on new code daily
- [ ] Run Slither after each merge
- [ ] Fuzzing tests for new functions
- [ ] Review access control changes
- [ ] Document security assumptions

### Testing Track (Days 5-20)
**Owner**: QA Engineer

🔴 **P0 Tasks**:
- [ ] Write tests for blocklist functions
- [ ] Write tests for timelock system
- [ ] Write tests for admin transfer
- [ ] Integration tests for V1→V2 upgrade
- [ ] Gas profiling and optimization

---

## Success Criteria

### Week 1 Complete When:
- ✅ Blocklisting fully implemented and tested
- ✅ 48-hour timelocks operational
- ✅ All tests passing

### Week 2 Complete When:
- ✅ Admin transfer with delay working
- ✅ Compliance flags implemented
- ✅ DLP registration enhanced
- ✅ ProofOfContribution upgraded

### Week 3 Complete When:
- ✅ Deployed to all testnets
- ✅ Compliance verification passing
- ✅ Documentation complete
- ✅ Audit package delivered

---

## Risk Management

### High Risk Items

1. **Breaking Changes in V2**
   - Risk: Existing integrations break
   - Mitigation: Maintain backwards compatibility where possible
   - Contingency: Provide migration guides

2. **Timelock Complexity**
   - Risk: Timelock system has bugs
   - Mitigation: Extensive testing, use proven patterns
   - Contingency: Can disable if critical issue found

3. **Audit Delays**
   - Risk: Audit finds critical issues
   - Mitigation: Internal security review first
   - Contingency: Hot-fix sprint post-audit

### Dependencies
- DATFactory source code for reference ✅
- VRC-20 specification clarity ✅
- Team availability during holidays ⚠️
- Auditor availability Jan 11 ⚠️

---

## Revised Timeline Summary

```
December 2024
├── Week 1 (Dec 20-26): VRC-20 Critical Features
│   ├── Blocklisting System
│   └── 48-Hour Timelocks
│
├── Week 2 (Dec 27-Jan 2): Admin & DLP
│   ├── Admin Transfer Delay
│   ├── Compliance Tracking
│   └── DLP Registration
│
January 2025
├── Week 3 (Jan 3-10): Testing & Audit Prep
│   ├── Comprehensive Testing
│   ├── Documentation
│   └── Audit Package
│
├── Week 4 (Jan 11-17): AUDIT PERIOD
│   └── Address auditor questions
│
├── Week 5 (Jan 18-24): Audit Fixes
│   └── Implement required changes
│
└── Week 6 (Jan 25-31): Mainnet Deployment
    ├── Deploy to Vana Mainnet
    └── Deploy to Base Mainnet
```

---

## Key Differences from Original Plan

| Aspect | Original Plan | Revised Plan |
|--------|--------------|--------------|
| **Duration** | 14 days | 21 days |
| **Audit Timing** | Before VRC-20 | After VRC-20 |
| **Blocklisting** | Post-audit | Pre-audit |
| **Timelocks** | Partial | Complete |
| **DLP Integration** | Basic stub | Full implementation |
| **Risk Level** | High (non-compliant audit) | Low (compliant audit) |

---

## Communication Plan

### Daily Standups
- **Time**: 10 AM EST
- **Focus**: Blockers on VRC-20 compliance
- **Duration**: 15 minutes max

### Weekly Reviews
- **Dec 26**: Week 1 VRC-20 features complete
- **Jan 2**: Week 2 Admin/DLP complete  
- **Jan 10**: Ready for audit

### External Communication
- **Dec 27**: Community update on VRC-20 progress
- **Jan 3**: Announce audit date
- **Jan 11**: Audit begins announcement
- **Jan 25**: Mainnet deployment timeline

---

## Definition of Done for VRC-20

A feature is VRC-20 compliant when:
- [ ] Matches DATFactory interface exactly
- [ ] Has comprehensive test coverage
- [ ] Gas costs are reasonable
- [ ] Documentation is complete
- [ ] Deployed and verified on testnet
- [ ] Compliance check script passes

---

## Post-Sprint Planning

### Sprint 3 (Post-Audit): Jan 18-31
- Audit remediation
- Mainnet deployment
- Migration activation
- DLP registration on Vana

### Sprint 4 (Post-Launch): Feb 1-14
- Monitor and optimize
- Community onboarding
- Liquidity provision
- Governance activation

---

*This revised sprint prioritizes VRC-20 compliance before audit, reducing risk and ensuring a smoother path to mainnet deployment and DLP reward eligibility.*