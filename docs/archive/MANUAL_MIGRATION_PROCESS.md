# Manual Migration Process Guide

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

*This document is maintained by the r/datadao technical team. For updates or corrections, please submit a PR to the repository.*