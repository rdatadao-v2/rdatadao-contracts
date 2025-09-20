# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

r/datadao V2 smart contracts implementing cross-chain migration from Base to Vana blockchain with expanded tokenomics (30M → 100M fixed supply). The system uses a hybrid architecture: UUPS upgradeable RDAT token for flexibility + non-upgradeable contracts for security-critical components.

**Current Status**:
- **Mainnet**: LIVE ✅ on Vana (Chain 1480) and Base (Chain 8453)
- **Tests**: 382/382 passing (100% coverage)
- **Audit**: Hashlock complete, all findings remediated
- **DLP**: Registered with ID 40 on Vana

## Core Commands

### Testing
```shell
# Run all tests (382 tests)
forge test

# Run specific test by name
forge test --match-test testWithdrawPenalties

# Run specific contract tests
forge test --match-contract TreasuryWalletTest

# Run with verbosity levels
forge test -v    # basic
forge test -vv   # detailed logs
forge test -vvv  # stack traces
forge test -vvvv # execution traces

# Run specific test categories
forge test --match-path test/security/*
forge test --match-path test/integration/*
forge test --match-path test/audit/*
forge test --match-path test/unit/*

# Generate coverage report
forge coverage

# Generate gas report
forge test --gas-report

# Run snapshot for gas optimization tracking
forge snapshot
```

### Building & Formatting
```shell
# Build contracts
forge build

# Build with size report
forge build --sizes

# Check formatting
forge fmt --check

# Auto-fix formatting
forge fmt

# Clean build artifacts
forge clean
```

### Local Development
```shell
# Start multi-chain local environment (Base on :8545, Vana on :8546)
./script/anvil-multichain.sh start

# Check status
./script/anvil-multichain.sh status

# Deploy full system locally
forge script script/local/DeployFullSystemLocal.s.sol \
  --rpc-url http://localhost:8546 \
  --broadcast \
  --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Stop local chains
./script/anvil-multichain.sh stop
```

### Contract Verification & Interaction
```shell
# Read contract state
cast call 0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E "totalSupply()" --rpc-url $VANA_RPC_URL
cast call 0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E "balanceOf(address)" <address> --rpc-url $VANA_RPC_URL
cast call 0x9d4aB2d3fb25D414dba1d9D22200356b5984D35E "totalMigrated()" --rpc-url $VANA_RPC_URL

# Generate ABIs for frontend integration
forge inspect RDATUpgradeable abi > abi/RDATUpgradeable.json
forge inspect TreasuryWallet abi > abi/TreasuryWallet.json
forge inspect VanaMigrationBridge abi > abi/VanaMigrationBridge.json
forge inspect BaseMigrationBridge abi > abi/BaseMigrationBridge.json
forge inspect StakingPositions abi > abi/StakingPositions.json
```

## High-Level Architecture

### Contract Hierarchy & Dependencies
```
RDATUpgradeable (UUPS Token) - Core token with fixed 100M supply
├── TreasuryWallet - Manages 70M RDAT with vesting schedules
│   └── Depends on: RDAT token address
├── VanaMigrationBridge - Manages 30M for V1→V2 migration
│   └── Depends on: RDAT token, validators
├── BaseMigrationBridge - Burns V1 tokens on Base
│   └── Depends on: V1 token address
└── RDATDataDAO - DLP integration for data rewards
    └── Depends on: RDAT token, Vana DLP Registry

Phase 2 Contracts (Not Deployed):
├── StakingPositions (NFT) - Time-locked staking positions
├── vRDAT - Soul-bound governance tokens
├── RewardsManager - Modular reward distribution
├── GovernanceCore - On-chain voting with TimelockController
└── RevenueCollector - Protocol fee aggregation
```

### Token Flow Architecture
1. **Initial Distribution**: Constructor mints 70M to Treasury, 30M to Migration Bridge (one-time only)
2. **Migration Flow**: Base V1 burn → Validator signatures (2/3) → Vana V2 mint
3. **Staking Flow** (Phase 2): Lock RDAT → Mint NFT position → Earn vRDAT → Vote on proposals
4. **Rewards Flow** (Phase 2): RewardsManager → Multiple reward modules → User claims

### Security Model
- **Role Hierarchy**: DEFAULT_ADMIN_ROLE > PAUSER_ROLE > TREASURY_ROLE > VALIDATOR_ROLE
- **Multisig Requirements**: 3/5 for critical ops, 2/5 for pause, 2/3 for validations
- **Time Delays**: 48hr governance timelock, 6hr migration challenge, 72hr pause auto-expiry
- **Supply Control**: No minting after deployment, all rewards from pre-allocated pools

## Critical Implementation Notes

### Fixed Supply Enforcement
The RDAT token has a `mint()` function that always reverts - this is intentional. Total supply is fixed at 100M, minted only in constructor to Treasury (70M) and Migration Bridge (30M).

### CREATE2 Deployment Pattern
Contracts use CREATE2 for deterministic addresses across chains. The deployment order matters:
1. Calculate RDAT address first
2. Deploy Treasury/Bridge with predicted RDAT address
3. Deploy RDAT last via CREATE2

### Migration Security
- V1 tokens burned to 0xdEaD (not held in contract)
- 6-hour challenge period for disputed migrations
- 7-day admin override for stuck migrations
- Daily limit: 300,000 RDAT

### Audit Remediations
All Hashlock findings have been addressed:
- H-01: `withdrawPenalties()` added to recover trapped funds
- H-02: Challenge period enforcement with admin override
- M-01: V1 tokens properly burned to dead address
- M-02: NFT transfer logic corrected
- M-03: Internal poolId generation prevents front-running

## Production Addresses

### Vana Mainnet (1480)
- RDAT Token: `0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E`
- Treasury: `0x77D2713972af12F1E3EF39b5395bfD65C862367C`
- Migration Bridge: `0x9d4aB2d3fb25D414dba1d9D22200356b5984D35E`
- RDATDataDAO: `0xBbB0B59163b850dDC5139e98118774557c5d9F92`
- Multisig: `0xe4F7Eca807C57311e715C3Ef483e72Fa8D5bCcDF`

### Base Mainnet (8453)
- RDAT V1: `0x4498cd8Ba045E00673402353f5a4347562707e7D`
- Migration Bridge: `0xa4435b45035a483d364de83B9494BDEFA8322626`
- Multisig: `0x90013583c66D2bf16327cB5Bc4a647AcceCF4B9A`

## Documentation Map

### Essential References
- `QUICK_REFERENCE.md` - All addresses and key commands
- `docs/README.md` - Documentation hub with complete index
- `docs/SPECIFICATIONS.md` - Current deployed vs planned features
- `docs/FRONTEND_INTEGRATION.md` - Frontend integration guide
- `docs/ADMIN_GUIDE.md` - Multisig operations guide

### Technical Deep Dives
- `docs/ARCHITECTURE.md` - System design diagrams
- `docs/CONTRACTS.md` - Contract method reference
- `docs/TESTING.md` - Test suite documentation
- `docs/AUDIT.md` - Security audit details
- `docs/PHASE_2_ROADMAP.md` - Upcoming features

## Environment Variables

Required for deployment scripts:
```shell
# Networks
VANA_RPC_URL=https://rpc.vana.org
BASE_RPC_URL=https://mainnet.base.org
VANA_MOKSHA_RPC_URL=https://rpc.moksha.vana.org
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org

# Keys
DEPLOYER_PRIVATE_KEY=<your_key>
BASESCAN_API_KEY=<for_verification>
VANASCAN_API_KEY=<for_verification>

# Addresses
VANA_MULTISIG_ADDRESS=0xe4F7Eca807C57311e715C3Ef483e72Fa8D5bCcDF
BASE_MULTISIG_ADDRESS=0x90013583c66D2bf16327cB5Bc4a647AcceCF4B9A
TREASURY_ADDRESS=<multisig_address>
ADMIN_ADDRESS=<multisig_address>
```

## CI/CD Pipeline

GitHub Actions runs on every push/PR:
1. `forge fmt --check` - Formatting verification
2. `forge build --sizes` - Build with size reporting
3. `forge test -vvv` - All 382 tests with verbosity

## Common Development Tasks

### Adding New Tests
Tests are organized by category in `test/`:
- `unit/` - Individual contract tests
- `integration/` - Cross-contract interactions
- `security/` - Attack vector tests
- `audit/` - Remediation validation

### Deploying Contract Updates
Phase 2 contracts can be deployed using:
```shell
forge script script/DeployStakingSystem.s.sol --rpc-url $VANA_RPC_URL --broadcast --verify
forge script script/DeployGovernanceSystem.s.sol --rpc-url $VANA_RPC_URL --broadcast --verify
```

### Debugging Failed Transactions
```shell
# Get transaction details
cast tx <tx_hash> --rpc-url $VANA_RPC_URL

# Decode revert reason
cast 4byte-decode <error_selector>

# Trace transaction execution
cast run <tx_hash> --rpc-url $VANA_RPC_URL
```