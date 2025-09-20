# r/datadao V2 - Project Overview

## Executive Summary

r/datadao V2 is a comprehensive blockchain ecosystem built on Vana, featuring cross-chain migration from Base with expanded tokenomics (30M → 100M fixed supply). The architecture uses a hybrid approach with UUPS upgradeable RDAT token and non-upgradeable staking contracts for optimal security and flexibility balance.

**Current Status**: Production-ready, audit-prepared, 370/373 tests passing (99.2%)

## Project Structure

### Documentation Index
1. **01_PROJECT_OVERVIEW.md** (this document) - Executive summary and navigation
2. **02_SPECIFICATIONS.md** - Complete technical specifications 
3. **03_CONTRACTS_SPECIFICATION.md** - Smart contract details and interfaces
4. **04_WHITEPAPER.md** - Economic model and tokenomics
5. **05_SPRINT_PLAN.md** - Development roadmap and milestones
6. **06_USE_CASES_AND_SCENARIOS.md** - User stories with Gherkin syntax
7. **07_WORKFLOW_SEQUENCE_DIAGRAMS.md** - Frontend integration flows
8. **08_DEPLOYMENT_AND_OPERATIONS.md** - Deployment guides and procedures
9. **09_TESTING_AND_AUDIT.md** - Test coverage and audit preparation
10. **10_GOVERNANCE_FRAMEWORK.md** - DAO governance and administration

## Quick Links

### For Developers
- [Contract Specifications](./03_CONTRACTS_SPECIFICATION.md)
- [Deployment Guide](./08_DEPLOYMENT_AND_OPERATIONS.md#deployment-guide)
- [Testing Requirements](./09_TESTING_AND_AUDIT.md#testing-requirements)

### For Frontend Teams
- [Workflow Diagrams](./07_WORKFLOW_SEQUENCE_DIAGRAMS.md)
- [Use Cases](./06_USE_CASES_AND_SCENARIOS.md)
- [Integration Points](./07_WORKFLOW_SEQUENCE_DIAGRAMS.md#6-front-end-integration-points)

### For Auditors
- [Audit Package](./09_TESTING_AND_AUDIT.md#audit-package)
- [Security Features](./03_CONTRACTS_SPECIFICATION.md#security-features)
- [Known Issues](./09_TESTING_AND_AUDIT.md#known-issues)

### For DAO Members
- [Governance Framework](./10_GOVERNANCE_FRAMEWORK.md)
- [Whitepaper](./04_WHITEPAPER.md)
- [Migration Process](./06_USE_CASES_AND_SCENARIOS.md#2-token-migration-epic)

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                     Vana Network                         │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │     RDAT     │  │    vRDAT     │  │   Staking    │ │
│  │  (ERC-20)    │  │ (Soul-bound) │  │  Positions   │ │
│  │  100M Fixed  │  │  Governance  │  │    (NFT)     │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
│         │                 │                  │          │
│         └─────────────────┼──────────────────┘          │
│                          │                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │   Treasury   │  │   Rewards    │  │  Migration   │ │
│  │    Wallet    │  │   Manager    │  │    Bridge    │ │
│  │  (70M RDAT)  │  │  (Modular)   │  │  (30M RDAT)  │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
│                                              │          │
└──────────────────────────────────────────────┼──────────┘
                                              │
                                    ┌─────────┴─────────┐
                                    │   Base Network    │
                                    │  ┌─────────────┐ │
                                    │  │  V1 Tokens  │ │
                                    │  │   (Base)    │ │
                                    │  └─────────────┘ │
                                    └───────────────────┘
```

## Core Contracts (11 Total)

1. **RDATUpgradeable** - Main ERC-20/VRC-20 token (100M fixed supply, UUPS)
2. **vRDAT** - Soul-bound governance token (proportional distribution)
3. **StakingPositions** - NFT-based staking with 30/90/180/365 day locks
4. **TreasuryWallet** - Manages 70M RDAT with phased vesting
5. **TokenVesting** - VRC-20 compliant team vesting (6mo cliff + 18mo linear)
6. **VanaMigrationBridge** - Secure V1→V2 cross-chain migration (30M allocation)
7. **BaseMigrationBridge** - Base chain side of migration bridge
8. **EmergencyPause** - Shared emergency response (72hr auto-expiry)
9. **RevenueCollector** - Fee distribution (50/30/20 split)
10. **RewardsManager** - UUPS upgradeable reward module orchestrator
11. **ProofOfContributionStub** - Vana DLP integration placeholder

## Key Features

### Fixed Supply Model
- **Total Supply**: 100M RDAT (minted entirely at deployment)
- **Distribution**: 70M to TreasuryWallet, 30M to MigrationBridge
- **No Minting**: `mint()` function always reverts - supply is immutable
- **Rewards**: From pre-allocated pools, not inflation

### Security Features
- Multi-sig control (3/5 critical, 2/5 pause)
- 72-hour emergency pause with auto-expiry
- Reentrancy guards on all state-changing functions
- 48-hour module timelock for reward modules
- Soul-bound vRDAT prevents governance attacks
- No MINTER_ROLE exists (eliminates minting vulnerabilities)

### Migration Features
- Cross-chain bridge (Base → Vana)
- Early bird bonuses (5%/3%/1% by week)
- Validator consensus (2/3 required)
- 6-hour challenge period
- Daily migration limits

### Staking Features
- NFT-based positions
- Multiple lock periods (30/90/180/365 days)
- Lock multipliers (1x/1.25x/1.5x/1.75x)
- Emergency withdrawal (50% penalty)
- Automatic vRDAT minting

### Governance Features
- Quadratic voting (cost = votes²)
- Soul-bound voting tokens
- 48-hour timelock
- Proposal thresholds
- Delegation support

## Network Configuration

### Mainnet Addresses
- **Vana Multisig**: `0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319`
- **Base Multisig**: `0x90013583c66D2bf16327cB5Bc4a647AcceCF4B9A`
- **Deployer**: `0x58eCB94e6F5e6521228316b55c465ad2A2938FbB`

### Chain IDs
- **Base Mainnet**: 8453
- **Vana Mainnet**: 1480
- **Base Sepolia**: 84532
- **Vana Moksha**: 14800

## Development Status

### Completed
- ✅ Core token contracts (11/11)
- ✅ Migration system
- ✅ Staking mechanism
- ✅ Governance framework
- ✅ Emergency response
- ✅ Treasury management
- ✅ Test coverage (99.2%)
- ✅ Documentation
- ✅ Audit preparation

### Pending
- ⏳ ProofOfContribution implementation (stub deployed)
- ⏳ Additional reward modules
- ⏳ Frontend development
- ⏳ External audit

## Contact & Support

- **GitHub**: [r/datadao-contracts](https://github.com/rdatadao/contracts)
- **Documentation**: This repository `/docs` folder
- **Security Contact**: security@rdatadao.org

## License

MIT License - See LICENSE file for details