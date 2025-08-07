# Cross-Chain Migration Testing Guide

## Overview
This guide explains how to test the V1 → V2 RDAT token migration from Base Sepolia to Vana Moksha testnet.

## Architecture
```
Base Sepolia (V1 Tokens)          →→→          Vana Moksha (V2 Tokens)
━━━━━━━━━━━━━━━━━━━━━━━━                       ━━━━━━━━━━━━━━━━━━━━━━━━
[V1 RDAT Token]                                [V2 RDAT Token]
     ↓                                              ↑
[Migration Bridge] ─── Emit Event ───→ [Oracle] ───┘
```

## Deployed Contracts

### Base Sepolia (Chain ID: 84532)
- **V1 RDAT Token (Mock)**: `0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E`
- **Migration Bridge**: `0xb7d6f8eadfD4415cb27686959f010771FE94561b`

### Vana Moksha (Chain ID: 14800)
- **V2 RDAT Token**: `0xEb0c43d5987de0672A22e350930F615Af646e28c`
- **Treasury (holds migration allocation)**: `0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319`

## Pre-funded Test Accounts

These accounts each have 1000 V1 RDAT tokens on Base Sepolia:

| Account | Address | V1 Balance |
|---------|---------|------------|
| Test 1 | `0x70997970C51812dc3A010C7d01b50e0d17dc79C8` | 1000 RDAT |
| Test 2 | `0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC` | 1000 RDAT |
| Test 3 | `0x90F79bf6EB2c4f870365E785982E1f101E93b906` | 1000 RDAT |

## Migration Process

### Step 1: Get Test ETH
Get Base Sepolia ETH from: https://www.alchemy.com/faucets/base-sepolia

### Step 2: Connect to Base Sepolia
```javascript
// Network Configuration
Network: Base Sepolia
RPC URL: https://sepolia.base.org
Chain ID: 84532
Currency: ETH
Explorer: https://sepolia.basescan.org
```

### Step 3: Approve Migration Bridge
Using one of the test accounts, approve the bridge to spend V1 tokens:

```javascript
// Connect to V1 Token Contract
const v1Token = "0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E"
const bridge = "0xb7d6f8eadfD4415cb27686959f010771FE94561b"
const amount = "1000000000000000000000" // 1000 tokens

// Call approve()
await v1Token.approve(bridge, amount)
```

### Step 4: Migrate Tokens
Call the migrate function on the bridge:

```javascript
// Call migrate()
await bridge.migrate(amount)

// This will:
// 1. Transfer V1 tokens from user to bridge
// 2. Lock them permanently
// 3. Emit MigrationInitiated event
```

### Step 5: Wait for Oracle Processing
The oracle service will:
1. Detect the MigrationInitiated event on Base Sepolia
2. Verify the migration details
3. Trigger V2 token distribution on Vana Moksha

**Note**: In testnet, this is currently a manual process. Contact the team for V2 distribution.

### Step 6: Receive V2 Tokens on Vana
Connect to Vana Moksha and check your V2 balance:

```javascript
// Network Configuration
Network: Vana Moksha
RPC URL: https://rpc.moksha.vana.org
Chain ID: 14800
Currency: VANA
Explorer: https://moksha.vanascan.io

// V2 Token Address
const v2Token = "0xEb0c43d5987de0672A22e350930F615Af646e28c"

// Check balance
await v2Token.balanceOf(yourAddress)
```

## Testing with Forge Scripts

### Check Migration Status
```bash
forge script script/TestMigration.s.sol \
  --rpc-url https://sepolia.base.org \
  -vv
```

### Check Specific User Migration
```bash
forge script script/TestMigration.s.sol \
  --sig "checkMigration(address)" \
  0x70997970C51812dc3A010C7d01b50e0d17dc79C8 \
  --rpc-url https://sepolia.base.org
```

## Using Etherscan/Basescan

### View Contracts
- V1 Token: https://sepolia.basescan.org/address/0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E
- Bridge: https://sepolia.basescan.org/address/0xb7d6f8eadfD4415cb27686959f010771FE94561b

### Interact with Contracts
1. Go to "Contract" → "Write Contract"
2. Connect your wallet
3. For V1 Token: Call `approve()`
4. For Bridge: Call `migrate()`

## Security Considerations

### What the Bridge Does
- ✅ Locks V1 tokens permanently (no burn function on V1)
- ✅ Emits verifiable events for oracle processing
- ✅ Tracks migration amounts per user
- ✅ Prevents double-spending

### What the Bridge Doesn't Do
- ❌ Does NOT mint V2 tokens (handled separately on Vana)
- ❌ Does NOT allow token recovery (migrations are final)
- ❌ Does NOT process cross-chain messages directly

## Common Issues

### "Insufficient Allowance"
**Solution**: Make sure to approve the bridge before migrating

### "Transfer Failed"
**Solution**: Check that you have enough V1 tokens

### "No V2 Tokens Received"
**Solution**: Oracle processing may take time. Contact team if > 1 hour.

## Important Notes

1. **Migrations are permanent** - V1 tokens cannot be recovered after migration
2. **1:1 exchange rate** - You receive the same amount of V2 tokens
3. **Gas fees required** - Need ETH on Base Sepolia for migration transaction
4. **Testnet only** - These contracts are for testing, not production

## Support

- Discord: Join #migration-help channel
- Documentation: https://docs.rdatadao.org/migration
- Team Contact: migration@rdatadao.org

## Migration Statistics

Check current migration stats:
```bash
cast call 0xb7d6f8eadfD4415cb27686959f010771FE94561b \
  "totalMigrated()" \
  --rpc-url https://sepolia.base.org
```

## Next Steps

After successful testnet migration:
1. Report any issues to the team
2. Help test edge cases
3. Prepare for mainnet migration (September 2024)

---

**Remember**: This is a testnet environment. Real token migration will occur on mainnet after audit completion.