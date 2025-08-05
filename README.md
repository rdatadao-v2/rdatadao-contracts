# 🚀 r/datadao V2 Beta Smart Contracts

**Version**: 2.0 Beta  
**Sprint**: August 5-18, 2025  
**Blockchain**: Vana (Primary), Base (Migration Only)

## 📋 Overview

RDAT V2 Beta represents a major upgrade from V1, expanding token supply from 30M to 100M and migrating from Base to Vana blockchain. This repository contains the smart contracts for the r/datadao ecosystem.

## 🏗️ Architecture

### Core Contracts
- **RDAT_V2**: Main ERC-20 token with VRC-20 compliance (100M supply)
- **vRDAT_V2**: Soul-bound governance token earned through staking
- **StakingV2**: Simplified staking system with time-lock multipliers
- **MigrationBridge_V2**: Secure V1→V2 cross-chain migration
- **EmergencyPause**: Shared emergency response system

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
forge script script/DeployV2Beta.s.sol --rpc-url http://localhost:8546 --broadcast

# Stop local chains
./script/anvil-multichain.sh stop
```

## 📦 Deployment

### Testnet Deployment (Vana Moksha)
```bash
forge script script/DeployV2Beta.s.sol \
  --rpc-url $VANA_MOKSHA_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --broadcast \
  --verify
```

### Mainnet Deployment (Vana)
```bash
forge script script/DeployV2Beta.s.sol \
  --rpc-url $VANA_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --broadcast \
  --verify \
  --slow
```

## 🔒 Security

### Audit Status
- Internal review: ✅ Complete
- External audit: 📅 Scheduled for Days 7-8

### Security Features
- Multi-signature control (3/5 for critical, 2/5 for pause)
- Emergency pause system (72-hour auto-expiry)
- Flash loan protection (48-hour delays)
- Soul-bound governance tokens (non-transferable)
- 2-of-3 validation for migration

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
