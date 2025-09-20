# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

r/datadao V2 smart contracts implementing cross-chain migration from Base to Vana blockchain with expanded tokenomics (30M → 100M fixed supply). Architecture uses hybrid approach: UUPS upgradeable RDAT token + non-upgradeable staking for optimal security/flexibility balance.

**Current Status**: MAINNET LIVE ✅ | 382/382 tests passing (100%)
**Deployment Status**: Vana mainnet (DLP ID: 40) + Base mainnet migration bridge active
**Audit Status**: Hashlock audit complete with all HIGH/MEDIUM/LOW findings remediated

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
ADMIN_ADDRESS=$VANA_MULTISIG_ADDRESS \
forge script script/DeployRDATUpgradeableProduction.s.sol --rpc-url $VANA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY --verify --with-gas-price 50000000000

# Deploy RDATDataDAO for DLP
forge script script/DeployRDATDataDAO.s.sol --rpc-url $VANA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY --with-gas-price 50000000000

# Register DLP (requires 1 VANA fee)
RDAT_DATA_DAO_ADDRESS=<dao_address> RDAT_TOKEN_ADDRESS=<token_address> TREASURY_ADDRESS=$VANA_MULTISIG_ADDRESS ADMIN_ADDRESS=$VANA_MULTISIG_ADDRESS \
forge script script/RegisterDLP.s.sol --rpc-url $VANA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY --with-gas-price 50000000000

# Base migration bridge
forge script script/DeployBaseMigrationMainnet.s.sol --rpc-url $BASE_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY --with-gas-price 1000000000

# Recover remaining funds after deployment
forge script script/RecoverFunds.s.sol --rpc-url <network_rpc> --broadcast --private-key $DEPLOYER_PRIVATE_KEY
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

**Mainnet (LIVE)**:
- Vana (1480):
  - RDAT Token: `0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E`
  - Treasury: `0x77D2713972af12F1E3EF39b5395bfD65C862367C`
  - Migration Bridge: `0x9d4aB2d3fb25D414dba1d9D22200356b5984D35E`
  - RDATDataDAO: `0xBbB0B59163b850dDC5139e98118774557c5d9F92`
  - DLP ID: 40
- Base (8453):
  - RDAT V1: `0x4498cd8Ba045E00673402353f5a4347562707e7D`
  - Migration Bridge: `0xa4435b45035a483d364de83B9494BDEFA8322626`

**Multisig Wallets**:
- Vana Multisig: `0xe4F7Eca807C57311e715C3Ef483e72Fa8D5bCcDF` (mainnet)
- Base Multisig: `0x90013583c66D2bf16327cB5Bc4a647AcceCF4B9A` (mainnet)
- Vana Testnet Multisig: `0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319`

**Validators** (2/3 required for migration):
- `0xd36B49f2DB6aA708Ce7245e8ab2453C6DfFc9d6f` (Angela)
- `0xC9Af4E56741f255743e8f4877d4cfa9971E910C2` (monkfenix.eth)
- `0x08Cc5ed1bA3C95AA741f8AaEf631f716b037444b` (Base multisig)

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
5. Deploy RDATDataDAO contract
6. Register DLP with Vana (costs 1 VANA fee, mainnet ID: 40)

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

# Migration validators (2/3 required for signatures)
VALIDATOR_1=0xd36B49f2DB6aA708Ce7245e8ab2453C6DfFc9d6f  # Angela
VALIDATOR_2=0xC9Af4E56741f255743e8f4877d4cfa9971E910C2  # monkfenix.eth
VALIDATOR_3_MAINNET=0x08Cc5ed1bA3C95AA741f8AaEf631f716b037444b  # Base multisig
VALIDATOR_3_TESTNET=0xdc096Bc0e5d7aB53C7Bd3cbb72B092d1054E393e  # Testnet validator

# Multisig addresses
VANA_MULTISIG_ADDRESS=0xe4F7Eca807C57311e715C3Ef483e72Fa8D5bCcDF  # Mainnet
BASE_MULTISIG_ADDRESS=0x90013583c66D2bf16327cB5Bc4a647AcceCF4B9A  # Mainnet

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
- `QUICK_REFERENCE.md` - All mainnet addresses and key information
- `FRONTEND_INTEGRATION_GUIDE_V2.md` - Complete frontend integration guide
- `docs/ADMIN_FEATURES_GUIDE.md` - Admin panel and multisig features
- `DEPLOYMENT_LOG.md` - Mainnet deployment details and costs
- `docs/AUDIT_REMEDIATION_SUMMARY.md` - All audit findings and fixes
- `deployments/mainnet-2025-09-20.json` - Mainnet deployment addresses

## Contract Verification & Interaction

### Read contract state
```shell
# Check token balance
cast call 0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E "balanceOf(address)" <address> --rpc-url https://rpc.vana.org

# Check DLP registration
cast call 0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E "dlpId()" --rpc-url https://rpc.vana.org

# Check migration status
cast call 0x9d4aB2d3fb25D414dba1d9D22200356b5984D35E "totalMigrated()" --rpc-url https://rpc.vana.org
```

### Generate ABIs
```shell
forge inspect RDATUpgradeable abi > abi/RDATUpgradeable.json
forge inspect TreasuryWallet abi > abi/TreasuryWallet.json
forge inspect VanaMigrationBridge abi > abi/VanaMigrationBridge.json
forge inspect BaseMigrationBridge abi > abi/BaseMigrationBridge.json
forge inspect RDATDataDAO abi > abi/RDATDataDAO.json
```