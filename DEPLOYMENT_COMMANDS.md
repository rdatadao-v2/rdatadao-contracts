# RDAT V2 Deployment Commands

## Environment Setup

Before deployment, ensure your `.env` file contains:

```bash
# Network RPCs
VANA_RPC_URL=https://rpc.vana.org
VANA_MOKSHA_RPC_URL=https://rpc.moksha.vana.org
BASE_RPC_URL=https://mainnet.base.org
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org

# Vana Network Multisig (receives treasury + admin roles)
VANA_MULTISIG_ADDRESS=0xe4F7Eca807C57311e715C3Ef483e72Fa8D5bCcDF
ADMIN_ADDRESS=0xe4F7Eca807C57311e715C3Ef483e72Fa8D5bCcDF
TREASURY_ADDRESS=0xe4F7Eca807C57311e715C3Ef483e72Fa8D5bCcDF

# Base Network Multisig
BASE_MULTISIG_ADDRESS=0x90013583c66D2bf16327cB5Bc4a647AcceCF4B9A

# Deployer
DEPLOYER_ADDRESS=0x58eCB94e6F5e6521228316b55c465ad2A2938FbB
DEPLOYER_PRIVATE_KEY=<your_private_key>

# Validators
VALIDATOR_1=0xd36B49f2DB6aA708Ce7245e8ab2453C6DfFc9d6f  # Angela
VALIDATOR_2=0xC9Af4E56741f255743e8f4877d4cfa9971E910C2  # monkfenix.eth
VALIDATOR_3_TESTNET=0xdc096Bc0e5d7aB53C7Bd3cbb72B092d1054E393e  # Base Sepolia multisig
VALIDATOR_3_MAINNET=0x08Cc5ed1bA3C95AA741f8AaEf631f716b037444b  # Base mainnet multisig
```

## Testnet Deployment

### 1. Deploy to Vana Moksha Testnet

```bash
# Dry run first (no broadcasting)
ADMIN_ADDRESS=$VANA_MULTISIG_ADDRESS \
forge script script/DeployRDATUpgradeableProduction.s.sol \
  --rpc-url $VANA_MOKSHA_RPC_URL \
  --sig "dryRun()"

# Deploy with broadcasting
ADMIN_ADDRESS=$VANA_MULTISIG_ADDRESS \
forge script script/DeployRDATUpgradeableProduction.s.sol \
  --rpc-url $VANA_MOKSHA_RPC_URL \
  --broadcast \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --verify
```

### 2. Deploy Migration Bridge to Base Sepolia

```bash
forge script script/DeployBaseMigration.s.sol \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --verify
```

### 3. Verify Deployment

```bash
# Check token distribution
cast call $RDAT_TOKEN "totalSupply()" --rpc-url $VANA_MOKSHA_RPC_URL
# Should return: 100000000000000000000000000 (100M * 10^18)

# Check treasury balance (should be 70M)
cast call $RDAT_TOKEN "balanceOf(address)" $TREASURY_ADDRESS --rpc-url $VANA_MOKSHA_RPC_URL
# Should return: 70000000000000000000000000 (70M * 10^18)

# Check migration bridge balance (should be 30M)
cast call $RDAT_TOKEN "balanceOf(address)" $MIGRATION_BRIDGE_ADDRESS --rpc-url $VANA_MOKSHA_RPC_URL
# Should return: 30000000000000000000000000 (30M * 10^18)
```

## Mainnet Deployment

### 1. Pre-Deployment Checklist

- [ ] Wallet funded with 1-2 VANA for deployment
- [ ] Wallet funded with 0.02-0.05 ETH on Base
- [ ] All validators confirmed and ready
- [ ] Multisig signers on standby
- [ ] Deployment scripts tested on testnet

### 2. Deploy to Vana Mainnet

```bash
# Dry run first (ALWAYS DO THIS!)
ADMIN_ADDRESS=$VANA_MULTISIG_ADDRESS \
forge script script/DeployRDATUpgradeableProduction.s.sol \
  --rpc-url $VANA_RPC_URL \
  --sig "dryRun()"

# Deploy with broadcasting
ADMIN_ADDRESS=$VANA_MULTISIG_ADDRESS \
forge script script/DeployRDATUpgradeableProduction.s.sol \
  --rpc-url $VANA_RPC_URL \
  --broadcast \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --verify \
  --slow \
  --legacy
```

### 3. Deploy Migration Bridge to Base Mainnet

```bash
# Deploy entry point on Base
forge script script/DeployBaseMigration.s.sol \
  --rpc-url $BASE_RPC_URL \
  --broadcast \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --verify \
  --slow
```

### 4. Post-Deployment Verification

```bash
# Verify token supply and distribution
forge script script/VerifyDeployment.s.sol \
  --rpc-url $VANA_RPC_URL

# Check all role assignments
cast call $RDAT_TOKEN "hasRole(bytes32,address)" \
  0x0000000000000000000000000000000000000000000000000000000000000000 \
  $VANA_MULTISIG_ADDRESS \
  --rpc-url $VANA_RPC_URL
```

## Token Distribution at Deployment

The RDAT token constructor automatically mints and distributes tokens:

```
Total Supply: 100,000,000 RDAT (fixed)
├── Treasury (70M → Vana Multisig)
│   ├── Team Vesting: 10M (10%)
│   ├── Development: 20M (20%)
│   ├── Community: 30M (30%)
│   └── Reserve: 10M (10%)
└── Migration Bridge (30M)
    └── V1 Holder Claims: 30M (30%)
```

## Role Assignments

The Vana multisig (`0xe4F7Eca807C57311e715C3Ef483e72Fa8D5bCcDF`) receives:

1. **DEFAULT_ADMIN_ROLE** - Manage all other roles
2. **PAUSER_ROLE** - Emergency pause capability
3. **UPGRADER_ROLE** - Contract upgrade authorization
4. **TREASURY_ROLE** - Treasury operations

## What Happens During Deployment

1. **CREATE2 Factory** deploys to enable deterministic addresses
2. **TreasuryWallet** deploys (proxy pattern)
3. **VanaMigrationBridge** deploys with 3 validators configured
4. **RDAT Token** deploys and:
   - Mints 70M RDAT to TreasuryWallet
   - Mints 30M RDAT to VanaMigrationBridge
   - Grants all admin roles to Vana multisig
5. **TreasuryWallet** initialized with Vana multisig as admin

## Common Issues and Solutions

### Issue: "ADMIN_ADDRESS not set"
**Solution**: Export the environment variable:
```bash
export ADMIN_ADDRESS=0xe4F7Eca807C57311e715C3Ef483e72Fa8D5bCcDF
```

### Issue: "Insufficient funds"
**Solution**: Ensure deployer wallet has:
- Vana network: 1-2 VANA
- Base network: 0.02-0.05 ETH

### Issue: "VALIDATOR not set"
**Solution**: Ensure all validator addresses are in `.env`:
```bash
export VALIDATOR_1=0xd36B49f2DB6aA708Ce7245e8ab2453C6DfFc9d6f
export VALIDATOR_2=0xC9Af4E56741f255743e8f4877d4cfa9971E910C2
export VALIDATOR_3_MAINNET=0x08Cc5ed1bA3C95AA741f8AaEf631f716b037444b
```

### Issue: Verification fails
**Solution**: Add API keys to `.env`:
```bash
VANASCAN_API_KEY=your_api_key_here
BASESCAN_API_KEY=your_api_key_here
```

## Emergency Procedures

### Pause Operations
```bash
# Pause token transfers (Vana multisig required)
cast send $RDAT_TOKEN "pause()" \
  --private-key $MULTISIG_SIGNER_KEY \
  --rpc-url $VANA_RPC_URL
```

### Add/Remove Validators
```bash
# Add validator (admin role required)
cast send $MIGRATION_BRIDGE "addValidator(address)" $NEW_VALIDATOR \
  --private-key $ADMIN_KEY \
  --rpc-url $VANA_RPC_URL

# Remove validator
cast send $MIGRATION_BRIDGE "removeValidator(address)" $OLD_VALIDATOR \
  --private-key $ADMIN_KEY \
  --rpc-url $VANA_RPC_URL
```

## Deployed Contract Addresses

### Vana Moksha Testnet (Chain ID: 14800)
- RDAT Token: `TBD after deployment`
- Treasury: `TBD after deployment`
- Migration Bridge: `TBD after deployment`

### Vana Mainnet (Chain ID: 1480)
- RDAT Token: `TBD after deployment`
- Treasury: `TBD after deployment`
- Migration Bridge: `TBD after deployment`

### Base Sepolia (Chain ID: 84532)
- MockRDAT V1: `0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E`
- Base Bridge: `0xb7d6f8eadfD4415cb27686959f010771FE94561b`

### Base Mainnet (Chain ID: 8453)
- Base Bridge: `TBD after deployment`

---

**Last Updated**: December 2024
**Version**: 1.0.0
**Next Update**: After testnet deployment