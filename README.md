# 🚀 r/datadao Smart Contracts

**Version**: 3.2 - Mainnet Live ✅
**Last Updated**: September 20, 2025
**Blockchain**: Vana (Primary), Base (Migration Only)
**Status**: 382/382 tests passing, audited, mainnet deployed

## 📋 Overview

RDAT V2 is now live on mainnet, representing a major upgrade from V1. The migration expanded token supply from 30M to 100M and moved from Base to Vana blockchain. This repository contains the audited smart contracts for the r/datadao ecosystem with fixed supply tokenomics and comprehensive vesting mechanisms.

**Mainnet Status**: ✅ Deployed on Vana (Chain ID: 1480) and Base (Chain ID: 8453)
**DLP Registration**: ✅ Active on Vana (DLP ID: 40)
**Audit Status**: ✅ Hashlock audit complete with all findings remediated

## 🏗️ Architecture

### Deployed Contracts (Live on Mainnet) ✅
1. **RDATUpgradeable**: `0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E` (100M fixed supply, UUPS)
2. **TreasuryWallet**: `0x77D2713972af12F1E3EF39b5395bfD65C862367C` (70M RDAT vesting)
3. **VanaMigrationBridge**: `0x9d4aB2d3fb25D414dba1d9D22200356b5984D35E` (30M for V1→V2)
4. **RDATDataDAO**: `0xBbB0B59163b850dDC5139e98118774557c5d9F92` (DLP ID: 40)
5. **BaseMigrationBridge**: `0xa4435b45035a483d364de83B9494BDEFA8322626` (Base network)

### Contracts Ready for Phase 2 Deployment 🔄
6. **vRDAT**: Soul-bound governance token (proportional distribution)
7. **StakingPositions**: NFT-based staking with 30/90/180/365 day locks
8. **TokenVesting**: VRC-20 compliant team vesting (6mo cliff + 18mo linear)
9. **RevenueCollector**: Fee distribution (50/30/20 split)
10. **RewardsManager**: UUPS upgradeable reward module orchestrator
11. **GovernanceCore**: On-chain voting with timelock execution
12. **EmergencyPause**: Shared emergency response (72hr auto-expiry)

### Key Features
- **Fixed Supply**: 100M RDAT total, no minting capability
- **Phased Vesting**: TreasuryWallet manages 70M with distinct schedules
- **VRC-20 Compliance**: Full compatibility with Vana DLP rewards
- **CREATE2 Deployment**: Deterministic cross-chain addresses
- **Emergency Controls**: Pause functionality with auto-expiry
- **UUPS Upgradeable**: Future improvements without token migration

### Key Addresses (Mainnet)
- **Vana Multisig**: `0xe4F7Eca807C57311e715C3Ef483e72Fa8D5bCcDF` (3/5 signers)
- **Base Multisig**: `0x90013583c66D2bf16327cB5Bc4a647AcceCF4B9A` (mainnet)
- **Migration Validators** (2/3 required):
  - Angela: `0xd36B49f2DB6aA708Ce7245e8ab2453C6DfFc9d6f`
  - monkfenix.eth: `0xC9Af4E56741f255743e8f4877d4cfa9971E910C2`
  - Base Multisig: `0x08Cc5ed1bA3C95AA741f8AaEf631f716b037444b`

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

## ✅ Production Status

### Mainnet Deployment Status ✅
- **Vana Mainnet**: ✅ Live since September 20, 2025
  - RDAT: `0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E`
  - Treasury: 70M RDAT correctly allocated
  - Migration Bridge: 30M RDAT correctly allocated
  - DLP Registration: ID 40 active
- **Base Mainnet**: ✅ Migration bridge deployed
- **Total Migrated**: Check at `cast call 0x9d4aB2d3fb25D414dba1d9D22200356b5984D35E "totalMigrated()" --rpc-url https://rpc.vana.org`

### Test Coverage - 100% PASSING ✅
```
Total Tests: 382 (expanded from 333)
Passing: 382 (100%) ✅
Failed: 0

Test Categories:
✅ Unit Tests: 100% passing (all core contracts)
✅ Integration Tests: 100% passing (cross-contract interactions)
✅ Security Tests: 100% passing (42 attack vector tests)
✅ Audit Tests: 100% passing (remediation validation)
✅ Migration Tests: 100% passing (end-to-end journeys)
```

### Security Audit Status ✅
- **Auditor**: Hashlock
- **Audit Period**: September 2025
- **Findings Remediated**: All HIGH, MEDIUM, and LOW findings addressed
- **Key Remediations**:
  - H-01: Added `withdrawPenalties()` for trapped fund recovery
  - H-02: Challenge period enforcement + 7-day admin override
  - M-01: V1 tokens burned to 0xdEaD address
  - M-02: Fixed NFT transfer blocking condition
  - M-03: Internal poolId generation prevents front-running
  - L-04/L-05: TimelockController and comprehensive reward accounting

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

### Mainnet Deployment (Already Deployed) ✅
```bash
# View deployment addresses
cast call 0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E "totalSupply()" --rpc-url https://rpc.vana.org
# Returns: 100000000000000000000000000 (100M RDAT)

# Check DLP registration
cast call 0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E "dlpId()" --rpc-url https://rpc.vana.org
# Returns: 40
```

### Phase 2 Deployment (Staking & Governance)
```bash
# Deploy staking contracts
forge script script/DeployStakingSystem.s.sol \
  --rpc-url $VANA_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --broadcast \
  --verify

# Deploy governance contracts
forge script script/DeployGovernanceSystem.s.sol \
  --rpc-url $VANA_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --broadcast \
  --verify
```

### Migration Process (For Users)
```javascript
// 1. On Base: Approve V1 tokens
const v1Contract = new Contract('0x4498cd8Ba045E00673402353f5a4347562707e7D', ERC20_ABI, signer);
await v1Contract.approve('0xa4435b45035a483d364de83B9494BDEFA8322626', amount);

// 2. On Base: Initiate migration
const baseBridge = new Contract('0xa4435b45035a483d364de83B9494BDEFA8322626', BRIDGE_ABI, signer);
const tx = await baseBridge.initiateMigration(amount);

// 3. Backend collects 2/3 validator signatures

// 4. On Vana: Claim with signatures
const vanaBridge = new Contract('0x9d4aB2d3fb25D414dba1d9D22200356b5984D35E', BRIDGE_ABI, signer);
await vanaBridge.processMigration(userAddress, amount, migrationId, signatures);
```

## 🔒 Security

### Audit Status
- **Hashlock Audit**: ✅ Complete (September 2025)
- **All Findings**: ✅ Remediated and validated
- **Test Coverage**: 100% (382/382 tests passing)

### Security Features
- Multi-signature control (3/5 for critical operations)
- Emergency pause system (72-hour auto-expiry)
- Timelock delays (48-hour for governance execution)
- Fixed supply (no minting capability post-deployment)
- Migration security (2/3 validator signatures required)
- Challenge period (6 hours) with admin override (7 days)

### Bug Bounty
Report security vulnerabilities to: security@rdatadao.org
**Rewards**: Up to $50,000 for critical vulnerabilities

## 📚 Documentation

### 🚀 Quick Start
- **[Quick Reference](./QUICK_REFERENCE.md)** - All mainnet addresses and key info
- **[Project Overview](./docs/PROJECT_OVERVIEW.md)** - Executive summary and vision
- **[Frontend Integration](./docs/FRONTEND_INTEGRATION.md)** - Complete UI integration guide

### 📖 Core Documentation
- **[System Architecture](./docs/ARCHITECTURE.md)** - Complete technical design
- **[Smart Contracts](./docs/CONTRACTS.md)** - Detailed contract reference
- **[Deployment Guide](./docs/DEPLOYMENT.md)** - Deployment process and commands
- **[Migration Guide](./docs/MIGRATION.md)** - V1 to V2 migration process

### 🔒 Security & Operations
- **[Security Documentation](./docs/SECURITY.md)** - Security model and practices
- **[Audit Report](./docs/AUDIT.md)** - Hashlock audit and remediations
- **[Admin Guide](./docs/ADMIN_GUIDE.md)** - Multisig and validator operations
- **[Testing Guide](./docs/TESTING.md)** - Test suite and coverage

### 🔮 Future Development
- **[Phase 2 Roadmap](./docs/PHASE_2_ROADMAP.md)** - Staking, rewards, and governance
- **[DLP Integration](./docs/DLP_VANA_INTEGRATION.md)** - Vana DLP documentation

### 🛠️ Developer Resources
- **[Claude.md](./CLAUDE.md)** - AI assistant instructions
- **[ABI Exports](./abi/)** - Contract ABIs for integration
- **[Deployment Scripts](./script/)** - Automation scripts
- **[Audit Reports](./audits/)** - PDF audit documents

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

## 📊 Current Status & Roadmap

### ✅ Phase 1 Complete (Mainnet Live)
- Token deployment and distribution
- Cross-chain migration infrastructure
- Treasury with vesting schedules
- DLP registration for Vana rewards
- Hashlock security audit

### 🔄 Phase 2 In Development (Q4 2025)
- Staking system with NFT positions
- vRDAT governance token
- Reward distribution modules
- On-chain governance voting
- Revenue collector integration

### 📋 Phase 3 Planned (2026)
- Full DAO automation
- Advanced reward programs
- Liquidity provisions
- Cross-chain expansions

## ⚠️ Disclaimer

These contracts have been audited by Hashlock and are live on mainnet. While thoroughly tested and audited, users should understand the risks involved in DeFi protocols. The team and DAO are not responsible for any loss of funds.

---

**Built with ❤️ by the r/datadao community**
