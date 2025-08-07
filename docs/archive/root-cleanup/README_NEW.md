# 🚀 RDAT V2 - Cross-Chain DeFi Protocol

[![Audit Status](https://img.shields.io/badge/Audit-Ready-green)](./docs/AUDIT_DOCUMENTATION.md)
[![Tests](https://img.shields.io/badge/Tests-333%20Passing-brightgreen)](./test)
[![Coverage](https://img.shields.io/badge/Coverage-98%25-brightgreen)](./docs/TECHNICAL_SPECIFICATION.md)
[![License](https://img.shields.io/badge/License-MIT-blue)](./LICENSE)

## 📖 Quick Navigation

### For Different Stakeholders

| I am a... | I need... | Go to... |
|-----------|-----------|----------|
| 👔 **Executive/Investor** | Business overview, metrics, risks | [Executive Summary](./EXECUTIVE_SUMMARY.md) |
| 💻 **Developer** | Integration guides, APIs, examples | [Developer Guide](./docs/DEVELOPER_GUIDE.md) |
| 🔍 **Auditor** | Security info, test coverage, issues | [Audit Documentation](./docs/AUDIT_DOCUMENTATION.md) |
| 📊 **Project Manager** | Sprint status, timeline, tasks | [Project Management](./PROJECT_MANAGEMENT.md) |
| 🔧 **DevOps Engineer** | Deployment guides, configs | [Deployment Operations](./docs/DEPLOYMENT_OPERATIONS.md) |
| 👥 **Community Member** | Governance, tokenomics | [Governance & Treasury](./docs/GOVERNANCE_TREASURY.md) |
| 🚨 **Emergency Response** | Incident procedures | [Emergency Procedures](./docs/EMERGENCY_PROCEDURES.md) |

## 🎯 Project Overview

RDAT V2 is a comprehensive DeFi protocol upgrade implementing cross-chain migration from Base to Vana blockchain with expanded tokenomics (30M → 100M fixed supply). The system features modular rewards architecture, time-lock staking with multipliers, and sophisticated governance mechanisms.

### Key Features
- **🔒 Fixed Supply**: 100M tokens, no inflation ever
- **🔄 Cross-Chain Migration**: Secure Base → Vana bridge
- **💎 NFT Staking**: Time-lock positions with 1x-1.75x multipliers
- **🏛️ Modular Rewards**: Flexible reward distribution system
- **🗳️ Soul-bound Governance**: Flash-loan resistant voting

## 🚀 Quick Start

### Prerequisites
```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Clone repository
git clone https://github.com/rdatadao/contracts-v2
cd contracts-v2

# Install dependencies
forge install
```

### Build & Test
```bash
# Build contracts
forge build

# Run tests
forge test

# Run with gas reporting
forge test --gas-report

# Check coverage
forge coverage
```

### Deploy (Testnet)
```bash
# Set environment variables
cp .env.example .env
# Edit .env with your values

# Deploy to Vana Moksha testnet
forge script script/Deploy.s.sol --rpc-url $VANA_MOKSHA_RPC --broadcast

# Deploy to Base Sepolia testnet
forge script script/Deploy.s.sol --rpc-url $BASE_SEPOLIA_RPC --broadcast
```

## 📊 Current Status

| Component | Status | Progress |
|-----------|--------|----------|
| Core Contracts | ✅ Complete | 100% |
| Test Suite | ✅ Complete | 333/333 passing |
| Documentation | 🔄 In Progress | 95% |
| Audit Preparation | ✅ Ready | 100% |
| Testnet Deployment | 🔄 In Progress | 90% |
| Mainnet Deployment | 📅 Scheduled | Aug 18-20 |

## 🏗️ Architecture

```
┌─────────────────────────────────────────────┐
│                EmergencyPause                │
└────────────────────┬────────────────────────┘
                     │
     ┌───────────────┼───────────────┐
     │               │               │
┌────▼──────┐ ┌─────▼──────┐ ┌─────▼──────┐
│   RDAT    │ │  Staking   │ │  Rewards   │
│  (Token)  │ │ (Positions)│ │ (Manager)  │
└───────────┘ └─────┬──────┘ └─────┬──────┘
                    │               │
                ┌───▼───┐      ┌────▼────┐
                │ vRDAT │      │ Modules │
                └───────┘      └─────────┘
```

## 📚 Documentation Structure

### Core Documentation (Consolidated)
- 📊 [Executive Summary](./EXECUTIVE_SUMMARY.md) - Business overview
- 📅 [Project Management](./PROJECT_MANAGEMENT.md) - Sprint tracking
- 🔧 [Technical Specification](./docs/TECHNICAL_SPECIFICATION.md) - Complete architecture
- 🔍 [Audit Documentation](./docs/AUDIT_DOCUMENTATION.md) - Security package
- 🚀 [Deployment Operations](./docs/DEPLOYMENT_OPERATIONS.md) - DevOps guide
- 🏛️ [Governance & Treasury](./docs/GOVERNANCE_TREASURY.md) - DAO mechanics
- 💻 [Developer Guide](./docs/DEVELOPER_GUIDE.md) - Integration guide
- 🚨 [Emergency Procedures](./docs/EMERGENCY_PROCEDURES.md) - Incident response
- 📄 [Whitepaper](./docs/WHITEPAPER.md) - Vision & tokenomics

### Archived Documentation
Historical documents and daily updates are in [`docs/archive/`](./docs/archive/) for reference.

## 🔐 Security

### Audit Status
- **Scheduled**: August 12-13, 2025
- **Firm**: [TBD]
- **Scope**: All core contracts
- **Preparation**: ✅ Complete

### Security Features
- Multi-signature control (3/5 critical, 2/5 emergency)
- Time-locked operations
- Reentrancy protection
- Emergency pause system (72-hour auto-expiry)
- No minting capability (fixed supply)

### Bug Bounty
Coming soon after audit completion.

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](./CONTRIBUTING.md) for details.

### Development Process
1. Fork the repository
2. Create your feature branch
3. Write tests for new features
4. Ensure all tests pass
5. Submit a pull request

## 📞 Support & Contact

### For Developers
- Discord: [#dev-support](https://discord.gg/rdatadao)
- Documentation: [Developer Guide](./docs/DEVELOPER_GUIDE.md)

### For General Inquiries
- Website: [rdatadao.org](https://rdatadao.org)
- Twitter: [@rdatadao](https://twitter.com/rdatadao)
- Email: contact@rdatadao.org

### For Security Issues
- Email: security@rdatadao.org
- PGP Key: [Available on request]

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details.

## 🙏 Acknowledgments

- OpenZeppelin for secure contract libraries
- Foundry team for the amazing development framework
- Vana team for blockchain support
- Our community for continuous feedback

---

**Version**: 2.0.0-beta  
**Last Updated**: August 7, 2025  
**Status**: 🟢 Audit Ready