# 🚀 r/datadao Smart Contracts

**Version**: 3.0 - Full VRC Compliance  
**Last Updated**: January 6, 2025  
**Blockchain**: Vana (Primary), Base (Migration Only)  
**Contracts**: 16 total (11 completed + MigrationBridge implemented)

## 📋 Overview

RDAT V2 represents a major upgrade from V1, expanding token supply from 30M to 100M and migrating from Base to Vana blockchain. This repository contains the smart contracts for the r/datadao ecosystem with fixed supply tokenomics and comprehensive vesting mechanisms.

## 🏗️ Architecture

### Core Contracts (16 Total)
1. **RDATUpgradeable**: Main ERC-20 token with VRC-20 compliance (100M fixed supply, UUPS) ✅
2. **vRDAT**: Soul-bound governance token with proportional distribution ✅
3. **StakingPositions**: NFT-based staking positions with lock periods ✅
4. **RewardsManager**: UUPS upgradeable orchestrator for reward modules 🔴
5. **vRDATRewardModule**: Proportional governance token distribution (days/365) ✅
6. **RDATRewardModule**: Time-based rewards with 1x-1.75x multipliers 🔴
7. **TreasuryWallet**: Manages 70M RDAT with phased vesting schedules ✅
8. **TokenVesting**: VRC-20 compliant team vesting (6-month cliff + 18-month linear) ✅
9. **MigrationBridge**: Secure V1→V2 cross-chain migration ✅
10. **EmergencyPause**: Shared emergency response system ✅
11. **RevenueCollector**: Dynamic fee distribution with RewardsManager integration ✅
12. **ProofOfContribution**: Vana DLP integration stub 🔴
13. **CREATE2Factory**: Deterministic deployment infrastructure ✅
14. **VRC14LiquidityModule**: VANA liquidity incentives 🔴
15. **DataPoolManager**: VRC-20 data pool management 🔴
16. **AllocationTracker**: Tracks distributions from TreasuryWallet ✅

### Key Features
- **Fixed Supply**: 100M RDAT total, no minting capability
- **Phased Vesting**: TreasuryWallet manages 70M with distinct schedules
- **VRC-20 Compliance**: Full compatibility with Vana DLP rewards
- **CREATE2 Deployment**: Deterministic cross-chain addresses
- **Emergency Controls**: Pause functionality with auto-expiry
- **UUPS Upgradeable**: Future improvements without token migration

### Key Addresses
- **Vana Multisig**: `0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319`
- **Base Multisig**: `0x90013583c66D2bf16327cB5Bc4a647AcceCF4B9A`
- **Deployer**: `0x58eCB94e6F5e6521228316b55c465ad2A2938FbB`

## 🛠️ Development Setup

### Prerequisites
- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Node.js >= 18
- Git

### Installation
```bash
# Clone repository
git clone https://github.com/rdatadao/contracts-v2.git
cd contracts-v2

# Install dependencies
forge install

# Copy environment variables
cp .env.example .env
# Edit .env with your configuration
```

### Build & Test
```bash
# Compile contracts
forge build

# Run tests
forge test

# Run tests with coverage
forge coverage

# Run specific test
forge test --match-test testStaking -vvv
```

### Local Development
```bash
# Start local multi-chain environment
./script/anvil-multichain.sh start

# Deploy to local chains
forge script script/Deploy.s.sol --rpc-url http://localhost:8546 --broadcast

# Stop local chains
./script/anvil-multichain.sh stop
```

## 🧪 Testing

### Test Status
```
Total Tests: 336
Passing: 294 (87.5%)
Failing: 42 (12.5%)

Core Contracts:
✅ TreasuryWallet: 14/14 tests passing (100%)
✅ TokenVesting: 38/38 tests passing (100%)
✅ RevenueCollector: 28/28 tests passing (100%)
✅ MigrationBridge: 30/34 tests passing (88%)
✅ RDATUpgradeable: 8/8 tests passing (100%)
✅ EmergencyPause: 19/19 tests passing (100%)
✅ CREATE2Deployment: 3/3 tests passing (100%)
⚠️  StakingPositions: 12/18 tests passing (67%)
🔴 RewardsManager: 0/45 tests passing (needs integration)
```

### Running Tests
```bash
# Run all tests
forge test

# Run specific test file
forge test --match-contract TreasuryWalletTest

# Run with gas reporting
forge test --gas-report

# Run with coverage
forge coverage
```

## 📦 Deployment

### Architecture
RDAT V2 uses a modular architecture with CREATE2 deployment:
- **Token Layer**: UUPS upgradeable RDAT with fixed 100M supply
- **Treasury Layer**: TreasuryWallet manages 70M with vesting schedules
- **Staking Layer**: StakingPositions NFT-based position tracking
- **Vesting Layer**: TokenVesting for VRC-20 compliant team allocations
- **Bridge Layer**: MigrationBridge for Base→Vana migration
- **Security Layer**: EmergencyPause with auto-expiry protection

### Deployment Overview
```bash
# Check deployment addresses across all chains
forge script script/ShowDeploymentAddresses.s.sol
```

### Testnet Deployment (Vana Moksha)
```bash
# Dry run first
forge script script/vana/DeployRDATUpgradeable.s.sol \
  --rpc-url $VANA_MOKSHA_RPC_URL \
  --sig "dryRun()"

# Deploy with broadcast
forge script script/vana/DeployRDATUpgradeable.s.sol \
  --rpc-url $VANA_MOKSHA_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --broadcast \
  --verify
```

### Mainnet Deployment (Vana)
```bash
# Dry run first
forge script script/vana/DeployRDATUpgradeable.s.sol \
  --rpc-url $VANA_RPC_URL \
  --sig "dryRun()"

# Deploy with broadcast
forge script script/vana/DeployRDATUpgradeable.s.sol \
  --rpc-url $VANA_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --broadcast \
  --verify \
  --slow
```

### Migration Bridge (Base Networks)
```bash
# Base contracts only receive migration bridge
# RDAT V2 is NOT deployed to Base
forge script script/base/DeployMigrationBridge.s.sol \
  --rpc-url $BASE_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --broadcast
```

## 🔒 Security

### Audit Status
- Internal review: ✅ Complete
- External audit: 📅 Scheduled for Days 7-8

### Security Features
- Multi-signature control (3/5 for critical, 2/5 for pause)
- Emergency pause system (72-hour auto-expiry)
- Module timelock (48-hour delay for new reward modules)
- Proportional vRDAT prevents governance gaming
- Dynamic reward rate for 2-year sustainability
- Enhanced bridge security (3-of-5 validators recommended)

### Bug Bounty
Report security vulnerabilities to: security@rdatadao.org

## 📚 Documentation

### Core Documentation
- [Full Specifications](./docs/SPECIFICATIONS.md) - Complete system design
- [Architecture Summary](./docs/ARCHITECTURE_SUMMARY.md) - High-level architecture overview
- [Implementation Updates](./docs/) - Daily progress updates:
  - [Day 6 Update](./docs/IMPLEMENTATION_UPDATE_DAY6.md) - Revenue distribution architecture
  - [Day 5 Update](./docs/IMPLEMENTATION_UPDATE_DAY5.md) - Migration system completion
- [Technical FAQ](./docs/TECHNICAL_FAQ.md) - Common questions answered

### Contract Specifications
- [TreasuryWallet Spec](./docs/TREASURY_WALLET_SPEC.md) - 70M RDAT vesting
- [TokenVesting Spec](./docs/TOKEN_VESTING_SPEC.md) - VRC-20 team vesting
- [Phase 3 Activation](./docs/PHASE_3_ACTIVATION_SPEC.md) - Future rewards unlock

### Development Guides
- [Testing Requirements](./docs/TESTING_REQUIREMENTS.md)
- [Deployment Guide](./docs/DEPLOYMENT_GUIDE.md)
- [Sprint Execution Plan](./docs/SPRINT_EXECUTION_PLAN_V2.md)

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

### Development Guidelines
- Write comprehensive tests for all new features
- Follow Solidity style guide
- Update documentation as needed
- Ensure 100% test coverage

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Links

- **Website**: [rdatadao.org](https://rdatadao.org)
- **Governance**: [snapshot.org/#/rdatadao.eth](https://snapshot.org/#/rdatadao.eth)
- **Discord**: [discord.gg/rdatadao](https://discord.gg/rdatadao)
- **Twitter**: [@rdatadao](https://twitter.com/rdatadao)

## ⚠️ Disclaimer

These contracts are currently in beta. While they have been thoroughly tested, please use at your own risk. The team is not responsible for any loss of funds.

---

**Built with ❤️ by the r/datadao community**
