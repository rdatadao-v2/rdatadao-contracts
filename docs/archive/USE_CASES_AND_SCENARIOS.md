# r/datadao Use Cases and Scenarios

## Table of Contents
1. [Token Deployment Epic](#1-token-deployment-epic)
2. [Token Migration Epic](#2-token-migration-epic)
3. [Token Administration Epic](#3-token-administration-epic)
4. [Data Contribution Epic](#4-data-contribution-epic)
5. [Token Staking Epic](#5-token-staking-epic)
6. [DAO Governance Epic](#6-dao-governance-epic)

---

## 1. Token Deployment Epic

### Use Cases

**UC-1.1: Initial Token Deployment**
- **As a** DAO administrator
- **I want to** deploy the RDAT token with fixed supply
- **So that** the token ecosystem can begin operating with predictable tokenomics

**UC-1.2: Treasury Initialization**
- **As a** DAO administrator
- **I want to** initialize the treasury with 70M tokens
- **So that** funds are secured for future DAO operations and distributions

**UC-1.3: Migration Bridge Setup**
- **As a** DAO administrator
- **I want to** allocate 30M tokens to the migration bridge
- **So that** V1 token holders can migrate to V2

**UC-1.4: Contract Verification**
- **As a** DAO administrator
- **I want to** verify all deployed contracts on block explorers
- **So that** the community can inspect and trust the code

### Scenarios

**Scenario 1.1: Successful Token Deployment**
```gherkin
Given the deployment script is configured with correct parameters
  AND the deployer has sufficient gas on Vana network
  AND CREATE2 factory is deployed
When the deployment script is executed
Then RDAT token is deployed with 100M fixed supply
  AND 70M tokens are transferred to TreasuryWallet
  AND 30M tokens are transferred to VanaMigrationBridge
  AND the deployer cannot mint additional tokens
```

**Scenario 1.2: Treasury Vesting Schedule Creation**
```gherkin
Given the TreasuryWallet has received 70M RDAT tokens
  AND the admin has DEFAULT_ADMIN_ROLE
When the admin calls createVestingSchedule()
Then vesting schedules are created for team (10M tokens)
  AND vesting schedules are created for advisors (5M tokens)
  AND vesting schedules are created for community rewards (20M tokens)
  AND remaining tokens stay in treasury for DAO governance
```

**Scenario 1.3: Failed Deployment - Insufficient Gas**
```gherkin
Given the deployment script is properly configured
  AND the deployer has insufficient gas
When the deployment script is executed
Then the transaction reverts with "insufficient funds"
  AND no contracts are deployed
  AND no tokens are minted
```

---

## 2. Token Migration Epic

### Use Cases

**UC-2.1: Standard Token Migration**
- **As a** V1 token holder
- **I want to** migrate my tokens from Base to Vana
- **So that** I can participate in the new ecosystem

**UC-2.2: Early Bird Migration**
- **As a** V1 token holder
- **I want to** migrate early to receive bonus tokens
- **So that** I can maximize my holdings

**UC-2.3: Migration Status Tracking**
- **As a** V1 token holder
- **I want to** track my migration request status
- **So that** I know when my tokens will be available

**UC-2.4: Emergency Migration Cancellation**
- **As a** V1 token holder
- **I want to** cancel my migration during the challenge period
- **So that** I can recover from mistakes

### Scenarios

**Scenario 2.1: Successful Standard Migration**
```gherkin
Given a user holds 1000 V1 tokens on Base
  AND the user has approved the BaseMigrationBridge
  AND the migration deadline has not passed
When the user calls initiateMigration(1000)
  AND validators submit 2+ confirmations
  AND 6 hour challenge period passes
Then the user receives 1000 V2 tokens on Vana
  AND the V1 tokens are locked in BaseMigrationBridge
  AND MigrationCompleted event is emitted
```

**Scenario 2.2: Early Bird Bonus Migration (Week 1)**
```gherkin
Given a user holds 10000 V1 tokens
  AND the current time is within week 1 of migration
  AND the user has approved the bridge
When the user initiates migration
  AND the migration is executed after challenge period
Then the user receives 10000 V2 tokens immediately
  AND the user receives 500 bonus tokens (5%)
  AND bonus tokens are vested (6 month cliff + 18 month linear)
```

**Scenario 2.3: Migration with Daily Limit Exceeded**
```gherkin
Given the daily migration limit is 1M tokens
  AND 900k tokens have been migrated today
  AND a user attempts to migrate 200k tokens
When the user calls initiateMigration(200000)
Then the transaction reverts with "DailyLimitExceeded"
  AND the user's tokens remain on Base
  AND the user must wait until next day
```

**Scenario 2.4: Migration Challenge by Validator**
```gherkin
Given a user has initiated migration of 5000 tokens
  AND the migration is in challenge period
  AND a validator detects suspicious activity
When the validator calls challengeMigration(requestId)
Then the migration is paused
  AND the dispute resolution process begins
  AND other validators vote on the challenge
  AND if challenge succeeds, migration is cancelled
```

**Scenario 2.5: Migration After Deadline**
```gherkin
Given the migration deadline is January 1, 2025
  AND the current date is January 2, 2025
  AND a user holds V1 tokens
When the user attempts to initiate migration
Then the transaction reverts with "MigrationDeadlinePassed"
  AND the user cannot migrate tokens
  AND remaining bridge tokens are returned to treasury
```

---

## 3. Token Administration Epic

### Use Cases

**UC-3.1: Emergency System Pause**
- **As a** security admin
- **I want to** pause all critical operations
- **So that** I can prevent damage during security incidents

**UC-3.2: Contract Upgrade**
- **As a** DAO admin
- **I want to** upgrade UUPS contracts
- **So that** bugs can be fixed and features added

**UC-3.3: Treasury Distribution**
- **As a** treasury admin
- **I want to** distribute tokens to approved recipients
- **So that** team and community allocations are fulfilled

**UC-3.4: Validator Management**
- **As a** bridge admin
- **I want to** add or remove validators
- **So that** the bridge remains secure and operational

### Scenarios

**Scenario 3.1: Emergency Pause Activation**
```gherkin
Given a critical vulnerability is discovered
  AND the admin has PAUSER_ROLE
  AND the system is currently unpaused
When the admin calls emergencyPause()
Then all token transfers are paused
  AND all staking operations are paused
  AND all migration operations are paused
  AND EmergencyPaused event is emitted with 72hr duration
  AND system automatically unpauses after 72 hours
```

**Scenario 3.2: UUPS Contract Upgrade**
```gherkin
Given a new RDAT implementation is deployed
  AND the upgrade proposal has passed governance
  AND 48 hour timelock has expired
When the admin executes the upgrade
Then the proxy points to new implementation
  AND all storage is preserved
  AND new features are available
  AND Upgraded event is emitted
```

**Scenario 3.3: Treasury Vesting Distribution**
```gherkin
Given the treasury has created vesting schedules
  AND 6 months have passed (cliff period)
  AND a team member is entitled to tokens
When checkAndRelease() is called for the team member
Then the cliff amount (25%) is released immediately
  AND monthly vesting begins for remaining 75%
  AND tokens are transferred to team member
  AND VestingReleased event is emitted
```

**Scenario 3.4: Adding New Validator**
```gherkin
Given the bridge has 3 active validators
  AND admin has ADMIN_ROLE on VanaMigrationBridge
  AND new validator address is not already registered
When admin calls addValidator(newValidatorAddress)
Then the validator is added to validator set
  AND validator count increases to 4
  AND ValidatorAdded event is emitted
  AND new validator can submit migration validations
```

---

## 4. Data Contribution Epic

### Use Cases

**UC-4.1: Reddit Data Submission**
- **As a** Reddit user
- **I want to** contribute my Reddit data archive
- **So that** I can earn RDAT rewards

**UC-4.2: Data Quality Verification**
- **As a** data contributor
- **I want to** have my data quality scored
- **So that** I receive fair rewards based on contribution value

**UC-4.3: Kismet Tier Progression**
- **As a** regular contributor
- **I want to** progress through Kismet tiers
- **So that** I earn higher reward multipliers

**UC-4.4: Epoch Reward Claims**
- **As a** data contributor
- **I want to** claim my epoch rewards
- **So that** I receive RDAT for my contributions

### Scenarios

**Scenario 4.1: First-Time Data Contribution**
```gherkin
Given a user has downloaded their Reddit data archive
  AND the user has connected their wallet
  AND the ProofOfContribution contract is active
When the user uploads the data file
  AND the frontend validates format and calculates quality score
  AND the data is uploaded to IPFS
Then a data pool is created with IPFS hash
  AND DataSubmitted event is emitted
  AND validators begin verification process
  AND user's contribution is pending validation
```

**Scenario 4.2: High-Quality Data Validation**
```gherkin
Given a user submitted data with 10000 karma
  AND the data includes 500 posts and 2000 comments
  AND 2+ validators have reviewed the data
When validators call validateContribution(contributionId)
Then the contribution is marked as verified
  AND quality score of 9500 is assigned
  AND user progresses to Gold tier (5001-7500 range)
  AND ContributionVerified event is emitted
```

**Scenario 4.3: Kismet Tier Upgrade**
```gherkin
Given a user is currently in Silver tier (2501-5000)
  AND user has accumulated 5100 total score
  AND new contribution is validated
When the system updates user statistics
Then user is promoted to Gold tier
  AND reward multiplier increases from 1.1x to 1.25x
  AND TierUpgraded event is emitted
  AND future rewards use new multiplier
```

**Scenario 4.4: Epoch Reward Distribution**
```gherkin
Given epoch 5 has ended
  AND user contributed 3 validated datasets in epoch 5
  AND user is in Platinum tier (1.5x multiplier)
  AND epoch reward pool is 100,000 RDAT
When user calls claimEpochRewards(5)
Then user's share is calculated based on contribution score
  AND 1.5x multiplier is applied to base rewards
  AND RDAT tokens are transferred to user
  AND EpochRewardsClaimed event is emitted
```

**Scenario 4.5: Invalid Data Rejection**
```gherkin
Given a user submits corrupted or fake data
  AND validators detect inconsistencies
  AND 2+ validators flag the contribution
When validators call rejectContribution(contributionId)
Then contribution is marked as rejected
  AND no rewards are allocated
  AND user's reputation score decreases
  AND ContributionRejected event is emitted
```

---

## 5. Token Staking Epic

### Use Cases

**UC-5.1: Standard Token Staking**
- **As a** token holder
- **I want to** stake my RDAT tokens
- **So that** I earn rewards and governance power

**UC-5.2: Lock Period Selection**
- **As a** staker
- **I want to** choose my lock period
- **So that** I can optimize rewards vs liquidity needs

**UC-5.3: Reward Claiming**
- **As a** staker
- **I want to** claim accumulated rewards
- **So that** I can compound or use earned tokens

**UC-5.4: Emergency Withdrawal**
- **As a** staker
- **I want to** emergency withdraw if needed
- **So that** I can access funds in critical situations

### Scenarios

**Scenario 5.1: Creating 30-Day Staking Position**
```gherkin
Given a user holds 1000 RDAT tokens
  AND user has approved StakingPositions contract
  AND user selects 30-day lock period
When user calls stake(1000, 30 days)
Then 1000 RDAT is transferred to StakingPositions
  AND NFT position #1 is minted to user
  AND 1000 vRDAT is minted to user (1x multiplier)
  AND position cannot be unstaked for 30 days
  AND Staked event is emitted
```

**Scenario 5.2: Creating 365-Day Staking Position**
```gherkin
Given a user holds 10000 RDAT tokens
  AND user wants maximum rewards
  AND user selects 365-day lock period
When user calls stake(10000, 365 days)
Then 10000 RDAT is locked in contract
  AND NFT position is minted
  AND 17500 vRDAT is minted (1.75x multiplier)
  AND position cannot be unstaked for 365 days
  AND higher reward rate is applied
```

**Scenario 5.3: Claiming Staking Rewards**
```gherkin
Given a user has staking position #42
  AND position has been staked for 60 days
  AND 500 RDAT rewards have accumulated
When user calls claimRewards(42)
Then RewardsManager calculates claimable amount
  AND 500 RDAT is transferred to user
  AND reward balance resets to 0
  AND RewardsClaimed event is emitted
  AND staking position remains active
```

**Scenario 5.4: Normal Unstaking After Lock**
```gherkin
Given user has position #10 with 5000 RDAT
  AND 90-day lock period has expired
  AND position has 200 RDAT unclaimed rewards
When user calls unstake(10)
Then rewards are automatically claimed (200 RDAT)
  AND 5000 RDAT principal is returned
  AND 6250 vRDAT is burned (1.25x for 90 days)
  AND NFT position #10 is burned
  AND Unstaked event is emitted
```

**Scenario 5.5: Emergency Withdrawal with Penalty**
```gherkin
Given user has position #25 with 10000 RDAT
  AND only 15 days of 180-day lock have passed
  AND user needs immediate liquidity
When user calls emergencyWithdraw(25)
Then 50% penalty is applied
  AND user receives 5000 RDAT (50% of principal)
  AND 5000 RDAT goes to treasury (50% penalty)
  AND all vRDAT is immediately burned
  AND position NFT is burned
  AND EmergencyWithdrawal event is emitted
```

**Scenario 5.6: Multiple Positions Management**
```gherkin
Given a user has 30000 RDAT tokens
  AND user wants to ladder positions
When user creates multiple positions:
  AND stakes 10000 RDAT for 30 days (position #1)
  AND stakes 10000 RDAT for 90 days (position #2)
  AND stakes 10000 RDAT for 180 days (position #3)
Then user holds 3 NFT positions
  AND user has 10000 + 12500 + 15000 = 37500 vRDAT
  AND each position unlocks at different times
  AND rewards accumulate independently
```

---

## 6. DAO Governance Epic

### Use Cases

**UC-6.1: Proposal Creation**
- **As a** vRDAT holder
- **I want to** create governance proposals
- **So that** I can influence DAO decisions

**UC-6.2: Quadratic Voting**
- **As a** vRDAT holder
- **I want to** vote with variable weight
- **So that** I can express preference intensity

**UC-6.3: Proposal Execution**
- **As a** community member
- **I want to** execute passed proposals
- **So that** governance decisions are implemented

**UC-6.4: Delegation**
- **As a** vRDAT holder
- **I want to** delegate my voting power
- **So that** experts can vote on my behalf

### Scenarios

**Scenario 6.1: Creating Treasury Allocation Proposal**
```gherkin
Given a user holds 10000 vRDAT
  AND proposal threshold is 5000 vRDAT
  AND user wants to propose 1M RDAT for development
When user calls propose() with:
  AND target: TreasuryWallet
  AND calldata: transfer(1M RDAT to dev fund)
  AND description: "Q1 2025 Development Budget"
Then proposal #1 is created
  AND 1-day voting delay begins
  AND ProposalCreated event is emitted
  AND proposal enters Pending state
```

**Scenario 6.2: Quadratic Voting on Proposal**
```gherkin
Given proposal #5 is in Active voting state
  AND user holds 10000 vRDAT
  AND user wants to vote with strength 50
When user calls castVote(5, FOR, 50)
Then quadratic cost = 50² = 2500 vRDAT
  AND 2500 vRDAT is burned from user
  AND 50 votes are counted FOR proposal
  AND VoteCast event is emitted
  AND user has 7500 vRDAT remaining
```

**Scenario 6.3: Proposal Reaching Quorum**
```gherkin
Given proposal #3 has been active for 7 days
  AND proposal received 1M votes FOR
  AND proposal received 400K votes AGAINST
  AND quorum requirement is 1M total votes
When voting period ends
Then proposal state changes to Succeeded
  AND proposal enters 48-hour timelock
  AND ProposalQueued event is emitted
  AND anyone can execute after timelock
```

**Scenario 6.4: Executing Passed Proposal**
```gherkin
Given proposal #7 is in Succeeded state
  AND 48-hour timelock has expired
  AND proposal allocates 500K RDAT for marketing
When anyone calls execute(7)
Then timelock executes the transaction
  AND TreasuryWallet transfers 500K RDAT
  AND proposal state changes to Executed
  AND ProposalExecuted event is emitted
```

**Scenario 6.5: Delegating Voting Power**
```gherkin
Given Alice holds 5000 vRDAT
  AND Bob is a governance expert
  AND Alice trusts Bob's judgment
When Alice calls delegate(Bob)
Then Bob's voting power increases by 5000
  AND Alice retains token ownership
  AND Alice cannot vote directly
  AND DelegateChanged event is emitted
  AND Bob can vote using Alice's power
```

**Scenario 6.6: Failed Proposal**
```gherkin
Given proposal #9 is in Active state
  AND voting period is 7 days
  AND proposal received 800K votes FOR
  AND proposal received 1.2M votes AGAINST
When voting period ends
Then proposal state changes to Defeated
  AND proposal cannot be executed
  AND ProposalDefeated event is emitted
  AND no on-chain changes occur
```

**Scenario 6.7: Emergency Governance Action**
```gherkin
Given a critical bug is discovered
  AND emergency proposal is created
  AND proposal has expedited 24-hour voting
When 2/3 super-majority is reached
  AND security council approves
Then proposal can be executed immediately
  AND normal timelock is bypassed
  AND EmergencyExecuted event is emitted
  AND fix is applied to contracts
```

---

## Cross-Epic Scenarios

### Scenario X.1: Complete User Journey
```gherkin
Given a new user holds 10000 V1 tokens on Base
When the user:
  AND migrates tokens to Vana (receives 10000 + 500 bonus)
  AND stakes 5000 RDAT for 90 days
  AND contributes Reddit data (earns 1000 RDAT)
  AND participates in governance voting
Then the user:
  AND holds 5500 liquid RDAT
  AND has 6250 vRDAT voting power
  AND earns staking rewards over time
  AND has Silver tier in Kismet system
  AND can claim epoch rewards quarterly
```

### Scenario X.2: Admin Emergency Response
```gherkin
Given a potential exploit is detected
When admin:
  AND triggers emergency pause
  AND investigates the issue
  AND develops a fix
  AND creates governance proposal for upgrade
  AND community votes to approve
  AND upgrade is executed after timelock
Then:
  AND system is unpaused
  AND vulnerability is patched
  AND no funds were lost
  AND normal operations resume
```

---

## Acceptance Criteria Summary

### Token Deployment
- ✅ 100M fixed supply deployed correctly
- ✅ 70M allocated to Treasury
- ✅ 30M allocated to Migration Bridge
- ✅ No minting capability after deployment

### Token Migration
- ✅ 1:1 migration ratio maintained
- ✅ Early bird bonuses calculated correctly
- ✅ Challenge period enforced (6 hours)
- ✅ Validator consensus required (2+)
- ✅ Daily limits enforced

### Token Administration
- ✅ Emergency pause auto-expires (72 hours)
- ✅ UUPS upgrades preserve storage
- ✅ Treasury vesting follows schedule
- ✅ Validator set maintains minimum count

### Data Contribution
- ✅ Quality scores calculated accurately
- ✅ Kismet tiers provide correct multipliers
- ✅ Epoch rewards distributed proportionally
- ✅ Invalid data rejected by validators

### Token Staking
- ✅ Lock periods enforced strictly
- ✅ vRDAT minted with correct multipliers
- ✅ Rewards accumulate properly
- ✅ Emergency exit applies 50% penalty
- ✅ NFT positions correctly tracked

### DAO Governance
- ✅ Proposal thresholds enforced
- ✅ Quadratic voting costs calculated correctly
- ✅ Timelock delays applied (48 hours)
- ✅ Quorum requirements met
- ✅ Delegation tracked accurately