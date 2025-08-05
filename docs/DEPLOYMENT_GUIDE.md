# 🚀 RDAT V2 Beta Deployment Guide

**Version**: 1.1 (Updated with 7 Contracts)  
**Sprint**: August 5-18, 2025  
**Target Chains**: Vana (Primary), Base (Migration Only)  
**Contract Count**: 7 Core Contracts (expanded from 5)

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
- [ ] All 7 contracts compiled successfully:
  - [ ] RDAT.sol (with reentrancy guards)
  - [ ] vRDAT.sol (with quadratic voting)
  - [ ] Staking.sol
  - [ ] MigrationBridge.sol
  - [ ] EmergencyPause.sol
  - [ ] RevenueCollector.sol (NEW)
  - [ ] ProofOfContribution.sol (NEW)
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

## 📦 Deployment Order (7 Contracts)

### Contract Dependencies
1. **EmergencyPause** (no dependencies)
2. **RDAT** (depends on treasury address)
3. **vRDAT** (no dependencies)
4. **ProofOfContribution** (no dependencies)
5. **RevenueCollector** (depends on RDAT and treasury)
6. **Staking** (depends on RDAT and vRDAT)
7. **MigrationBridge** (depends on RDAT)

### Phase 1: Testnet (Days 3-4)

1. **Deploy to Vana Moksha**
   ```bash
   export TREASURY_ADDRESS=0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319
   export MULTISIG_ADDRESS=0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319
   
   forge script script/DeployV2Beta.s.sol --rpc-url $VANA_MOKSHA_RPC_URL --broadcast
   ```

2. **Verify Contracts**
   ```bash
   forge verify-contract <RDAT_ADDRESS> src/RDAT.sol:RDAT --chain-id 14800
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

### Role Assignment (Updated for 7 Contracts)
```solidity
// Critical roles requiring multisig
DEFAULT_ADMIN_ROLE -> Gnosis Safe (all contracts)
PAUSER_ROLE -> Gnosis Safe + Emergency addresses
MINTER_ROLE -> MigrationBridge (for RDAT)
MINTER_ROLE -> Staking (for vRDAT)
BURNER_ROLE -> Governance contracts (for vRDAT quadratic voting)
VALIDATOR_ROLE -> 3 independent validators (MigrationBridge)
VALIDATOR_ROLE -> Oracle validators (ProofOfContribution)
REGISTRAR_ROLE -> Gnosis Safe (ProofOfContribution)
DISTRIBUTOR_ROLE -> Gnosis Safe + Automation (RevenueCollector)
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
**Last Updated**: Sprint Day 1