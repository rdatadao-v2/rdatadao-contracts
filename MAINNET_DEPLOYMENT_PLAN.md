# Mainnet Deployment Plan & Information Verification

**Date**: September 20, 2025
**Status**: Pre-Deployment Verification

## 🔍 Required Information Checklist

### Base Mainnet (Chain ID: 8453)
- [ ] **Existing RDAT V1 Address**: ❓ **MISSING - CRITICAL**
- [x] **Base Multisig**: `0x08Cc5ed1bA3C95AA741f8AaEf631f716b037444b` ✅
- [x] **Base RPC**: `https://mainnet.base.org` ✅

### Vana Mainnet (Chain ID: 1480)
- [x] **Vana Multisig**: `0xe4F7Eca807C57311e715C3Ef483e72Fa8D5bCcDF` ✅
- [ ] **Vana DLP Registry**: ❓ **NEED TO VERIFY**
- [x] **Vana RPC**: `https://rpc.vana.org` ✅
- [ ] **RDAT V2 Address**: Will be generated during deployment

### Deployment Accounts
- [x] **Deployer**: `0x58eCB94e6F5e6521228316b55c465ad2A2938FbB` ✅
- [x] **Deployer Balance (Vana)**: 2.199 VANA ✅
- [x] **Deployer Balance (Base)**: 0.015 ETH ✅

### Validators
- [x] **Validator 1 (Angela)**: `0xd36B49f2DB6aA708Ce7245e8ab2453C6DfFc9d6f` ✅
- [x] **Validator 2 (monkfenix.eth)**: `0xC9Af4E56741f255743e8f4877d4cfa9971E910C2` ✅
- [x] **Validator 3 (Base Mainnet)**: `0x08Cc5ed1bA3C95AA741f8AaEf631f716b037444b` ✅

## 🚨 CRITICAL MISSING INFORMATION

### 1. Base Mainnet RDAT V1 Address
**Status**: ❌ **MISSING - DEPLOYMENT BLOCKED**

We need the existing RDAT V1 token address on Base mainnet to configure the migration bridge. Without this, users cannot migrate their tokens.

**Action Required**:
- Confirm if RDAT V1 exists on Base mainnet
- If yes, provide the contract address
- If no, determine migration strategy

### 2. Vana DLP Registry Address
**Status**: ⚠️ **NEEDS VERIFICATION**

We need the official DLP Registry address on Vana mainnet. The testnet address was different from mainnet.

**Known Testnet Address**: `0xf63508A05478701b8A0868a6D0fC804AC32469Cc`
**Mainnet Address**: Need to verify with Vana documentation

## 📋 Deployment Sequence (PENDING INFO)

### Phase 0: Information Gathering [CURRENT]
```
1. ❌ Get Base mainnet RDAT V1 address
2. ❌ Verify Vana mainnet DLP Registry address
3. ❌ Confirm all multisig signers ready
```

### Phase 1: Vana Mainnet Deployment
```
1. Deploy CREATE2 Factory
2. Deploy Treasury Wallet (proxy)
3. Deploy Migration Bridge
4. Deploy RDAT Token (proxy)
   - Auto-mints 70M to Treasury
   - Auto-mints 30M to Bridge
5. Deploy Staking Positions
6. Deploy vRDAT
7. Deploy Emergency Pause
8. Deploy Revenue Collector
9. Deploy Rewards Manager
10. Deploy RDATDataDAO (DLP)
```

### Phase 2: DLP Registration
```
1. Register RDATDataDAO with Vana DLP Registry
2. Update RDAT token with DLP ID
3. Verify registration success
```

### Phase 3: Base Mainnet Deployment
```
1. Deploy BaseMigrationBridge
2. Configure with:
   - V1 RDAT address (MISSING!)
   - Vana bridge address
   - Validators
3. Test small migration
```

## 📊 Expected Contract Addresses

### To Be Generated on Vana:
```
RDATUpgradeable (Proxy): TBD
RDATUpgradeable (Implementation): TBD
TreasuryWallet (Proxy): TBD
VanaMigrationBridge: TBD
StakingPositions: TBD
vRDAT: TBD
EmergencyPause: TBD
RevenueCollector: TBD
RewardsManager: TBD
RDATDataDAO: TBD
DLP_ID: TBD
```

### To Be Generated on Base:
```
BaseMigrationBridge: TBD
```

## 🛑 DEPLOYMENT BLOCKED

**Cannot proceed without:**
1. Base mainnet RDAT V1 contract address
2. Vana mainnet DLP Registry address confirmation

## 📝 Information Verification Commands

### Check for RDAT V1 on Base
```bash
# Search for potential RDAT contracts on Base
# Need to check with team or documentation
```

### Verify Vana DLP Registry
```bash
# Check if testnet registry exists on mainnet
cast code 0xf63508A05478701b8A0868a6D0fC804AC32469Cc --rpc-url https://rpc.vana.org

# If empty, need to find correct address from Vana docs
```

## 🔄 Next Steps

1. **IMMEDIATE**: Get missing information
   - Base RDAT V1 address
   - Vana DLP Registry address

2. **THEN**: Update deployment scripts
   - Configure BaseMigrationBridge with V1 address
   - Update DLP registration with correct registry

3. **FINALLY**: Run full simulation
   - Test with actual mainnet parameters
   - Verify all configurations

## 📞 Questions to Answer

1. **Does RDAT V1 exist on Base mainnet?**
   - If yes: What's the address?
   - If no: How do we handle migration?

2. **What's the Vana mainnet DLP Registry?**
   - Is it the same as testnet?
   - Do we need different registration process?

3. **Are all multisig signers ready?**
   - Vana multisig operational?
   - Base multisig operational?

---

**Status**: ⏸️ **DEPLOYMENT ON HOLD**
**Reason**: Missing critical information
**Action**: Awaiting Base RDAT V1 address and Vana DLP Registry confirmation