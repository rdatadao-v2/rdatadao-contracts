# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

r/datadao V2 smart contracts implementing cross-chain migration from Base to Vana blockchain with expanded tokenomics (30M → 100M fixed supply). Architecture uses hybrid approach: UUPS upgradeable RDAT token + non-upgradeable staking for optimal security/flexibility balance.

**Current Status**: 333/333 tests passing, production-ready, audit-ready

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
```

### Deployment
```shell
# Check deployment readiness
forge script script/CheckDeploymentReadiness.s.sol --rpc-url $VANA_MOKSHA_RPC_URL --sender $DEPLOYER_ADDRESS

# Deploy with dry run first
forge script script/DeployRDATUpgradeableSimple.s.sol --rpc-url $VANA_MOKSHA_RPC_URL --sig "dryRun()"

# Deploy with broadcast
forge script script/DeployRDATUpgradeableSimple.s.sol --rpc-url $VANA_MOKSHA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY

# Check balances and deployment status
./script/check-balances.sh
./script/deployment-summary.sh
```

## Architecture

### Core Contracts (11 total)
1. **RDATUpgradeable** - Main ERC-20/VRC-20 token (100M fixed supply, UUPS)
2. **vRDAT** - Soul-bound governance token (proportional distribution)
3. **StakingPositions** - NFT-based staking with 30/90/180/365 day locks
4. **TreasuryWallet** - Manages 70M RDAT with phased vesting
5. **TokenVesting** - VRC-20 compliant team vesting (6mo cliff + 18mo linear)
6. **MigrationBridge** - Secure V1→V2 cross-chain migration (30M allocation)
7. **EmergencyPause** - Shared emergency response (72hr auto-expiry)
8. **RevenueCollector** - Fee distribution (50/30/20 split)
9. **RewardsManager** - UUPS upgradeable reward module orchestrator
10. **ProofOfContributionStub** - Vana DLP integration placeholder
11. **CREATE2Factory** - Deterministic deployment infrastructure

### Fixed Supply Model
- **Total Supply**: 100M RDAT (minted entirely at deployment)
- **Distribution**: 70M to TreasuryWallet, 30M to MigrationBridge
- **No Minting**: `mint()` function always reverts - supply is immutable
- **Rewards**: From pre-allocated pools, not inflation

### Key Addresses
- **Vana Multisig**: `0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319`
- **Base Multisig**: `0x90013583c66D2bf16327cB5Bc4a647AcceCF4B9A`
- **Deployer**: `0x58eCB94e6F5e6521228316b55c465ad2A2938FbB`

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
```

## Deployment Process (CREATE2)

1. Calculate RDAT address via CREATE2 (resolves circular dependencies)
2. Deploy TreasuryWallet with predicted RDAT address
3. Deploy MigrationBridge with predicted RDAT address  
4. Deploy RDATUpgradeable via CREATE2 (mints 70M to Treasury, 30M to Bridge)
5. Treasury distributes per DAO vote (manual trigger post-migration)

## Security Features
- Multi-sig control (3/5 critical, 2/5 pause)
- 72-hour emergency pause with auto-expiry
- Reentrancy guards on all state-changing functions
- 48-hour module timelock for reward modules
- Soul-bound vRDAT prevents governance attacks
- No MINTER_ROLE exists (eliminates minting vulnerabilities)

## Testing Requirements
- 100% coverage target (currently achieved)
- Unit tests for all functions
- Integration tests for contract interactions
- Fuzz tests for edge cases
- Security tests for common attack vectors

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