# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

r/datadao V2 smart contracts implementing cross-chain migration from Base to Vana blockchain with expanded tokenomics (30M → 100M fixed supply). Architecture uses hybrid approach: UUPS upgradeable RDAT token + non-upgradeable staking for optimal security/flexibility balance.

**Current Status**: 333/333 tests passing (100%) ✅, production-ready, audit-ready  
**Audit Report**: Preliminary audit report available at `r_datadao_Smart_Contract_Audit_Report_Preliminary_Report_v1.pdf`

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

# Register DLP after deployment
RDAT_DATA_DAO_ADDRESS=0x32B481b52616044E5c937CF6D20204564AD62164 RDAT_TOKEN_ADDRESS=0xC1aC75130533c7F93BDa67f6645De65C9DEE9a3A \
forge script script/RegisterDLP.s.sol:RegisterDLP --rpc-url $VANA_MOKSHA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY

# Check balances and deployment status
./script/check-balances.sh
./script/deployment-summary.sh
```

## Architecture

### Core Contracts (12 total)
1. **RDATUpgradeable** - Main ERC-20/VRC-20 token (100M fixed supply, UUPS) ✅
2. **vRDAT** - Soul-bound governance token (proportional distribution) ✅
3. **StakingPositions** - NFT-based staking with 30/90/180/365 day locks ✅
4. **TreasuryWallet** - Manages 70M RDAT with phased vesting ✅
5. **TokenVesting** - VRC-20 compliant team vesting (6mo cliff + 18mo linear) ✅
6. **MigrationBridge** - Secure V1→V2 cross-chain migration (30M allocation) ✅
7. **VanaMigrationBridge** - Vana-side bridge with validator consensus (30M allocation) ✅
8. **RDATDataDAO** - Vana DLP contract for data contribution and validation ✅
   - **DLP ID**: 155 (Successfully registered on Vana Moksha)
9. **EmergencyPause** - Shared emergency response (72hr auto-expiry) ✅
10. **RevenueCollector** - Fee distribution (50/30/20 split) ✅
11. **RewardsManager** - UUPS upgradeable reward module orchestrator ✅
12. **CREATE2Factory** - Deterministic deployment infrastructure ✅

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
6. Register DLP with Vana using `RegisterDLP.s.sol` script

### Deployment Verification
```shell
# Show deployment addresses across all chains
forge script script/ShowDeploymentAddresses.s.sol

# Verify deployment integrity
forge script script/VerifyDeployment.s.sol --rpc-url $VANA_MOKSHA_RPC_URL
```

## Testing Strategy

### Current Test Status ✅
- **Total Tests**: 333
- **Passing**: 333 (100%)
- **Unit Tests**: 100% passing (all core contracts)
- **Integration Tests**: 100% passing (cross-contract interactions)
- **Security Tests**: 100% passing (attack vectors, griefing protection)
- **Scenario Tests**: 100% passing (complete migration journeys)
- **Production Simulations**: All deployment scripts validated

### Test Categories
- **Unit Tests**: Individual contract functions
- **Integration Tests**: Cross-contract interactions
- **Scenario Tests**: Complete user journeys
- **Security Tests**: Attack vectors and edge cases (24 tests in `/test/security/`)
- **Fuzz Tests**: Property-based testing

### Running Specific Test Categories
```shell
# Run only security tests
forge test --match-path test/security/*

# Run integration tests
forge test --match-path test/integration/*

# Run tests for specific contract
forge test --match-contract RDATUpgradeableTest

# Run with detailed gas reporting
forge test --gas-report --match-test testStaking
```

## Production Readiness ✅

### Deployment Status
- **Vana Moksha**: Fully deployed and operational
  - RDAT: `0xC1aC75130533c7F93BDa67f6645De65C9DEE9a3A` (100M supply correctly distributed)
  - Treasury: `0x31C3e3F091FB2A25d4dac82474e7dc709adE754a` (70M RDAT)
  - Migration Bridge: `0x31C3e3F091FB2A25d4dac82474e7dc709adE754a` (30M RDAT)
  - Data DAO: `0x32B481b52616044E5c937CF6D20204564AD62164` (DLP ID: 155)
- **Base Sepolia**: Migration testing infrastructure deployed
- **Mainnet**: Ready for deployment (all scripts validated)

### GitHub Actions CI/CD ✅
- **Workflow**: `.github/workflows/test.yml`
- Build: ✅ Passing (`forge build --sizes`)
- Tests: ✅ 333/333 passing (`forge test -vvv`)
- Formatting: ✅ All files standardized (`forge fmt --check`)
- Gas Reporting: ✅ Optimized contracts

### Deployment Scripts ✅
All deployment scripts tested and production-ready:
- `DeployRDATUpgradeableProduction.s.sol` - Struct-based deployment (recommended)
- `DeployRDATUpgradeableSimple.s.sol` - Standard deployment
- `DeployFullSystem.s.sol` - Complete ecosystem deployment
- Pre-deployment validation with `PreDeploymentCheck.s.sol`

## Security Features
- Multi-sig control (3/5 critical, 2/5 pause)
- 72-hour emergency pause with auto-expiry
- Reentrancy guards on all state-changing functions
- 48-hour module timelock for reward modules
- Soul-bound vRDAT prevents governance attacks
- No MINTER_ROLE exists (eliminates minting vulnerabilities)
- Comprehensive security test coverage (24 attack vector tests)

## Git Workflow

### Commit Format
```
<type>: <subject>

<body>

🤖 Generated with Claude Code

Co-Authored-By: Claude <noreply@anthropic.com>
```

**Types**: feat, fix, test, docs, refactor, checkpoint, wip

#### Key Principles
- Commit after each logical unit of work
- Every commit should compile and pass existing tests
- Use "checkpoint:" for stable rollback points
- Document experiments and edge cases in commits
- Create session summaries at end of work sessions

## Documentation

Comprehensive documentation organized in `/docs/`:
- **01_PROJECT_OVERVIEW.md**: High-level project summary
- **02_SPECIFICATIONS.md**: Detailed technical specifications (175KB)
- **03_CONTRACTS_SPECIFICATION.md**: Contract-specific details
- **04_WHITEPAPER.md**: Economic model and tokenomics
- **05_SPRINT_PLAN.md**: Development timeline and milestones
- **06_USE_CASES_AND_SCENARIOS.md**: User journey examples
- **07_WORKFLOW_SEQUENCE_DIAGRAMS.md**: System interaction flows
- **08_DEPLOYMENT_AND_OPERATIONS.md**: Production deployment guide
- **09_TESTING_AND_AUDIT.md**: Comprehensive testing requirements
- **10_GOVERNANCE_FRAMEWORK.md**: DAO governance mechanics
- **ABI_EXPORT_GUIDE.md**: Instructions for exporting contract ABIs

## Utility Scripts

Production and development utilities in `/scripts/`:
- **export-abi.sh**: Export contract ABIs for frontend integration
- **extract-abi.sh**: Extract specific ABIs from build artifacts
- **setup-frontend.sh**: Configure frontend repository
- **fix-test-compilation.sh**: Resolve test compilation issues
- **remove-minter-role-references.sh**: Clean up deprecated minter role
- **update-tests-for-fixed-supply.sh**: Update tests for fixed supply model