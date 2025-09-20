# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

r/datadao V2 smart contracts implementing cross-chain migration from Base to Vana blockchain with expanded tokenomics (30M → 100M fixed supply). Architecture uses hybrid approach: UUPS upgradeable RDAT token + non-upgradeable staking for optimal security/flexibility balance.

**Current Status**: 382/382 tests passing (100%) ✅
**Audit Status**: Hashlock preliminary audit complete with all HIGH/MEDIUM/LOW findings remediated

## Core Commands

### Building & Testing
```shell
# Build contracts
forge build

# Run all tests
forge test

# Run specific test
forge test --match-test testStaking
forge test --match-contract TreasuryWalletTest

# Test with verbosity (-vvv for stack traces, -vvvv for execution traces)
forge test -vvv

# Coverage report
forge coverage

# Gas optimization
forge snapshot

# Run with gas reporting
forge test --gas-report

# Run security tests
forge test --match-path test/security/*

# Run integration tests
forge test --match-path test/integration/*

# Run audit remediation tests
forge test --match-path test/audit/*

# Format check
forge fmt --check

# Format fix
forge fmt
```

### Local Development
```shell
# Multi-chain local environment (Base + Vana)
./script/anvil-multichain.sh start
./script/anvil-multichain.sh status
./script/anvil-multichain.sh stop

# Deploy full system to local
forge script script/local/DeployFullSystemLocal.s.sol --rpc-url http://localhost:8546 --broadcast --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

### Testnet Operations
```shell
# Check deployment readiness
forge script script/CheckDeploymentReadiness.s.sol --rpc-url $VANA_MOKSHA_RPC_URL --sender $DEPLOYER_ADDRESS

# Deploy with dry run first (always run before broadcast)
TREASURY_ADDRESS=$VANA_MULTISIG_ADDRESS ADMIN_ADDRESS=$VANA_MULTISIG_ADDRESS \
forge script script/DeployRDATUpgradeableSimple.s.sol --rpc-url $VANA_MOKSHA_RPC_URL --sig "dryRun()"

# Deploy with broadcast
TREASURY_ADDRESS=$VANA_MULTISIG_ADDRESS ADMIN_ADDRESS=$VANA_MULTISIG_ADDRESS \
forge script script/DeployRDATUpgradeableSimple.s.sol --rpc-url $VANA_MOKSHA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY

# MockRDAT V1 Faucet (for migration testing on Base Sepolia)
# Mint to deployer for distribution
forge script script/MockRDATFaucet.s.sol --sig "mintToDeployer(uint256)" 10000 --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY

# Distribute to testers
forge script script/MockRDATFaucet.s.sol --sig "distributeToTester(address,uint256)" TESTER_ADDRESS 100 --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY
```

### Production Deployment
```shell
# Mainnet deployment (Vana)
TREASURY_ADDRESS=$VANA_MULTISIG_ADDRESS ADMIN_ADDRESS=$VANA_MULTISIG_ADDRESS \
forge script script/DeployRDATUpgradeableProduction.s.sol --rpc-url $VANA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY --verify

# Base migration bridge
forge script script/DeployBaseMigration.s.sol --rpc-url $BASE_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY --verify

# Register DLP (post-deployment)
RDAT_TOKEN_ADDRESS=<deployed_address> \
forge script script/RegisterDLP.s.sol --rpc-url $VANA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY
```

## High-Level Architecture

### Token Distribution Model
```
Total Supply: 100M RDAT (fixed, immutable)
├── Treasury: 70M (70%)
│   ├── Team: 10M (6mo cliff + 18mo linear vesting)
│   ├── Development: 20M (DAO-controlled)
│   ├── Community Rewards: 30M (Phase 3 gated)
│   └── Reserve: 10M (Emergency/partnerships)
└── Migration Bridge: 30M (30%)
    └── V1 Holders: 1:1 exchange ratio
```

### Contract Interaction Flow
1. **Token Creation**: RDATUpgradeable deployed via CREATE2 with predetermined address
2. **Initial Distribution**: Constructor mints 70M to Treasury, 30M to Bridge (one-time only)
3. **Migration**: Users burn V1 tokens on Base → validators sign → receive V2 on Vana
4. **Staking**: Users lock RDAT → receive NFT position + vRDAT governance tokens
5. **Governance**: vRDAT holders vote → timelock delay → execute via treasury
6. **Rewards**: RewardsManager orchestrates modular reward programs from pre-allocated pools

### Security Architecture
- **Access Control**: Role-based with multi-sig requirements
  - DEFAULT_ADMIN_ROLE: 3/5 multisig (critical operations)
  - PAUSER_ROLE: 2/5 multisig (emergency response)
  - TREASURY_ROLE: Treasury contract only (penalty withdrawals)
- **Timelock**: 48-hour delay via OpenZeppelin TimelockController
- **Emergency Pause**: 72-hour auto-expiry prevents permanent freeze
- **Migration Security**: 6-hour challenge period, 7-day admin override
- **Fixed Supply**: No minting post-deployment (mint() always reverts)

### Key Contract Addresses

**Testnets (Active)**:
- Vana Moksha: See `deployments/vana-moksha-testnet.json`
- Base Sepolia: See `deployments/base-sepolia-testnet.json`

**Key Wallets**:
- Deployer: `0x58eCB94e6F5e6521228316b55c465ad2A2938FbB`
- Vana Multisig: `0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319`
- Base Multisig: `0x90013583c66D2bf16327cB5Bc4a647AcceCF4B9A`

## Critical Implementation Details

### Fixed Supply Enforcement
- Total supply set in constructor: 100M RDAT
- Minting disabled: `mint()` function exists but always reverts
- All rewards from pre-allocated treasury pools, not inflation

### Audit Remediations Implemented
- **H-01**: Added `withdrawPenalties()` for trapped fund recovery
- **H-02**: Challenge period enforcement + admin override after 7 days
- **M-01**: V1 tokens burned to 0xdEaD address
- **M-02**: Fixed NFT transfer blocking condition
- **M-03**: Internal poolId generation prevents front-running
- **L-04/L-05**: TimelockController and comprehensive reward accounting

### Deployment Process
1. Calculate RDAT address via CREATE2
2. Deploy TreasuryWallet with predicted RDAT address
3. Deploy MigrationBridge with predicted RDAT address
4. Deploy RDATUpgradeable via CREATE2 (mints to Treasury + Bridge)
5. Register DLP with Vana (manual process, ID: 155 on testnet)

## Environment Configuration

Required environment variables:
```shell
# RPC URLs
VANA_RPC_URL=https://rpc.vana.org
VANA_MOKSHA_RPC_URL=https://rpc.moksha.vana.org
BASE_RPC_URL=https://mainnet.base.org
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org

# Deployment
DEPLOYER_PRIVATE_KEY=<your_key>
TREASURY_ADDRESS=<multisig_address>
ADMIN_ADDRESS=<multisig_address>

# Migration validators (3 required)
VALIDATOR_1=<address>
VALIDATOR_2=<address>
VALIDATOR_3=<address>

# API Keys (for verification)
BASESCAN_API_KEY=<key>
VANASCAN_API_KEY=<key>
```

## GitHub Actions CI

Workflow (`.github/workflows/test.yml`) runs on every push/PR:
1. `forge fmt --check` - Format verification
2. `forge build --sizes` - Build with size reporting
3. `forge test -vvv` - Run all 382 tests with verbosity

## Documentation Structure

Key documentation files:
- `DEPLOYMENT_STATUS.md` - Current deployment status and addresses
- `FRONTEND_INTEGRATION_GUIDE.md` - Frontend integration instructions
- `AUDIT_README.md` - Comprehensive audit submission guide
- `docs/AUDIT_REMEDIATION_SUMMARY.md` - All audit findings and fixes
- `docs/02_SPECIFICATIONS.md` - Complete technical specifications (175KB)