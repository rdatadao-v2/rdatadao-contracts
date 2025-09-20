# Validator Operations Guide for r/datadao Migration Bridge

## Quick Start Checklist

### Pre-Deployment Setup
- [ ] Confirm wallet access for your validator address
- [ ] Secure private keys in hardware wallet or secure storage
- [ ] Set up monitoring infrastructure for Base chain events
- [ ] Join validator communication channel (Discord/Telegram)
- [ ] Test wallet signatures on testnet first

## Validator Responsibilities

### Primary Duties
1. **Monitor Base Chain Burns**: Watch for `MigrationInitiated` events
2. **Validate Migrations**: Submit validation within 24 hours of burn
3. **Challenge Suspicious Activity**: Flag fraudulent migrations within 6 hours
4. **Maintain Uptime**: Ensure 95%+ availability during migration period

### Response Time Requirements
- **Normal Migration**: Validate within 24 hours
- **Large Migration (>10,000 RDAT)**: Validate within 12 hours
- **Suspicious Activity**: Challenge within 6 hours
- **Emergency**: Respond within 2 hours

## Technical Setup

### 1. Environment Configuration

Create a `.env` file for your validator node:

```bash
# Your validator private key (KEEP SECURE!)
VALIDATOR_PRIVATE_KEY=your_private_key_here

# RPC endpoints
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
BASE_MAINNET_RPC_URL=https://mainnet.base.org
VANA_MOKSHA_RPC_URL=https://rpc.moksha.vana.org
VANA_MAINNET_RPC_URL=https://rpc.vana.org

# Contract addresses (will be provided after deployment)
BASE_BRIDGE_ADDRESS=0x... # BaseMigrationBridge on Base
VANA_BRIDGE_ADDRESS=0x... # VanaMigrationBridge on Vana

# Alert webhook (optional)
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...
```

### 2. Install Monitoring Script

```bash
# Clone the validator tools repository
git clone https://github.com/rdatadao/validator-tools.git
cd validator-tools

# Install dependencies
npm install

# Configure environment
cp .env.example .env
# Edit .env with your settings

# Run validator monitor
npm run monitor
```

### 3. Manual Validation Process

If automatic monitoring fails, manually validate migrations:

```javascript
// Connect to Vana network
const provider = new ethers.JsonRpcProvider(VANA_RPC_URL);
const wallet = new ethers.Wallet(VALIDATOR_PRIVATE_KEY, provider);
const bridge = new ethers.Contract(VANA_BRIDGE_ADDRESS, BRIDGE_ABI, wallet);

// Submit validation
async function validateMigration(user, amount, burnTxHash, burnBlockNumber) {
  const tx = await bridge.submitValidation(
    user,
    amount,
    burnTxHash,
    burnBlockNumber
  );
  console.log(`Validation submitted: ${tx.hash}`);
  return tx.wait();
}
```

## Migration Validation Workflow

### Step 1: Detect Migration on Base

Monitor the BaseMigrationBridge for `MigrationInitiated` events:

```javascript
baseBridge.on('MigrationInitiated', (user, amount, txHash, event) => {
  console.log(`New migration detected:
    User: ${user}
    Amount: ${ethers.formatEther(amount)} RDAT
    Tx Hash: ${txHash}
    Block: ${event.blockNumber}
  `);

  // Proceed to validation
  validateMigration(user, amount, txHash, event.blockNumber);
});
```

### Step 2: Verify Burn Transaction

Before validating, verify the burn actually happened:

```javascript
async function verifyBurn(txHash) {
  const tx = await baseProvider.getTransaction(txHash);
  const receipt = await baseProvider.getTransactionReceipt(txHash);

  // Check transaction is confirmed
  const currentBlock = await baseProvider.getBlockNumber();
  const confirmations = currentBlock - receipt.blockNumber;

  if (confirmations < 12) {
    console.log(`Waiting for confirmations: ${confirmations}/12`);
    return false;
  }

  // Verify it's to the correct bridge
  if (tx.to.toLowerCase() !== BASE_BRIDGE_ADDRESS.toLowerCase()) {
    console.error('Transaction not to bridge contract!');
    return false;
  }

  return true;
}
```

### Step 3: Submit Validation on Vana

```javascript
async function submitValidationToVana(user, amount, burnTxHash, burnBlockNumber) {
  try {
    // Check if already validated by us
    const requestId = ethers.keccak256(
      ethers.AbiCoder.defaultAbiCoder().encode(
        ['address', 'uint256', 'bytes32'],
        [user, amount, burnTxHash]
      )
    );

    const hasValidated = await bridge.hasValidated(requestId, wallet.address);
    if (hasValidated) {
      console.log('Already validated this migration');
      return;
    }

    // Submit validation
    const tx = await bridge.submitValidation(
      user,
      amount,
      burnTxHash,
      burnBlockNumber,
      { gasLimit: 500000 }
    );

    console.log(`Validation submitted: ${tx.hash}`);
    await tx.wait();
    console.log('Validation confirmed');

  } catch (error) {
    console.error('Validation failed:', error);
    // Alert team
    sendAlert(`Validation failed: ${error.message}`);
  }
}
```

### Step 4: Monitor for Consensus

```javascript
async function checkConsensus(requestId) {
  const request = await bridge.getMigrationRequest(requestId);

  console.log(`Migration status:
    Validations: ${request.validatorApprovals}/2 required
    Challenged: ${request.challenged}
    Executed: ${request.executed}
  `);

  if (request.validatorApprovals >= 2 && !request.challenged) {
    console.log('Migration ready for execution');
  }
}
```

## Challenging Suspicious Migrations

### When to Challenge
- Amount exceeds user's known balance
- Burn transaction appears fraudulent
- User address is on blacklist
- Unusual patterns detected

### How to Challenge

```javascript
async function challengeMigration(requestId, reason) {
  console.log(`CHALLENGING MIGRATION: ${requestId}`);
  console.log(`Reason: ${reason}`);

  try {
    const tx = await bridge.challengeMigration(requestId);
    console.log(`Challenge submitted: ${tx.hash}`);
    await tx.wait();

    // Alert all validators and admin
    sendUrgentAlert(`Migration challenged: ${requestId}\nReason: ${reason}`);

  } catch (error) {
    console.error('Challenge failed:', error);
  }
}
```

## Emergency Procedures

### 1. Validator Key Compromise

If your validator key is compromised:

```bash
# 1. Immediately notify admin and other validators
# 2. Admin removes compromised validator:
cast send $VANA_BRIDGE "removeValidator(address)" $COMPROMISED_ADDRESS \
  --private-key $ADMIN_KEY

# 3. Set up new validator address
# 4. Admin adds new validator:
cast send $VANA_BRIDGE "addValidator(address)" $NEW_VALIDATOR_ADDRESS \
  --private-key $ADMIN_KEY
```

### 2. Bridge Under Attack

If detecting multiple fraudulent migrations:

```javascript
// Any validator can initiate emergency pause
async function emergencyPause() {
  // Challenge all suspicious migrations
  for (const suspiciousId of suspiciousMigrations) {
    await challengeMigration(suspiciousId, 'Potential attack detected');
  }

  // Alert admin to pause bridge
  sendUrgentAlert('BRIDGE UNDER ATTACK - PAUSE REQUIRED');
}
```

### 3. Communication Failure

If primary communication channel fails:

1. **Primary**: Project Discord validator channel
2. **Backup**: Telegram group
3. **Emergency**: Email to security@rdatadao.org
4. **Last Resort**: On-chain message via challenge reason

## Monitoring Dashboard

### Key Metrics to Track

```javascript
// Monitor these metrics
async function getValidatorMetrics() {
  const metrics = {
    // Personal validator stats
    totalValidated: await bridge.validatorStats(wallet.address),
    pendingValidations: await getPendingValidations(),

    // Bridge health
    dailyVolume: await bridge.dailyMigrated(),
    dailyLimit: await bridge.dailyLimit(),
    totalMigrated: await bridge.totalMigrated(),

    // Consensus status
    activeValidators: await bridge.validatorCount(),
    minValidators: await bridge.MIN_VALIDATORS(),

    // Security
    challengedMigrations: await getChallengedMigrations(),
    pauseStatus: await bridge.paused()
  };

  return metrics;
}
```

### Alert Thresholds

Set up alerts for:
- Daily volume > 80% of limit
- Pending validations > 5
- Validator count < 3
- Any challenged migration
- Bridge paused event

## Testing on Testnet

### Base Sepolia to Vana Moksha Test

1. **Get Test Tokens**:
```bash
# Use the faucet to get MockRDAT on Base Sepolia
forge script script/MockRDATFaucet.s.sol \
  --sig "mintToDeployer(uint256)" 1000 \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast \
  --private-key $DEPLOYER_PRIVATE_KEY
```

2. **Initiate Test Migration**:
```javascript
// Approve and migrate on Base Sepolia
const amount = ethers.parseEther("100");
await mockRDAT.approve(BASE_BRIDGE_ADDRESS, amount);
await baseBridge.initiateMigration(amount);
```

3. **Validate as Validator**:
```javascript
// Monitor and validate on Vana Moksha
// Your monitoring script should detect and validate automatically
```

4. **Verify Success**:
```javascript
// Check balance on Vana Moksha
const v2Balance = await rdatV2.balanceOf(userAddress);
console.log(`V2 Balance: ${ethers.formatEther(v2Balance)} RDAT`);
```

## Validator Rewards

### Compensation Structure
- Base fee: Covered by migration bonus pool
- Performance bonus: Based on uptime and response time
- Emergency response: Additional compensation for critical interventions

### Claiming Rewards
Validator rewards will be distributed monthly:
```javascript
// Check claimable rewards
const rewards = await bridge.validatorRewards(wallet.address);

// Claim rewards
await bridge.claimValidatorRewards();
```

## Support Contacts

### Validator Team Contacts
- **Angela (Dev)**: @angela_dev (Discord)
- **monkfenix.eth**: @monkfenix (Discord)
- **Multisig Operators**: Via governance channel

### Technical Support
- **Primary**: #validators channel in project Discord
- **Urgent**: Direct message to technical lead
- **Email**: validators@rdatadao.org

### Escalation Path
1. Try to reach other validators first
2. Contact technical lead
3. Contact admin multisig signers
4. Emergency pause if critical

## Appendix: Common Issues

### Issue 1: "Already Validated" Error
**Cause**: You've already submitted validation for this migration
**Solution**: Check if other validators have validated; wait for consensus

### Issue 2: "Challenge Period Active"
**Cause**: Migration is within 6-hour challenge window
**Solution**: Wait for challenge period to end before execution

### Issue 3: "Daily Limit Exceeded"
**Cause**: Bridge has hit daily migration limit
**Solution**: Migration will process next day; inform user

### Issue 4: Gas Estimation Failed
**Cause**: Transaction will revert
**Solution**: Check migration details; may be already processed

## Validator Agreement

By operating a validator node, you agree to:
1. Maintain 95%+ uptime during migration period
2. Respond to emergency situations within 2 hours
3. Keep validator keys secure and never share them
4. Report suspicious activity immediately
5. Participate in monthly validator meetings

---

**Document Version**: 1.0.0
**Last Updated**: December 2024
**Next Review**: After first mainnet migration