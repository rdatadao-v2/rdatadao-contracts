# r/datadao Smart Contract Workflow Sequence Diagrams

## Table of Contents
1. [Migration Workflows](#1-migration-workflows)
2. [Staking Workflows](#2-staking-workflows)
3. [Governance Workflows](#3-governance-workflows)
4. [Contribution Workflows](#4-contribution-workflows)
5. [Admin Workflows](#5-admin-workflows)
6. [Front-End Integration Points](#6-front-end-integration-points)

---

## 1. Migration Workflows

### 1.1 Complete V1 to V2 Token Migration

```mermaid
sequenceDiagram
    participant User
    participant Frontend
    participant BaseChain
    participant BaseBridge
    participant Validators
    participant VanaBridge
    participant VanaChain
    
    Note over User,VanaChain: User initiates migration from Base to Vana
    
    User->>Frontend: Click "Migrate Tokens"
    Frontend->>BaseChain: Check V1 balance
    BaseChain-->>Frontend: Return balance
    Frontend-->>User: Show balance & migration UI
    
    User->>Frontend: Enter amount & confirm
    Frontend->>User: Request wallet signature
    
    Note over Frontend,BaseBridge: Step 1: Initiate on Base Chain
    Frontend->>BaseBridge: approve(amount)
    BaseBridge-->>Frontend: Approval confirmed
    Frontend->>BaseBridge: initiateMigration(amount)
    BaseBridge->>BaseChain: transferFrom(user, bridge, amount)
    BaseBridge-->>Frontend: emit MigrationInitiated(burnTxHash)
    Frontend-->>User: Show "Migration initiated"
    
    Note over Validators: Step 2: Validator Consensus (Backend)
    Validators->>BaseBridge: Monitor events
    Validators->>VanaBridge: submitValidation(user, amount, burnTxHash)
    Note right of Validators: Requires 2/3 validators
    
    Note over Frontend,VanaBridge: Step 3: Challenge Period (6 hours)
    Frontend->>VanaBridge: getMigrationRequest(requestId)
    VanaBridge-->>Frontend: Return status & timeRemaining
    Frontend-->>User: Show countdown timer
    
    Note over Frontend,VanaChain: Step 4: Execute Migration
    Frontend->>VanaBridge: canExecute(requestId)
    VanaBridge-->>Frontend: true (after 6 hours)
    Frontend->>VanaBridge: executeMigration(requestId)
    VanaBridge->>VanaChain: transfer(user, amount + bonus)
    VanaBridge-->>Frontend: emit MigrationCompleted
    Frontend-->>User: Show "Migration complete!"
```

### 1.2 Migration with Early Bird Bonus

```mermaid
sequenceDiagram
    participant User
    participant Frontend
    participant VanaBridge
    participant BonusVesting
    
    Note over User,BonusVesting: Bonus calculation based on timing
    
    User->>Frontend: Check migration bonus
    Frontend->>VanaBridge: calculateBonus(amount, currentWeek)
    
    alt Week 1-2 (5% bonus)
        VanaBridge-->>Frontend: 5% bonus
    else Week 3-4 (3% bonus)
        VanaBridge-->>Frontend: 3% bonus
    else Week 5-8 (1% bonus)
        VanaBridge-->>Frontend: 1% bonus
    else After Week 8
        VanaBridge-->>Frontend: 0% bonus
    end
    
    Frontend-->>User: Display bonus amount
    
    Note over Frontend,BonusVesting: After migration execution
    VanaBridge->>BonusVesting: createVestingSchedule(user, bonusAmount)
    BonusVesting-->>Frontend: Vesting created (6mo cliff + 18mo linear)
    Frontend-->>User: Show vesting schedule
```

---

## 2. Staking Workflows

### 2.1 User Stakes Tokens

```mermaid
sequenceDiagram
    participant User
    participant Frontend
    participant RDAT
    participant StakingPositions
    participant vRDAT
    participant RewardsManager
    
    Note over User,RewardsManager: User creates staking position
    
    User->>Frontend: Navigate to Staking
    Frontend->>RDAT: balanceOf(user)
    RDAT-->>Frontend: Available balance
    Frontend->>StakingPositions: getLockMultipliers()
    StakingPositions-->>Frontend: [30d: 1x, 90d: 1.25x, 180d: 1.5x, 365d: 1.75x]
    Frontend-->>User: Show staking options
    
    User->>Frontend: Select amount & lock period
    Frontend-->>User: Show projected vRDAT & rewards
    User->>Frontend: Confirm stake
    
    Frontend->>RDAT: approve(StakingPositions, amount)
    RDAT-->>Frontend: Approval confirmed
    Frontend->>StakingPositions: stake(amount, lockPeriod)
    StakingPositions->>RDAT: transferFrom(user, StakingPositions, amount)
    StakingPositions->>StakingPositions: _mint(user, positionNFT)
    StakingPositions->>RewardsManager: notifyStake(positionId, amount, lockPeriod)
    RewardsManager->>vRDAT: mint(user, vRDATAmount)
    
    StakingPositions-->>Frontend: emit Staked(user, positionId)
    Frontend-->>User: Show position NFT & details
```

### 2.2 User Unstakes After Lock Period

```mermaid
sequenceDiagram
    participant User
    participant Frontend
    participant StakingPositions
    participant RDAT
    participant vRDAT
    participant RewardsManager
    
    Note over User,RewardsManager: User unstakes after lock expires
    
    User->>Frontend: View staking positions
    Frontend->>StakingPositions: getPositions(user)
    StakingPositions-->>Frontend: Position details array
    Frontend-->>User: Show positions with unlock times
    
    alt Position locked
        Frontend-->>User: Show time remaining
        User->>Frontend: Request emergency exit
        Frontend->>User: Warn about 50% penalty
        User->>Frontend: Confirm emergency exit
        Frontend->>StakingPositions: emergencyExit(positionId)
        StakingPositions->>vRDAT: burn(user, vRDATAmount)
        StakingPositions->>RDAT: transfer(user, amount * 50%)
        StakingPositions->>RDAT: transfer(treasury, amount * 50%)
    else Position unlocked
        User->>Frontend: Click unstake
        Frontend->>StakingPositions: unstake(positionId)
        StakingPositions->>RewardsManager: claimRewards(positionId)
        RewardsManager->>RDAT: transfer(user, rewards)
        StakingPositions->>vRDAT: burn(user, vRDATAmount)
        StakingPositions->>RDAT: transfer(user, fullAmount)
        StakingPositions->>StakingPositions: _burn(positionNFT)
    end
    
    StakingPositions-->>Frontend: emit Unstaked
    Frontend-->>User: Show transaction complete
```

### 2.3 Claiming Staking Rewards

```mermaid
sequenceDiagram
    participant User
    participant Frontend
    participant RewardsManager
    participant RewardModules
    participant RDAT
    
    Note over User,RDAT: User claims accumulated rewards
    
    User->>Frontend: View rewards
    Frontend->>RewardsManager: getClaimableRewards(user)
    RewardsManager->>RewardModules: calculateRewards(positions)
    RewardModules-->>RewardsManager: Reward amounts
    RewardsManager-->>Frontend: Total claimable
    Frontend-->>User: Show claimable rewards
    
    User->>Frontend: Claim rewards
    Frontend->>RewardsManager: claimRewards(positionIds)
    RewardsManager->>RewardModules: distributeRewards(user)
    RewardModules->>RDAT: transfer(user, rewards)
    RewardsManager-->>Frontend: emit RewardsClaimed
    Frontend-->>User: Show rewards received
```

---

## 3. Governance Workflows

### 3.1 Creating a Governance Proposal

```mermaid
sequenceDiagram
    participant User
    participant Frontend
    participant vRDAT
    participant Governor
    participant Timelock
    
    Note over User,Timelock: User creates on-chain proposal
    
    User->>Frontend: Create proposal
    Frontend->>vRDAT: balanceOf(user)
    vRDAT-->>Frontend: Voting power
    Frontend->>Governor: proposalThreshold()
    Governor-->>Frontend: Min vRDAT required
    
    alt Insufficient vRDAT
        Frontend-->>User: Need more vRDAT (show requirement)
    else Sufficient vRDAT
        User->>Frontend: Enter proposal details
        Frontend->>Frontend: Format proposal data
        User->>Frontend: Submit proposal
        Frontend->>Governor: propose(targets, values, calldatas, description)
        Governor-->>Frontend: proposalId
        Frontend-->>User: Proposal created (ID: xxx)
    end
```

### 3.2 Quadratic Voting on Proposals

```mermaid
sequenceDiagram
    participant User
    participant Frontend
    participant vRDAT
    participant Governor
    
    Note over User,Governor: Quadratic voting with vRDAT burn
    
    User->>Frontend: View active proposals
    Frontend->>Governor: getActiveProposals()
    Governor-->>Frontend: Proposal list
    Frontend-->>User: Display proposals
    
    User->>Frontend: Select proposal to vote
    Frontend->>Governor: getProposalDetails(proposalId)
    Governor-->>Frontend: Details & current votes
    Frontend->>vRDAT: balanceOf(user)
    vRDAT-->>Frontend: Available vRDAT
    
    User->>Frontend: Enter vote weight (1-100)
    Frontend->>Frontend: Calculate quadratic cost
    Note right of Frontend: Cost = weight²
    Frontend-->>User: Show cost (e.g., 100 vRDAT for 10 votes)
    
    User->>Frontend: Confirm vote
    Frontend->>Governor: castVoteWithReason(proposalId, support, weight, reason)
    Governor->>vRDAT: burn(user, quadraticCost)
    Governor-->>Frontend: emit VoteCast
    Frontend-->>User: Vote recorded
```

### 3.3 Proposal Execution

```mermaid
sequenceDiagram
    participant Anyone
    participant Frontend
    participant Governor
    participant Timelock
    participant Target
    
    Note over Anyone,Target: Anyone can execute passed proposals
    
    Anyone->>Frontend: View passed proposals
    Frontend->>Governor: getExecutableProposals()
    Governor-->>Frontend: Ready proposals list
    
    Anyone->>Frontend: Execute proposal
    Frontend->>Governor: execute(proposalId)
    Governor->>Timelock: queueTransaction()
    
    Note over Timelock: 48-hour timelock
    
    alt After timelock period
        Governor->>Timelock: executeTransaction()
        Timelock->>Target: call(data)
        Target-->>Timelock: Success
        Timelock-->>Governor: Success
        Governor-->>Frontend: emit ProposalExecuted
        Frontend-->>Anyone: Execution complete
    end
```

---

## 4. Contribution Workflows

### 4.1 Reddit Data Contribution & Validation

```mermaid
sequenceDiagram
    participant User
    participant Frontend
    participant IPFS
    participant ProofOfContribution
    participant Validators
    participant RDAT
    
    Note over User,RDAT: User contributes Reddit data for rewards
    
    User->>Frontend: Upload Reddit data export
    Frontend->>Frontend: Parse & validate format
    Frontend->>Frontend: Calculate quality score
    Note right of Frontend: Score based on posts, comments, karma
    
    Frontend->>IPFS: Upload data
    IPFS-->>Frontend: IPFS hash
    
    Frontend->>ProofOfContribution: createDataPool(ipfsHash)
    ProofOfContribution-->>Frontend: poolId
    
    Frontend->>ProofOfContribution: addDataToPool(poolId, dataHash, qualityScore)
    ProofOfContribution-->>Frontend: emit DataSubmitted
    
    Note over Validators: Validation process (backend)
    Validators->>IPFS: Retrieve & verify data
    Validators->>ProofOfContribution: validateContribution(user, contributionId)
    
    alt 2+ validators approve
        ProofOfContribution->>ProofOfContribution: Mark as verified
        ProofOfContribution-->>Frontend: emit ContributionVerified
        Frontend-->>User: Data verified ✓
    else Validation fails
        ProofOfContribution-->>Frontend: emit ContributionRejected
        Frontend-->>User: Data rejected ✗
    end
```

### 4.2 Kismet-Based Reward Distribution

```mermaid
sequenceDiagram
    participant User
    participant Frontend
    participant ProofOfContribution
    participant RDAT
    
    Note over User,RDAT: Rewards with reputation multipliers
    
    User->>Frontend: Check rewards
    Frontend->>ProofOfContribution: getUserStats(user)
    ProofOfContribution-->>Frontend: totalScore, contributions, tier
    
    Note over Frontend: Calculate Kismet Tier
    alt Score 0-2500 (Bronze)
        Frontend->>Frontend: multiplier = 1.0x
    else Score 2501-5000 (Silver)
        Frontend->>Frontend: multiplier = 1.1x
    else Score 5001-7500 (Gold)
        Frontend->>Frontend: multiplier = 1.25x
    else Score 7501+ (Platinum)
        Frontend->>Frontend: multiplier = 1.5x
    end
    
    Frontend-->>User: Show tier & multiplier
    
    User->>Frontend: Claim epoch rewards
    Frontend->>RDAT: claimEpochRewards(epochId)
    RDAT->>ProofOfContribution: getEpochScore(user, epochId)
    ProofOfContribution-->>RDAT: Score with multiplier
    RDAT->>RDAT: Calculate share of pool
    RDAT->>RDAT: transfer(user, rewards)
    RDAT-->>Frontend: emit EpochRewardsClaimed
    Frontend-->>User: Rewards received!
```

---

## 5. Admin Workflows

### 5.1 Emergency Pause

```mermaid
sequenceDiagram
    participant Admin
    participant Frontend
    participant EmergencyPause
    participant RDAT
    participant StakingPositions
    participant MigrationBridge
    
    Note over Admin,MigrationBridge: Admin pauses system for emergency
    
    Admin->>Frontend: Access admin panel
    Frontend->>EmergencyPause: isPauser(admin)
    EmergencyPause-->>Frontend: true
    
    Admin->>Frontend: Initiate emergency pause
    Frontend-->>Admin: Confirm action
    Admin->>Frontend: Confirm
    
    Frontend->>EmergencyPause: emergencyPause()
    EmergencyPause->>RDAT: pause()
    EmergencyPause->>StakingPositions: pause()
    EmergencyPause->>MigrationBridge: pause()
    EmergencyPause-->>Frontend: emit EmergencyPaused(duration: 72hrs)
    
    Frontend-->>Admin: System paused for 72 hours
    
    Note over EmergencyPause: Auto-unpause after 72 hours
    
    alt Manual unpause before expiry
        Admin->>Frontend: Unpause system
        Frontend->>EmergencyPause: emergencyUnpause()
        EmergencyPause->>RDAT: unpause()
        EmergencyPause->>StakingPositions: unpause()
        EmergencyPause->>MigrationBridge: unpause()
    end
```

### 5.2 Contract Upgrade (UUPS)

```mermaid
sequenceDiagram
    participant Admin
    participant Frontend
    participant Governor
    participant Timelock
    participant ProxyAdmin
    participant RDATProxy
    
    Note over Admin,RDATProxy: Admin upgrades RDAT contract
    
    Admin->>Frontend: Propose upgrade
    Frontend->>Frontend: Validate new implementation
    Admin->>Frontend: Submit upgrade proposal
    
    Frontend->>Governor: propose(upgrade targets, calldata)
    Governor-->>Frontend: proposalId
    
    Note over Governor: Voting period (1 week)
    
    alt Proposal passes
        Frontend->>Governor: queue(proposalId)
        Governor->>Timelock: schedule upgrade
        
        Note over Timelock: 48-hour delay
        
        Frontend->>Governor: execute(proposalId)
        Governor->>Timelock: execute
        Timelock->>ProxyAdmin: upgrade(proxy, newImplementation)
        ProxyAdmin->>RDATProxy: upgradeTo(newImplementation)
        RDATProxy-->>Frontend: emit Upgraded
        Frontend-->>Admin: Upgrade complete
    end
```

### 5.3 Treasury Distribution

```mermaid
sequenceDiagram
    participant Admin
    participant Frontend
    participant TreasuryWallet
    participant RDAT
    participant Recipients
    
    Note over Admin,Recipients: Admin distributes treasury funds
    
    Admin->>Frontend: Access treasury panel
    Frontend->>TreasuryWallet: getVestingSchedules()
    TreasuryWallet-->>Frontend: Active schedules
    Frontend->>TreasuryWallet: getReleasableAmount()
    TreasuryWallet-->>Frontend: Available to distribute
    Frontend-->>Admin: Show treasury status
    
    Admin->>Frontend: Create distribution
    Admin->>Frontend: Add recipients & amounts
    Note right of Admin: Team, advisors, community
    
    Admin->>Frontend: Execute distribution
    Frontend->>TreasuryWallet: distribute(recipients, amounts, vestingParams)
    
    loop For each recipient
        TreasuryWallet->>TreasuryWallet: Create vesting schedule
        TreasuryWallet->>RDAT: transfer(recipient, initialRelease)
    end
    
    TreasuryWallet-->>Frontend: emit DistributionExecuted
    Frontend-->>Admin: Distribution complete
```

### 5.4 Validator Management

```mermaid
sequenceDiagram
    participant Admin
    participant Frontend
    participant VanaBridge
    
    Note over Admin,VanaBridge: Admin manages bridge validators
    
    Admin->>Frontend: Access validator settings
    Frontend->>VanaBridge: getValidators()
    VanaBridge-->>Frontend: Current validator list
    Frontend-->>Admin: Show validators
    
    alt Add validator
        Admin->>Frontend: Add new validator address
        Frontend->>VanaBridge: addValidator(address)
        VanaBridge-->>Frontend: emit ValidatorAdded
    else Remove validator
        Admin->>Frontend: Select validator to remove
        Frontend->>VanaBridge: validatorCount()
        VanaBridge-->>Frontend: count
        alt count > MIN_VALIDATORS
            Frontend->>VanaBridge: removeValidator(address)
            VanaBridge-->>Frontend: emit ValidatorRemoved
        else count <= MIN_VALIDATORS
            Frontend-->>Admin: Cannot remove (min validators required)
        end
    end
    
    Frontend-->>Admin: Validator list updated
```

---

## 6. Front-End Integration Points

### 6.1 Key Smart Contract Interactions

| Workflow | Contract | Key Methods | Events to Monitor |
|----------|----------|-------------|-------------------|
| **Migration** | BaseMigrationBridge | `initiateMigration()` | `MigrationInitiated` |
| | VanaMigrationBridge | `executeMigration()`, `calculateBonus()` | `MigrationCompleted` |
| **Staking** | StakingPositions | `stake()`, `unstake()`, `emergencyExit()` | `Staked`, `Unstaked` |
| | RewardsManager | `claimRewards()`, `getClaimableRewards()` | `RewardsClaimed` |
| **Governance** | Governor | `propose()`, `castVote()`, `execute()` | `ProposalCreated`, `VoteCast` |
| | vRDAT | `balanceOf()`, `burn()` | `Transfer` |
| **Contribution** | ProofOfContribution | `createDataPool()`, `addDataToPool()` | `DataSubmitted`, `ContributionVerified` |
| | RDAT | `claimEpochRewards()` | `EpochRewardsClaimed` |
| **Admin** | EmergencyPause | `emergencyPause()`, `emergencyUnpause()` | `EmergencyPaused` |
| | TreasuryWallet | `distribute()`, `checkAndRelease()` | `DistributionExecuted` |

### 6.2 Frontend State Management

```typescript
// Key state to track
interface UserState {
  // Balances
  rdatBalance: BigNumber;
  vrdatBalance: BigNumber;
  v1TokenBalance: BigNumber;
  
  // Positions
  stakingPositions: Position[];
  migrationStatus: MigrationStatus;
  
  // Rewards
  claimableRewards: BigNumber;
  epochParticipation: Map<number, boolean>;
  kismetTier: 'Bronze' | 'Silver' | 'Gold' | 'Platinum';
  
  // Governance
  votingPower: BigNumber;
  activeProposals: Proposal[];
  delegatedTo: Address;
}

interface SystemState {
  paused: boolean;
  currentEpoch: number;
  migrationDeadline: Date;
  dailyMigrationLimit: BigNumber;
  dailyMigrationUsed: BigNumber;
}
```

### 6.3 Critical User Flows

1. **First-Time User**:
   - Connect wallet → Check V1 balance → Migrate → Stake → Participate in governance

2. **Returning User**:
   - Check positions → Claim rewards → Vote on proposals → Manage stakes

3. **Data Contributor**:
   - Submit data → Wait for validation → Check tier → Claim epoch rewards

4. **Admin**:
   - Monitor system → Respond to emergencies → Execute treasury operations → Manage validators

### 6.4 Error Handling

```typescript
// Common errors to handle
enum ContractError {
  INSUFFICIENT_BALANCE = "Insufficient balance",
  MIGRATION_DEADLINE_PASSED = "Migration deadline passed",
  POSITION_LOCKED = "Position still locked",
  DAILY_LIMIT_EXCEEDED = "Daily migration limit exceeded",
  NOT_AUTHORIZED = "Not authorized",
  PAUSED = "System is paused",
  INVALID_LOCK_PERIOD = "Invalid lock period",
  ALREADY_CLAIMED = "Already claimed",
  BELOW_MIN_STAKE = "Below minimum stake",
  CHALLENGE_PERIOD_ACTIVE = "Challenge period active"
}
```

### 6.5 Event Monitoring Setup

```javascript
// Critical events to monitor
const eventFilters = {
  // Migration events
  migrationInitiated: baseBridge.filters.MigrationInitiated(),
  migrationCompleted: vanaBridge.filters.MigrationCompleted(),
  
  // Staking events
  staked: stakingPositions.filters.Staked(),
  unstaked: stakingPositions.filters.Unstaked(),
  
  // Governance events
  proposalCreated: governor.filters.ProposalCreated(),
  voteCast: governor.filters.VoteCast(),
  proposalExecuted: governor.filters.ProposalExecuted(),
  
  // System events
  emergencyPaused: emergencyPause.filters.EmergencyPaused(),
  upgraded: proxy.filters.Upgraded()
};
```

---

## Implementation Checklist

### Frontend Components Needed

- [ ] **Migration Widget**: Balance check, amount input, bonus calculator, status tracker
- [ ] **Staking Dashboard**: Position cards, lock period selector, rewards tracker
- [ ] **Governance Portal**: Proposal list, voting interface, delegation manager
- [ ] **Contribution Hub**: Data upload, quality scorer, tier display
- [ ] **Admin Panel**: Emergency controls, treasury manager, validator settings
- [ ] **User Profile**: Balance overview, position summary, reward history

### Required Integrations

- [ ] **Wallet Connection**: MetaMask, WalletConnect, Coinbase Wallet
- [ ] **Multi-chain Support**: Base & Vana network switching
- [ ] **IPFS**: Data storage for contributions
- [ ] **Event Indexer**: Real-time updates via events
- [ ] **Price Feeds**: For USD value displays
- [ ] **Analytics**: User behavior tracking

### Security Considerations

- [ ] Input validation on all user inputs
- [ ] Proper error handling and user feedback
- [ ] Transaction confirmation dialogs
- [ ] Slippage protection for swaps
- [ ] Rate limiting on API calls
- [ ] Secure admin authentication

---

## Appendix: Contract Addresses

```javascript
// Mainnet Addresses (to be deployed)
const contracts = {
  base: {
    v1Token: "0x...",
    baseMigrationBridge: "0x..."
  },
  vana: {
    rdatToken: "0x...",
    vrdatToken: "0x...",
    stakingPositions: "0x...",
    vanaMigrationBridge: "0x...",
    governor: "0x...",
    treasuryWallet: "0x...",
    rewardsManager: "0x...",
    proofOfContribution: "0x...",
    emergencyPause: "0x..."
  }
};
```