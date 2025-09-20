# r/datadao V2 Testing Guide

## Overview
This guide provides comprehensive testing instructions for the r/datadao V2 smart contracts deployed on testnets. It covers functional testing, security validation, and migration flows for both community testers and professional auditors.

## Deployed Contracts

### Vana Moksha Testnet (Chain ID: 14800)
- **RDAT Token**: `0xEb0c43d5987de0672A22e350930F615Af646e28c`
- **vRDAT**: `0x386f44505DB03a387dF1402884d5326247DCaaC8`
- **StakingPositions**: `0x3f2236ef5360BEDD999378672A145538f701E662`
- **TreasuryWallet**: `0x31C3e3F091FB2A25d4dac82474e7dc709adE754a`
- **RevenueCollector**: `0x5588e399206880Fcd2C7Ca8dE04126854ce273cE`
- **EmergencyPause**: `0xF73c6216d7D6218d722968e170Cfff6654A8936c`
- **ProofOfContribution**: `0xdbb1926C6cA2a68A8832d550d94C648c19Dbae6b`

### Base Sepolia Testnet (Chain ID: 84532)
- **Mock V1 Token**: `0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E`
- **Migration Bridge**: `0xb7d6f8eadfD4415cb27686959f010771FE94561b`

## Getting Test Tokens

### Vana Moksha
1. Get testnet VANA from the faucet: [Vana Faucet](https://faucet.vana.org)
2. Request test RDAT tokens from the team Discord

### Base Sepolia
1. Get testnet ETH from: [Base Sepolia Faucet](https://www.alchemy.com/faucets/base-sepolia)
2. Mock V1 tokens have been pre-minted to test addresses

## Testing Scenarios

### 1. Token Operations (RDAT)

#### Basic Transfer Test
```javascript
// Connect to RDAT token at 0xEb0c43d5987de0672A22e350930F615Af646e28c
// Test transfers between accounts
// Verify balance updates correctly
```

**Expected Results:**
- Transfers should complete successfully
- Balances should update accurately
- Events should be emitted

#### Approval and TransferFrom
```javascript
// Approve spender for specific amount
// Execute transferFrom as approved spender
// Verify allowance decreases correctly
```

### 2. Staking Operations

#### Create Staking Position
```javascript
// Approve StakingPositions contract for RDAT
// Call stake() with amount and lock duration (30, 90, 180, or 365 days)
// Verify NFT minted and vRDAT balance updated
```

**Lock Duration Multipliers:**
- 30 days: 1.0x
- 90 days: 1.5x
- 180 days: 2.0x
- 365 days: 4.0x

#### Unstake Position
```javascript
// Wait for lock period to expire
// Call unstake() with position ID
// Verify RDAT returned and vRDAT burned
```

### 3. Migration Flow (Cross-Chain)

#### V1 to V2 Migration
1. **On Base Sepolia:**
   - Approve Migration Bridge for V1 tokens
   - Call `migrate(amount)` on bridge
   - Note the migration ID in event

2. **On Vana Moksha:**
   - Wait for oracle confirmation (simulated in testnet)
   - Verify V2 tokens received

### 4. Governance Testing

#### vRDAT Soul-bound Properties
```javascript
// Attempt to transfer vRDAT (should fail)
// Verify balance remains tied to staking positions
// Test delegation functionality
```

### 5. Emergency Pause Testing

#### Pause Activation
```javascript
// Only authorized pausers can trigger
// Verify all critical functions are paused
// Check auto-expiry after 72 hours
```

## Security Validation Checklist

### Access Control
- [ ] Verify only admin can upgrade contracts
- [ ] Test role-based permissions on all contracts
- [ ] Confirm deployer roles are renounced where appropriate

### Reentrancy Protection
- [ ] Test multiple stake/unstake in same transaction
- [ ] Verify guards on all state-changing functions
- [ ] Test cross-contract reentrancy attempts

### Integer Overflow/Underflow
- [ ] Test with maximum uint256 values
- [ ] Verify SafeMath or Solidity 0.8+ protections
- [ ] Test edge cases in reward calculations

### Upgrade Security
- [ ] Verify implementation cannot be called directly
- [ ] Test upgrade process (admin only)
- [ ] Confirm storage layout preservation

## Auditor-Specific Tests

### Static Analysis
```bash
# Run Slither
slither . --config-file slither.config.json

# Run Mythril
myth analyze src/RDATUpgradeable.sol

# Check coverage
forge coverage --report lcov
```

### Formal Verification
```bash
# Run Certora (if specs available)
certoraRun specs/RDAT.spec

# Halmos symbolic testing
halmos --contract RDATUpgradeable
```

### Gas Optimization
```bash
# Generate gas snapshot
forge snapshot

# Compare with baseline
forge snapshot --diff
```

## Reporting Issues

### For Community Testers
1. Join our Discord: [r/datadao Discord](https://discord.gg/rdatadao)
2. Report issues in #testnet-feedback channel
3. Include transaction hash and description

### For Professional Auditors
1. Submit findings via: audit@rdatadao.org
2. Use severity classification:
   - Critical: Direct risk of fund loss
   - High: Indirect risk or governance compromise
   - Medium: Potential for exploitation
   - Low: Best practice violations
   - Informational: Suggestions

## Test Data

### Pre-funded Test Accounts (Base Sepolia)
These accounts have 1000 V1 tokens each:
- `0x70997970C51812dc3A010C7d01b50e0d17dc79C8`
- `0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC`
- `0x90F79bf6EB2c4f870365E785982E1f101E93b906`

### Contract ABIs
Available at: `/abi/` directory or via:
```javascript
import { RDATUpgradeableABI, CONTRACT_ADDRESSES } from '@rdatadao/contracts';
const addresses = CONTRACT_ADDRESSES[14800]; // Vana Moksha
```

## Automated Testing

### Running Test Suite
```bash
# Clone repository
git clone https://github.com/rdatadao/contracts-v2
cd contracts-v2

# Install dependencies
forge install

# Run tests
forge test -vvv

# Run specific test
forge test --match-test testStaking -vvv
```

### Integration Tests
```bash
# Test migration flow
forge test --match-test testCrossChainMigration

# Test governance
forge test --match-test testGovernance

# Test emergency procedures
forge test --match-test testEmergencyPause
```

## Support Resources

- **Documentation**: [docs.rdatadao.org](https://docs.rdatadao.org)
- **GitHub**: [github.com/rdatadao/contracts-v2](https://github.com/rdatadao/contracts-v2)
- **Discord**: [discord.gg/rdatadao](https://discord.gg/rdatadao)
- **Email**: support@rdatadao.org

## Bounty Program

We offer rewards for finding bugs:
- **Critical**: Up to $50,000
- **High**: Up to $20,000
- **Medium**: Up to $5,000
- **Low**: Up to $1,000

Submit findings to: bounty@rdatadao.org

## Timeline

- **Testnet Phase**: August 7 - August 21, 2024
- **Audit Period**: August 22 - September 5, 2024
- **Mainnet Launch**: September 2024 (pending audit)

---

Thank you for helping us build a more secure and robust protocol!