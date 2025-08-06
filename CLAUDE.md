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
1. **RDATUpgradeable** - Main ERC-20 token with VRC-20 compliance (100M supply, UUPS upgradeable)
2. **vRDAT** - Soul-bound governance token earned through staking (non-upgradeable)
3. **Staking** - Time-lock staking system with multipliers (non-upgradeable, manual migration)
4. **MigrationBridge** - Secure V1→V2 cross-chain migration
5. **EmergencyPause** - Shared emergency response system
6. **RevenueCollector** - Fee distribution mechanism (50/30/20 split)
7. **ProofOfContribution** - Vana DLP compliance stub

### Architecture Approach
- **RDAT Token**: Uses UUPS upgradeable pattern for flexibility and future improvements
- **Staking Contract**: Non-upgradeable with emergency migration for maximum security
- This hybrid approach provides the best of both patterns: flexibility for the token, security for staking

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
./script/deploy.sh vana-moksha RDATUpgradeable
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

## Git Commit Strategy and Development Workflow

### Commit Frequency and Granularity
1. **Commit Early and Often**: Make commits after each logical unit of work:
   - After implementing a new contract
   - After adding a major function or feature
   - After writing tests for a component
   - After fixing a significant bug
   - After updating documentation

2. **Atomic Commits**: Each commit should represent one logical change:
   - Don't mix feature implementation with refactoring
   - Separate test additions from implementation changes
   - Keep documentation updates in their own commits

3. **Stable Checkpoints**: Every commit should leave the codebase in a working state:
   - All existing tests should pass (unless explicitly fixing broken tests)
   - The code should compile without errors
   - No half-implemented features

### Commit Message Format
```
<type>: <subject>

<body>

<footer>
```

**Types**:
- `feat`: New feature or contract
- `fix`: Bug fix
- `docs`: Documentation changes
- `test`: Test additions or modifications
- `refactor`: Code restructuring without behavior change
- `perf`: Performance improvements
- `chore`: Build process or auxiliary tool changes
- `revert`: Reverting a previous commit

**Example**:
```
feat: implement VRC14LiquidityModule for liquidity incentives

- 90-day VANA liquidity program with daily tranches
- Configurable Uniswap V3 integration
- Automatic VANA->RDAT swaps and LP provision
- Proportional LP share distribution to stakers
- Mock Uniswap V3 contracts for testing
- 16 tests passing with full coverage

🤖 Generated with Claude Code

Co-Authored-By: Claude <noreply@anthropic.com>
```

### Edge Case Development Strategy
When exploring edge cases and potential design limitations:

1. **Create Feature Branches** (conceptually through commits):
   ```bash
   # Before starting experimental work
   git commit -m "checkpoint: stable state before <experiment description>"
   ```

2. **Document Experiments**:
   ```bash
   git commit -m "experiment: testing <edge case description>
   
   - What we're testing: <description>
   - Expected behavior: <description>
   - Actual behavior: <description>
   - Findings: <description>"
   ```

3. **Commit Both Successes and Failures**:
   - Failed approaches provide valuable documentation
   - Include why something didn't work
   - Reference the commit when trying alternative approaches

4. **Redesign Commits**:
   ```bash
   git commit -m "redesign: <component> to handle <limitation>
   
   - Previous approach: <description>
   - Limitation discovered: <description>
   - New approach: <description>
   - Trade-offs: <description>"
   ```

### Rollback Strategy Documentation
1. **Mark Stable Versions**:
   ```bash
   git commit -m "checkpoint: <feature> complete and tested
   
   - All tests passing
   - Ready for integration
   - Rollback point if next feature causes issues"
   ```

2. **Document Rollback Points** in commit messages:
   ```bash
   git commit -m "feat: add complex feature X
   
   ...
   
   Rollback: git checkout <previous-commit-hash> if issues arise"
   ```

### Working with Incomplete Features
When implementing large features across multiple sessions:

1. **Use TODO Markers**:
   ```bash
   git commit -m "wip: partial implementation of RewardsManager
   
   Completed:
   - Basic structure
   - Program registration
   
   TODO:
   - Claim aggregation
   - Emergency controls
   - Integration tests"
   ```

2. **Maintain Compilation**: Even WIP commits should compile:
   ```solidity
   function notImplemented() external {
       revert("TODO: Implement in next session");
   }
   ```

### Testing Strategy for Edge Cases
1. **Commit Failing Tests First**:
   ```bash
   git commit -m "test: add edge case tests for <scenario>
   
   - Tests currently failing
   - Documents expected behavior
   - Will fix in next commit"
   ```

2. **Then Commit the Fix**:
   ```bash
   git commit -m "fix: handle <edge case> in <component>
   
   - Tests now passing
   - Solution: <description>
   - Addresses issue found in <previous-commit>"
   ```

### Session Continuity
At the end of each session:

1. **Create Session Summary**:
   ```bash
   git commit -m "docs: session summary - <date> - <main achievement>
   
   Completed:
   - <list of achievements>
   
   Discovered Issues:
   - <list of edge cases or limitations found>
   
   Next Session:
   - <prioritized TODO list>
   
   Stable Rollback Points:
   - <commit>: <description>
   - <commit>: <description>"
   ```

2. **Update TODO List** in the codebase
3. **Ensure Clean Working Directory** (all changes committed)

### Emergency Procedures
If something goes catastrophically wrong:

1. **Don't Panic** - We have rollback points
2. **Commit the Broken State** with clear description:
   ```bash
   git commit -m "broken: <what broke> while attempting <what>
   
   - Error: <description>
   - Suspected cause: <description>
   - Will rollback to <commit> and try different approach"
   ```
3. **Document the Learning** for future reference

This strategy ensures we maintain a clear history of our development process, making it easy to understand why decisions were made and providing safe rollback points when exploring edge cases leads to dead ends.