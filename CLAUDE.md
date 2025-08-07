# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

r/datadao V2 smart contracts implementing cross-chain migration from Base to Vana blockchain with expanded tokenomics (30M → 100M fixed supply). Architecture uses hybrid approach: UUPS upgradeable RDAT token + non-upgradeable staking for optimal security/flexibility balance.

**Current Status**: 294/336 tests passing (87.5%), production-ready core contracts

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

# Test with verbosity (use -vvv for stack traces, -vvvv for execution traces)
forge test -vvv

# Coverage report
forge coverage

# Gas optimization
forge snapshot

# Run with gas reporting
forge test --gas-report
```

### Local Development
```shell
# Multi-chain local environment (Base + Vana)
./script/anvil-multichain.sh start
./script/anvil-multichain.sh status
./script/anvil-multichain.sh stop

# Deploy to local chains
./script/deploy.sh local-vana RDATUpgradeable
./script/deploy.sh local-base MigrationBridge

# Or deploy full system to local
forge script script/local/DeployFullSystemLocal.s.sol --rpc-url http://localhost:8546 --broadcast --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

### Deployment Scripts
```shell
# Check deployment readiness
forge script script/CheckDeploymentReadiness.s.sol --rpc-url $VANA_MOKSHA_RPC_URL --sender $DEPLOYER_ADDRESS

# Deploy with dry run first (always run this before broadcast)
TREASURY_ADDRESS=$VANA_MULTISIG_ADDRESS ADMIN_ADDRESS=$VANA_MULTISIG_ADDRESS DEPLOYER_ADDRESS=$DEPLOYER_ADDRESS \
forge script script/DeployRDATUpgradeableSimple.s.sol --rpc-url $VANA_MOKSHA_RPC_URL --sig "dryRun()"

# Deploy with broadcast
TREASURY_ADDRESS=$VANA_MULTISIG_ADDRESS ADMIN_ADDRESS=$VANA_MULTISIG_ADDRESS \
forge script script/DeployRDATUpgradeableSimple.s.sol --rpc-url $VANA_MOKSHA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY

# Vana-specific deployment
forge script script/vana/DeployRDATUpgradeable.s.sol --rpc-url $VANA_MOKSHA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY

# Check balances and deployment status
./script/check-balances.sh
./script/deployment-summary.sh
```

## Architecture

### Core Contracts (16 total, 11 completed)
1. **RDATUpgradeable** - Main ERC-20/VRC-20 token (100M fixed supply, UUPS) ✅
2. **vRDAT** - Soul-bound governance token (proportional distribution) ✅
3. **StakingPositions** - NFT-based staking with 30/90/180/365 day locks ✅
4. **TreasuryWallet** - Manages 70M RDAT with phased vesting ✅
5. **TokenVesting** - VRC-20 compliant team vesting (6mo cliff + 18mo linear) ✅
6. **MigrationBridge** - Secure V1→V2 cross-chain migration (30M allocation) ✅
7. **EmergencyPause** - Shared emergency response (72hr auto-expiry) ✅
8. **RevenueCollector** - Fee distribution (50/30/20 split) ✅
9. **AllocationTracker** - Tracks distributions from TreasuryWallet ✅
10. **CREATE2Factory** - Deterministic deployment infrastructure ✅
11. **vRDATRewardModule** - Proportional governance token distribution ✅
12. **RewardsManager** - UUPS upgradeable reward module orchestrator 🔴
13. **RDATRewardModule** - Time-based rewards with multipliers 🔴
14. **ProofOfContribution** - Vana DLP integration 🔴
15. **VRC14LiquidityModule** - VANA liquidity incentives 🔴
16. **DataPoolManager** - VRC-20 data pool management 🔴

### Fixed Supply Model
- **Total Supply**: 100M RDAT (minted entirely at deployment)
- **Distribution**: 70M to TreasuryWallet, 30M to MigrationBridge
- **No Minting**: `mint()` function always reverts - supply is immutable
- **Rewards**: From pre-allocated pools, not inflation

### Key Addresses
- **Vana Multisig**: `0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319`
- **Base Multisig**: `0x90013583c66D2bf16327cB5Bc4a647AcceCF4B9A`
- **Deployer**: `0x58eCB94e6F5e6521228316b55c465ad2A2938FbB`
- **Local Anvil Account**: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`

## Chain Configuration

Project uses Foundry profiles (in foundry.toml):
- `local-base`: Port 8545, Chain ID 8453
- `local-vana`: Port 8546, Chain ID 1480
- `base-sepolia`: Chain ID 84532
- `vana-moksha`: Chain ID 14800 (testnet)
- `base`: Chain ID 8453 (mainnet)
- `vana`: Chain ID 1480 (mainnet)

## Environment Setup
```shell
cp .env.example .env
# Configure:
# - RPC URLs (VANA_RPC_URL, BASE_RPC_URL, etc.)
# - DEPLOYER_PRIVATE_KEY
# - TREASURY_ADDRESS (use appropriate multisig)
# - ADMIN_ADDRESS (use appropriate multisig)
# - VALIDATOR_1, VALIDATOR_2, VALIDATOR_3 (for bridge)
```

## Deployment Process (CREATE2)

1. Calculate RDAT address via CREATE2 (resolves circular dependencies)
2. Deploy TreasuryWallet with predicted RDAT address
3. Deploy MigrationBridge with predicted RDAT address  
4. Deploy RDATUpgradeable via CREATE2 (mints 70M to Treasury, 30M to Bridge)
5. Treasury distributes per DAO vote (manual trigger post-migration)

### Deployment Verification
```shell
# Show deployment addresses across all chains
forge script script/ShowDeploymentAddresses.s.sol

# Verify deployment integrity
forge script script/VerifyDeployment.s.sol --rpc-url $VANA_MOKSHA_RPC_URL
```

## Testing Strategy

### Current Test Status
- **Total Tests**: 336
- **Passing**: 294 (87.5%)
- **Core Contracts**: 100% passing (TreasuryWallet, TokenVesting, RevenueCollector, RDATUpgradeable, EmergencyPause)
- **Integration Tests**: MigrationBridge (88%), StakingPositions (67%)
- **Pending**: RewardsManager integration (45 tests)

### Test Categories
- **Unit Tests**: Individual contract functions
- **Integration Tests**: Cross-contract interactions
- **Scenario Tests**: Complete user journeys
- **Security Tests**: Attack vectors and edge cases
- **Fuzz Tests**: Property-based testing

## Security Features
- Multi-sig control (3/5 critical, 2/5 pause)
- 72-hour emergency pause with auto-expiry
- Reentrancy guards on all state-changing functions
- 48-hour module timelock for reward modules
- Soul-bound vRDAT prevents governance attacks
- No MINTER_ROLE exists (eliminates minting vulnerabilities)

## Git Workflow

### Commit Format
```
<type>: <subject>

<body>

🤖 Generated with Claude Code

Co-Authored-By: Claude <noreply@anthropic.com>
```

**Types**: feat, fix, test, docs, refactor, checkpoint, wip

### Key Principles
- Commit after each logical unit of work
- Every commit should compile and pass existing tests
- Use "checkpoint:" for stable rollback points
- Document experiments and edge cases in commits
- Create session summaries at end of work sessions