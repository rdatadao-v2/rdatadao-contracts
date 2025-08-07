# 🧪 RDAT V2 Beta Testing Requirements

**Version**: 2.0 (Modular Rewards Architecture)  
**Framework**: Foundry/Forge  
**Coverage Target**: 100%  
**Sprint Days**: 5-8 (Testing Focus)  
**Contract Count**: 11 Core Contracts (modular architecture)

## 📋 Testing Overview

### Test Categories
1. **Unit Tests**: Individual contract functions
2. **Integration Tests**: Multi-contract interactions
3. **Fuzz Tests**: Edge case discovery
4. **Invariant Tests**: System-wide properties
5. **Gas Optimization Tests**: Performance benchmarks

## 🎯 Contract-Specific Test Requirements

### 1. RDAT Tests (Enhanced with Reentrancy Guards)

#### Unit Tests (`test/unit/RDAT.t.sol`)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../../src/RDAT.sol";

contract RDATTest is Test {
    RDAT public token;
    address public treasury = makeAddr("treasury");
    address public user = makeAddr("user");
    
    function setUp() public {
        token = new RDAT(treasury);
    }
    
    // Deployment tests
    function test_DeploymentState() public {
        assertEq(token.name(), "r/datadao");
        assertEq(token.symbol(), "RDAT");
        assertEq(token.totalSupply(), 70_000_000e18); // 100M - 30M migration
        assertEq(token.balanceOf(treasury), 70_000_000e18);
    }
    
    // Access control tests
    function test_OnlyMinterCanMint() public {
        vm.prank(user);
        vm.expectRevert();
        token.mint(user, 1000e18);
    }
    
    // Minting tests
    function test_MintingRespectsMaxSupply() public {
        vm.prank(token.DEFAULT_ADMIN_ROLE());
        token.grantRole(token.MINTER_ROLE(), address(this));
        
        // Should succeed - within limit
        token.mint(user, 30_000_000e18);
        
        // Should fail - exceeds max supply
        vm.expectRevert("Exceeds max supply");
        token.mint(user, 1);
    }
    
    // Pausable tests
    function test_PauseStopsTransfers() public {
        vm.prank(treasury);
        token.transfer(user, 1000e18);
        
        token.pause();
        
        vm.prank(user);
        vm.expectRevert("Pausable: paused");
        token.transfer(treasury, 1000e18);
    }
    
    // VRC-20 tests
    function test_VRC20Compliance() public {
        assertTrue(token.isVRC20());
        
        token.setPoCContract(makeAddr("poc"));
        assertEq(token.pocContract(), makeAddr("poc"));
    }
}
```

#### Fuzz Tests

```solidity
function testFuzz_Transfer(address to, uint256 amount) public {
    vm.assume(to != address(0));
    vm.assume(amount <= token.balanceOf(treasury));
    
    uint256 treasuryBefore = token.balanceOf(treasury);
    uint256 toBefore = token.balanceOf(to);
    
    vm.prank(treasury);
    token.transfer(to, amount);
    
    assertEq(token.balanceOf(treasury), treasuryBefore - amount);
    assertEq(token.balanceOf(to), toBefore + amount);
}
```

### 2. vRDAT Tests

#### Unit Tests (`test/unit/vRDAT.t.sol`)

```solidity
contract vRDATTest is Test {
    vRDAT public vrdat;
    address public staking = makeAddr("staking");
    address public user = makeAddr("user");
    
    function setUp() public {
        vrdat = new vRDAT();
        vrdat.grantRole(vrdat.MINTER_ROLE(), staking);
    }
    
    function test_NonTransferable() public {
        vm.expectRevert(vRDAT.NonTransferableToken.selector);
        vrdat.transfer(user, 100);
        
        vm.expectRevert(vRDAT.NonTransferableToken.selector);
        vrdat.transferFrom(address(this), user, 100);
        
        vm.expectRevert(vRDAT.NonTransferableToken.selector);
        vrdat.approve(user, 100);
    }
    
    function test_MintDelay() public {
        vm.prank(staking);
        vrdat.mint(user, 1000e18);
        
        // Immediate second mint should fail
        vm.prank(staking);
        vm.expectRevert(vRDAT.MintDelayNotMet.selector);
        vrdat.mint(user, 1000e18);
        
        // After delay should succeed
        skip(48 hours);
        vm.prank(staking);
        vrdat.mint(user, 1000e18);
    }
    
    function test_MaxBalanceEnforcement() public {
        vm.prank(staking);
        vrdat.mint(user, 10_000_000e18); // Max allowed
        
        skip(48 hours);
        
        vm.prank(staking);
        vm.expectRevert(vRDAT.ExceedsMaxBalance.selector);
        vrdat.mint(user, 1);
    }
}
```

### 3. StakingManager Tests (NEW - Modular Architecture)

#### Unit Tests (`test/unit/StakingManager.t.sol`)

```solidity
contract StakingManagerTest is Test {
    StakingManager public stakingManager;
    RDAT public rdat;
    address public user = makeAddr("user");
    address public treasury = makeAddr("treasury");
    
    function setUp() public {
        rdat = new RDAT(treasury);
        stakingManager = new StakingManager(address(rdat));
        
        // Fund user
        vm.prank(treasury);
        rdat.transfer(user, 100_000e18);
    }
    
    function test_MultipleStakes() public {
        vm.startPrank(user);
        rdat.approve(address(stakingManager), 100_000e18);
        
        // Create multiple stakes
        uint256 stakeId1 = stakingManager.stake(10_000e18, 30 days);
        uint256 stakeId2 = stakingManager.stake(20_000e18, 90 days);
        uint256 stakeId3 = stakingManager.stake(30_000e18, 365 days);
        
        // Verify stake IDs are unique
        assertTrue(stakeId1 != stakeId2);
        assertTrue(stakeId2 != stakeId3);
        
        // Verify user stakes
        uint256[] memory userStakes = stakingManager.getUserStakes(user);
        assertEq(userStakes.length, 3);
        assertEq(userStakes[0], stakeId1);
        assertEq(userStakes[1], stakeId2);
        assertEq(userStakes[2], stakeId3);
        
        // Verify total staked
        assertEq(stakingManager.userTotalStaked(user), 60_000e18);
        assertEq(stakingManager.totalStaked(), 60_000e18);
        vm.stopPrank();
    }
    
    function test_EmergencyWithdraw() public {
        vm.startPrank(user);
        rdat.approve(address(stakingManager), 10_000e18);
        uint256 stakeId = stakingManager.stake(10_000e18, 365 days);
        
        // Emergency withdraw immediately
        uint256 balanceBefore = rdat.balanceOf(user);
        stakingManager.emergencyWithdraw(stakeId);
        
        // Verify tokens returned
        assertEq(rdat.balanceOf(user), balanceBefore + 10_000e18);
        
        // Verify stake is inactive
        IStakingManager.StakeInfo memory stake = stakingManager.getStake(user, stakeId);
        assertFalse(stake.active);
        assertTrue(stake.emergencyUnlocked);
        vm.stopPrank();
    }
}
```

### 4. RewardsManager Tests (NEW - Modular Architecture)

#### Integration Tests (`test/integration/RewardsManager.t.sol`)

```solidity
contract RewardsManagerTest is Test {
    StakingManager public stakingManager;
    RewardsManager public rewardsManager;
    vRDATRewardModule public vrdatModule;
    RDATRewardModule public rdatModule;
    RDAT public rdat;
    vRDAT public vrdat;
    
    address public user = makeAddr("user");
    address public treasury = makeAddr("treasury");
    
    function setUp() public {
        // Deploy core contracts
        rdat = new RDAT(treasury);
        vrdat = new vRDAT(address(this));
        stakingManager = new StakingManager(address(rdat));
        rewardsManager = new RewardsManager();
        
        // Deploy reward modules
        vrdatModule = new vRDATRewardModule(
            address(vrdat),
            address(stakingManager),
            address(rewardsManager),
            address(this)
        );
        
        rdatModule = new RDATRewardModule(
            address(rdat),
            address(stakingManager),
            address(rewardsManager),
            address(this)
        );
        
        // Configure roles
        vrdat.grantRole(vrdat.MINTER_ROLE(), address(vrdatModule));
        vrdat.grantRole(vrdat.BURNER_ROLE(), address(vrdatModule));
        
        // Register programs
        rewardsManager.registerProgram(
            address(vrdatModule),
            "vRDAT Governance",
            block.timestamp,
            0 // Perpetual
        );
        
        rewardsManager.registerProgram(
            address(rdatModule),
            "RDAT Rewards",
            block.timestamp,
            365 days
        );
        
        // Fund contracts
        vm.prank(treasury);
        rdat.transfer(address(rdatModule), 10_000_000e18);
        
        // Fund user
        vm.prank(treasury);
        rdat.transfer(user, 100_000e18);
    }
    
    function test_ModularRewardFlow() public {
        vm.startPrank(user);
        rdat.approve(address(stakingManager), 10_000e18);
        
        // Stake triggers reward modules
        uint256 stakeId = stakingManager.stake(10_000e18, 180 days);
        
        // Verify vRDAT minted immediately (2x multiplier for 6 months)
        assertEq(vrdat.balanceOf(user), 20_000e18);
        
        // Advance time and check RDAT rewards
        skip(30 days);
        
        uint256[] memory rewards = rewardsManager.calculateRewards(user, stakeId);
        assertGt(rewards[1], 0); // RDAT rewards accumulated
        
        // Claim rewards
        uint256 balanceBefore = rdat.balanceOf(user);
        rewardsManager.claimRewards(stakeId);
        assertGt(rdat.balanceOf(user), balanceBefore);
        
        vm.stopPrank();
    }
    
    function test_EmergencyWithdrawBurnsVRDAT() public {
        vm.startPrank(user);
        rdat.approve(address(stakingManager), 10_000e18);
        uint256 stakeId = stakingManager.stake(10_000e18, 365 days);
        
        // Verify vRDAT minted (4x multiplier)
        assertEq(vrdat.balanceOf(user), 40_000e18);
        
        // Emergency withdraw
        stakingManager.emergencyWithdraw(stakeId);
        
        // Verify vRDAT burned
        assertEq(vrdat.balanceOf(user), 0);
        vm.stopPrank();
    }
}
```

### 5. Reward Module Tests (NEW)

#### Unit Tests for vRDATRewardModule (`test/unit/vRDATRewardModule.t.sol`)

```solidity
contract vRDATRewardModuleTest is Test {
    vRDATRewardModule public module;
    vRDAT public vrdat;
    address public rewardsManager = makeAddr("rewardsManager");
    address public user = makeAddr("user");
    
    function setUp() public {
        vrdat = new vRDAT(address(this));
        module = new vRDATRewardModule(
            address(vrdat),
            address(0), // Mock staking manager
            rewardsManager,
            address(this)
        );
        
        vrdat.grantRole(vrdat.MINTER_ROLE(), address(module));
        vrdat.grantRole(vrdat.BURNER_ROLE(), address(module));
    }
    
    function test_MultiplierCalculations() public {
        vm.prank(rewardsManager);
        
        // Test different lock periods
        module.onStake(user, 1, 10_000e18, 30 days);
        assertEq(vrdat.balanceOf(user), 10_000e18); // 1x
        
        skip(48 hours); // Mint delay
        
        module.onStake(user, 2, 10_000e18, 90 days);
        assertEq(vrdat.balanceOf(user), 25_000e18); // +1.5x
        
        skip(48 hours);
        
        module.onStake(user, 3, 10_000e18, 180 days);
        assertEq(vrdat.balanceOf(user), 45_000e18); // +2x
        
        skip(48 hours);
        
        module.onStake(user, 4, 10_000e18, 365 days);
        assertEq(vrdat.balanceOf(user), 85_000e18); // +4x
    }
}
```

### 6. Old Staking Tests (Legacy - Will be deprecated)

```solidity
contract StakingIntegrationTest is Test {
    RDAT public rdat;
    vRDAT public vrdat;
    Staking public staking;
    
    address public treasury = makeAddr("treasury");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    
    function setUp() public {
        // Deploy ecosystem
        rdat = new RDAT(treasury);
        vrdat = new vRDAT();
        staking = new Staking(address(rdat), address(vrdat));
        
        // Configure roles
        vrdat.grantRole(vrdat.MINTER_ROLE(), address(staking));
        
        // Fund users
        vm.prank(treasury);
        rdat.transfer(alice, 10_000e18);
        
        vm.prank(treasury);
        rdat.transfer(bob, 50_000e18);
    }
    
    function test_StakingFlow() public {
        // Alice stakes with 30-day lock
        vm.startPrank(alice);
        rdat.approve(address(staking), 10_000e18);
        staking.stake(10_000e18, 30 days);
        vm.stopPrank();
        
        // Verify state
        assertEq(rdat.balanceOf(alice), 0);
        assertEq(vrdat.balanceOf(alice), 10_000e18); // 1x multiplier
        assertEq(staking.totalStaked(), 10_000e18);
        
        // Bob stakes with 365-day lock
        vm.startPrank(bob);
        rdat.approve(address(staking), 50_000e18);
        staking.stake(50_000e18, 365 days);
        vm.stopPrank();
        
        // Verify 4x multiplier
        assertEq(vrdat.balanceOf(bob), 200_000e18); // 4x multiplier
        
        // Alice tries early unstake - should fail
        skip(15 days);
        vm.prank(alice);
        vm.expectRevert("Lock period not ended");
        staking.unstake();
        
        // Alice unstakes after lock period
        skip(16 days); // Total 31 days
        vm.prank(alice);
        staking.unstake();
        
        assertEq(rdat.balanceOf(alice), 10_000e18);
    }
}
```

### 4. MigrationBridge Tests

#### Multi-Sig Validation Tests

```solidity
contract MigrationBridgeTest is Test {
    MigrationBridge public bridge;
    RDAT public rdatV2;
    
    address public validator1 = makeAddr("validator1");
    address public validator2 = makeAddr("validator2");
    address public validator3 = makeAddr("validator3");
    address public user = makeAddr("user");
    
    bytes32 public burnTxHash = keccak256("burn_tx_123");
    
    function setUp() public {
        rdatV2 = new RDAT(address(this));
        bridge = new MigrationBridge(address(rdatV2));
        
        // Setup validators
        bridge.grantRole(bridge.VALIDATOR_ROLE(), validator1);
        bridge.grantRole(bridge.VALIDATOR_ROLE(), validator2);
        bridge.grantRole(bridge.VALIDATOR_ROLE(), validator3);
        
        // Grant minter role to bridge
        rdatV2.grantRole(rdatV2.MINTER_ROLE(), address(bridge));
    }
    
    function test_TwoOfThreeValidation() public {
        uint256 amount = 1000e18;
        bytes32 requestId = keccak256(abi.encodePacked(user, amount, burnTxHash));
        
        // First validator submits
        vm.prank(validator1);
        bridge.submitMigration(user, amount, burnTxHash);
        
        // Check not executed yet
        assertEq(rdatV2.balanceOf(user), 0);
        
        // Second validator validates - should execute
        vm.prank(validator2);
        bridge.validateMigration(requestId);
        
        // Verify execution with bonus
        uint256 expectedBonus = (amount * 500) / 10000; // 5% week 1-2
        assertEq(rdatV2.balanceOf(user), amount + expectedBonus);
    }
    
    function test_BonusCalculation() public {
        assertEq(bridge.calculateBonus(1000e18), 50e18); // 5% week 1-2
        
        skip(3 weeks);
        assertEq(bridge.calculateBonus(1000e18), 30e18); // 3% week 3-4
        
        skip(4 weeks);
        assertEq(bridge.calculateBonus(1000e18), 10e18); // 1% week 5-8
        
        skip(2 weeks);
        assertEq(bridge.calculateBonus(1000e18), 0); // 0% after 8 weeks
    }
}
```

### 5. RevenueCollector Tests (NEW)

#### Unit Tests (`test/unit/RevenueCollector.t.sol`)

```solidity
contract RevenueCollectorTest is Test {
    RevenueCollector public collector;
    RDAT public rdat;
    Staking public staking;
    address public treasury = makeAddr("treasury");
    
    function test_DistributionCalculations() public {
        // Test 50/30/20 split
        uint256 balance = 1000e18;
        assertEq(collector.calculateStakerShare(balance), 500e18);
        assertEq(collector.calculateTreasuryShare(balance), 300e18);
        assertEq(collector.calculateBurnShare(balance), 200e18);
    }
    
    function test_ReentrancyProtection() public {
        // Attempt reentrancy attack
        ReentrancyAttacker attacker = new ReentrancyAttacker(collector);
        rdat.transfer(address(attacker), 1000e18);
        vm.expectRevert("ReentrancyGuard: reentrant call");
        attacker.attack();
    }
}
```

### 6. ProofOfContribution Tests (NEW)

#### Unit Tests (`test/unit/ProofOfContribution.t.sol`)

```solidity
contract ProofOfContributionTest is Test {
    ProofOfContribution public poc;
    address public validator = makeAddr("validator");
    address public contributor = makeAddr("contributor");
    
    function test_ContributorRegistration() public {
        vm.prank(registrar);
        poc.registerContributor(contributor);
        assertTrue(poc.registeredContributors(contributor));
        assertEq(poc.totalContributors(), 1);
    }
    
    function test_DuplicateDataHashPrevention() public {
        bytes32 dataHash = keccak256("test_data");
        
        // First submission succeeds
        vm.prank(validator);
        poc.validateContribution(contributor, dataHash, 80);
        
        // Duplicate submission fails
        vm.expectRevert("Already processed");
        poc.validateContribution(contributor, dataHash, 90);
    }
    
    function test_QualityScoreAccumulation() public {
        vm.startPrank(validator);
        poc.validateContribution(contributor, keccak256("data1"), 80);
        poc.validateContribution(contributor, keccak256("data2"), 90);
        vm.stopPrank();
        
        assertEq(poc.contributorScores(contributor), 170);
    }
}
```

### 7. Emergency System Tests

#### Invariant Tests (`test/invariant/EmergencyInvariant.t.sol`)

```solidity
contract EmergencyInvariantTest is Test {
    // Test that emergency pause auto-expires after 72 hours
    function invariant_EmergencyPauseExpires() public {
        assertTrue(
            !staking.emergencyPaused() || 
            block.timestamp > staking.pausedAt() + 72 hours
        );
    }
    
    // Test that total staked never exceeds total RDAT supply
    function invariant_StakedNeverExceedsSupply() public {
        assertTrue(staking.totalStaked() <= rdat.totalSupply());
    }
    
    // Test that vRDAT total never exceeds theoretical maximum
    function invariant_vRDATCap() public {
        uint256 maxPossible = rdat.totalSupply() * 4; // Max 4x multiplier
        assertTrue(vrdat.totalSupply() <= maxPossible);
    }
}
```

## 🔥 Gas Optimization Testing

### Gas Benchmarks (`test/gas/GasBenchmark.t.sol`)

```solidity
contract GasBenchmarkTest is Test {
    function test_TransferGas() public {
        uint256 gasStart = gasleft();
        vm.prank(treasury);
        rdat.transfer(user, 1000e18);
        uint256 gasUsed = gasStart - gasleft();
        
        console.log("Transfer gas:", gasUsed);
        assertLt(gasUsed, 65_000); // Target
    }
    
    function test_StakeGas() public {
        vm.prank(alice);
        rdat.approve(address(staking), 1000e18);
        
        uint256 gasStart = gasleft();
        vm.prank(alice);
        staking.stake(1000e18, 30 days);
        uint256 gasUsed = gasStart - gasleft();
        
        console.log("Stake gas:", gasUsed);
        assertLt(gasUsed, 150_000); // Target
    }
}
```

## 📊 Test Coverage Requirements

### Minimum Coverage Targets
- **Line Coverage**: 100%
- **Branch Coverage**: 95%
- **Function Coverage**: 100%

### Coverage Commands
```bash
# Generate coverage report
forge coverage --report lcov

# Detailed coverage by contract
forge coverage --report summary

# Coverage with specific match
forge coverage --match-contract RDAT
```

## 🏃 Test Execution Plan

### Day 5-6: Unit Testing
```bash
# Run all unit tests
forge test --match-path test/unit/*

# Run with verbosity
forge test --match-path test/unit/* -vvv

# Run specific contract tests
forge test --match-contract RDATTest
```

### Day 6-7: Integration Testing
```bash
# Run integration tests
forge test --match-path test/integration/*

# Run with fork for mainnet testing
forge test --fork-url $VANA_RPC_URL --match-path test/integration/*
```

### Day 7-8: Fuzz & Invariant Testing
```bash
# Run fuzz tests with more runs
forge test --match-test testFuzz -vvv --fuzz-runs 10000

# Run invariant tests
forge test --match-contract Invariant
```

## 🐛 Testing Checklist

### Pre-Audit Checklist
- [ ] 100% line coverage achieved
- [ ] All critical paths tested
- [ ] Fuzz tests passing with 10k+ runs
- [ ] Gas optimization targets met
- [ ] Integration tests with mock bridge
- [ ] Emergency scenarios tested
- [ ] Access control fully tested
- [ ] Edge cases documented and tested

### Security Test Cases (Updated for 7 Contracts)
- [ ] Reentrancy protection verified (all contracts)
- [ ] Integer overflow/underflow tests
- [ ] Access control bypass attempts
- [ ] Flash loan attack simulations (48-hour delays)
- [ ] Multi-sig validation edge cases
- [ ] Time manipulation tests
- [ ] Gas griefing scenarios
- [ ] Quadratic voting math correctness (vRDAT)
- [ ] Revenue distribution accuracy (RevenueCollector)
- [ ] Duplicate data hash prevention (ProofOfContribution)

## 🚨 Critical Test Scenarios

### Migration Bridge
1. **Duplicate migration attempts**
2. **Invalid burn transaction hashes**
3. **Daily limit exhaustion**
4. **Validator collusion scenarios**
5. **Time-based bonus boundaries**

### Staking System
1. **Multiple stake attempts**
2. **Early unstake attempts**
3. **vRDAT minting accuracy**
4. **Lock period enforcement**
5. **Total staked accounting**

### Emergency System
1. **Pause during active operations**
2. **Auto-expiry after 72 hours**
3. **Multiple pausers coordination**
4. **Unpause authorization**

---

**Document Status**: Ready for Implementation  
**Testing Phase**: Days 5-8 of Sprint  
**Audit Preparation**: Days 7-8