# Sprint 2 Roadmap: VRC-20 Compliance Pre-Audit Sprint

**Sprint Duration**: 11 days (remaining)  
**Start Date**: August 7, 2025 (TODAY)  
**End Date**: August 18, 2025  
**Sprint Goal**: Implement essential VRC-20 compliance features BEFORE audit to ensure DLP eligibility

## Sprint Overview

This sprint focuses on rapid VRC-20 compliance implementation:
1. **Blocklisting System** - Required for VRC-20 (Days 3-4)
2. **48-Hour Timelocks** - Critical for security (Days 5-6)
3. **DLP Registration** - Enable reward eligibility (Days 8-9)
4. **Audit Preparation** - Freeze compliant code (Days 10-11)

## Priority Levels

- 🔴 **P0 (Critical)**: Must complete for mainnet launch
- 🟡 **P1 (Important)**: Should complete for full functionality  
- 🟢 **P2 (Nice-to-have)**: Can defer to post-launch

## Week 1 (August 7-13)

### Day 1-2: Sprint Setup & VRC-20 Assessment (Aug 7-8)
**Owner**: Entire Team

🔴 **P0 Tasks - TODAY (Aug 7)**:
- [x] Review VRC-20 compliance gaps (75% compliant)
- [x] Assess RDATUpgradeableV2.sol implementation
- [ ] Decide on minimal viable compliance approach
- [ ] Create V2 upgrade strategy
- [ ] Setup feature branches for VRC-20 work

🟡 **P1 Tasks**:
- [ ] Document audit remediations needed
- [ ] Update test suite based on audit feedback

### Day 3-4: Blocklisting Implementation (Aug 9-10)
**Owner**: Developer 1 (Weekend Work)

🔴 **P0 Tasks - Blocklisting**:
- [ ] Port blocklist system from RDATUpgradeableV2
- [ ] Implement blacklist/unBlacklist admin functions
- [ ] Add transfer restrictions for blacklisted addresses
- [ ] Write comprehensive blocklist tests
- [ ] Verify gas impact is acceptable

### Day 5-6: 48-Hour Timelocks (Aug 11-12)
**Owner**: Developer 2

🔴 **P0 Tasks - Timelocks**:
- [ ] Implement 48-hour timelock for upgrades (use V2 code)
- [ ] Add admin transfer delay mechanism
- [ ] Create schedule/execute/cancel pattern
- [ ] Write timelock scenario tests
- [ ] Document timelock procedures

### Day 7: Integration & Testing (Aug 13)
**Owner**: Full Team

🔴 **P0 Tasks**:
- [ ] Merge audit fixes to main branch
- [ ] Run full test suite (must be 100% passing)
- [ ] Deploy to testnet for integration testing
- [ ] Test migration flow end-to-end on testnet
- [ ] Test vesting contract with real addresses

🟡 **P1 Tasks**:
- [ ] Gas optimization based on audit recommendations
- [ ] Update documentation with audit changes

## Week 2 (August 14-18)

### Day 8-9: DLP Registration & Compliance (Aug 14-15)
**Owner**: Dev Team

🔴 **P0 Tasks - Minimum DLP Registration**:
- [ ] Implement basic DLP registration:
  ```solidity
  contract RDATUpgradeable {
      address public dlpAddress;
      bool public isDLPRegistered;
      
      function registerDLP(address _dlpAddress) external onlyRole(ADMIN_ROLE) {
          require(!isDLPRegistered, "Already registered");
          dlpAddress = _dlpAddress;
          isDLPRegistered = true;
          emit DLPRegistered(_dlpAddress, block.timestamp);
      }
  }
  ```
- [ ] Add epoch tracking (basic):
  ```solidity
  mapping(uint256 => uint256) public epochRewards;
  uint256 public currentEpoch = 1;
  
  function getCurrentEpoch() external view returns (uint256) {
      return currentEpoch;
  }
  ```
- [ ] Update ProofOfContributionStub with real validators
- [ ] Test VRC-20 interface compliance

🟡 **P1 Tasks - Enhanced Features**:
- [ ] Basic kismet calculation (can be simplified):
  ```solidity
  function calculateDataRewards(address user, uint256 dataValue) external view returns (uint256) {
      // Simplified version for launch
      uint256 userScore = proofOfContribution.totalScore(user);
      return (dataValue * userScore) / 10000;
  }
  ```

### Day 10: Final Testing & Deployment (Aug 16)
**Owner**: Full Team

🔴 **P0 Tasks**:
- [ ] Final testnet deployment (Vana Moksha + Base Sepolia)
- [ ] Run complete integration tests
- [ ] Verify all multisig transactions prepared
- [ ] Create deployment checklist
- [ ] Prepare deployment scripts with correct addresses:
  ```bash
  # Vana Mainnet
  ADMIN=0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319
  TREASURY=0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319
  
  # Base Mainnet  
  ADMIN=0x90013583c66D2bf16327cB5Bc4a647AcceCF4B9A
  TREASURY=0x90013583c66D2bf16327cB5Bc4a647AcceCF4B9A
  ```

🟡 **P1 Tasks**:
- [ ] Update frontend to show deployment status
- [ ] Prepare announcement materials

### Day 11: Audit Preparation (Aug 17-18)
**Owner**: Full Team + Multisig Signers

🔴 **P0 - Deployment Sequence**:

#### Audit Submission (Aug 19)
**Morning (9 AM - 12 PM)**:
- [ ] Deploy CREATE2 Factory
- [ ] Deploy EmergencyPause
- [ ] Deploy ProofOfContributionStub
- [ ] Deploy vRDAT
- [ ] Deploy TreasuryWallet

**Afternoon (1 PM - 5 PM)**:
- [ ] Deploy RDATUpgradeable (via CREATE2)
- [ ] Deploy VanaMigrationBridge
- [ ] Deploy StakingPositions
- [ ] Deploy RewardsManager + vRDATRewardModule
- [ ] Deploy TokenVesting

**Evening (6 PM - 8 PM)**:
- [ ] Verify all contracts on explorer
- [ ] Run deployment verification script
- [ ] Document deployed addresses

#### Day 14: Base Mainnet Deployment + Go-Live
**Morning (9 AM - 12 PM)**:
- [ ] Deploy migration helper contracts on Base
- [ ] Configure bridge validators (minimum 3)
- [ ] Test bridge validation flow
- [ ] Enable migration on Base V1 contract

**Afternoon (1 PM - 4 PM)**:
- [ ] Public announcement
- [ ] Enable staking on Vana
- [ ] Monitor first transactions
- [ ] Support team on standby

## Parallel Workstreams

### Documentation Track (Throughout Sprint)
**Owner**: Technical Writer / Dev Support

🟡 **P1 Tasks**:
- [ ] Update deployment guide with mainnet addresses
- [ ] Create user migration guide
- [ ] Write staking tutorial
- [ ] Update technical FAQ with audit findings
- [ ] Create troubleshooting guide

### DevOps Track (Days 1-10)
**Owner**: DevOps Engineer

🔴 **P0 Tasks**:
- [ ] Setup monitoring for all contracts
- [ ] Configure alerting for bridge validations
- [ ] Setup validator infrastructure (3 validators minimum)
- [ ] Create emergency response runbooks
- [ ] Setup contract verification automation

🟡 **P1 Tasks**:
- [ ] Setup analytics dashboard
- [ ] Configure backup RPC endpoints
- [ ] Create automated testing pipeline

## Success Criteria

### Must Have (🔴 P0)
- [x] All audit critical/high findings resolved
- [x] Contracts deployed to mainnet (Base + Vana)
- [x] Migration bridge operational with 3+ validators
- [x] Staking system live and accepting deposits
- [x] TokenVesting deployed with team allocations
- [x] Basic VRC-20 compliance for DLP eligibility

### Should Have (🟡 P1)
- [ ] Gas optimizations implemented
- [ ] Enhanced monitoring and alerting
- [ ] Complete documentation
- [ ] Basic kismet rewards

### Nice to Have (🟢 P2) - Defer to Sprint 3
- [ ] Full ProofOfContribution implementation
- [ ] Data pool management
- [ ] Advanced kismet formula
- [ ] Cross-DLP integrations

## Risk Management

### High Risk Items
1. **Audit Findings Complexity**
   - Mitigation: Reserve 50% of sprint for fixes
   - Backup: Delay non-critical features

2. **Mainnet Deployment Issues**
   - Mitigation: Practice on testnet Day 11-12
   - Backup: Deployment rollback plan ready

3. **Bridge Validator Setup**
   - Mitigation: Test validators on Day 8-10
   - Backup: Team acts as initial validators

### Dependencies
- Audit report available by Day 1
- Multisig signers available Day 13-14
- Vana team responsive for DLP questions
- Base and Vana mainnets stable

## Daily Standups

**Time**: 10 AM EST Daily  
**Duration**: 15 minutes  
**Format**: 
- What did you complete yesterday?
- What will you work on today?
- Any blockers?

## Sprint Deliverables

By end of Sprint 2, we will have:

1. ✅ **Mainnet Deployment**: Live on Base and Vana
2. ✅ **Audit Compliance**: All critical findings addressed
3. ✅ **VRC-20 Basic**: Minimum compliance for DLP
4. ✅ **Migration Active**: V1 holders can migrate
5. ✅ **Staking Live**: Users can stake and earn vRDAT
6. ✅ **Team Vesting**: TokenVesting deployed and configured

## Post-Sprint (September 2+)

### Sprint 3 Focus (2 weeks):
- Full ProofOfContribution implementation
- Data pool management system
- Enhanced kismet formula
- Reddit API integration

### Sprint 4 Focus (2 weeks):
- Cross-DLP integrations
- Advanced analytics
- Governance deployment
- Community incentive programs

## Communication Plan

### Internal Updates
- Daily: Slack standups
- Day 7: Mid-sprint review
- Day 14: Sprint retrospective

### External Updates
- Day 7: Community progress update
- Day 12: Deployment announcement (48hr notice)
- Day 14: Launch announcement

## Definition of Done

A task is complete when:
- [ ] Code is written and tested
- [ ] Tests pass (100% of existing tests)
- [ ] Code reviewed by another developer
- [ ] Documentation updated
- [ ] Deployed to testnet (if applicable)
- [ ] Verified working end-to-end

## Emergency Procedures

If critical issues arise:
1. **Stop deployment** if in progress
2. **Convene emergency meeting** within 2 hours
3. **Assess impact** and options
4. **Decide**: Fix now, rollback, or defer
5. **Communicate** to team and community

## Team Assignments

| Role | Primary Owner | Backup |
|------|--------------|--------|
| Audit Remediation | Developer 1 | Developer 2 |
| VRC-20 Implementation | Developer 2 | Developer 1 |
| Testing | QA Engineer | Developer 1 |
| Deployment | DevOps | Developer 2 |
| Documentation | Technical Writer | Developer 1 |
| Validator Setup | DevOps | Developer 2 |
| Community Comms | Community Manager | Product Owner |

---

*This sprint roadmap is aggressive but achievable with focused execution. Daily standups and clear priorities are essential for success.*