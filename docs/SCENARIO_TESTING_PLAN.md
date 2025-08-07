# Comprehensive Scenario Testing Plan

*Date: August 7, 2025*  
*Version: 1.0*  
*Purpose: Complete user journey testing for migration, staking, and governance*

## Overview

This document outlines a comprehensive plan to build scenario tests that cover the complete user experience across the three main pillars of the r/datadao V2 system:

1. **Cross-Chain Migration**: Base → Vana token migration with validator consensus
2. **Staking & Rewards**: Token staking, position management, and reward claiming
3. **Governance**: Proposal creation, voting, and execution with hybrid on/off-chain flow

## Current Test Coverage Analysis

### ✅ Existing Tests
- **CrossChainMigration.t.sol**: Basic migration flow with validator consensus
- **ModularGovernanceIntegration.t.sol**: Core governance module interactions
- **StakingPositions.t.sol**: Individual staking operations
- **VRC20Compliance.t.sol**: VRC-20 feature testing

### ❌ Missing Scenario Coverage
- **Complete User Journeys**: End-to-end flows across multiple contracts
- **Off-Chain Simulation**: Validator coordination, snapshot voting
- **Real-World Timing**: Realistic delays and sequences
- **Error Recovery**: What happens when steps fail mid-journey
- **Cross-System Integration**: How migration affects staking affects governance

---

## 📋 Scenario Test Structure

### Test Categories
```
test/scenarios/
├── migration/
│   ├── CompleteMigrationJourney.t.sol
│   ├── MigrationEdgeCases.t.sol
│   └── ValidatorCoordination.t.sol
├── staking/
│   ├── StakingLifecycle.t.sol
│   ├── RewardOptimization.t.sol
│   └── PositionManagement.t.sol
├── governance/
│   ├── ProposalLifecycle.t.sol
│   ├── HybridVoting.t.sol
│   └── GovernanceExecution.t.sol
├── integration/
│   ├── MigrationToStaking.t.sol
│   ├── StakingToGovernance.t.sol
│   └── FullEcosystemJourney.t.sol
└── helpers/
    ├── OffChainSimulator.sol
    ├── ScenarioHelpers.sol
    └── MockExternalServices.sol
```

---

## 🔄 Migration Scenario Tests

### 1. Complete Migration Journey (`CompleteMigrationJourney.t.sol`)

**User Story**: "As a V1 RDAT holder, I want to migrate my tokens from Base to Vana and start staking immediately."

**Test Scenarios**:
```solidity
test_HappyPath_SmallMigration()      // < 1000 RDAT
test_HappyPath_LargeMigration()      // > 100k RDAT  
test_HappyPath_MaxDailyLimit()       // = 300k RDAT
test_BonusDecay_WeekByWeek()         // Time-based bonus testing
test_MigrationWithStaking()          // Immediate staking post-migration
```

**Off-Chain Simulation Required**:
- **Validator Coordination**: Mock 3/5 validator consensus
- **Challenge Period**: Simulate 6-hour waiting periods
- **Cross-Chain Events**: Base event → Vana execution

### 2. Migration Edge Cases (`MigrationEdgeCases.t.sol`)

**Failure Scenarios**:
```solidity
test_InvalidBurnProof()              // Malformed burn evidence
test_ValidatorCollusion()            // 2/3 validators agree on wrong amount
test_DuplicateMigration()           // Same burn hash used twice
test_ExpiredMigrationWindow()       // Migration after 1 year deadline
test_ContractPausedDuringMigration() // Emergency pause mid-flow
test_InsufficientBridgeBalance()    // Bridge runs out of V2 tokens
```

### 3. Validator Coordination (`ValidatorCoordination.t.sol`)

**Multi-Actor Scenarios**:
```solidity
test_ValidatorUptime()              // Validators going offline
test_ValidatorRemoval()             // Admin removes misbehaving validator
test_ValidatorRotation()            // Adding new validators
test_SlashingProtection()           // Preventing validator attacks
```

---

## 💰 Staking Scenario Tests

### 1. Staking Lifecycle (`StakingLifecycle.t.sol`)

**User Story**: "As a token holder, I want to optimize my staking strategy for maximum governance power and rewards."

**Test Scenarios**:
```solidity
test_NewUser_FirstTimeStaking()     // Onboarding experience
test_StakingStrategyOptimization()   // Multiple positions for max rewards
test_PositionConsolidation()        // Unstaking and re-staking
test_EmergencyWithdrawal()          // 50% penalty scenarios
test_MaxPositionsPerUser()          // 100 position limit testing
```

### 2. Reward Optimization (`RewardOptimization.t.sol`)

**Complex Reward Scenarios**:
```solidity
test_RewardAccrualOverTime()        // 30/90/180/365 day periods
test_CompoundStaking()              // Using rewards to create new positions
test_RewardModuleUpgrades()         // New reward types added
test_RevenueSharing()               // 50/30/20 revenue split flow
test_MultiTokenRewards()            // RDAT + external token rewards
```

### 3. Position Management (`PositionManagement.t.sol`)

**NFT Position Scenarios**:
```solidity
test_PositionTransfers()            // Trading locked positions
test_PositionMetadata()             // NFT data accuracy
test_PositionEnumeration()          // Gas costs with 100 positions
test_PositionRecovery()             // Lost NFT recovery mechanisms
```

---

## 🗳️ Governance Scenario Tests

### 1. Proposal Lifecycle (`ProposalLifecycle.t.sol`)

**User Story**: "As a DAO member, I want to create a proposal, gather support, and see it executed."

**Complete Flow**:
```solidity
test_ProposalCreation()             // Create with proper snapshot backing
test_CommunityDiscussion()          // Off-chain discussion period
test_SnapshotVoting()               // Off-chain temperature check
test_OnChainVoting()                // Quadratic voting with vRDAT
test_ProposalExecution()            // Timelock and execution
test_ProposalCancellation()         // Admin emergency cancellation
```

### 2. Hybrid Voting (`HybridVoting.t.sol`)

**Two-Phase Voting System**:
```solidity
test_OffChainSnapshot()             // Simulate snapshot.org integration
test_QuorumCalculation()            // Different quorum thresholds
test_QuadraticVotingMath()          // Cost calculation accuracy
test_VotingPowerDecay()             // vRDAT balance changes during voting
test_VoteEscrow()                   // Locking vRDAT during voting
```

### 3. Governance Execution (`GovernanceExecution.t.sol`)

**Post-Voting Actions**:
```solidity
test_TimelockExecution()            // 48-hour delays
test_MultiCallExecution()           // Complex proposal execution
test_ParameterChanges()             // Updating system parameters
test_UpgradeGovernance()            // Self-upgrading governance
test_TreasuryManagement()           // Treasury fund allocation
```

---

## 🔗 Integration Scenario Tests

### 1. Migration to Staking (`MigrationToStaking.t.sol`)

**Cross-System Flows**:
```solidity
test_MigrateAndStakeImmediately()   // Migration → immediate staking
test_BonusVestingIntegration()      // Migration bonus → staking rewards  
test_VestingClaimAndStake()         // Vesting unlock → new staking position
```

### 2. Staking to Governance (`StakingToGovernance.t.sol`)

**Governance Power Flow**:
```solidity
test_StakeForVotingPower()          // Staking to gain vRDAT for voting
test_RewardGovernanceParticipation() // Extra rewards for active voters
test_GovernanceProposalExecution()  // Using governance to change staking params
```

### 3. Full Ecosystem Journey (`FullEcosystemJourney.t.sol`)

**Complete User Experience**:
```solidity
test_V1HolderToDAOMember()          // Migration → Staking → Governance → Rewards
test_MultiUserEcosystem()           // 10 users through complete journey
test_SystemStressTest()             // High load scenarios
test_EconomicGameTheory()           // Incentive alignment testing
```

---

## 🔧 Off-Chain Simulation Framework

### 1. Off-Chain Simulator (`OffChainSimulator.sol`)

**Mock External Services**:
```solidity
contract OffChainSimulator {
    // Validator Network Simulation
    function simulateValidatorNetwork(bytes32 burnTxHash, uint256 amount) external;
    function addValidator(address validator) external;
    function simulateValidatorOffline(address validator) external;
    
    // Snapshot Integration
    function createSnapshot(uint256 blockNumber) external returns (bytes32 snapshotId);
    function simulateSnapshotVote(bytes32 snapshotId, address voter, bool support) external;
    function finalizeSnapshot(bytes32 snapshotId) external returns (bool passed);
    
    // Time Management
    function simulateTimeProgression(uint256 days) external;
    function simulateBlockProgression(uint256 blocks) external;
    
    // External Oracle Data
    function simulatePriceFeeds(address token, uint256 price) external;
    function simulateMarketConditions(bool bullish) external;
}
```

### 2. Scenario Helpers (`ScenarioHelpers.sol`)

**Common Test Utilities**:
```solidity
contract ScenarioHelpers {
    // User Management
    function createUser(string memory name) external returns (address);
    function fundUser(address user, uint256 v1Amount, uint256 ethAmount) external;
    function setupUserStaking(address user, uint256[] memory amounts, uint256[] memory periods) external;
    
    // System State Management
    function snapshotSystemState() external returns (bytes32 stateId);
    function restoreSystemState(bytes32 stateId) external;
    function validateSystemInvariant() external view returns (bool);
    
    // Event Verification
    function expectMigrationEvent(address user, uint256 amount) external;
    function expectStakingEvent(address user, uint256 positionId) external;
    function expectGovernanceEvent(uint256 proposalId, uint8 outcome) external;
}
```

### 3. Mock External Services (`MockExternalServices.sol`)

**Integration Points**:
```solidity
contract MockExternalServices {
    // Snapshot.org API Mock
    function snapshot_createProposal(bytes memory ipfsData) external returns (bytes32 proposalId);
    function snapshot_vote(bytes32 proposalId, address voter, bool support, uint256 weight) external;
    function snapshot_getResults(bytes32 proposalId) external view returns (bool passed, uint256 turnout);
    
    // Cross-Chain Bridge Mocks
    function base_simulateTransaction(bytes memory txData) external returns (bytes32 txHash);
    function vana_simulateValidatorResponse(bytes32 txHash, bool isValid) external;
    
    // DLP Registry Mock (for VRC-20)
    function dlp_registerToken(address tokenAddress) external returns (uint256 dlpId);
    function dlp_updateMetadata(uint256 dlpId, string memory metadata) external;
}
```

---

## 📊 Testing Methodology

### 1. Scenario Test Structure

**Each Scenario Test Should Include**:
```solidity
contract ExampleScenarioTest is Test {
    using ScenarioHelpers for address;
    using OffChainSimulator for bytes32;
    
    // Test Setup (actors, initial state)
    function setUp() public { /* ... */ }
    
    // Happy Path Tests
    function test_HappyPath_[ScenarioName]() public { /* ... */ }
    
    // Edge Case Tests  
    function test_EdgeCase_[FailureMode]() public { /* ... */ }
    
    // Error Recovery Tests
    function test_Recovery_[RecoveryScenario]() public { /* ... */ }
    
    // Invariant Verification
    function test_Invariants_[SystemProperty]() public { /* ... */ }
    
    // State Verification Helpers
    function _verifyUserState(address user) internal view { /* ... */ }
    function _verifySystemHealth() internal view { /* ... */ }
}
```

### 2. Test Data Management

**Realistic Test Data**:
- **Small Users**: 1-100 RDAT holdings
- **Medium Users**: 1K-10K RDAT holdings  
- **Whales**: 100K+ RDAT holdings
- **Time Periods**: 1 hour to 1 year progressions
- **Error Rates**: 1-5% validator/transaction failure rates

### 3. Performance Benchmarking

**Gas Usage Tracking**:
```solidity
function test_GasUsage_[Scenario]() public {
    uint256 gasStart = gasleft();
    
    // Execute scenario
    _executeScenario();
    
    uint256 gasUsed = gasStart - gasleft();
    
    // Log gas usage
    console2.log("Gas used for scenario:", gasUsed);
    
    // Assert reasonable limits
    assertLt(gasUsed, MAX_GAS_LIMIT);
}
```

---

## 🚀 Implementation Plan

### Phase 1: Framework Setup (Days 1-2)
1. **Create test directory structure**
2. **Build OffChainSimulator base framework**
3. **Implement ScenarioHelpers utilities**
4. **Setup MockExternalServices**

### Phase 2: Migration Scenarios (Days 3-4)
1. **Complete Migration Journey tests**
2. **Migration Edge Cases tests**
3. **Validator Coordination tests**
4. **Cross-chain simulation framework**

### Phase 3: Staking Scenarios (Days 5-6)
1. **Staking Lifecycle tests**
2. **Reward Optimization tests**
3. **Position Management tests**
4. **Performance benchmarking**

### Phase 4: Governance Scenarios (Days 7-8)
1. **Proposal Lifecycle tests**
2. **Hybrid Voting tests**
3. **Governance Execution tests**
4. **Snapshot integration simulation**

### Phase 5: Integration Tests (Days 9-10)
1. **Cross-system integration scenarios**
2. **Full ecosystem journey tests**
3. **System stress testing**
4. **Economic incentive validation**

### Phase 6: Debugging & Optimization (Days 11-12)
1. **Fix issues discovered during testing**
2. **Performance optimization based on findings**
3. **Documentation of discovered edge cases**
4. **Test coverage analysis and gap filling**

---

## 🎯 Success Criteria

### Test Coverage Goals
- **🎯 Scenario Coverage**: 100% of major user journeys
- **🎯 Error Recovery**: 90% of failure modes covered
- **🎯 Performance**: All scenarios < 30M gas
- **🎯 Integration**: Cross-system flows verified

### Quality Metrics
- **Code Coverage**: Maintain 95%+ line coverage
- **Gas Efficiency**: No regression in gas costs
- **Reliability**: All scenario tests pass consistently
- **Documentation**: Each scenario documented with user stories

### Debugging Process
1. **Test Failure Analysis**: Root cause identification
2. **Contract Bug Fixes**: Code corrections with explanations
3. **Test Refinement**: Scenario test improvements
4. **Regression Testing**: Re-run all scenarios post-fix

---

## 📋 Deliverables

### Code Deliverables
- [ ] 15+ comprehensive scenario test files
- [ ] Off-chain simulation framework
- [ ] Mock external service integration
- [ ] Performance benchmarking suite

### Documentation Deliverables
- [ ] Scenario test execution guide
- [ ] User journey documentation
- [ ] Debugging runbook
- [ ] Performance analysis report

### Quality Assurance
- [ ] All scenario tests passing
- [ ] Code review completed
- [ ] Performance benchmarks established
- [ ] Integration with existing test suite

---

*This plan ensures comprehensive testing of real-world usage patterns while identifying potential issues before mainnet deployment.*