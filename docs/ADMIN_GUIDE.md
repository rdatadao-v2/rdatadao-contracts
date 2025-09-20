# Admin Operations Guide

**Last Updated**: September 20, 2025
**Target Audience**: Multisig owners, validators, and delegated administrators

## 🔑 Access Control Overview

### Role Hierarchy

```
┌─────────────────────────────────────────┐
│         Vana Multisig (3/5)            │
│  0xe4F7Eca807C57311e715C3Ef483e72Fa8D5bCcDF │
├─────────────────────────────────────────┤
│ • Full treasury control                 │
│ • Contract upgrades (UUPS)              │
│ • Emergency pause/unpause               │
│ • Validator management                  │
│ • DLP configuration                     │
│ • Vesting administration                │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│         Base Multisig                   │
│  0x90013583c66D2bf16327cB5Bc4a647AcceCF4B9A │
├─────────────────────────────────────────┤
│ • Base bridge administration            │
│ • Emergency pause on Base               │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│         Migration Validators (2/3)      │
├─────────────────────────────────────────┤
│ • Sign migration requests               │
│ • Validate data contributions           │
│ • Monitor bridge operations             │
└─────────────────────────────────────────┘
```

### Individual Roles

| Role | Contracts | Capabilities | Required Signers |
|------|-----------|--------------|------------------|
| DEFAULT_ADMIN_ROLE | All upgradeable | Full control | 3/5 multisig |
| PAUSER_ROLE | Emergency-enabled | Pause/unpause | 2/5 multisig |
| UPGRADER_ROLE | UUPS contracts | Contract upgrades | 3/5 multisig |
| TREASURY_ROLE | TreasuryWallet | Execute proposals | Treasury contract only |

## 💰 Treasury Management

### Current State
- **Total Allocation**: 70,000,000 RDAT
- **Contract Address**: `0x77D2713972af12F1E3EF39b5395bfD65C862367C`
- **Distribution Schedule**:
  - Team: 10M (6-month cliff + 18-month linear vesting)
  - Development: 20M (DAO-controlled, immediate)
  - Community Rewards: 30M (Phase 3 activation)
  - Reserve: 10M (Emergency/partnerships)

### Treasury Operations

#### Execute DAO Proposal
```solidity
// Function signature
function executeDAOProposal(
    address to,
    uint256 amount,
    string memory reason
) external onlyRole(DEFAULT_ADMIN_ROLE)

// Example: Fund development team
treasury.executeDAOProposal(
    0xDevTeamAddress,
    1000000e18, // 1M RDAT
    "Q4 2025 development funding"
)
```

#### Withdraw Penalties (Recover Slashed Tokens)
```solidity
// Function signature
function withdrawPenalties() external onlyRole(DEFAULT_ADMIN_ROLE)

// This recovers any tokens sent to treasury from penalty mechanisms
treasury.withdrawPenalties()
```

#### Update Vesting Schedule
```solidity
// Function signature
function updateVestingSchedule(
    uint256 scheduleId,
    uint256 newCliff,
    uint256 newDuration,
    uint256 newAmount
) external onlyRole(DEFAULT_ADMIN_ROLE)
```

### Treasury Security Requirements
1. All proposals require 3/5 multisig approval
2. Transactions should include detailed reason strings
3. Large transfers (>1M RDAT) should have forum discussion
4. Emergency withdrawals require separate governance vote

## 🌉 Migration Bridge Administration

### Validator Management

#### Current Validators
1. **Angela** (Dev): `0xd36B49f2DB6aA708Ce7245e8ab2453C6DfFc9d6f`
2. **monkfenix.eth**: `0xC9Af4E56741f255743e8f4877d4cfa9971E910C2`
3. **Base Multisig**: `0x08Cc5ed1bA3C95AA741f8AaEf631f716b037444b`

#### Add New Validator
```solidity
// On Vana Migration Bridge
function addValidator(address validator) external onlyRole(DEFAULT_ADMIN_ROLE)

// Example
migrationBridge.addValidator(0xNewValidatorAddress)
```

#### Remove Validator
```solidity
function removeValidator(address validator) external onlyRole(DEFAULT_ADMIN_ROLE)

// Example
migrationBridge.removeValidator(0xOldValidatorAddress)
```

#### Update Required Signatures
```solidity
function setRequiredSignatures(uint256 count) external onlyRole(DEFAULT_ADMIN_ROLE)

// Example: Increase to 3 signatures required
migrationBridge.setRequiredSignatures(3)
```

### Migration Monitoring

#### Check Migration Status
```bash
# Total migrated amount
cast call 0x9d4aB2d3fb25D414dba1d9D22200356b5984D35E \
  "totalMigrated()" --rpc-url https://rpc.vana.org

# Check if specific user migrated
cast call 0x9d4aB2d3fb25D414dba1d9D22200356b5984D35E \
  "hasMigrated(address)" USER_ADDRESS --rpc-url https://rpc.vana.org

# Remaining migration capacity
echo $((30000000 - $(cast call 0x9d4aB2d3fb25D414dba1d9D22200356b5984D35E \
  "totalMigrated()" --rpc-url https://rpc.vana.org | xargs)))
```

### Handle Stuck Migrations

#### Override Migration (After 7-Day Challenge Period)
```solidity
// For migrations that pass challenge period without processing
function adminOverrideMigration(
    address user,
    uint256 amount,
    bytes32 migrationId
) external onlyRole(DEFAULT_ADMIN_ROLE)
```

## 🚨 Emergency Operations

### Pause System

#### Pause All Operations
```solidity
// Pause RDAT token transfers
rdatToken.pause()

// Pause migration bridge
migrationBridge.pause()

// Pause treasury operations
treasury.pause()
```

#### Unpause System
```solidity
// Resume operations (requires PAUSER_ROLE)
rdatToken.unpause()
migrationBridge.unpause()
treasury.unpause()
```

### Emergency Response Checklist
1. **Identify Issue**: Document the security concern
2. **Pause Affected Contracts**: Use pause() on impacted contracts
3. **Notify Team**: Alert all multisig signers
4. **Assess Impact**: Evaluate affected users and funds
5. **Develop Fix**: Create and test solution
6. **Deploy Fix**: Use upgrade mechanism if needed
7. **Resume Operations**: Unpause contracts
8. **Post-Mortem**: Document incident and response

### Auto-Expiry Protection
- Emergency pauses automatically expire after 72 hours
- This prevents permanent system freeze
- Plan fixes within this window

## 🔄 Contract Upgrades (UUPS)

### Upgradeable Contracts
- RDATUpgradeable (Token)
- TreasuryWallet
- RewardsManager (Phase 2)

### Upgrade Process

#### 1. Deploy New Implementation
```bash
forge script script/UpgradeRDAT.s.sol \
  --rpc-url $VANA_RPC_URL \
  --broadcast \
  --private-key $DEPLOYER_PRIVATE_KEY
```

#### 2. Upgrade via Multisig
```solidity
// Get new implementation address from deployment
address newImplementation = 0xNewImplementationAddress;

// Call upgrade (requires UPGRADER_ROLE)
UUPSUpgradeable(rdatToken).upgradeTo(newImplementation);
```

#### 3. Verify Upgrade
```bash
# Check implementation address
cast call PROXY_ADDRESS "implementation()" --rpc-url $VANA_RPC_URL

# Test new functionality
cast call PROXY_ADDRESS "newFunction()" --rpc-url $VANA_RPC_URL
```

### Upgrade Safety Checklist
- [ ] New implementation tested on testnet
- [ ] Storage layout compatibility verified
- [ ] No selector collisions
- [ ] Initialization properly handled
- [ ] 3/5 multisig approval obtained
- [ ] Community notification sent
- [ ] Monitoring alerts configured

## 📊 DLP Management

### Current Configuration
- **DLP ID**: 40
- **Registry**: `0x4D59880a924526d1dD33260552Ff4328b1E18a43`
- **DataDAO Contract**: `0xBbB0B59163b850dDC5139e98118774557c5d9F92`

### Update DLP Registration
```solidity
// Update DLP ID if needed
function setDlpId(uint256 newDlpId) external onlyRole(DEFAULT_ADMIN_ROLE)

// Update registry address
function setDlpRegistry(address newRegistry) external onlyRole(DEFAULT_ADMIN_ROLE)
```

### Monitor DLP Activity
```bash
# Check current DLP ID
cast call 0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E \
  "dlpId()" --rpc-url https://rpc.vana.org

# Check DLP registry
cast call 0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E \
  "dlpRegistry()" --rpc-url https://rpc.vana.org
```

## 🔐 Multisig Operations

### Using Gnosis Safe

#### Setup
1. Connect to [app.safe.global](https://app.safe.global)
2. Add Vana network:
   - Chain ID: 1480
   - RPC: https://rpc.vana.org
   - Explorer: https://vanascan.io
3. Import multisig: `0xe4F7Eca807C57311e715C3Ef483e72Fa8D5bCcDF`

#### Creating Transactions
1. Navigate to "New Transaction"
2. Select "Contract Interaction"
3. Enter contract address
4. Input ABI (available in `/abi` folder)
5. Select function and parameters
6. Review and create transaction
7. Share with other signers for approval

#### Best Practices
- Always simulate transactions first
- Include clear descriptions
- Batch related operations when possible
- Maintain quorum availability (3/5)
- Use time-locks for significant changes

## 📈 Monitoring & Analytics

### Key Metrics to Track

```javascript
// Daily monitoring checklist
const monitoring = {
  // Token metrics
  totalSupply: await rdatToken.totalSupply(),
  treasuryBalance: await rdatToken.balanceOf(treasury),
  bridgeBalance: await rdatToken.balanceOf(migrationBridge),

  // Migration metrics
  totalMigrated: await migrationBridge.totalMigrated(),
  uniqueMigrants: await migrationBridge.migrantCount(),

  // System health
  isPaused: await rdatToken.paused(),
  pendingUpgrades: await checkPendingUpgrades(),

  // DLP metrics
  dlpRewards: await checkDLPRewards(),
  dataContributions: await dataDAO.totalContributions()
};
```

### Alert Thresholds
- Migration bridge balance < 1M RDAT
- Treasury balance < 5M RDAT
- Unusual transfer patterns (>100k RDAT)
- Pause events
- Failed multisig transactions

## 🛠️ Troubleshooting

### Common Issues & Solutions

| Issue | Diagnosis | Solution |
|-------|-----------|----------|
| Migration stuck | Check validator signatures | Manually trigger signature collection |
| Pause won't lift | Check 72hr expiry | May need to wait for auto-expiry |
| Upgrade fails | Verify implementation | Check storage layout compatibility |
| Treasury transfer fails | Check role permissions | Ensure DEFAULT_ADMIN_ROLE |
| DLP rewards not flowing | Verify DLP registration | Check with Vana team |

### Emergency Contacts
- **Technical Lead**: dev@rdatadao.org
- **Security Team**: security@rdatadao.org
- **Vana Support**: support@vana.org
- **Multisig Signers**: Via secure channel only

## 📝 Audit Trail Requirements

### Documentation Standards
All admin actions must include:
1. **Reason**: Clear explanation of action
2. **Authorization**: Link to governance vote or emergency declaration
3. **Impact**: Affected users and amounts
4. **Timeline**: Expected duration of changes
5. **Rollback**: Plan to reverse if needed

### Example Documentation
```
Action: Emergency Pause - RDAT Token
Date: 2025-09-21 14:30 UTC
Authorized By: Emergency response protocol
Reason: Potential vulnerability in transfer logic
Impact: All token transfers halted
Duration: Maximum 72 hours
Rollback: Auto-expires or manual unpause after fix
Transaction: 0xabc...def
Signers: Alice, Bob, Charlie (3/5)
```

## 🔄 Phase 2 Preparation

### Upcoming Admin Responsibilities

#### Staking System Launch
- Deploy StakingPositions contract
- Deploy vRDAT governance token
- Configure reward modules
- Set staking parameters

#### Governance Activation
- Deploy governance contracts
- Configure voting parameters
- Set timelock delays
- Transfer control to DAO

#### Rewards Management
- Deploy RewardsManager
- Configure reward pools
- Set distribution schedules
- Monitor sustainability

### Pre-Launch Checklist
- [ ] Contracts audited
- [ ] Testnet validation complete
- [ ] Documentation updated
- [ ] UI/UX ready
- [ ] Community notification sent
- [ ] Support team briefed
- [ ] Monitoring configured
- [ ] Emergency procedures tested

## ⚠️ Security Best Practices

1. **Never share private keys**
2. **Use hardware wallets for signing**
3. **Verify all addresses twice**
4. **Test on testnet first**
5. **Maintain secure communication channels**
6. **Document all actions**
7. **Follow timelock delays**
8. **Ensure multiple signers available**
9. **Regular security audits**
10. **Monitor for unusual activity**

## 📚 Additional Resources

- [Contract Documentation](./CONTRACTS.md)
- [Security Procedures](./SECURITY.md)
- [Deployment Guide](./PRODUCTION_DEPLOYMENT_GUIDE.md)
- [Validator Operations](./VALIDATOR_OPERATIONS_GUIDE.md)
- [Emergency Response Plan](./EMERGENCY_RESPONSE.md)