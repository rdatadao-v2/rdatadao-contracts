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
  - [ ] StakingManager.sol (immutable core staking logic)
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
STAKING_NOTIFIER_ROLE -> StakingManager (on RewardsManager)
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