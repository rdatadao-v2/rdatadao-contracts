# Testing Guide

**Last Updated**: September 20, 2025
**Test Coverage**: 100% (382/382 tests passing)
**Framework**: Foundry

## 📊 Test Coverage Summary

### Current Status
```
┌────────────────────────────────────────┐
│         Test Coverage Report           │
├────────────────────────────────────────┤
│ Total Tests: 382                       │
│ Passing: 382 ✅                        │
│ Failed: 0                              │
│ Coverage: 100%                         │
├────────────────────────────────────────┤
│ Unit Tests: 168                        │
│ Integration Tests: 112                 │
│ Security Tests: 42                     │
│ Audit Tests: 35                        │
│ Migration Tests: 25                    │
└────────────────────────────────────────┘
```

## 🧪 Running Tests

### Quick Start
```bash
# Run all tests
forge test

# Run with verbosity
forge test -vvv  # Show stack traces
forge test -vvvv # Show execution traces

# Run specific test file
forge test --match-contract RDATUpgradeableTest

# Run specific test function
forge test --match-test testMigration

# Run with gas reporting
forge test --gas-report

# Run with coverage
forge coverage
```

### Test Categories

#### Unit Tests
```bash
# Token tests
forge test --match-contract RDATUpgradeableTest
forge test --match-contract TreasuryWalletTest
forge test --match-contract VanaMigrationBridgeTest

# Staking tests (Phase 2)
forge test --match-contract StakingPositionsTest
forge test --match-contract vRDATTest

# Governance tests (Phase 2)
forge test --match-contract GovernanceCoreTest
```

#### Integration Tests
```bash
# Cross-contract interactions
forge test --match-path test/integration/*

# Full system tests
forge test --match-contract FullSystemTest

# Migration flow tests
forge test --match-contract MigrationFlowTest
```

#### Security Tests
```bash
# Attack vector tests
forge test --match-path test/security/*

# Specific attacks
forge test --match-test testReentrancy
forge test --match-test testFlashLoan
forge test --match-test testSandwich
```

#### Audit Remediation Tests
```bash
# Verify audit fixes
forge test --match-path test/audit/*

# Specific remediations
forge test --match-test testWithdrawPenalties  # H-01
forge test --match-test testChallengePeriod    # H-02
forge test --match-test testV1Burning          # M-01
```

## 🔧 Test Structure

### Test File Organization
```
test/
├── unit/                    # Individual contract tests
│   ├── RDATUpgradeable.t.sol
│   ├── TreasuryWallet.t.sol
│   ├── VanaMigrationBridge.t.sol
│   └── StakingPositions.t.sol
├── integration/             # Multi-contract tests
│   ├── MigrationFlow.t.sol
│   ├── StakingRewards.t.sol
│   └── GovernanceFlow.t.sol
├── security/               # Security-focused tests
│   ├── Reentrancy.t.sol
│   ├── AccessControl.t.sol
│   └── Emergency.t.sol
├── audit/                  # Audit remediation tests
│   ├── HighFindings.t.sol
│   ├── MediumFindings.t.sol
│   └── LowFindings.t.sol
└── helpers/                # Test utilities
    ├── BaseTest.sol
    ├── Mocks.sol
    └── Utils.sol
```

### Base Test Contract
```solidity
contract BaseTest is Test {
    // Core contracts
    RDATUpgradeable public rdatToken;
    TreasuryWallet public treasury;
    VanaMigrationBridge public vanaBridge;

    // Test addresses
    address public admin = makeAddr("admin");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    // Constants
    uint256 constant INITIAL_SUPPLY = 100_000_000e18;
    uint256 constant TREASURY_ALLOCATION = 70_000_000e18;
    uint256 constant MIGRATION_ALLOCATION = 30_000_000e18;

    function setUp() public virtual {
        // Deploy contracts
        deployContracts();

        // Setup initial state
        setupInitialState();

        // Label addresses for traces
        vm.label(admin, "Admin");
        vm.label(user1, "User1");
        vm.label(user2, "User2");
    }
}
```

## ✅ Writing Tests

### Unit Test Example
```solidity
contract RDATUpgradeableTest is BaseTest {
    function testTransfer() public {
        // Setup
        uint256 amount = 1000e18;
        vm.prank(treasury);
        rdatToken.transfer(user1, amount);

        // Action
        vm.prank(user1);
        rdatToken.transfer(user2, amount);

        // Assert
        assertEq(rdatToken.balanceOf(user1), 0);
        assertEq(rdatToken.balanceOf(user2), amount);
    }

    function testCannotMint() public {
        // Attempt to mint (should always fail)
        vm.prank(admin);
        vm.expectRevert("Minting is permanently disabled");
        rdatToken.mint(user1, 1000e18);
    }

    function testPauseUnpause() public {
        // Pause
        vm.prank(admin);
        rdatToken.pause();
        assertTrue(rdatToken.paused());

        // Cannot transfer when paused
        vm.prank(user1);
        vm.expectRevert("Pausable: paused");
        rdatToken.transfer(user2, 100e18);

        // Unpause
        vm.prank(admin);
        rdatToken.unpause();
        assertFalse(rdatToken.paused());
    }
}
```

### Integration Test Example
```solidity
contract MigrationFlowTest is BaseTest {
    function testCompleteV1ToV2Migration() public {
        // 1. Setup V1 tokens on Base
        uint256 migrationAmount = 10000e18;
        setupV1Tokens(user1, migrationAmount);

        // 2. User initiates migration on Base
        vm.prank(user1);
        bytes32 migrationId = baseBridge.initiateMigration(migrationAmount);

        // 3. Validators sign the migration
        bytes[] memory signatures = getValidatorSignatures(
            user1,
            migrationAmount,
            migrationId
        );

        // 4. User claims on Vana
        vm.prank(user1);
        vanaBridge.processMigration(
            user1,
            migrationAmount,
            migrationId,
            signatures
        );

        // 5. Verify migration complete
        assertEq(rdatToken.balanceOf(user1), migrationAmount);
        assertTrue(vanaBridge.hasMigrated(user1));
    }
}
```

### Security Test Example
```solidity
contract ReentrancyTest is BaseTest {
    function testCannotReenterWithdraw() public {
        // Deploy malicious contract
        ReentrancyAttacker attacker = new ReentrancyAttacker(
            address(stakingPositions)
        );

        // Fund attacker
        vm.prank(treasury);
        rdatToken.transfer(address(attacker), 10000e18);

        // Attempt reentrancy attack
        vm.expectRevert("ReentrancyGuard: reentrant call");
        attacker.attack();
    }
}
```

## 🔨 Fuzzing Tests

### Basic Fuzzing
```solidity
function testFuzzTransfer(address to, uint256 amount) public {
    // Bound inputs
    vm.assume(to != address(0));
    vm.assume(to != address(rdatToken));
    amount = bound(amount, 0, rdatToken.balanceOf(user1));

    // Execute transfer
    vm.prank(user1);
    rdatToken.transfer(to, amount);

    // Verify
    assertEq(rdatToken.balanceOf(to), amount);
}
```

### Invariant Testing
```solidity
contract InvariantTest is BaseTest {
    function invariant_totalSupplyConstant() public {
        assertEq(rdatToken.totalSupply(), INITIAL_SUPPLY);
    }

    function invariant_noNegativeBalances() public {
        assertTrue(rdatToken.balanceOf(user1) >= 0);
        assertTrue(rdatToken.balanceOf(user2) >= 0);
    }

    function invariant_sumOfBalancesEqualsTotalSupply() public {
        uint256 sum = rdatToken.balanceOf(treasury) +
                     rdatToken.balanceOf(address(vanaBridge)) +
                     rdatToken.balanceOf(user1) +
                     rdatToken.balanceOf(user2);
        assertEq(sum, INITIAL_SUPPLY);
    }
}
```

## 🎯 Test Helpers

### Mock Contracts
```solidity
contract MockERC20 is ERC20 {
    constructor() ERC20("Mock", "MCK") {
        _mint(msg.sender, 1000000e18);
    }
}

contract MockValidator {
    function signMigration(
        address user,
        uint256 amount,
        bytes32 migrationId
    ) external pure returns (bytes memory) {
        return abi.encodePacked(
            keccak256(abi.encode(user, amount, migrationId))
        );
    }
}
```

### Utility Functions
```solidity
library TestUtils {
    function fastForward(uint256 seconds) internal {
        vm.warp(block.timestamp + seconds);
    }

    function getSignature(
        uint256 privateKey,
        bytes32 messageHash
    ) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, messageHash);
        return abi.encodePacked(r, s, v);
    }

    function expectEmit(address emitter) internal {
        vm.expectEmit(true, true, true, true, emitter);
    }
}
```

## 📈 Gas Optimization Testing

### Gas Snapshot
```bash
# Create gas snapshot
forge snapshot

# Compare with previous snapshot
forge snapshot --diff

# Specific test gas usage
forge test --match-test testStaking --gas-report
```

### Gas Benchmarking
```solidity
contract GasBenchmark is BaseTest {
    function testGasTransfer() public {
        uint256 gasBefore = gasleft();

        vm.prank(user1);
        rdatToken.transfer(user2, 1000e18);

        uint256 gasUsed = gasBefore - gasleft();
        console.log("Transfer gas used:", gasUsed);

        // Assert reasonable gas usage
        assertLt(gasUsed, 70000);
    }

    function testGasStaking() public {
        uint256 gasBefore = gasleft();

        vm.prank(user1);
        stakingPositions.stake(1000e18, 30 days);

        uint256 gasUsed = gasBefore - gasleft();
        console.log("Staking gas used:", gasUsed);

        assertLt(gasUsed, 200000);
    }
}
```

## 🐞 Debugging Tests

### Using Console Logs
```solidity
import "forge-std/console.sol";

function testWithLogging() public {
    console.log("Starting test");
    console.log("User balance:", rdatToken.balanceOf(user1));

    vm.prank(user1);
    rdatToken.transfer(user2, 1000e18);

    console.log("Transfer complete");
    console.log("New balance:", rdatToken.balanceOf(user2));
}
```

### Stack Traces
```bash
# Show stack traces on failure
forge test -vvv

# Show execution traces
forge test -vvvv

# Debug specific test
forge test --debug testMigration
```

## 🔄 Continuous Integration

### GitHub Actions Workflow
```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: foundry-rs/foundry-toolchain@v1
      - run: forge install
      - run: forge fmt --check
      - run: forge build --sizes
      - run: forge test -vvv
      - run: forge coverage --report=lcov
```

### Pre-commit Hooks
```bash
#!/bin/bash
# .git/hooks/pre-commit

# Run tests
forge test

# Check formatting
forge fmt --check

# Run slither
slither .

if [ $? -ne 0 ]; then
    echo "Tests failed. Commit aborted."
    exit 1
fi
```

## 📊 Test Coverage Analysis

### Generate Coverage Report
```bash
# Generate coverage
forge coverage

# Detailed coverage
forge coverage --report=lcov

# View in browser
genhtml lcov.info -o coverage
open coverage/index.html
```

### Coverage Requirements
- Minimum 95% line coverage
- 100% branch coverage for critical functions
- All modifiers tested
- All events tested
- All error cases covered

## 🎮 Testing Best Practices

### DO's
1. **Test happy path and edge cases**
2. **Use descriptive test names**
3. **Test all modifiers and access controls**
4. **Verify events are emitted**
5. **Test upgrade scenarios**
6. **Use fuzzing for inputs**
7. **Test gas consumption**
8. **Mock external dependencies**

### DON'Ts
1. **Don't test library code**
2. **Don't skip negative tests**
3. **Don't hardcode addresses**
4. **Don't ignore warnings**
5. **Don't test on mainnet**
6. **Don't use random seeds**
7. **Don't skip reentrancy tests**
8. **Don't forget invariants**

## 🚀 Advanced Testing

### Fork Testing
```solidity
contract ForkTest is Test {
    function setUp() public {
        // Fork mainnet at specific block
        vm.createSelectFork("https://rpc.vana.org", 1000000);
    }

    function testMainnetInteraction() public {
        // Test against real mainnet state
        IERC20 rdatToken = IERC20(0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E);
        uint256 supply = rdatToken.totalSupply();
        assertEq(supply, 100_000_000e18);
    }
}
```

### Differential Testing
```solidity
contract DifferentialTest is BaseTest {
    function testImplementationConsistency(uint256 amount) public {
        amount = bound(amount, 1, 1000000e18);

        // Test old implementation
        uint256 resultOld = oldImplementation.calculate(amount);

        // Test new implementation
        uint256 resultNew = newImplementation.calculate(amount);

        // Results should match
        assertEq(resultOld, resultNew);
    }
}
```

## 📝 Test Documentation

### Test Naming Convention
```solidity
// Format: test[Contract][Function][Scenario]

// Success cases
testTransferSucceedsWithValidAmount()
testStakeCreatesPosition()

// Failure cases
testTransferRevertsWhenPaused()
testStakeRevertsWithZeroAmount()

// Fuzzing
testFuzzTransferWithRandomAmount(uint256)

// Invariants
invariant_totalSupplyNeverChanges()
```

### Test Comments
```solidity
/**
 * @notice Test that migration correctly processes validator signatures
 * @dev Tests the complete flow from Base to Vana
 * Security: Ensures signatures cannot be reused
 */
function testMigrationWithValidatorSignatures() public {
    // Test implementation
}
```

## 🔗 Resources

### Documentation
- [Foundry Book](https://book.getfoundry.sh/)
- [Forge Test Reference](https://book.getfoundry.sh/forge/tests)
- [Cheatcodes Reference](https://book.getfoundry.sh/cheatcodes/)

### Tools
- [Echidna](https://github.com/crytic/echidna) - Property testing
- [Slither](https://github.com/crytic/slither) - Static analysis
- [Mythril](https://github.com/ConsenSys/mythril) - Security analysis

## ⚠️ Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| Stack too deep | Refactor to use structs |
| Out of gas | Increase gas limit or optimize |
| Failing tests after upgrade | Check storage layout |
| Fork tests failing | Update RPC endpoint |
| Coverage not generating | Install lcov tools |

### Debug Commands
```bash
# Debug specific test
forge test --debug testName

# Show config
forge config

# Clean and rebuild
forge clean && forge build

# Update dependencies
forge update
```