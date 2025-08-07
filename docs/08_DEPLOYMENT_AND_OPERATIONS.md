# 🚀 RDAT V2 Beta Deployment Guide

**Version**: 2.0 (Modular Rewards Architecture)  
**Sprint**: August 5-18, 2025  
**Target Chains**: Vana (Primary), Base (Migration Only)  
**Contract Count**: 11 Core Contracts (modular architecture)

## 🔑 Deployment Addresses

### Gnosis Safe Multi-Signatures
- **Vana/Vana Moksha**: `0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319`
- **Base/Base Sepolia**: `0x90013583c66D2bf16327cB5Bc4a647AcceCF4B9A`

### Deployer Wallet
- **Address**: `0x58eCB94e6F5e6521228316b55c465ad2A2938FbB`
- **Private Key**: Stored in `.env` file as `DEPLOYER_PRIVATE_KEY` (never commit to version control)

⚠️ **SECURITY WARNING**: The private key must be stored securely in your local `.env` file which is gitignored. Never commit private keys to version control.

## 📋 Pre-Deployment Checklist

### Environment Setup
- [ ] Foundry installed and updated to latest version
- [ ] `.env` file created from `.env.example`
- [ ] Private key securely stored in `.env`
- [ ] RPC URLs configured for all chains
- [ ] Deployer wallet funded on target chains

### Contract Verification
- [ ] All 11 contracts compiled successfully:
  - [ ] RDATUpgradeable.sol (UUPS upgradeable with reentrancy guards)
  - [ ] vRDAT.sol (with quadratic voting)
  - [ ] StakingPositions.sol (immutable core staking logic)
  - [ ] RewardsManager.sol (UUPS upgradeable orchestrator)
  - [ ] vRDATRewardModule.sol (soul-bound governance rewards)
  - [ ] RDATRewardModule.sol (time-based RDAT rewards)
  - [ ] MigrationBridge.sol
  - [ ] EmergencyPause.sol
  - [ ] RevenueCollector.sol
  - [ ] ProofOfContribution.sol
  - [ ] FutureRewardModules.sol (placeholder for expansion)
- [ ] Tests passing with 100% coverage
- [ ] Security review completed (reentrancy, flash loans)
- [ ] Gas optimization targets met
- [ ] Vana DLP compliance verified

## 🌐 Chain-Specific Configuration

### Vana Mainnet (Chain ID: 1480)
```bash
# Deployment command
forge script script/DeployV2Beta.s.sol \
  --rpc-url $VANA_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --broadcast \
  --verify \
  --etherscan-api-key $VANASCAN_API_KEY
```

**Configuration**:
- Multisig: `0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319`
- Treasury: `0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319` (same as multisig)
- Primary deployment chain for all V2 contracts

### Vana Moksha Testnet (Chain ID: 14800)
```bash
# Testnet deployment
forge script script/DeployV2Beta.s.sol \
  --rpc-url $VANA_MOKSHA_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --broadcast \
  --verify
```

### Base Mainnet (Chain ID: 8453)
```bash
# Only MockRDAT for testing migration
forge script script/DeployMockRDAT.s.sol \
  --rpc-url $BASE_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --broadcast \
  --verify \
  --etherscan-api-key $BASESCAN_API_KEY
```

**Note**: Base is ONLY used for V1 token migration. No V2 contracts deployed here.

## 🔴 Critical: Fixed Supply Deployment

### Token Supply Model
**IMPORTANT**: RDAT has a fixed supply of 100M tokens, all minted at deployment:
- **No Minting Post-Deployment**: The `mint()` function always reverts
- **No MINTER_ROLE**: This role doesn't exist in the contract
- **Pre-allocated Distribution**: 70M to Treasury, 30M to MigrationBridge
- **Immutable Supply**: Cannot be changed after deployment

### Fixed Supply Implications
1. **Test with Realistic Amounts**: Cannot mint tokens for testing
2. **Treasury Management**: Must carefully manage the 70M allocation
3. **Migration Limits**: Hard cap of 30M for V1→V2 migration
4. **Reward Sustainability**: All rewards from pre-allocated pools

## 📦 Deployment Order (11 Contracts)

### Contract Dependencies
1. **EmergencyPause** (no dependencies)
2. **RDATUpgradeable** (depends on treasury address) - MINTS 100M AT DEPLOYMENT
3. **vRDAT** (no dependencies) - Dynamic supply based on staking
4. **ProofOfContribution** (no dependencies)
5. **StakingPositions** (immutable, depends on RDAT)
6. **RewardsManager** (upgradeable, no initial dependencies)
7. **vRDATRewardModule** (depends on vRDAT, StakingPositions, RewardsManager)
8. **RDATRewardModule** (depends on RDAT, StakingPositions, RewardsManager)
9. **RevenueCollector** (depends on RDAT and treasury)
10. **MigrationBridge** (depends on RDAT) - RECEIVES 30M RDAT
11. **Future Reward Modules** (as needed)

### Phase 1: Testnet (Days 3-4)

1. **Deploy to Vana Moksha**
   ```bash
   export TREASURY_ADDRESS=0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319
   export MULTISIG_ADDRESS=0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319
   
   forge script script/DeployV2Beta.s.sol --rpc-url $VANA_MOKSHA_RPC_URL --broadcast
   ```

2. **Verify Contracts**
   ```bash
   forge verify-contract <RDAT_PROXY_ADDRESS> src/RDATUpgradeable.sol:RDATUpgradeable --chain-id 14800
   forge verify-contract <vRDAT_ADDRESS> src/vRDAT.sol:vRDAT --chain-id 14800
   # ... repeat for all contracts
   ```

3. **Configure Validators**
   ```bash
   # Add migration bridge validators (need 3)
   cast send <BRIDGE_ADDRESS> "grantRole(bytes32,address)" \
     $(cast sig "VALIDATOR_ROLE()") <VALIDATOR_1> \
     --rpc-url $VANA_MOKSHA_RPC_URL \
     --private-key $DEPLOYER_PRIVATE_KEY
   ```

4. **Configure Modular Rewards System**
   ```bash
   # Grant vRDATRewardModule minting/burning roles on vRDAT
   cast send <vRDAT_ADDRESS> "grantRole(bytes32,address)" \
     $(cast sig "MINTER_ROLE()") <vRDAT_REWARD_MODULE_ADDRESS> \
     --rpc-url $VANA_MOKSHA_RPC_URL \
     --private-key $DEPLOYER_PRIVATE_KEY
   
   cast send <vRDAT_ADDRESS> "grantRole(bytes32,address)" \
     $(cast sig "BURNER_ROLE()") <vRDAT_REWARD_MODULE_ADDRESS> \
     --rpc-url $VANA_MOKSHA_RPC_URL \
     --private-key $DEPLOYER_PRIVATE_KEY
   
   # Register reward programs
   cast send <REWARDS_MANAGER> "registerProgram(address,string,uint256,uint256)" \
     <vRDAT_REWARD_MODULE_ADDRESS> "vRDAT Governance Rewards" $(date +%s) 0 \
     --rpc-url $VANA_MOKSHA_RPC_URL \
     --private-key $DEPLOYER_PRIVATE_KEY
   
   cast send <REWARDS_MANAGER> "registerProgram(address,string,uint256,uint256)" \
     <RDAT_REWARD_MODULE_ADDRESS> "RDAT Staking Rewards" $(date +%s) 63072000 \
     --rpc-url $VANA_MOKSHA_RPC_URL \
     --private-key $DEPLOYER_PRIVATE_KEY
   ```

### Phase 2: Mainnet (Days 12-13)

1. **Final Safety Checks**
   - [ ] Testnet deployment fully tested
   - [ ] Migration flow validated
   - [ ] Emergency procedures tested
   - [ ] Multisig signers ready

2. **Deploy to Vana Mainnet**
   ```bash
   # Set mainnet configuration
   export TREASURY_ADDRESS=0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319
   export MULTISIG_ADDRESS=0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319
   
   # Deploy with verification
   forge script script/DeployV2Beta.s.sol \
     --rpc-url $VANA_RPC_URL \
     --private-key $DEPLOYER_PRIVATE_KEY \
     --broadcast \
     --verify \
     --slow
   ```

3. **Post-Deployment Configuration**
   ```bash
   # Transfer ownership to multisig
   cast send <CONTRACT_ADDRESS> "grantRole(bytes32,address)" \
     $(cast sig "DEFAULT_ADMIN_ROLE()") $MULTISIG_ADDRESS \
     --rpc-url $VANA_RPC_URL \
     --private-key $DEPLOYER_PRIVATE_KEY
   
   # Renounce deployer admin
   cast send <CONTRACT_ADDRESS> "renounceRole(bytes32,address)" \
     $(cast sig "DEFAULT_ADMIN_ROLE()") $DEPLOYER_ADDRESS \
     --rpc-url $VANA_RPC_URL \
     --private-key $DEPLOYER_PRIVATE_KEY
   ```

## 🔒 Security Procedures

### Multisig Setup
1. **Vana Gnosis Safe** (`0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319`)
   - Required signatures: 3/5 for critical operations
   - Required signatures: 2/5 for pause operations
   
2. **Base Gnosis Safe** (`0x90013583c66D2bf16327cB5Bc4a647AcceCF4B9A`)
   - Only used for monitoring V1 token burns
   - Not involved in V2 operations

### Role Assignment (Updated for 11 Contracts - Modular Architecture)
```solidity
// Critical roles requiring multisig
DEFAULT_ADMIN_ROLE -> Gnosis Safe (all contracts)
PAUSER_ROLE -> Gnosis Safe + Emergency addresses
MINTER_ROLE -> MigrationBridge (for RDAT)
MINTER_ROLE -> vRDATRewardModule ONLY (for vRDAT)
BURNER_ROLE -> vRDATRewardModule ONLY (for vRDAT emergency burns)
VALIDATOR_ROLE -> 3 independent validators (MigrationBridge)
VALIDATOR_ROLE -> Oracle validators (ProofOfContribution)
REGISTRAR_ROLE -> Gnosis Safe (ProofOfContribution)
DISTRIBUTOR_ROLE -> Gnosis Safe + Automation (RevenueCollector)
REWARDS_MANAGER_ROLE -> RewardsManager (on all reward modules)
STAKING_NOTIFIER_ROLE -> StakingPositions (on RewardsManager)
```

### Emergency Contacts
- **Technical Lead**: Configure in deployment
- **Security Team**: Configure in deployment
- **Multisig Signers**: Configure in deployment

## 📊 Post-Deployment Verification

### Contract Verification Checklist
- [ ] All contracts verified on block explorer
- [ ] Contract source matches GitHub
- [ ] Constructor arguments correct
- [ ] Roles properly configured
- [ ] Multisig has admin control

### Functional Testing
```bash
# Test token transfer
cast send $RDAT "transfer(address,uint256)" \
  <TEST_ADDRESS> 1000000000000000000 \
  --rpc-url $VANA_RPC_URL \
  --private-key <TEST_PRIVATE_KEY>

# Test staking
cast send $RDAT "approve(address,uint256)" \
  $STAKING 1000000000000000000 \
  --rpc-url $VANA_RPC_URL \
  --private-key <TEST_PRIVATE_KEY>

cast send $STAKING "stake(uint256,uint256)" \
  1000000000000000000 2592000 \
  --rpc-url $VANA_RPC_URL \
  --private-key <TEST_PRIVATE_KEY>
```

## 🚨 Emergency Procedures

### If Deployment Fails
1. **Do NOT panic or rush**
2. **Document the exact error**
3. **Check deployer wallet balance**
4. **Verify network connectivity**
5. **Re-run with `--slow` flag**

### If Wrong Configuration
1. **Use multisig to update roles**
2. **If before ownership transfer, use deployer to fix**
3. **Document all changes made**

### Emergency Pause
```bash
# Any pauser can trigger emergency pause
cast send <CONTRACT> "emergencyPause()" \
  --rpc-url $VANA_RPC_URL \
  --private-key <PAUSER_PRIVATE_KEY>
```

## 📝 Deployment Log Template

```markdown
## Deployment Log - [DATE]

### Environment
- Chain: [Vana Mainnet/Moksha/Base]
- Block Number: [BLOCK]
- Gas Price: [GWEI]
- Deployer: 0x58eCB94e6F5e6521228316b55c465ad2A2938FbB

### Deployed Contracts
- RDAT: 0x...
- vRDAT: 0x...
- Staking: 0x...
- MigrationBridge: 0x...

### Configuration
- Treasury: 0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319
- Multisig: 0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319
- Validators: [LIST]

### Verification Links
- [Vanascan/Basescan links]

### Notes
- [Any issues or observations]
```

## 🔗 Useful Commands

### Check Deployment Status
```bash
# Get deployment address
forge script script/DeployV2Beta.s.sol --rpc-url $VANA_RPC_URL --sig "run()"

# Check contract code
cast code <CONTRACT_ADDRESS> --rpc-url $VANA_RPC_URL

# Check roles
cast call <CONTRACT> "hasRole(bytes32,address)(bool)" \
  $(cast sig "DEFAULT_ADMIN_ROLE()") $MULTISIG_ADDRESS \
  --rpc-url $VANA_RPC_URL
```

### Monitor Migration
```bash
# Check total migrated
cast call $MIGRATION_BRIDGE "totalMigrated()(uint256)" --rpc-url $VANA_RPC_URL

# Check daily limit status  
cast call $MIGRATION_BRIDGE "dailyMigrated()(uint256)" --rpc-url $VANA_RPC_URL
```

---

**Document Status**: Ready for Deployment  
**Security Level**: HIGH - Contains sensitive deployment information  
**Last Updated**: Sprint Day 1# Manual Migration Process Guide

*Last Updated: January 2025*  
*Version: 1.0.0*

## 🎯 Overview

This document provides step-by-step instructions for manually executing token migrations from Base (V1) to Vana (V2) in cases where automated processes are unavailable or emergency intervention is required.

## 📋 Prerequisites

### Required Access
- **Admin Role**: Multi-sig wallet with DEFAULT_ADMIN_ROLE on both bridges
- **Validator Access**: At least 3 of 5 validators must be available
- **Emergency Pause Access**: Ability to pause contracts if needed

### Required Tools
- `cast` (Foundry) - For blockchain interactions
- `jq` - For JSON processing
- Access to both Base and Vana RPC endpoints
- Private keys or hardware wallet access

### Contract Addresses

#### Base Chain
- **V1 Token**: `[TO BE DEPLOYED]`
- **BaseMigrationBridge**: `[TO BE DEPLOYED]`

#### Vana Chain
- **V2 Token (RDAT)**: `[TO BE DEPLOYED]`
- **VanaMigrationBridge**: `[TO BE DEPLOYED]`

## 🚨 Emergency Procedures

### 1. Emergency Pause

If issues are detected during migration:

```bash
# Pause Base bridge
cast send --rpc-url $BASE_RPC \
    $BASE_BRIDGE \
    "emergencyPause()" \
    --private-key $ADMIN_KEY

# Pause Vana bridge
cast send --rpc-url $VANA_RPC \
    $VANA_BRIDGE \
    "emergencyPause()" \
    --private-key $ADMIN_KEY
```

**Note**: Emergency pause automatically expires after 72 hours.

### 2. Emergency Recovery

For stuck migrations:

```bash
# On Vana bridge - mark migration as failed
cast send --rpc-url $VANA_RPC \
    $VANA_BRIDGE \
    "markMigrationFailed(bytes32)" \
    $REQUEST_ID \
    --private-key $ADMIN_KEY

# User can then retry migration
```

## 📝 Manual Migration Process

### Step 1: Pre-Migration Verification

```bash
# Check user's V1 balance
V1_BALANCE=$(cast call --rpc-url $BASE_RPC \
    $V1_TOKEN \
    "balanceOf(address)" \
    $USER_ADDRESS)

echo "User V1 Balance: $V1_BALANCE"

# Check migration limits
DAILY_LIMIT=$(cast call --rpc-url $BASE_RPC \
    $BASE_BRIDGE \
    "DAILY_MIGRATION_LIMIT()")

DAILY_MIGRATED=$(cast call --rpc-url $BASE_RPC \
    $BASE_BRIDGE \
    "dailyMigrated()")

echo "Daily limit: $DAILY_LIMIT"
echo "Already migrated today: $DAILY_MIGRATED"
```

### Step 2: Process Migration Request

If a user has initiated migration but it's stuck:

```bash
# Get migration request details
REQUEST_DETAILS=$(cast call --rpc-url $BASE_RPC \
    $BASE_BRIDGE \
    "migrationRequests(bytes32)" \
    $REQUEST_ID)

# Parse details (user, amount, block, processed)
USER=$(echo $REQUEST_DETAILS | cut -d' ' -f1)
AMOUNT=$(echo $REQUEST_DETAILS | cut -d' ' -f2)
BLOCK=$(echo $REQUEST_DETAILS | cut -d' ' -f3)
PROCESSED=$(echo $REQUEST_DETAILS | cut -d' ' -f4)

echo "Migration Request:"
echo "  User: $USER"
echo "  Amount: $AMOUNT"
echo "  Block: $BLOCK"
echo "  Processed: $PROCESSED"
```

### Step 3: Validator Coordination

Gather validator signatures for the migration:

```bash
# Message to sign
MESSAGE_HASH=$(cast keccak \
    $(cast abi-encode "f(bytes32,address,uint256,uint256)" \
        $REQUEST_ID \
        $USER \
        $AMOUNT \
        $BLOCK))

# Each validator signs
VALIDATOR_1_SIG=$(cast wallet sign $MESSAGE_HASH --private-key $VALIDATOR_1_KEY)
VALIDATOR_2_SIG=$(cast wallet sign $MESSAGE_HASH --private-key $VALIDATOR_2_KEY)
VALIDATOR_3_SIG=$(cast wallet sign $MESSAGE_HASH --private-key $VALIDATOR_3_KEY)
```

### Step 4: Execute Migration on Vana

```bash
# Combine signatures
SIGNATURES=$(cast abi-encode "f(bytes[])" \
    "[$VALIDATOR_1_SIG,$VALIDATOR_2_SIG,$VALIDATOR_3_SIG]")

# Execute migration
cast send --rpc-url $VANA_RPC \
    $VANA_BRIDGE \
    "executeMigration(bytes32,address,uint256,uint256,bytes[])" \
    $REQUEST_ID \
    $USER \
    $AMOUNT \
    $BLOCK \
    $SIGNATURES \
    --private-key $EXECUTOR_KEY
```

### Step 5: Verify Migration

```bash
# Check V2 balance
V2_BALANCE=$(cast call --rpc-url $VANA_RPC \
    $V2_TOKEN \
    "balanceOf(address)" \
    $USER)

echo "User V2 Balance: $V2_BALANCE"

# Verify migration marked as complete
IS_PROCESSED=$(cast call --rpc-url $VANA_RPC \
    $VANA_BRIDGE \
    "processedMigrations(bytes32)" \
    $REQUEST_ID)

if [ "$IS_PROCESSED" = "true" ]; then
    echo "✅ Migration completed successfully"
else
    echo "❌ Migration not yet processed"
fi
```

## 🔄 Batch Migration Process

For processing multiple stuck migrations:

```bash
#!/bin/bash
# batch-migration.sh

# Read pending migrations from file
while IFS=',' read -r request_id user amount block; do
    echo "Processing migration: $request_id"
    
    # Get validator signatures
    MESSAGE_HASH=$(cast keccak \
        $(cast abi-encode "f(bytes32,address,uint256,uint256)" \
            $request_id $user $amount $block))
    
    # Collect signatures (automated via validator nodes)
    SIGS=$(./collect-signatures.sh $MESSAGE_HASH)
    
    # Execute migration
    cast send --rpc-url $VANA_RPC \
        $VANA_BRIDGE \
        "executeMigration(bytes32,address,uint256,uint256,bytes[])" \
        $request_id $user $amount $block $SIGS \
        --private-key $EXECUTOR_KEY
        
    sleep 5 # Rate limiting
done < pending_migrations.csv
```

## 🔍 Monitoring and Verification

### Check Migration Status

```bash
# Check specific migration
./check-migration.sh $REQUEST_ID

# Output:
# Base Chain:
#   Request initiated: ✓
#   V1 tokens burned: ✓
#   
# Vana Chain:
#   Validators signed: 3/5
#   Migration executed: ✓
#   V2 tokens minted: ✓
#   Bonus applied: 5%
```

### Daily Migration Report

```bash
# Generate daily report
cast logs --rpc-url $BASE_RPC \
    --from-block $(($(cast block-number) - 7200)) \
    --address $BASE_BRIDGE \
    "MigrationInitiated(bytes32,address,uint256,uint256)" \
    | jq -r '.[] | [.topics[1], .topics[2], .data] | @csv' \
    > daily_migrations.csv

# Summary
echo "Daily Migration Summary:"
echo "Total migrations: $(wc -l < daily_migrations.csv)"
echo "Total volume: $(awk -F',' '{sum+=$3} END {print sum}' daily_migrations.csv)"
```

## 🛠️ Troubleshooting

### Common Issues and Solutions

#### 1. Migration Stuck - No Validator Signatures

**Symptom**: Migration initiated but no execution on Vana  
**Solution**:
```bash
# Check validator status
for VALIDATOR in $VALIDATOR_1 $VALIDATOR_2 $VALIDATOR_3; do
    IS_ACTIVE=$(cast call --rpc-url $VANA_RPC \
        $VANA_BRIDGE \
        "validators(address)" \
        $VALIDATOR)
    echo "Validator $VALIDATOR active: $IS_ACTIVE"
done

# If validators offline, use emergency admin execution
cast send --rpc-url $VANA_RPC \
    $VANA_BRIDGE \
    "emergencyExecuteMigration(bytes32,address,uint256)" \
    $REQUEST_ID $USER $AMOUNT \
    --private-key $ADMIN_KEY
```

#### 2. Daily Limit Exceeded

**Symptom**: Migration reverts with "Daily limit exceeded"  
**Solution**:
```bash
# Wait for limit reset (UTC midnight)
SECONDS_UNTIL_RESET=$((86400 - $(date +%s) % 86400))
echo "Limit resets in: $((SECONDS_UNTIL_RESET / 3600)) hours"

# Or request emergency limit increase (requires governance)
```

#### 3. Insufficient V2 Token Supply

**Symptom**: "Insufficient balance" on Vana bridge  
**Solution**:
```bash
# Check bridge balance
BRIDGE_BALANCE=$(cast call --rpc-url $VANA_RPC \
    $V2_TOKEN \
    "balanceOf(address)" \
    $VANA_BRIDGE)

if [ "$BRIDGE_BALANCE" -lt "$REQUIRED_AMOUNT" ]; then
    echo "⚠️ Bridge needs refunding"
    # Contact treasury for allocation
fi
```

#### 4. Duplicate Migration Attempt

**Symptom**: "Migration already processed"  
**Solution**:
```bash
# Verify if user already received V2 tokens
V2_BALANCE=$(cast call --rpc-url $VANA_RPC \
    $V2_TOKEN \
    "balanceOf(address)" \
    $USER)

if [ "$V2_BALANCE" -gt "0" ]; then
    echo "User already migrated. V2 balance: $V2_BALANCE"
fi
```

## 📊 Migration Analytics

### Generate Migration Metrics

```bash
# Total migrations processed
TOTAL_MIGRATIONS=$(cast call --rpc-url $VANA_RPC \
    $VANA_BRIDGE \
    "totalMigrations()")

# Total volume migrated
TOTAL_VOLUME=$(cast call --rpc-url $VANA_RPC \
    $VANA_BRIDGE \
    "totalMigrated()")

# Average migration size
AVG_SIZE=$((TOTAL_VOLUME / TOTAL_MIGRATIONS))

# Bonus tokens distributed
BONUS_DISTRIBUTED=$(cast call --rpc-url $VANA_RPC \
    $VANA_BRIDGE \
    "totalBonusDistributed()")

echo "Migration Statistics:"
echo "  Total migrations: $TOTAL_MIGRATIONS"
echo "  Total volume: $(echo "scale=2; $TOTAL_VOLUME / 10^18" | bc) RDAT"
echo "  Average size: $(echo "scale=2; $AVG_SIZE / 10^18" | bc) RDAT"
echo "  Bonus distributed: $(echo "scale=2; $BONUS_DISTRIBUTED / 10^18" | bc) RDAT"
```

## 🔐 Security Considerations

### Before Manual Intervention

1. **Verify Contract Addresses**: Always verify you're interacting with correct contracts
2. **Check Signatures**: Ensure validator signatures are authentic
3. **Validate Amounts**: Double-check migration amounts match requests
4. **Monitor Gas Prices**: Ensure reasonable gas prices to avoid failed transactions
5. **Backup Data**: Keep records of all manual interventions

### Multi-Sig Execution

For admin functions requiring multi-sig:

```bash
# Prepare transaction data
DATA=$(cast calldata "emergencyPause()")

# Submit to Gnosis Safe
# Use Gnosis Safe UI or SDK to create transaction
# Collect required signatures
# Execute when threshold reached
```

## 📱 Contact Information

### Emergency Contacts

- **Technical Lead**: [REDACTED]
- **Security Team**: security@rdatadao.org
- **Validator Coordinator**: validators@rdatadao.org

### Escalation Path

1. **Level 1**: Validator coordinator (non-critical issues)
2. **Level 2**: Technical lead (system failures)
3. **Level 3**: Emergency multi-sig execution (critical security)

## 📚 Additional Resources

- [Migration Architecture Documentation](./MIGRATION_ARCHITECTURE.md)
- [Validator Operations Guide](./VALIDATOR_GUIDE.md)
- [Emergency Response Procedures](./EMERGENCY_PROCEDURES.md)
- [Contract Addresses Registry](./DEPLOYED_ADDRESSES.md)

## ✅ Checklist for Manual Migration

- [ ] Verify user's migration request is valid
- [ ] Check daily migration limits
- [ ] Confirm V1 tokens are burned on Base
- [ ] Collect required validator signatures (3 of 5)
- [ ] Execute migration on Vana
- [ ] Verify V2 tokens are minted
- [ ] Confirm bonus calculation is correct
- [ ] Update migration tracking spreadsheet
- [ ] Notify user of completion
- [ ] Document any issues encountered

---

*This document is maintained by the r/datadao technical team. For updates or corrections, please submit a PR to the repository.*# Emergency Response Playbook - RDAT V2

**Last Updated**: August 6, 2025  
**Status**: Complete emergency procedures documentation  
**Criticality**: HIGH - All team members must be familiar with these procedures  

---

## =� Overview

This playbook defines emergency response procedures for various security incidents and operational emergencies in the RDAT V2 ecosystem. Response time is critical - all team members should be familiar with these procedures.

---

## =� Incident Severity Levels

| Level | Description | Response Time | Examples |
|-------|-------------|---------------|----------|
| **CRITICAL** | Immediate threat to funds or system | < 15 minutes | Active exploit, private key compromise |
| **HIGH** | Significant risk, not immediate | < 1 hour | Suspicious activity, potential vulnerability |
| **MEDIUM** | Operational issue, low risk | < 4 hours | Failed transactions, UI issues |
| **LOW** | Minor issue, no immediate risk | < 24 hours | Documentation errors, minor bugs |

---

## =4 CRITICAL: Active Exploit Response

### Detection Indicators
- Unexpected token movements
- Abnormal gas consumption
- Multiple failed transactions
- Community reports of losses

### Immediate Actions (0-15 minutes)

1. **PAUSE ALL CONTRACTS** (Any Emergency Team member)
   ```bash
   # Execute emergency pause
   cast send $EMERGENCY_PAUSE "pauseAll()" \
     --private-key $EMERGENCY_KEY \
     --rpc-url $RPC_URL
   ```

2. **Alert Core Team**
   - Telegram: [Emergency Channel]
   - Discord: @emergency-response
   - Email: security@rdatadao.com

3. **Document Initial Findings**
   - Transaction hashes
   - Affected addresses
   - Estimated impact

### Investigation Phase (15-60 minutes)

1. **Gather Evidence**
   - Export all relevant transactions
   - Screenshot suspicious activity
   - Check all contract states

2. **Identify Attack Vector**
   - Review recent transactions
   - Check for known vulnerabilities
   - Analyze attack pattern

3. **Assess Damage**
   - Total funds at risk
   - Number of affected users
   - Contracts compromised

### Mitigation Phase (1-4 hours)

1. **Deploy Fixes**
   - Develop patch (if applicable)
   - Test on fork
   - Prepare deployment

2. **Communication**
   - Draft incident report
   - Prepare user notifications
   - Update status page

3. **Execute Recovery**
   - Deploy fixes via multisig
   - Unpause when safe
   - Monitor for issues

---

## =� HIGH: Suspicious Activity Response

### Examples
- Unusual staking patterns
- Potential governance attacks
- Abnormal reward claims

### Response Steps

1. **Monitor & Document** (0-30 minutes)
   - Track suspicious addresses
   - Document transaction patterns
   - Calculate potential impact

2. **Escalate if Needed** (30-60 minutes)
   - Consult security team
   - Consider preventive pause
   - Prepare mitigation plan

3. **Take Action** (1-4 hours)
   - Implement restrictions
   - Update parameters
   - Notify affected users

---

## = Key Compromise Procedures

### If Private Key Compromised

1. **Immediate Actions**
   - Revoke all permissions from compromised address
   - Transfer any accessible funds to secure address
   - Pause affected contracts

2. **Multisig Response**
   ```solidity
   // Remove compromised signer
   multisig.removeOwner(compromisedAddress);
   
   // Add new secure signer
   multisig.addOwner(newSecureAddress);
   ```

3. **Audit Trail**
   - Document compromise details
   - Review access logs
   - Update security procedures

---

## < Cross-Chain Bridge Issues

### Bridge Halted

1. **Verify on Both Chains**
   - Check Base status
   - Check Vana status
   - Verify validator status

2. **Coordinate Validators**
   - Contact all 3 validators
   - Verify consensus
   - Plan restart

3. **Resume Operations**
   - Clear pending migrations
   - Update validator set if needed
   - Monitor for issues

### Invalid Migration Detected

1. **Challenge Period** (0-6 hours)
   - Submit challenge transaction
   - Provide evidence
   - Alert validators

2. **Resolution**
   - Validators review evidence
   - Vote on validity
   - Execute decision

---

## =� Emergency Contacts

### Core Team (To be filled at deployment)
| Role | Name | Contact | Timezone |
|------|------|---------|----------|
| Technical Lead | [Name] | [Telegram/Phone] | [TZ] |
| Security Lead | [Name] | [Telegram/Phone] | [TZ] |
| Operations Lead | [Name] | [Telegram/Phone] | [TZ] |
| Multisig Signer 1 | [Name] | [Telegram] | [TZ] |
| Multisig Signer 2 | [Name] | [Telegram] | [TZ] |

### External Support
- **Audit Firm**: [Contact info]
- **Legal Counsel**: [Contact info]
- **PR Agency**: [Contact info]

---

## =� Incident Response Checklist

### During Incident
- [ ] Pause affected contracts
- [ ] Alert core team
- [ ] Document everything
- [ ] Assess impact
- [ ] Develop fix
- [ ] Test solution
- [ ] Communicate status

### Post-Incident
- [ ] Deploy fixes
- [ ] Unpause contracts
- [ ] Publish report
- [ ] Compensate users (if applicable)
- [ ] Update procedures
- [ ] Schedule retrospective

---

## =� Technical Commands

### Emergency Pause
```bash
# Pause specific contract
cast send $CONTRACT "pause()" --private-key $EMERGENCY_KEY

# Pause via EmergencyPause (all contracts)
cast send $EMERGENCY_PAUSE "pauseAll()" --private-key $EMERGENCY_KEY
```

### Check Contract Status
```bash
# Check if paused
cast call $CONTRACT "paused()" --rpc-url $RPC_URL

# Check pause timestamp
cast call $CONTRACT "pausedAt()" --rpc-url $RPC_URL

# Calculate auto-unpause time (72 hours)
echo $(($(cast call $CONTRACT "pausedAt()") + 259200))
```

### Multisig Operations
```bash
# Submit transaction
cast send $MULTISIG "submitTransaction(address,uint256,bytes)" \
  $TARGET 0 $CALLDATA --private-key $SIGNER_KEY

# Confirm transaction
cast send $MULTISIG "confirmTransaction(uint256)" \
  $TX_ID --private-key $SIGNER_KEY

# Execute transaction (after confirmations)
cast send $MULTISIG "executeTransaction(uint256)" \
  $TX_ID --private-key $SIGNER_KEY
```

---

## =� Communication Templates

### Initial Alert (Internal)
```
=� SECURITY ALERT - [CRITICAL/HIGH/MEDIUM]

Time: [UTC timestamp]
Issue: [Brief description]
Impact: [Estimated affected users/funds]
Status: Investigating / Mitigating / Resolved

Actions taken:
- [Action 1]
- [Action 2]

Next steps:
- [Step 1]
- [Step 2]

Point person: [Name]
```

### Public Announcement
```
� System Maintenance Notice

We are currently investigating [general description].
User funds are [safe/being secured].

Actions taken:
- System paused as precaution
- Team investigating issue
- Updates every 30 minutes

Latest updates: [status page URL]
```

### Post-Incident Report
```
=� Incident Report - [Date]

Summary: [What happened]
Impact: [Who was affected and how]
Root cause: [Technical explanation]
Resolution: [How it was fixed]
Prevention: [Future measures]

Full details: [blog post URL]
```

---

## = Auto-Unpause Mechanism

All emergency pauses auto-expire after 72 hours to prevent permanent lock:

```solidity
modifier whenNotPaused() {
    require(!paused || block.timestamp > pausedAt + 72 hours, "Paused");
    _;
}
```

To unpause before expiry:
1. 3/5 multisig required
2. Document reason for unpause
3. Verify fix deployed
4. Monitor after unpause

---

## =� Lessons Learned Process

After each incident:

1. **Retrospective Meeting** (within 48 hours)
   - What went well?
   - What could improve?
   - Action items

2. **Update Procedures**
   - Revise this playbook
   - Update monitoring
   - Improve automation

3. **Share Knowledge**
   - Internal documentation
   - Community updates
   - Industry sharing (if applicable)

---

## <� Prevention Measures

### Monitoring Setup
- Transaction monitoring alerts
- Unusual volume detection
- Gas price anomaly alerts
- Social media monitoring

### Regular Drills
- Monthly pause/unpause test
- Quarterly full incident drill
- Annual third-party assessment

### Access Control
- Regular key rotation
- Access audit monthly
- Multisig signer verification
- Hardware wallet enforcement

---

**Remember**: Speed matters, but accuracy matters more. Take 30 seconds to think before acting. Document everything. Protect users first, protocol second.