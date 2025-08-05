# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Development Commands

**Build contracts:**
```shell
forge build
```

**Run tests:**
```shell
forge test
```

**Run specific test:**
```shell
forge test --match-test test_Increment
forge test --match-contract CounterTest
```

**Run tests with verbosity:**
```shell
forge test -vvv  # Shows stack traces for failing tests
forge test -vvvv # Shows execution traces for all tests
```

**Test coverage:**
```shell
forge coverage
```

**Format code:**
```shell
forge fmt
```

**Check formatting:**
```shell
forge fmt --check
```

**Gas optimization:**
```shell
forge snapshot
```

**Deploy contracts:**
```shell
forge script script/Deploy.s.sol --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast --verify
```

**Check deployment readiness:**
```shell
forge script script/CheckDeploymentReadiness.s.sol --rpc-url $VANA_MOKSHA_RPC_URL --sender $DEPLOYER_ADDRESS
```

**Generate ABI files for frontend:**
```shell
# Export all contract ABIs
./scripts/export-abi.sh

# Or manually export specific contract ABI
forge inspect MockRDAT abi > abi/MockRDAT.json
```

**Check balances across chains:**
```shell
./script/check-balances.sh
```

**View deployment summary:**
```shell
./script/deployment-summary.sh
```

**Local development chain (single):**
```shell
anvil
```

**Multi-chain local development:**
```shell
# Start both Base and Vana local chains
./script/anvil-multichain.sh start

# Check status
./script/anvil-multichain.sh status

# View logs
./script/anvil-multichain.sh logs base
./script/anvil-multichain.sh logs vana

# Stop all chains
./script/anvil-multichain.sh stop
```

**Multi-chain testing:**
```shell
# Run tests on both local chains
./script/test-multichain.sh all

# Run tests on specific chain
./script/test-multichain.sh base
./script/test-multichain.sh vana

# Deploy to local chains
./script/deploy.sh local-base Counter
./script/deploy.sh local-vana VanaData
```

## Project Architecture

This is the r/datadao V2 smart contract repository, implementing a cross-chain migration from Base to Vana blockchain with expanded tokenomics (30M → 100M supply).

### Core Contracts (V2 Beta)
1. **RDAT** - Main ERC-20 token with VRC-20 compliance (100M supply)
2. **vRDAT** - Soul-bound governance token earned through staking
3. **Staking** - Time-lock staking system with multipliers
4. **MigrationBridge** - Secure V1→V2 cross-chain migration
5. **EmergencyPause** - Shared emergency response system
6. **RevenueCollector** - Fee distribution mechanism (50/30/20 split)
7. **ProofOfContribution** - Vana DLP compliance stub

### Directory Structure
- `src/`: Solidity smart contracts
  - `interfaces/`: Contract interfaces (IRDAT, IStaking, etc.)
  - `libraries/`: Shared libraries
  - `mocks/`: Test mock contracts
- `test/`: Test files using forge-std
  - `unit/`: Unit tests for individual contracts
  - `integration/`: Multi-contract interaction tests
  - `fuzz/`: Fuzz testing
- `script/`: Deployment and utility scripts
  - `base/`: Base-specific deployment scripts
  - `vana/`: Vana-specific deployment scripts
  - `shared/`: Shared deployment infrastructure
  - `staking/`: Staking-related scripts
  - `mocks/`: Mock deployment scripts
- `docs/`: Technical documentation
  - `SPECIFICATIONS.md`: Complete system specs
  - `TESTING_REQUIREMENTS.md`: Testing guidelines
  - `DEPLOYMENT_GUIDE.md`: Deployment procedures
- `lib/`: Dependencies (forge-std, openzeppelin)

### Chain Configuration
The project uses Foundry profiles for different chains:
- `default`: Local development
- `local-base`: Local Base chain (port 8545, chain ID: 8453)
- `local-vana`: Local Vana chain (port 8546, chain ID: 1480)
- `base`: Base mainnet (chain ID: 8453)
- `base-sepolia`: Base Sepolia testnet (chain ID: 84532)
- `vana`: Vana mainnet (chain ID: 1480)
- `vana-moksha`: Vana Moksha testnet (chain ID: 14800)

### Environment Setup
```shell
cp .env.example .env
# Edit .env with:
# - RPC URLs for each chain
# - Deployer private key
# - Multisig addresses
# - Etherscan API keys
```

### Key Addresses
- **Vana Multisig**: `0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319`
- **Base Multisig**: `0x90013583c66D2bf16327cB5Bc4a647AcceCF4B9A`
- **Deployer**: `0x58eCB94e6F5e6521228316b55c465ad2A2938FbB`

### Deployment Workflow

**Using the deployment helper:**
```shell
./script/deploy.sh [chain] [contract]

# Examples:
./script/deploy.sh vana-moksha RDAT
./script/deploy.sh base-sepolia MigrationBridge
```

**Direct deployment scripts:**
```shell
# Deploy V2 system to Vana testnet
forge script script/Deploy.s.sol --rpc-url $VANA_MOKSHA_RPC_URL --broadcast --verify

# Deploy specific contracts
forge script script/vana/DeployRDATWithVesting.s.sol --rpc-url $VANA_RPC_URL --broadcast
forge script script/staking/DeployStaking.s.sol --rpc-url $VANA_MOKSHA_RPC_URL --broadcast
```

### Security Features
- Multi-signature control (3/5 for critical, 2/5 for pause)
- Emergency pause with 72-hour auto-expiry
- Reentrancy guards on all state-changing functions
- Flash loan protection with 48-hour delays
- Daily migration limits
- 2-of-3 validator consensus for bridge

### Testing Requirements
- Target: 100% test coverage
- Unit tests for all functions
- Integration tests for contract interactions
- Fuzz tests for edge cases
- Invariant tests for system properties
- Gas optimization benchmarks

### Contract Dependencies
- OpenZeppelin Contracts v5.0.0
- OpenZeppelin Contracts Upgradeable v5.0.0
- Foundry forge-std
- Solidity 0.8.23