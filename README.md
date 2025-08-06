# 🚀 r/datadao Smart Contracts

**Version**: 3.0 - Full VRC Compliance  
**Sprint**: August 5-18, 2025  
**Blockchain**: Vana (Primary), Base (Migration Only)  
**Contracts**: 14 total (7 completed, 7 remaining)

## 📋 Overview

RDAT represents a major upgrade from V1, expanding token supply from 30M to 100M and migrating from Base to Vana blockchain. This repository contains the smart contracts for the r/datadao ecosystem.

## 🏗️ Architecture

### Core Contracts (14 Total)
1. **RDATUpgradeable**: Main ERC-20 token with full VRC-20 compliance (100M supply, UUPS) ✅
2. **vRDAT**: Soul-bound governance token with proportional distribution ✅
3. **StakingManager**: Immutable core staking with EnumerableSet optimization ✅
4. **RewardsManager**: UUPS upgradeable orchestrator for reward modules 🔴
5. **vRDATRewardModule**: Proportional governance token distribution (days/365) ✅
6. **RDATRewardModule**: Time-based rewards with 1x-1.75x multipliers 🔴
7. **MigrationBridge**: Secure V1→V2 cross-chain migration 🔴
8. **EmergencyPause**: Shared emergency response system ✅
9. **RevenueCollector**: Fee distribution mechanism (50/30/20 split) 🔴
10. **ProofOfContribution**: Full Vana DLP implementation 🔴
11. **Create2Factory**: Deterministic deployment factory ✅
12. **VRC14LiquidityModule**: VANA liquidity incentives (90-day tranches) 🆕
13. **DataPoolManager**: VRC-20 data pool management 🆕
14. **RDATVesting**: Team token vesting (6-month cliff) 🆕

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

## 📦 Deployment

### Architecture
RDAT V2 uses a modular triple-layer architecture:
- **Token Layer**: UUPS upgradeable RDAT for flexibility and bug fixes
- **Staking Layer**: Immutable StakingManager for maximum security
- **Rewards Layer**: Upgradeable RewardsManager with pluggable modules
- **Key Innovation**: Separation of staking state from reward logic
- **Gas Optimization**: EnumerableSet for O(1) stake operations
- **Anti-Gaming**: Proportional vRDAT distribution (days/365)

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

- [Contract Specifications](./CONTRACTS_SPEC.md)
- [Testing Requirements](./docs/TESTING_REQUIREMENTS.md)
- [Deployment Guide](./docs/DEPLOYMENT_GUIDE.md)
- [Full Specifications](./docs/SPECIFICATIONS.md)

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
