# 🚀 r/DataDAO Quick Reference Card

## Mainnet Deployment (September 20, 2025)

### 🔗 Contract Addresses

#### Vana Mainnet (1480)
```
RDAT Token:        0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E
Treasury:          0x77D2713972af12F1E3EF39b5395bfD65C862367C
Migration Bridge:  0x9d4aB2d3fb25D414dba1d9D22200356b5984D35E
RDATDataDAO:       0xBbB0B59163b850dDC5139e98118774557c5d9F92
DLP ID:            40
```

#### Base Mainnet (8453)
```
RDAT V1:           0x4498cd8Ba045E00673402353f5a4347562707e7D
Migration Bridge:  0xa4435b45035a483d364de83B9494BDEFA8322626
```

### 👛 Multisig Wallets
```
Vana Multisig:     0xe4F7Eca807C57311e715C3Ef483e72Fa8D5bCcDF
Base Multisig:     0x90013583c66D2bf16327cB5Bc4a647AcceCF4B9A
```

### 🔑 Validators (2/3 Required)
```
Angela:            0xd36B49f2DB6aA708Ce7245e8ab2453C6DfFc9d6f
monkfenix.eth:     0xC9Af4E56741f255743e8f4877d4cfa9971E910C2
Base Multisig:     0x08Cc5ed1bA3C95AA741f8AaEf631f716b037444b
```

### 📊 Token Distribution
```
Total Supply:      100,000,000 RDAT
Treasury:          70,000,000 RDAT (70%)
Migration Pool:    30,000,000 RDAT (30%)
```

### 🌐 Network Configuration

```javascript
// Vana Mainnet
const vana = {
  chainId: 1480,
  rpc: 'https://rpc.vana.org',
  explorer: 'https://vanascan.io'
}

// Base Mainnet
const base = {
  chainId: 8453,
  rpc: 'https://mainnet.base.org',
  explorer: 'https://basescan.org'
}
```

### 🧪 Testnet Addresses

#### Vana Moksha (14800)
```
RDAT Token:        0xEb0c43d5987de0672A22e350930F615Af646e28c
Treasury:          0x31C3e3F091FB2A25d4dac82474e7dc709adE754a
Admin Multisig:    0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319
```

#### Base Sepolia (84532)
```
Mock RDAT V1:      0xEb0c43d5987de0672A22e350930F615Af646e28c
Migration Bridge:  0xF73c6216d7D6218d722968e170Cfff6654A8936c
```

### 🔄 Migration Flow

1. **Base**: User approves V1 tokens
2. **Base**: User initiates migration
3. **Backend**: Collect 2/3 validator signatures
4. **Vana**: User claims V2 tokens with signatures
5. **Result**: 1:1 exchange (V1 burned, V2 minted)

### 📝 Key Contract Methods

```typescript
// Token Operations
balanceOf(address) → uint256
transfer(to, amount) → bool
approve(spender, amount) → bool

// Migration (Base)
initiateMigration(amount) → bytes32

// Migration (Vana)
processMigration(user, amount, id, signatures) → bool

// Treasury
executeDAOProposal(to, amount, reason)
withdrawPenalties() // Admin only

// DLP
dlpId() → 40
dlpRegistered() → true
```

### 🛠️ ABI Generation

```bash
forge inspect RDATUpgradeable abi > abi/RDAT.json
forge inspect TreasuryWallet abi > abi/Treasury.json
forge inspect VanaMigrationBridge abi > abi/VanaBridge.json
forge inspect BaseMigrationBridge abi > abi/BaseBridge.json
forge inspect RDATDataDAO abi > abi/DataDAO.json
```

### 🔐 Admin Roles

```
DEFAULT_ADMIN_ROLE: Full control
PAUSER_ROLE:        Emergency pause
UPGRADER_ROLE:      UUPS upgrades
TREASURY_ROLE:      Treasury ops
VALIDATOR_ROLE:     Sign migrations
```

### ⚠️ Important Notes

- **Fixed Supply**: 100M RDAT (no minting)
- **DLP ID 40**: Required for Vana rewards
- **2/3 Validators**: Required for migrations
- **UUPS Pattern**: Token & Treasury upgradeable
- **Emergency Pause**: 72-hour auto-expiry

### 📞 Support

- Docs: `/docs` folder
- Frontend Guide: `FRONTEND_INTEGRATION_GUIDE_V2.md`
- Admin Guide: `docs/ADMIN_FEATURES_GUIDE.md`
- Audit: `docs/audit/RDAT_V2_FINAL_AUDIT.pdf`

---
**Status**: ✅ MAINNET LIVE | **DLP**: ✅ REGISTERED | **Migration**: ✅ ACTIVE