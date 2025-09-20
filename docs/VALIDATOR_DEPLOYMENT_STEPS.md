# Validator Deployment Manual Steps

## Pre-Deployment Checklist

### 1. Confirm Validator Participation

**Contact each validator to confirm:**

#### Angela (Dev Team)
- **Wallet Address**: `0xd36B49f2DB6aA708Ce7245e8ab2453C6DfFc9d6f`
- **Networks**: Base Sepolia + Base Mainnet
- [ ] Confirm wallet access
- [ ] Confirm availability for validation duties
- [ ] Provide monitoring tools/scripts

#### monkfenix.eth
- **Wallet Address**: `0xC9Af4E56741f255743e8f4877d4cfa9971E910C2`
- **Networks**: Base Sepolia + Base Mainnet
- [ ] Confirm wallet access
- [ ] Confirm availability for validation duties
- [ ] Provide monitoring tools/scripts

#### Multisig Validators
- **Base Sepolia**: `0xdc096Bc0e5d7aB53C7Bd3cbb72B092d1054E393e`
- **Base Mainnet**: `0x08Cc5ed1bA3C95AA741f8AaEf631f716b037444b`
- [ ] Confirm all signers have access
- [ ] Establish signing procedures
- [ ] Set response time expectations

### 2. Environment Configuration

Ensure `.env` file is properly configured:

```bash
# Migration Bridge Validators (3 required)
# Angela (dev) - Same address for testnet and mainnet
VALIDATOR_1=0xd36B49f2DB6aA708Ce7245e8ab2453C6DfFc9d6f

# monkfenix.eth - Same address for testnet and mainnet
VALIDATOR_2=0xC9Af4E56741f255743e8f4877d4cfa9971E910C2

# Multisig - Different for testnet vs mainnet
VALIDATOR_3_TESTNET=0xdc096Bc0e5d7aB53C7Bd3cbb72B092d1054E393e
VALIDATOR_3_MAINNET=0x08Cc5ed1bA3C95AA741f8AaEf631f716b037444b
```

### 3. Communication Setup

- [ ] Create private Discord channel for validators
- [ ] Add all validators to channel
- [ ] Share emergency contact information
- [ ] Establish escalation procedures

## Testnet Deployment (Base Sepolia → Vana Moksha)

### Step 1: Deploy to Vana Moksha Testnet

```bash
# Set testnet multisig addresses
export TREASURY_ADDRESS=0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319
export ADMIN_ADDRESS=0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319

# Deploy with testnet validators
forge script script/DeployRDATUpgradeableProduction.s.sol \
  --rpc-url $VANA_MOKSHA_RPC_URL \
  --broadcast \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --verify
```

### Step 2: Verify Validator Setup

```bash
# Check each validator has the VALIDATOR_ROLE
cast call $VANA_BRIDGE "hasRole(bytes32,address)" \
  $(cast keccak "VALIDATOR_ROLE") \
  0xd36B49f2DB6aA708Ce7245e8ab2453C6DfFc9d6f \
  --rpc-url $VANA_MOKSHA_RPC_URL

# Repeat for each validator address
```

### Step 3: Test Migration Flow

1. **Mint test tokens on Base Sepolia**:
```bash
forge script script/MockRDATFaucet.s.sol \
  --sig "mintToDeployer(uint256)" 1000 \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast \
  --private-key $DEPLOYER_PRIVATE_KEY
```

2. **Distribute to test account**:
```bash
forge script script/MockRDATFaucet.s.sol \
  --sig "distributeToTester(address,uint256)" $TEST_ADDRESS 100 \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast \
  --private-key $DEPLOYER_PRIVATE_KEY
```

3. **Have validators monitor and validate migration**

4. **Verify 2-of-3 consensus works**

## Mainnet Deployment (Base → Vana)

### Step 1: Final Validator Confirmation

**48 hours before deployment:**
- [ ] Confirm all validators ready
- [ ] Review security procedures
- [ ] Test communication channels
- [ ] Dry run validation process

### Step 2: Deploy to Vana Mainnet

```bash
# Set mainnet multisig addresses
export TREASURY_ADDRESS=$VANA_MULTISIG_ADDRESS
export ADMIN_ADDRESS=$VANA_MULTISIG_ADDRESS

# Deploy with mainnet validators
forge script script/DeployRDATUpgradeableProduction.s.sol \
  --rpc-url $VANA_RPC_URL \
  --broadcast \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --verify \
  --slow
```

### Step 3: Deploy Base Migration Bridge

```bash
# Deploy migration entry point on Base
forge script script/DeployBaseMigration.s.sol \
  --rpc-url $BASE_RPC_URL \
  --broadcast \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --verify \
  --slow
```

### Step 4: Post-Deployment Verification

1. **Verify validator roles**:
```bash
# Check validator count
cast call $VANA_BRIDGE "validatorCount()" --rpc-url $VANA_RPC_URL

# Should return 3
```

2. **Verify each validator**:
```bash
for VALIDATOR in $VALIDATOR_1 $VALIDATOR_2 $VALIDATOR_3_MAINNET; do
  echo "Checking validator: $VALIDATOR"
  cast call $VANA_BRIDGE "hasRole(bytes32,address)" \
    $(cast keccak "VALIDATOR_ROLE") \
    $VALIDATOR \
    --rpc-url $VANA_RPC_URL
done
```

3. **Test small migration**:
- Transfer 1 RDAT from team wallet
- Have validators validate
- Confirm receipt on Vana

### Step 5: Enable Validator Monitoring

**For Each Validator:**

1. **Provide monitoring script**:
```bash
# Share the validator-tools repository
git clone https://github.com/rdatadao/validator-tools.git
cd validator-tools
npm install
```

2. **Configure environment**:
```bash
# Each validator creates their .env
VALIDATOR_PRIVATE_KEY=<their_private_key>
BASE_BRIDGE_ADDRESS=<deployed_base_bridge>
VANA_BRIDGE_ADDRESS=<deployed_vana_bridge>
BASE_RPC_URL=https://mainnet.base.org
VANA_RPC_URL=https://rpc.vana.org
```

3. **Start monitoring**:
```bash
npm run monitor:mainnet
```

## Post-Deployment Monitoring

### First 24 Hours
- [ ] All validators online and monitoring
- [ ] Test migration completed successfully
- [ ] No unexpected errors in logs
- [ ] Communication channels active

### First Week
- [ ] Daily validator check-ins
- [ ] Review migration patterns
- [ ] Adjust daily limits if needed
- [ ] Document any issues

### Ongoing
- [ ] Weekly validator sync meetings
- [ ] Monthly performance review
- [ ] Quarterly security audit
- [ ] Annual validator rotation consideration

## Emergency Contacts

### Primary Contacts
- **Technical Lead**: Via Discord #validators
- **Angela (Dev)**: Direct message on Discord
- **monkfenix.eth**: Direct message on Discord
- **Multisig Operators**: Via governance channel

### Escalation
1. Validator Discord channel
2. Direct message to online validators
3. Email: security@rdatadao.org
4. Emergency multisig action

## Manual Override Procedures

### If Validator Needs Replacement

1. **Remove compromised/inactive validator**:
```bash
cast send $VANA_BRIDGE "removeValidator(address)" \
  $OLD_VALIDATOR \
  --private-key $ADMIN_PRIVATE_KEY \
  --rpc-url $VANA_RPC_URL
```

2. **Add new validator**:
```bash
cast send $VANA_BRIDGE "addValidator(address)" \
  $NEW_VALIDATOR \
  --private-key $ADMIN_PRIVATE_KEY \
  --rpc-url $VANA_RPC_URL
```

### If Bridge Needs Pausing

```bash
# Any PAUSER_ROLE holder can pause
cast send $VANA_BRIDGE "pause()" \
  --private-key $PAUSER_PRIVATE_KEY \
  --rpc-url $VANA_RPC_URL
```

### If Migration Challenged

1. **Wait 7 days for review period**
2. **Admin can override if legitimate**:
```bash
cast send $VANA_BRIDGE "overrideChallenge(bytes32)" \
  $REQUEST_ID \
  --private-key $ADMIN_PRIVATE_KEY \
  --rpc-url $VANA_RPC_URL
```

## Success Criteria

### Testnet Success
- [ ] All 3 validators successfully validate a migration
- [ ] 2-of-3 consensus executes migration
- [ ] Challenge mechanism tested
- [ ] Communication channels verified

### Mainnet Success
- [ ] Bridge deployed with correct validators
- [ ] First migration completed
- [ ] All validators monitoring actively
- [ ] No security incidents in first week

---

**Document Version**: 1.0.0
**Created**: December 2024
**Last Updated**: December 2024
**Next Review**: Before mainnet deployment