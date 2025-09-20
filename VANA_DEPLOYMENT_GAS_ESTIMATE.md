# Vana Network Deployment Gas Estimates

## Executive Summary

**Total VANA Needed: ~2.0-2.5 VANA**
- Contract Deployment: 0.5-1.5 VANA (depending on gas prices)
- DLP Registration: 1.0 VANA (fixed fee)
- Safety Buffer: 0.5 VANA

**Current Balance: 0.099 VANA ❌ INSUFFICIENT**
**Need to Add: ~2 VANA**

## Detailed Contract Deployment Costs

### Contracts to Deploy on Vana

| Contract | Estimated Gas | Purpose |
|----------|---------------|---------|
| CREATE2Factory | 200,000 | Deterministic addresses |
| RDATUpgradeable | 3,616,200 | Main token (UUPS) |
| TreasuryWallet | 2,900,000 | 70M token vault |
| VanaMigrationBridge | 2,400,000 | 30M migration pool |
| StakingPositions | 3,200,000 | NFT staking system |
| vRDAT | 1,600,000 | Governance token |
| EmergencyPause | 800,000 | Shared emergency system |
| RevenueCollector | 1,200,000 | Fee distribution |
| RewardsManager | 2,000,000 | Reward orchestration |
| RDATDataDAO | 1,600,000 | DLP implementation |
| ProofOfContribution | 800,000 | Kismet stub |
| Proxy Deployments (3x) | 1,200,000 | UUPS proxies |
| **TOTAL** | **~21,916,200** | **Full system** |

### Cost by Gas Price

| Gas Price | Deployment Cost | Network Condition | Probability |
|-----------|-----------------|-------------------|-------------|
| 10 gwei | 0.22 VANA | Very Low | 10% |
| 20 gwei | 0.44 VANA | Low | 20% |
| **50 gwei** | **1.10 VANA** | **Normal** | **40%** |
| 100 gwei | 2.19 VANA | High | 20% |
| 200 gwei | 4.38 VANA | Very High | 8% |
| 500 gwei | 10.96 VANA | Congested | 2% |

## Total Deployment Budget

### Deployment Components

```
Contract Deployment:     0.5-1.5 VANA (expected ~1.1 VANA)
DLP Registration Fee:    1.0 VANA (fixed)
Transaction Fees:        0.1 VANA (multiple txs)
Safety Buffer:           0.4 VANA (for retries/issues)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TOTAL RECOMMENDED:       2.5 VANA
```

### Budget Scenarios

| Scenario | Gas Price | Total Cost | Description |
|----------|-----------|------------|-------------|
| **Best Case** | 10-20 gwei | 1.3-1.5 VANA | Off-peak deployment |
| **Expected** | 50 gwei | 2.1 VANA | Normal conditions |
| **Safe** | 100 gwei | 2.5-3.0 VANA | High gas buffer |
| **Worst Case** | 200+ gwei | 5+ VANA | Network congestion |

## Deployment Strategy to Minimize Costs

### 1. Deploy During Low Activity
- Monitor Vana network gas prices
- Deploy during off-peak hours (typically weekends, early UTC morning)
- Target 20-30 gwei gas prices

### 2. Batch Optimization
The deployment script already optimizes by:
- Using CREATE2 for deterministic addresses
- Deploying in efficient order
- Minimizing cross-contract calls

### 3. Phased Deployment (If Needed)
If gas is high, deploy in phases:

**Phase 1: Core (1.0 VANA)**
- RDATUpgradeable
- TreasuryWallet
- VanaMigrationBridge

**Phase 2: DLP (1.0 VANA)**
- RDATDataDAO
- Register with Vana

**Phase 3: Staking (0.5 VANA)**
- StakingPositions
- vRDAT
- RewardsManager

## Current Funding Status

```bash
Deployer: 0x58eCB94e6F5e6521228316b55c465ad2A2938FbB

Current Balances:
├── Vana: 0.099 VANA  ❌ INSUFFICIENT
└── Base: 0.00499 ETH  ✅ SUFFICIENT

Required:
├── Vana: 2.5 VANA (2.0 minimum, 2.5 recommended)
└── Base: 0 ETH (current balance sufficient)

TO FUND:
Send 2.5 VANA to 0x58eCB94e6F5e6521228316b55c465ad2A2938FbB
```

## Gas Price Monitoring

### Check Current Gas Prices
```bash
# Check Vana network gas price
cast gas-price --rpc-url https://rpc.vana.org

# Monitor mempool
cast block --rpc-url https://rpc.vana.org latest
```

### Deployment Commands with Gas Control

```bash
# Deploy with specific gas price (e.g., 30 gwei)
ADMIN_ADDRESS=$VANA_MULTISIG_ADDRESS \
forge script script/DeployRDATUpgradeableProduction.s.sol \
  --rpc-url $VANA_RPC_URL \
  --broadcast \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --with-gas-price 30000000000 \  # 30 gwei in wei
  --verify

# Or use priority fee for EIP-1559
ADMIN_ADDRESS=$VANA_MULTISIG_ADDRESS \
forge script script/DeployRDATUpgradeableProduction.s.sol \
  --rpc-url $VANA_RPC_URL \
  --broadcast \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --priority-gas-price 2000000000 \  # 2 gwei priority
  --verify
```

## Comparison with Other Networks

| Network | Full Deployment | At Normal Gas | USD Estimate |
|---------|----------------|---------------|--------------|
| **Vana** | ~22M gas | 2.1 VANA | ~$20-40 |
| **Base** | ~1.1M gas | 0.0001 ETH | ~$0.40 |
| Ethereum | ~22M gas | 0.44 ETH | ~$1,500 |
| Polygon | ~22M gas | 0.022 MATIC | ~$0.02 |
| Arbitrum | ~22M gas | 0.0022 ETH | ~$7 |

## Risk Mitigation

### If Deployment Fails
1. **Insufficient Gas**: Increase gas limit by 20%
2. **Out of VANA**: Can resume deployment (contracts track state)
3. **Contract Too Large**: Already optimized, shouldn't be issue
4. **Network Congestion**: Wait for lower gas prices

### Emergency Funding
If you run out of VANA mid-deployment:
1. Note the last successful contract address
2. Fund the wallet
3. Resume from next contract in sequence
4. Update addresses in deployment record

## Recommendations

1. **Fund with 2.5 VANA** for safety margin
2. **Monitor gas prices** before starting
3. **Run dry-run first** to verify everything
4. **Deploy during low activity** (save 50-70% on gas)
5. **Keep deployment logs** for troubleshooting

## Summary

- **Minimum Required**: 1.5 VANA (risky, no buffer)
- **Recommended**: 2.0 VANA (reasonable buffer)
- **Safe**: 2.5 VANA (comfortable margin)
- **Current Gap**: Need to add ~2.0-2.5 VANA

The deployment will mint tokens automatically:
- 70M RDAT → Treasury (Vana multisig)
- 30M RDAT → Migration Bridge
- No additional transactions needed for distribution

---

*Last Updated: December 2024*
*Note: VANA price estimates based on typical L1 gas economics*