# r/datadao V2 Architecture Summary

## Overview
This document provides a comprehensive summary of the r/datadao V2 smart contract architecture, highlighting key design decisions, implementation progress, and architectural improvements made during development.

## Core Architecture Principles

### 1. **Triple-Layer Pattern**
- **Upgradeable Token (RDAT)**: UUPS pattern for future improvements
- **Immutable Staking (StakingPositions)**: NFT-based for maximum security
- **Modular Rewards (RewardsManager)**: Flexible reward distribution system

### 2. **Fixed Supply Model**
- Total Supply: 100,000,000 RDAT (minted at deployment)
- No minting function - prevents inflation
- Pre-allocated pools for sustainability

### 3. **Cross-Chain Migration**
- Secure bridge from Base to Vana
- Multi-validator consensus (3+ validators)
- 6-hour challenge period
- Bonus incentives with separate vesting

## Key Contracts and Their Roles

### Core Contracts
1. **RDATUpgradeable.sol**
   - Main ERC-20 token with VRC-20 compliance
   - UUPS upgradeable pattern
   - 100M fixed supply
   - CREATE2 deployment for deterministic addresses

2. **StakingPositions.sol**
   - NFT-based staking (ERC-721)
   - Each stake = unique NFT position
   - Time-lock multipliers (1x, 1.5x, 2x, 4x)
   - Soul-bound during lock period
   - Emergency withdrawal with 50% penalty

3. **vRDAT.sol**
   - Soul-bound governance token
   - Non-transferable
   - Earned through staking
   - Used for quadratic voting

### Revenue System
4. **RevenueCollector.sol**
   - **Dynamic Token Support**: Queries RewardsManager for supported tokens
   - **Distribution Logic**:
     - Supported tokens: 50/30/20 (stakers/treasury/contributors)
     - Unsupported tokens: 100% to treasury (awaiting DAO decision)
   - **Integration**: Works with both legacy (RDAT) and new tokens

5. **RewardsManager.sol**
   - Orchestrates multiple reward modules
   - Tracks supported tokens via `isTokenSupported()`
   - Enables hot-swappable reward programs
   - Module-based architecture for flexibility

### Migration System
6. **BaseMigrationBridge.sol**
   - Burns V1 tokens on Base chain
   - Emits events for validators
   - Tracks burn transactions

7. **VanaMigrationBridge.sol**
   - Releases V2 tokens on Vana
   - Requires 3+ validator consensus
   - 6-hour challenge period
   - Daily migration limits (300K default)

8. **MigrationBonusVesting.sol**
   - 12-month linear vesting for bonuses
   - Separate from migration reserve
   - Time-based incentives (5%/3%/1%/0%)

### Supporting Contracts
9. **TreasuryWallet.sol**
   - Multi-sig treasury management
   - Tracks distributions
   - DAO-controlled allocations

10. **TokenVesting.sol**
    - Team token vesting
    - 6-month cliff + 18-month linear
    - Required for Vana DLP compliance

11. **EmergencyPause.sol**
    - Shared emergency response
    - 72-hour auto-expiry
    - Multi-sig controlled

## Architectural Decisions and Rationale

### 1. **Why NFT-Based Staking?**
- **Problem**: Traditional staking contracts have upgrade limitations
- **Solution**: NFT positions allow:
  - Multiple concurrent stakes per user
  - Independent position management
  - Transfer capabilities after unlock
  - Clean separation from rewards

### 2. **Why Separate Migration Bonuses?**
- **Problem**: Initial design used migration reserve for bonuses
- **User Feedback**: "The bonus incentive should not be paid from the migration reserve"
- **Solution**: Separate MigrationBonusVesting contract
  - Migration reserve (30M) only for 1:1 exchange
  - Bonuses from separate allocation
  - 12-month vesting prevents dumps

### 3. **Why Dynamic Revenue Distribution?**
- **Problem**: Hard-coded RDAT-only distribution
- **Evolution**: Support for multiple revenue tokens
- **Solution**: RewardsManager integration
  - Query token support dynamically
  - Treasury holds unsupported tokens
  - DAO decides on new distributions

### 4. **Why UUPS Over Transparent Proxy?**
- **Gas Efficiency**: Lower overhead for users
- **Flexibility**: Upgrade logic in implementation
- **Security**: Combined with multi-sig and timelock

## Security Features

### Multi-Layer Security
1. **Access Control**
   - Role-based permissions (ADMIN, PAUSER, UPGRADER)
   - Multi-sig requirements for critical operations
   - Timelock for upgrades

2. **Economic Security**
   - Daily migration limits
   - Emergency withdrawal penalties
   - Flash loan protection (48-hour delays)

3. **Technical Security**
   - Reentrancy guards on all state changes
   - Pausable functionality
   - Storage gaps for upgrade safety

### Validator Network
- 3+ validators required for consensus
- 12+ block confirmations on Base
- Challenge period for disputes
- On-chain proof verification

## Implementation Progress

### Completed ✅
- RDATUpgradeable with fixed supply
- StakingPositions with NFT positions
- vRDAT soul-bound tokens
- RevenueCollector with dynamic support
- Complete migration bridge system
- Bonus vesting separation
- TreasuryWallet with tracking
- TokenVesting contracts
- CREATE2 deployment infrastructure

### In Progress 🚧
- RewardsManager full integration
- Reward module implementations
- ProofOfContribution (Vana DLP)

### Testing Status
- **Total Tests**: 336
- **Passing**: 294
- **Failing**: 42 (mostly due to deprecated reward claiming)

## Key Improvements Over V1

1. **Tokenomics**
   - 30M → 100M supply expansion
   - Fixed supply (no inflation)
   - Pre-allocated reward pools

2. **Architecture**
   - Single contract → Modular system
   - Basic staking → NFT positions
   - RDAT-only → Multi-token support

3. **Governance**
   - Simple voting → Quadratic voting
   - Transferable → Soul-bound vRDAT
   - Basic → Advanced delegation

4. **Revenue**
   - No revenue → 50/30/20 distribution
   - Static → Dynamic token support
   - Manual → Automated distribution

## Deployment Strategy

### Phase 1: Core Infrastructure
1. Deploy CREATE2 factory
2. Calculate deterministic addresses
3. Deploy TreasuryWallet
4. Deploy RDAT with 100M supply
5. Deploy staking and reward contracts
6. Deploy migration bridges

### Phase 2: Migration
1. Open migration on Base
2. Activate validators
3. Enable Vana bridge
4. Monitor and support users
5. Distribute bonuses via vesting

### Phase 3: Operations
1. Activate revenue collection
2. Enable reward programs
3. Launch governance
4. Continuous monitoring

## Future Considerations

### Planned Enhancements
1. **Additional Reward Modules**
   - Partner token distributions
   - Retroactive rewards
   - Special event rewards

2. **Advanced Governance**
   - On-chain execution
   - Delegation improvements
   - Vote aggregation

3. **DeFi Integrations**
   - Liquid staking derivatives
   - Lending/borrowing
   - AMM integrations

### Upgrade Path
1. **Token Upgrades**: Via UUPS pattern
2. **New Rewards**: Deploy new modules
3. **Staking Changes**: Migration mechanism
4. **Revenue Updates**: Add token support

## Conclusion

The r/datadao V2 architecture represents a significant evolution from V1, introducing:
- **Modularity**: Separate concerns for flexibility
- **Security**: Multi-layer protection mechanisms
- **Scalability**: Support for multiple tokens and programs
- **Governance**: Advanced voting and delegation
- **Sustainability**: Fixed supply with pre-allocated rewards

The architecture prioritizes user security while maintaining flexibility for future growth and adaptation to the evolving DeFi landscape.