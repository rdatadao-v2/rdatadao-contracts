# 🚀 MAINNET DEPLOYMENT LOG

**Start Time**: September 20, 2025 - 15:50 AEST
**End Time**: September 20, 2025 - 16:10 AEST
**Deployer**: 0x58eCB94e6F5e6521228316b55c465ad2A2938FbB
**Status**: ✅ DEPLOYMENT COMPLETE

---

## PHASE 1: VANA MAINNET DEPLOYMENT ✅ COMPLETE

### Pre-Deployment Status
- Wallet Balance: 2.199 VANA ✅
- Gas Price: 50 gwei ✅

### Deployment Transaction
- Transaction Hash: 0x0e8e34c03e037fb62b388e965e92e23c6ac1e693a093e16e0e962a8ad54c34f5
- Gas Used: 0.64038425 VANA
- Status: SUCCESS ✅

### Deployment Command
```bash
source .env
ADMIN_ADDRESS=$VANA_MULTISIG_ADDRESS \
forge script script/DeployRDATUpgradeableProduction.s.sol \
  --rpc-url $VANA_RPC_URL \
  --broadcast \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --verify \
  --with-gas-price 50000000000
```

### Deployment Progress
✅ Completed at 15:55 AEST

---

## Deployed Addresses

### Vana Mainnet (Chain 1480)
- RDAT Token (Proxy): 0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E
- RDAT Token (Implementation): 0xaA77d23Df97C0693308B9A6560d50d376794C8f5
- TreasuryWallet (Proxy): 0x77D2713972af12F1E3EF39b5395bfD65C862367C
- TreasuryWallet (Implementation): 0xb8E3f2A01819f2A66b1667DB271568AD2f7BD9Be
- VanaMigrationBridge: 0x9d4aB2d3fb25D414dba1d9D22200356b5984D35E
- CREATE2Factory: 0xa4435b45035a483d364de83B9494BDEFA8322626
- RDATDataDAO: 0xBbB0B59163b850dDC5139e98118774557c5d9F92

### DLP Registration ✅ COMPLETE
- DLP ID: 40
- Registration TX: Success
- Registration Fee Paid: 1 VANA

### Base Mainnet (Chain 8453)
- RDAT V1 (Existing): 0x4498cd8Ba045E00673402353f5a4347562707e7D
- BaseMigrationBridge: 0xa4435b45035a483d364de83B9494BDEFA8322626

---

## PHASE 2: BASE MAINNET DEPLOYMENT ✅ COMPLETE

### Deployment Details
- Gas Price: 1 gwei
- Gas Used: 0.001441112 ETH
- Base Migration Bridge: 0xa4435b45035a483d364de83B9494BDEFA8322626
- Admin: 0x90013583c66D2bf16327cB5Bc4a647AcceCF4B9A

---

## 🎉 DEPLOYMENT SUMMARY

### Total Cost
- **Vana**: 1.64038425 VANA (0.64 deployment + 1.0 DLP registration)
- **Base**: 0.001441112 ETH

### Key Addresses for Frontend Integration
```javascript
const MAINNET_CONFIG = {
  vana: {
    chainId: 1480,
    rpcUrl: 'https://rpc.vana.org',
    contracts: {
      rdatToken: '0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E',
      treasury: '0x77D2713972af12F1E3EF39b5395bfD65C862367C',
      migrationBridge: '0x9d4aB2d3fb25D414dba1d9D22200356b5984D35E',
      rdatDataDAO: '0xBbB0B59163b850dDC5139e98118774557c5d9F92',
      dlpId: 40
    }
  },
  base: {
    chainId: 8453,
    rpcUrl: 'https://mainnet.base.org',
    contracts: {
      rdatV1: '0x4498cd8Ba045E00673402353f5a4347562707e7D',
      migrationBridge: '0xa4435b45035a483d364de83B9494BDEFA8322626'
    }
  }
};
```

---