# 📅 Updated Sprint Plan - RDAT V2 Beta

**Sprint Duration**: August 5-18, 2025 (13 days)  
**Current Date**: August 6, 2025  
**Days Remaining**: 12 days  
**Target**: Audit-ready contracts for Phase 1 (Launch)

## 🎯 Sprint Goals

### Primary Objectives:
1. Complete all Phase 1 contracts (vRDAT rewards only)
2. Implement TreasuryWallet with vesting schedules
3. Fix all test compilation errors
4. Achieve 90%+ test coverage
5. Prepare for security audit

### Out of Scope (Phase 3):
- RDATRewardModule implementation
- Full ProofOfContribution integration
- DEX swap functionality for RevenueCollector
- Governance extensions

## 📊 Current Status

### ✅ Completed (9/13 contracts):
1. RDATUpgradeable ✅
2. vRDAT ✅
3. StakingPositions ✅
4. RewardsManager ✅
5. vRDATRewardModule ✅
6. RevenueCollector ✅
7. EmergencyPause ✅
8. ProofOfContribution (stub) ✅
9. MockRDAT ✅

### 🚧 In Progress:
1. TreasuryWallet (NEW - High Priority)
2. Test fixes for fixed supply

### 📋 Remaining:
1. MigrationBridge
2. Deployment scripts
3. Integration testing

## 📅 Day-by-Day Plan

### Day 1-2 (Aug 6-7): TreasuryWallet Implementation
- [ ] Design TreasuryWallet contract
- [ ] Implement vesting schedules
- [ ] Add Phase 3 activation logic
- [ ] Write comprehensive tests
- [ ] Update deployment scripts

### Day 3-4 (Aug 8-9): Test Suite Fixes
- [ ] Fix all RDAT minting references in tests
- [ ] Update test expectations for fixed supply
- [ ] Remove contradictory test scenarios
- [ ] Achieve 90%+ coverage on all contracts

### Day 5-6 (Aug 10-11): MigrationBridge
- [ ] Implement cross-chain bridge contract
- [ ] Add 1-year deadline mechanism
- [ ] Implement return to TreasuryWallet
- [ ] Write security-focused tests

### Day 7-8 (Aug 12-13): Integration & Deployment
- [ ] Full deployment script with proper sequence
- [ ] Cross-contract integration tests
- [ ] Gas optimization pass
- [ ] Initial audit prep documentation

### Day 9-10 (Aug 14-15): Security Review
- [ ] Internal security review
- [ ] Fix any critical issues found
- [ ] Update all documentation
- [ ] Prepare audit package

### Day 11-12 (Aug 16-17): Final Polish
- [ ] Address any remaining issues
- [ ] Final test run on testnet
- [ ] Complete audit documentation
- [ ] Team review and sign-off

### Day 13 (Aug 18): Audit Submission
- [ ] Submit contracts for audit
- [ ] Deploy to testnet
- [ ] Public announcement

## 🔧 Technical Tasks Breakdown

### TreasuryWallet Contract:
```solidity
contract TreasuryWallet is UUPSUpgradeable, AccessControlUpgradeable {
    struct VestingSchedule {
        uint256 total;
        uint256 released;
        uint256 tgeAmount;
        uint256 cliffDuration;
        uint256 vestingDuration;
        uint256 startTime;
        bool isPhase3Gated;
    }
    
    mapping(bytes32 => VestingSchedule) public vestingSchedules;
    bool public phase3Active;
    
    function setupVestingSchedule(...) external onlyRole(ADMIN_ROLE);
    function setPhase3Active() external onlyRole(ADMIN_ROLE);
    function checkAndRelease() external;
    function distribute(address to, uint256 amount) external onlyRole(DISTRIBUTOR_ROLE);
    function executeDAOProposal(...) external onlyRole(DAO_ROLE);
}
```

### Test Updates Required:
1. Replace all `rdat.mint()` with treasury transfers
2. Update initialization to 3 parameters
3. Remove MINTER_ROLE references
4. Fix reward expectations (no minting)
5. Update vRDAT tests for no delay

### Deployment Order:
1. EmergencyPause
2. CREATE2 Factory
3. vRDAT
4. TreasuryWallet
5. RDAT (with TreasuryWallet address)
6. MigrationBridge (with CREATE2)
7. StakingPositions
8. RewardsManager
9. vRDATRewardModule
10. RevenueCollector

## 🚨 Critical Path Items

### Must Complete by Aug 10:
- TreasuryWallet implementation
- All test fixes
- Basic deployment script

### Must Complete by Aug 14:
- MigrationBridge
- Full integration testing
- Gas optimization

### Must Complete by Aug 18:
- Security review complete
- All documentation updated
- Testnet deployment successful

## 📈 Success Metrics

### Code Quality:
- [ ] 90%+ test coverage
- [ ] 0 high/critical issues in slither
- [ ] All tests passing
- [ ] Gas usage optimized

### Documentation:
- [ ] All specs updated and consistent
- [ ] Deployment guide complete
- [ ] Security considerations documented
- [ ] API documentation complete

### Deployment:
- [ ] Testnet deployment successful
- [ ] All contracts verified
- [ ] Integration tests passing
- [ ] Ready for audit

## 🚀 Phase 3 Planning (Post-Launch)

### When Phase 3 Activates:
1. Deploy RDATRewardModule
2. Fund with 30M RDAT from TreasuryWallet
3. Register with RewardsManager
4. Enable RDAT staking rewards

### Future Enhancements:
- Full ProofOfContribution integration
- DEX integration for fee swaps
- Governance contract deployment
- Additional reward modules

---

**Note**: This sprint focuses on delivering a secure, functional Phase 1 with only vRDAT rewards. RDAT staking rewards and other advanced features are deferred to Phase 3 to meet our tight timeline.