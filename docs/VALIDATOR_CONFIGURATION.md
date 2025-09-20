# Migration Bridge Validator Configuration

## Overview
The r/datadao V2 migration system uses a multi-signature validator approach to secure cross-chain token migrations from Base to Vana. This document details the validator configuration for both testnet and mainnet deployments.

## Validator Architecture

### Security Model
- **Consensus Requirement**: 2-of-3 validators must approve each migration
- **Challenge Period**: 6 hours after validation for security review
- **Admin Override**: Available after 7 days if migration is challenged
- **Daily Limits**: 300,000 RDAT per day (adjustable by admin)

## Production Validators

### Validator Addresses

#### Validator 1: Angela (Dev Team)
- **Address**: `0xd36B49f2DB6aA708Ce7245e8ab2453C6DfFc9d6f`
- **Networks**: Same address for Base Sepolia and Base Mainnet
- **Role**: Technical team validator
- **Responsibility**: Monitor migrations, validate legitimate burns

#### Validator 2: monkfenix.eth
- **Address**: `0xC9Af4E56741f255743e8f4877d4cfa9971E910C2`
- **Networks**: Same address for Base Sepolia and Base Mainnet
- **Role**: Community validator
- **Responsibility**: Independent validation of migrations

#### Validator 3: Multisig Wallet
- **Base Sepolia Address**: `0xdc096Bc0e5d7aB53C7Bd3cbb72B092d1054E393e`
- **Base Mainnet Address**: `0x08Cc5ed1bA3C95AA741f8AaEf631f716b037444b`
- **Role**: Governance-controlled validator
- **Responsibility**: Final approval requiring multiple signers

## Deployment Configuration

### Environment Setup

```bash
# .env configuration
VALIDATOR_1=0xd36B49f2DB6aA708Ce7245e8ab2453C6DfFc9d6f  # Angela
VALIDATOR_2=0xC9Af4E56741f255743e8f4877d4cfa9971E910C2  # monkfenix.eth
VALIDATOR_3_TESTNET=0xdc096Bc0e5d7aB53C7Bd3cbb72B092d1054E393e  # Base Sepolia multisig
VALIDATOR_3_MAINNET=0x08Cc5ed1bA3C95AA741f8AaEf631f716b037444b  # Base Mainnet multisig
```

### Testnet Deployment (Base Sepolia)

```bash
# Deploy Vana Migration Bridge with testnet validators
TREASURY_ADDRESS=$VANA_MULTISIG_ADDRESS \
ADMIN_ADDRESS=$VANA_MULTISIG_ADDRESS \
VALIDATOR_3=$VALIDATOR_3_TESTNET \
forge script script/DeployVanaMigrationBridge.s.sol \
  --rpc-url $VANA_MOKSHA_RPC_URL \
  --broadcast \
  --private-key $DEPLOYER_PRIVATE_KEY
```

### Mainnet Deployment (Base Mainnet)

```bash
# Deploy Vana Migration Bridge with mainnet validators
TREASURY_ADDRESS=$VANA_MULTISIG_ADDRESS \
ADMIN_ADDRESS=$VANA_MULTISIG_ADDRESS \
VALIDATOR_3=$VALIDATOR_3_MAINNET \
forge script script/DeployVanaMigrationBridge.s.sol \
  --rpc-url $VANA_RPC_URL \
  --broadcast \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --verify
```

## Validator Operations

### Pre-Deployment Checklist

1. **Confirm Validator Availability**
   - [ ] Angela confirms wallet access and availability
   - [ ] monkfenix.eth confirms wallet access and availability
   - [ ] Multisig signers confirm access

2. **Setup Monitoring Infrastructure**
   - [ ] Configure event monitoring for Base chain burns
   - [ ] Setup alerting for new migration requests
   - [ ] Establish communication channels for validators

3. **Test Validator Operations**
   - [ ] Test migration on Base Sepolia testnet
   - [ ] Verify 2-of-3 consensus mechanism
   - [ ] Test challenge and override procedures

### Migration Validation Process

1. **Monitor Base Chain Events**
   ```javascript
   // Monitor BaseMigrationBridge for MigrationInitiated events
   baseBridge.on('MigrationInitiated', (user, amount, txHash, event) => {
     // Alert validators
   });
   ```

2. **Submit Validation on Vana**
   ```javascript
   // Each validator calls submitValidation
   await vanaBridge.submitValidation(
     userAddress,
     amount,
     burnTxHash,
     burnBlockNumber
   );
   ```

3. **Challenge Process (if needed)**
   ```javascript
   // Any validator can challenge within 6 hours
   await vanaBridge.challengeMigration(requestId);
   ```

### Validator Management Commands

#### Adding a New Validator
```javascript
// Only DEFAULT_ADMIN_ROLE can execute
await vanaBridge.addValidator(newValidatorAddress);
```

#### Removing a Validator
```javascript
// Cannot go below 2 validators minimum
await vanaBridge.removeValidator(validatorAddress);
```

#### Checking Validator Status
```javascript
const isValidator = await vanaBridge.hasRole(VALIDATOR_ROLE, address);
const validatorCount = await vanaBridge.validatorCount();
```

## Security Procedures

### Emergency Response

1. **Suspicious Migration Detected**
   - Any validator can challenge within 6-hour window
   - Challenge prevents automatic execution
   - Admin review required after 7 days

2. **Validator Compromise**
   - Immediately remove compromised validator
   - Add replacement validator
   - Review recent migrations for issues

3. **Bridge Pause**
   - PAUSER_ROLE can pause bridge operations
   - All migrations halted during pause
   - Resume requires admin action

### Daily Operations

1. **Regular Monitoring**
   - Check daily migration volume vs limits
   - Review pending migrations
   - Verify validator consensus status

2. **Weekly Review**
   - Audit migration patterns
   - Check for unusual activity
   - Update daily limits if needed

## Manual Setup Steps

### Before Mainnet Deployment

1. **Validator Preparation**
   ```bash
   # Each validator should:
   # 1. Secure their private keys
   # 2. Set up monitoring infrastructure
   # 3. Test on Base Sepolia first
   ```

2. **Update Deployment Scripts**
   ```solidity
   // In DeployVanaMigrationBridge.s.sol
   address[] memory validators = new address[](3);
   validators[0] = 0xd36B49f2DB6aA708Ce7245e8ab2453C6DfFc9d6f; // Angela
   validators[1] = 0xC9Af4E56741f255743e8f4877d4cfa9971E910C2; // monkfenix.eth
   validators[2] = isTestnet ?
     0xdc096Bc0e5d7aB53C7Bd3cbb72B092d1054E393e : // Testnet multisig
     0x08Cc5ed1bA3C95AA741f8AaEf631f716b037444b;  // Mainnet multisig
   ```

3. **Communication Setup**
   - Create private Discord/Telegram channel for validators
   - Establish escalation procedures
   - Document response time expectations

### Post-Deployment Verification

1. **Verify Validator Roles**
   ```bash
   cast call $VANA_BRIDGE "hasRole(bytes32,address)" \
     $VALIDATOR_ROLE $VALIDATOR_ADDRESS \
     --rpc-url $VANA_RPC_URL
   ```

2. **Test Migration Flow**
   - Small test migration with all validators
   - Verify 2-of-3 consensus works
   - Test challenge mechanism

3. **Document Actual Addresses**
   - Record deployed bridge addresses
   - Update frontend configuration
   - Share with validator team

## Contact Information

### Validators
- **Angela (Dev)**: Contact via team Discord
- **monkfenix.eth**: Contact via project Discord
- **Multisig Signers**: Contact via governance channel

### Emergency Contacts
- **Technical Lead**: Via team Discord
- **Security Team**: security@rdatadao.org
- **Admin Multisig**: Via governance channel

## Appendix: Validator Scripts

### Monitor Migrations Script
```javascript
// monitor-migrations.js
const ethers = require('ethers');

const BASE_RPC = process.env.BASE_RPC_URL;
const VANA_RPC = process.env.VANA_RPC_URL;
const VALIDATOR_KEY = process.env.VALIDATOR_PRIVATE_KEY;

// Monitor Base for burns
const baseProvider = new ethers.JsonRpcProvider(BASE_RPC);
const baseBridge = new ethers.Contract(BASE_BRIDGE_ADDRESS, BASE_ABI, baseProvider);

baseBridge.on('MigrationInitiated', async (user, amount, txHash, event) => {
  console.log(`New migration: ${user} - ${amount} RDAT`);

  // Submit validation on Vana
  const vanaProvider = new ethers.JsonRpcProvider(VANA_RPC);
  const vanaSigner = new ethers.Wallet(VALIDATOR_KEY, vanaProvider);
  const vanaBridge = new ethers.Contract(VANA_BRIDGE_ADDRESS, VANA_ABI, vanaSigner);

  try {
    const tx = await vanaBridge.submitValidation(
      user,
      amount,
      txHash,
      event.blockNumber
    );
    console.log(`Validation submitted: ${tx.hash}`);
  } catch (error) {
    console.error(`Validation failed: ${error.message}`);
    // Alert team
  }
});
```

---

**Last Updated**: December 2024
**Version**: 1.0.0
**Status**: Ready for Production Deployment