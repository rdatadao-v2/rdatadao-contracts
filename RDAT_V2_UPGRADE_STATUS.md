# RDAT V2 Upgrade - 30M RDAT Recovery

## Status: ✅ Deployment Complete - Ready for Multisig Execution

### Deployed Contracts

- **V2 Implementation**: `0xf73c6216d7d6218d722968e170cfff6654a8936c` ✅
  - Deployed to Vana mainnet (Chain 1480)
  - Contains `rescueBrokenBridgeFunds()` function
  - Deployment tx in broadcast logs

### Safe Transaction Files

All transaction files are in `/safe-transactions/`:

1. ✅ **step2-upgrade-to-v2.json** - Upgrade RDAT proxy to V2 implementation
2. ✅ **step3-rescue-30m-rdat.json** - Execute rescue function to transfer 30M RDAT

### Next Steps (Multisig Execution Required)

#### Step 1: Execute Upgrade Transaction

1. Open Safe at: https://safe.vana.org
2. Connect with wallet that has signing authority for: `0xe4F7Eca807C57311e715C3Ef483e72Fa8D5bCcDF`
3. Go to "Transaction Builder" app
4. Upload file: `/safe-transactions/step2-upgrade-to-v2.json`
5. Review transaction:
   - Target: `0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E` (RDAT Proxy)
   - Function: `upgradeToAndCall(address,bytes)`
   - New Implementation: `0xf73c6216d7d6218d722968e170cfff6654a8936c`
6. Execute and wait for confirmation

#### Step 2: Execute Rescue Transaction

1. After upgrade is confirmed, return to Safe Transaction Builder
2. Upload file: `/safe-transactions/step3-rescue-30m-rdat.json`
3. Review transaction:
   - Target: `0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E` (RDAT Proxy)
   - Function: `rescueBrokenBridgeFunds()`
4. Execute and wait for confirmation

#### Step 3: Verify Results

Run these commands to verify the 30M RDAT transfer:

```bash
# Check old bridge balance (should be 0)
cast call 0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E \
  "balanceOf(address)" 0x9d4aB2d3fb25D414dba1d9D22200356b5984D35E \
  --rpc-url https://rpc.vana.org

# Check new bridge balance (should be 30M = 30000000000000000000000000)
cast call 0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E \
  "balanceOf(address)" 0xEb0c43d5987de0672A22e350930F615Af646e28c \
  --rpc-url https://rpc.vana.org

# Verify rescue was executed
cast call 0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E \
  "isRescueExecuted()" \
  --rpc-url https://rpc.vana.org
```

### Contract Addresses Reference

- **RDAT Proxy**: `0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E`
- **V2 Implementation**: `0xf73c6216d7d6218d722968e170cfff6654a8936c`
- **Vana Multisig**: `0xe4F7Eca807C57311e715C3Ef483e72Fa8D5bCcDF`
- **Old Bridge** (broken): `0x9d4aB2d3fb25D414dba1d9D22200356b5984D35E`
- **New Bridge** (destination): `0xEb0c43d5987de0672A22e350930F615Af646e28c`

### How the Rescue Works

1. **Upgrade Mechanism**: UUPS upgrade pattern via `upgradeToAndCall()`
2. **Rescue Function**: Uses internal `_transfer()` to move tokens from old bridge
3. **Security**: Hard-coded addresses, one-time use only, transparent on-chain event
4. **Result**: 30M RDAT moved from broken bridge to new bridge, ready for user claims

### Timeline

- ✅ **Completed**: V2 implementation deployed
- ✅ **Completed**: Safe transaction files generated
- 🔄 **Next**: Execute upgrade via multisig
- 🔄 **Next**: Execute rescue via multisig
- 🔄 **Next**: Verify 30M RDAT transferred

---

**Documentation**: See `/safe-transactions/README.md` for detailed instructions
