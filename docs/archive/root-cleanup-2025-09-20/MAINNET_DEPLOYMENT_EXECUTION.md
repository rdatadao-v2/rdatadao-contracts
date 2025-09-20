# 🚀 Mainnet Deployment Execution Plan

**Date**: September 20, 2025
**Status**: ✅ READY TO EXECUTE

## 📋 Complete Information Verified

### Base Mainnet (Chain ID: 8453)
- ✅ **RDAT V1 Address**: `0x4498cd8Ba045E00673402353f5a4347562707e7D` (existing token to migrate)
- ✅ **Base Multisig**: `0x08Cc5ed1bA3C95AA741f8AaEf631f716b037444b`
- ✅ **Base RPC**: `https://mainnet.base.org`

### Vana Mainnet (Chain ID: 1480)
- ✅ **Vana Multisig**: `0xe4F7Eca807C57311e715C3Ef483e72Fa8D5bCcDF`
- ✅ **Vana DLP Registry**: `0x4D59880a924526d1dD33260552Ff4328b1E18a43`
- ✅ **Vana RPC**: `https://rpc.vana.org`

### Deployment Configuration
- ✅ **Deployer**: `0x58eCB94e6F5e6521228316b55c465ad2A2938FbB`
- ✅ **Balance (Vana)**: 2.199 VANA (sufficient)
- ✅ **Balance (Base)**: 0.015 ETH (sufficient)

### Validators (for Migration Bridge)
- ✅ **Validator 1**: `0xd36B49f2DB6aA708Ce7245e8ab2453C6DfFc9d6f` (Angela)
- ✅ **Validator 2**: `0xC9Af4E56741f255743e8f4877d4cfa9971E910C2` (monkfenix.eth)
- ✅ **Validator 3**: `0x08Cc5ed1bA3C95AA741f8AaEf631f716b037444b` (Base multisig)

## 🎯 Deployment Strategy

This deployment creates:
1. **NEW RDAT V2** on Vana (100M supply)
2. **Migration Bridge** on Base to burn old RDAT V1 tokens
3. **Migration Bridge** on Vana to mint new RDAT V2 tokens

## 📊 Token Migration Flow

```
User on Base                    Validators                    User on Vana
     │                               │                              │
     ├──[1. Approve Bridge]──────────►                              │
     ├──[2. Call migrate()]──────────►                              │
     │                               │                              │
     │   [V1 tokens burned to 0xdEaD]                              │
     │                               │                              │
     │                          [3. Sign proof]                     │
     │                               │                              │
     └────────────────────────────────────────[4. Claim V2]────────►
                                                                    │
                                                         [Receive RDAT V2]
```

## 🔐 Pre-Deployment Checklist

- [x] Wallet funding verified (2.199 VANA, 0.015 ETH)
- [x] All addresses confirmed
- [x] Validators configured
- [x] Scripts tested on testnet
- [ ] Gas prices checked (<50 gwei recommended)
- [ ] Team on standby
- [ ] Communication channels open

## 📝 Deployment Execution Steps

### Step 1: Final Pre-Flight Check
```bash
# Verify environment
source .env
echo "=== Configuration Check ==="
echo "Deployer: $DEPLOYER_ADDRESS"
echo "Vana Multisig: $VANA_MULTISIG_ADDRESS"
echo "Base Multisig: $BASE_MULTISIG_ADDRESS"
echo "RDAT V1 on Base: 0x4498cd8Ba045E00673402353f5a4347562707e7D"

# Check gas prices
echo ""
echo "=== Gas Prices ==="
cast gas-price --rpc-url https://rpc.vana.org
cast gas-price --rpc-url https://mainnet.base.org
```

### Step 2: Deploy to Vana Mainnet
```bash
# Set admin address
export ADMIN_ADDRESS=$VANA_MULTISIG_ADDRESS

# Run deployment
forge script script/DeployRDATUpgradeableProduction.s.sol \
  --rpc-url $VANA_RPC_URL \
  --broadcast \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --verify \
  --slow \
  --with-gas-price 50000000000  # 50 gwei

# SAVE OUTPUT: Note all contract addresses!
```

### Step 3: Register DLP on Vana
```bash
# Set DLP contract addresses (from Step 2 output)
export RDAT_DATA_DAO_ADDRESS=<RDATDataDAO_address_from_deployment>
export RDAT_TOKEN_ADDRESS=<RDAT_proxy_address_from_deployment>

# Register with Vana DLP Registry (costs 1 VANA)
forge script script/RegisterDLP.s.sol \
  --rpc-url $VANA_RPC_URL \
  --broadcast \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --with-gas-price 50000000000

# SAVE OUTPUT: Note DLP ID!
```

### Step 4: Deploy Migration Bridge to Base
```bash
# Update script with V1 token address
cat > script/DeployBaseMigration.s.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script} from "forge-std/Script.sol";
import {BaseMigrationBridge} from "../src/BaseMigrationBridge.sol";

contract DeployBaseMigration is Script {
    address constant RDAT_V1 = 0x4498cd8Ba045E00673402353f5a4347562707e7D;

    function run() external returns (address) {
        address admin = vm.envAddress("BASE_MULTISIG_ADDRESS");

        vm.startBroadcast();

        BaseMigrationBridge bridge = new BaseMigrationBridge(
            RDAT_V1,
            admin
        );

        vm.stopBroadcast();

        return address(bridge);
    }
}
EOF

# Deploy bridge
forge script script/DeployBaseMigration.s.sol \
  --rpc-url $BASE_RPC_URL \
  --broadcast \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --verify \
  --slow

# SAVE OUTPUT: Note bridge address!
```

### Step 5: Document Deployed Addresses
```bash
# Create deployment record
cat > deployments/mainnet-$(date -I).json << EOF
{
  "deploymentDate": "$(date -I)",
  "vana": {
    "chainId": 1480,
    "contracts": {
      "RDATUpgradeable_Proxy": "<address>",
      "RDATUpgradeable_Implementation": "<address>",
      "TreasuryWallet": "<address>",
      "VanaMigrationBridge": "<address>",
      "StakingPositions": "<address>",
      "vRDAT": "<address>",
      "EmergencyPause": "<address>",
      "RevenueCollector": "<address>",
      "RewardsManager": "<address>",
      "RDATDataDAO": "<address>",
      "DLP_ID": "<id>"
    }
  },
  "base": {
    "chainId": 8453,
    "contracts": {
      "RDAT_V1": "0x4498cd8Ba045E00673402353f5a4347562707e7D",
      "BaseMigrationBridge": "<address>"
    }
  }
}
EOF
```

## 🔍 Post-Deployment Verification

### Verify Vana Deployment
```bash
# Check token supply
cast call <RDAT_PROXY> "totalSupply()" --rpc-url $VANA_RPC_URL

# Check treasury balance (should be 70M * 10^18)
cast call <RDAT_PROXY> "balanceOf(address)" <TREASURY_ADDRESS> --rpc-url $VANA_RPC_URL

# Check migration bridge balance (should be 30M * 10^18)
cast call <RDAT_PROXY> "balanceOf(address)" <VANA_BRIDGE> --rpc-url $VANA_RPC_URL

# Verify DLP registration
cast call 0x4D59880a924526d1dD33260552Ff4328b1E18a43 "dlpIds(address)" <RDAT_DATA_DAO> --rpc-url $VANA_RPC_URL
```

### Verify Base Deployment
```bash
# Check bridge configuration
cast call <BASE_BRIDGE> "v1Token()" --rpc-url $BASE_RPC_URL
# Should return: 0x4498cd8Ba045E00673402353f5a4347562707e7D

# Check validators
cast call <BASE_BRIDGE> "hasRole(bytes32,address)" \
  $(cast keccak "VALIDATOR_ROLE") \
  0xd36B49f2DB6aA708Ce7245e8ab2453C6DfFc9d6f \
  --rpc-url $BASE_RPC_URL
```

### Test Migration Flow
```bash
# Small test migration (if you have V1 tokens)
# 1. Approve bridge on Base
cast send 0x4498cd8Ba045E00673402353f5a4347562707e7D \
  "approve(address,uint256)" <BASE_BRIDGE> 1000000000000000000 \
  --rpc-url $BASE_RPC_URL \
  --private-key $TEST_KEY

# 2. Initiate migration
cast send <BASE_BRIDGE> "initiateMigration(uint256)" 1000000000000000000 \
  --rpc-url $BASE_RPC_URL \
  --private-key $TEST_KEY
```

## 📊 Expected Addresses Summary

### Frontend Integration Addresses
```javascript
// Production Mainnet Configuration
const config = {
  vana: {
    chainId: 1480,
    rpcUrl: 'https://rpc.vana.org',
    contracts: {
      rdatToken: '<TO_BE_FILLED>',         // Main RDAT V2 token
      treasury: '<TO_BE_FILLED>',          // Treasury wallet
      migrationBridge: '<TO_BE_FILLED>',   // Vana migration bridge
      stakingPositions: '<TO_BE_FILLED>',  // NFT staking
      vRDAT: '<TO_BE_FILLED>',            // Governance token
      rdatDataDAO: '<TO_BE_FILLED>',      // DLP contract
      dlpId: '<TO_BE_FILLED>'             // DLP registration ID
    }
  },
  base: {
    chainId: 8453,
    rpcUrl: 'https://mainnet.base.org',
    contracts: {
      rdatV1: '0x4498cd8Ba045E00673402353f5a4347562707e7D',  // Old token
      migrationBridge: '<TO_BE_FILLED>'                       // Base bridge
    }
  }
};
```

## ⚠️ Important Notes

1. **Save all addresses immediately** after each deployment step
2. **Verify contracts** on block explorers
3. **Test with small amounts** before announcing
4. **Keep deployment logs** for troubleshooting
5. **Update frontend config** with deployed addresses

## 🚨 Emergency Procedures

If deployment fails:
1. Note the last successful step
2. Check error messages
3. DO NOT PANIC - contracts are upgradeable
4. Contact team via Discord
5. Resume from failed step after fix

## 📞 Support During Deployment

- Technical Lead: Via Discord
- Validators: Ready to monitor
- Frontend Team: Standing by for addresses
- Community: Awaiting announcement

---

**Status**: ✅ READY TO EXECUTE
**Next Action**: Run Step 1 (Pre-Flight Check)