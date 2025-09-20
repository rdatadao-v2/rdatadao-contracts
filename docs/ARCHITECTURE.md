# System Architecture

**Last Updated**: September 20, 2025
**Version**: 3.2 - Mainnet

## 🏗️ High-Level Architecture

### System Overview
```
┌─────────────────────────────────────────────────────────┐
│                    User Layer                            │
│         (Wallets, dApps, Governance Portal)              │
└─────────────────┬───────────────────────────────────────┘
                  │
┌─────────────────┴───────────────────────────────────────┐
│                  Token Layer                             │
│   RDATUpgradeable (100M) ─── vRDAT (Soul-bound)         │
└─────────────────┬───────────────────────────────────────┘
                  │
┌─────────────────┴───────────────────────────────────────┐
│                 Economic Layer                           │
│  Treasury (70M) ─── Migration (30M) ─── Staking         │
└─────────────────┬───────────────────────────────────────┘
                  │
┌─────────────────┴───────────────────────────────────────┐
│                Infrastructure Layer                      │
│   Bridge ─── DLP ─── Rewards ─── Governance            │
└─────────────────────────────────────────────────────────┘
```

## 💰 Token Economics Architecture

### Supply Distribution
```
Total Supply: 100,000,000 RDAT (Fixed, Immutable)
│
├── Treasury: 70,000,000 (70%)
│   ├── Team Vesting: 10,000,000
│   │   └── 6-month cliff + 18-month linear
│   ├── Development Fund: 20,000,000
│   │   └── DAO-controlled immediate access
│   ├── Community Rewards: 30,000,000
│   │   └── Phase 3 activation (locked)
│   └── Strategic Reserve: 10,000,000
│       └── Emergency/Partnerships
│
└── Migration Pool: 30,000,000 (30%)
    └── 1:1 exchange for V1 holders
```

### Token Flow Architecture
```
V1 Holders (Base) ──┐
                    ├──> Migration Bridge ──> V2 Holders (Vana)
                    │         │
                    │         └──> Burn V1 tokens
                    │
Treasury (Vana) ────┼──> Vesting Contracts ──> Recipients
                    │
                    └──> Reward Pools ──> Stakers
```

## 🔐 Security Architecture

### Access Control Hierarchy
```
Multisig (3/5 signers)
├── DEFAULT_ADMIN_ROLE
│   ├── Contract upgrades
│   ├── Treasury management
│   └── Critical parameters
├── PAUSER_ROLE (2/5 signers)
│   ├── Emergency pause
│   └── System freeze (72hr max)
└── Individual Roles
    ├── TREASURY_ROLE (Treasury contract only)
    ├── MINTER_ROLE (Not used - fixed supply)
    └── VALIDATOR_ROLE (Migration signatures)
```

### Upgrade Pattern (UUPS)
```
Proxy Contract ──────> Implementation V1
      │                        │
      │ upgrade()             │
      ↓                        ↓
Proxy Contract ──────> Implementation V2
```

**Upgradeable Contracts**:
- RDATUpgradeable (Token)
- TreasuryWallet
- RewardsManager

**Non-Upgradeable Contracts** (Security through immutability):
- StakingPositions
- VanaMigrationBridge
- BaseMigrationBridge
- vRDAT

## 🌉 Cross-Chain Architecture

### Migration Flow
```
Base Network                    Vana Network
─────────────                   ─────────────

User                           User
 │                              │
 ├─1. Approve V1──>             │
 │                              │
 ├─2. Lock tokens──>            │
 │                              │
BaseMigrationBridge             │
 │                              │
 ├─3. Emit Event──>             │
 │                              │
 └─4. Burn V1──────>            │
                                │
Backend Service                 │
 │                              │
 ├─5. Collect sigs──>           │
 │                              │
Validators (2/3)                │
 │                              │
 └─6. Sign migration──>         │
                                │
                                ├─7. Submit sigs──>
                                │
                                VanaMigrationBridge
                                │
                                ├─8. Verify sigs──>
                                │
                                ├─9. Mint V2──>
                                │
                                └─10. Transfer──> User
```

### Validator Architecture
```
Validator Set (2/3 required)
├── Validator 1: Angela (Dev)
│   └── 0xd36B49f2DB6aA708Ce7245e8ab2453C6DfFc9d6f
├── Validator 2: monkfenix.eth
│   └── 0xC9Af4E56741f255743e8f4877d4cfa9971E910C2
└── Validator 3: Base Multisig
    └── 0x08Cc5ed1bA3C95AA741f8AaEf631f716b037444b
```

## 🏆 Staking Architecture (Phase 2)

### Staking System Design
```
User Stakes RDAT
       │
       ├──> StakingPositions Contract
       │           │
       │           ├──> Creates NFT Position
       │           │         │
       │           │         ├── Amount
       │           │         ├── Duration (30/90/180/365)
       │           │         ├── Multiplier (1x-1.75x)
       │           │         └── Timestamp
       │           │
       │           └──> Notifies RewardsManager
       │                       │
       └──> Receives vRDAT     ├──> vRDATRewardModule
                               │         │
                               │         └──> Mints vRDAT
                               │
                               └──> Other Reward Modules
```

### NFT Position Structure
```solidity
struct Position {
    uint256 amount;        // RDAT staked
    uint256 startTime;     // Stake timestamp
    uint256 lockDuration;  // 30/90/180/365 days
    uint256 multiplier;    // 100/115/135/175 (1x-1.75x)
    address owner;         // Position owner
    bool active;           // Active status
}
```

## 🗳️ Governance Architecture (Phase 2)

### Governance Flow
```
Proposal Creation ──> Voting Period ──> Timelock ──> Execution
        │                   │              │            │
   Need 10k vRDAT      3 day period    48hr delay   Automatic
        │                   │              │            │
   Store on-chain      Quadratic vote   Security    Anyone can
                       (burn vRDAT)      review      execute
```

### Contract Interaction
```
GovernanceCore
     │
     ├──> GovernanceVoting
     │         │
     │         └──> vRDAT (voting power)
     │
     └──> GovernanceExecution
               │
               └──> TimelockController ──> Target Contracts
```

## 💎 Rewards Architecture

### Modular Rewards System
```
RewardsManager (UUPS Upgradeable)
     │
     ├──> Module Registry
     │         │
     │         ├──> vRDATRewardModule (Active)
     │         ├──> RDATRewardModule (Phase 3)
     │         ├──> PartnerRewardModule (Future)
     │         └──> NFTRewardModule (Future)
     │
     └──> Distribution Logic
               │
               ├──> Calculate rewards
               ├──> Track claims
               └──> Handle withdrawals
```

### Revenue Flow
```
Revenue Sources
     │
     └──> RevenueCollector
               │
               ├──> 50% Staking Rewards Pool
               ├──> 30% Treasury
               └──> 20% Contributor Pool
```

## 🔧 Smart Contract Deployment Architecture

### CREATE2 Deployment Pattern
```
1. Calculate deterministic addresses
        │
        └──> Salt + Bytecode = Address
                    │
2. Deploy contracts in order
        │
        ├──> TreasuryWallet (needs RDAT address)
        ├──> MigrationBridge (needs RDAT address)
        └──> RDATUpgradeable (via CREATE2)
                    │
                    └──> Mints 70M to Treasury
                    └──> Mints 30M to Bridge
```

### Deployment Dependencies
```
Create2Factory
     │
     └──> RDATUpgradeable ──────┐
                                 │
TreasuryWallet <─────────────────┤
     │                          │
     └──> Vesting Contracts     │
                                 │
VanaMigrationBridge <────────────┘
     │
     └──> Validator Set

RDATDataDAO
     │
     └──> DLP Registry (ID: 40)
```

## 📊 Data Layer Architecture

### On-Chain Data
```
Blockchain State
├── Token Balances
├── Staking Positions (NFTs)
├── Governance Proposals
├── Migration Records
└── Vesting Schedules
```

### Off-Chain Data
```
Backend Services
├── Migration Signatures
├── Analytics/Metrics
├── Price Feeds
├── User Profiles
└── Historical Data
```

### DLP Integration
```
Vana Network
     │
     └──> DLP Registry
               │
               └──> RDATDataDAO (ID: 40)
                         │
                         ├──> Data Contributions
                         └──> Reward Distribution
```

## 🚨 Emergency Architecture

### Pause Mechanism
```
Emergency Detected
     │
     ├──> Admin calls pause()
     │         │
     │         └──> All transfers halted
     │
     ├──> 72-hour countdown starts
     │         │
     │         └──> Auto-unpause after expiry
     │
     └──> Fix deployed via upgrade
               │
               └──> Manual unpause()
```

### Circuit Breakers
- Transfer limits
- Staking caps
- Withdrawal delays
- Governance timelocks

## 🔄 Phase Migration Architecture

### Phase 1 → Phase 2
```
Current State (Phase 1)          Target State (Phase 2)
─────────────────────            ─────────────────────
Token (Live) ─────────────────> Token + Staking
Treasury (Live) ──────────────> Treasury + Vesting Active
Migration (Live) ─────────────> Migration + Bonus Rewards
Basic Transfer ───────────────> Transfer + Governance
```

### Phase 2 → Phase 3
```
Phase 2 State                    Phase 3 State
─────────────                    ─────────────
Manual Governance ────────────> Automated DAO
Fixed Rewards ────────────────> Dynamic Rewards
Single Token ─────────────────> Multi-Token Revenue
Limited DLP ──────────────────> Full Data Marketplace
```

## 📈 Monitoring Architecture

### System Health Metrics
```
Monitoring Dashboard
     │
     ├──> Contract Metrics
     │     ├── Token supply/transfers
     │     ├── TVL in staking
     │     └── Migration progress
     │
     ├──> Performance Metrics
     │     ├── Gas usage
     │     ├── Transaction success rate
     │     └── Response times
     │
     └──> Security Metrics
           ├── Unusual patterns
           ├── Large transfers
           └── Failed transactions
```

### Alert System
```
Event Monitors ──> Alert Rules ──> Notification Channels
                         │                  │
                    Thresholds         Discord/Email
                         │                  │
                    Severity          Admin/Public
```

## 🔒 Security Considerations

### Attack Vectors & Mitigations
| Vector | Risk | Mitigation |
|--------|------|------------|
| Reentrancy | High | ReentrancyGuard on all external calls |
| Flash Loan | Medium | Soul-bound vRDAT prevents gaming |
| Front-running | Medium | Commit-reveal for sensitive operations |
| DoS | Low | Position limits, gas optimization |
| Upgrade Risk | High | UUPS pattern, timelock, multisig |

### Audit Trail
- Hashlock audit completed (September 2025)
- All HIGH/MEDIUM/LOW findings remediated
- Continuous monitoring post-deployment
- Bug bounty program active

## 📚 Technical Stack

### Smart Contracts
- **Language**: Solidity 0.8.19
- **Framework**: Foundry
- **Libraries**: OpenZeppelin 4.9.0
- **Pattern**: UUPS Upgradeable

### Infrastructure
- **Primary Chain**: Vana (Chain ID: 1480)
- **Secondary Chain**: Base (Chain ID: 8453)
- **RPC**: Vana official RPC
- **Explorer**: Vanascan.io

### Development Tools
- **Testing**: Forge test suite
- **Coverage**: 100% (382 tests)
- **CI/CD**: GitHub Actions
- **Deployment**: Forge scripts

## 🎯 Future Architecture Considerations

### Scalability
- Layer 2 integration
- Cross-chain expansion
- Sharding preparation

### Interoperability
- Bridge to more chains
- Standard token wrapping
- Cross-chain governance

### Decentralization
- Progressive decentralization
- Validator expansion
- Community nodes

### Innovation
- ZK proof integration
- AI/ML for data validation
- Advanced DeFi features