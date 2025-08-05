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
forge script script/Counter.s.sol:CounterScript --rpc-url <RPC_URL> --private-key <PRIVATE_KEY>
```

**Generate ABI files for frontend:**
```shell
# Export all contract ABIs
./scripts/export-abi.sh

# Or manually export specific contract ABI
forge inspect MockRDAT abi > abi/MockRDAT.json
```

**Frontend integration with wagmi:**
```shell
# Set up example frontend structure
./scripts/setup-frontend.sh

# In frontend project, generate TypeScript types
npx wagmi generate
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

This is a multi-chain Foundry smart contract project supporting deployments to both Base and Vana blockchains. The project follows an organized structure for chain-specific deployments:

### Directory Structure
- `src/`: Contains Solidity smart contracts
  - `src/base/`: Base-specific contracts (only deployable on Base)
  - `src/vana/`: Vana-specific contracts (only deployable on Vana)
  - `src/shared/`: Multi-chain contracts (deployable on both chains)
- `test/`: Contains test files using forge-std testing framework
- `script/`: Contains deployment scripts
  - `script/base/`: Base-specific deployment scripts
  - `script/vana/`: Vana-specific deployment scripts
  - `script/shared/`: Shared deployment infrastructure and multi-chain scripts
- `lib/`: Contains dependencies (currently forge-std testing library)
- `out/`: Compilation artifacts (gitignored)

### Chain Configuration
The project uses Foundry profiles for different chains:
- `default`: Local development
- `local-base`: Local Base chain (port 8545, chain ID: 8453)
- `local-vana`: Local Vana chain (port 8546, chain ID: 1480)
- `base`: Base mainnet (chain ID: 8453)
- `base-sepolia`: Base Sepolia testnet (chain ID: 84532)
- `vana`: Vana mainnet (chain ID: 1480)
- `vana-moksha`: Vana Moksha testnet (chain ID: 14800)

### Multi-Chain Deployment

**Environment Setup:**
```shell
cp .env.example .env
# Edit .env with your private key and RPC URLs
```

**Deploy to specific chains using profiles:**
```shell
# Base deployments
forge script script/base/DeployCounter.s.sol:DeployCounterBase --rpc-url $BASE_RPC_URL --broadcast
forge script script/base/DeployBaseOnly.s.sol:DeployBaseOnly --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast

# Vana deployments
forge script script/vana/DeployCounter.s.sol:DeployCounterVana --rpc-url $VANA_RPC_URL --broadcast
forge script script/vana/DeployVanaData.s.sol:DeployVanaData --rpc-url $VANA_TESTNET_RPC_URL --broadcast

# Multi-chain contracts (deploy to either chain)
forge script script/shared/DeployMultiChainRegistry.s.sol:DeployMultiChainRegistry --rpc-url $BASE_RPC_URL --broadcast
```

**Using the deployment helper script:**
```shell
./script/deploy.sh [chain] [contract]

# Examples:
./script/deploy.sh base-sepolia Counter
./script/deploy.sh vana-moksha VanaData
./script/deploy.sh base Registry
```

### Contract Types
1. **Chain-specific contracts**: Include chain ID validation in constructor
2. **Multi-chain contracts**: Detect chain ID and adjust behavior accordingly
3. **Shared utilities**: BaseDeployScript provides common deployment infrastructure

The project uses:
- Solidity ^0.8.13
- forge-std for testing framework which provides Test base contract, console logging, and cheat codes (vm)
- Foundry's built-in testing with support for fuzz testing and invariant testing
- Environment-based configuration for multi-chain deployments