# Safe Multisig Transactions

This directory contains JSON transaction files for Safe multisig execution.

## RDAT V2 Upgrade - 30M RDAT Recovery

### Overview
Upgrade RDAT token contract to V2 to recover 30M RDAT from broken VanaMigrationBridge.

### Steps

#### 1. Deploy V2 Implementation
First, deploy the RDATUpgradeableV2 implementation contract:

```bash
cd /Users/nissan/code/rdatadao-contracts
forge script script/UpgradeRDATToV2.s.sol:UpgradeRDATToV2 \
  --rpc-url https://rpc.vana.org \
  --private-key <DEPLOYER_KEY> \
  --broadcast \
  --verify
```

This will output:
- V2 Implementation address
- Upgrade call data
- Rescue call data

#### 2. Execute Upgrade Transaction
Use the V2 implementation address from step 1 to create the upgrade transaction:

```json
{
  "to": "0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E",
  "value": "0",
  "data": "<upgrade_call_data_from_step_1>",
  "operation": 0
}
```

Load this in Safe Transaction Builder and execute from multisig: `0xe4F7Eca807C57311e715C3Ef483e72Fa8D5bCcDF`

#### 3. Execute Rescue Transaction
After upgrade is confirmed, execute the rescue function:

```json
{
  "to": "0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E",
  "value": "0",
  "data": "0x8c0d34e8",
  "operation": 0
}
```

This calls `rescueBrokenBridgeFunds()` which transfers 30M RDAT from old bridge to new bridge.

#### 4. Verify Result
Check new bridge balance:

```bash
cast call 0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E \
  "balanceOf(address)" 0xEb0c43d5987de0672A22e350930F615Af646e28c \
  --rpc-url https://rpc.vana.org
```

Should return: `30000000000000000000000000` (30M RDAT)

### Contract Addresses

- **RDAT Proxy**: `0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E`
- **Vana Multisig**: `0xe4F7Eca807C57311e715C3Ef483e72Fa8D5bCcDF`
- **Old Bridge** (source): `0x9d4aB2d3fb25D414dba1d9D22200356b5984D35E`
- **New Bridge** (destination): `0xEb0c43d5987de0672A22e350930F615Af646e28c`

### Function Signatures

- `upgradeToAndCall(address,bytes)`: `0x4f1ef286`
- `rescueBrokenBridgeFunds()`: `0x8c0d34e8`
