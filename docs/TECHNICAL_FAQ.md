# Technical FAQ and Architectural Decisions

This document captures important technical decisions, architectural patterns, and frequently asked questions about the r/datadao V2 smart contract implementation.

## Table of Contents
1. [RDAT Tokenomics](#rdat-tokenomics)
2. [Emergency Pause Architecture](#emergency-pause-architecture)
3. [Emergency Migration Architecture](#emergency-migration-architecture)
4. [Token Architecture](#token-architecture)
5. [Security Decisions](#security-decisions)

---

## RDAT Tokenomics

### Q: Why is RDAT non-mintable after deployment?

**A:** RDAT uses a fixed supply model for several critical reasons:

#### 1. **Predictable Economics**
- Fixed 100M supply ensures no inflation
- Token holders know exact supply forever
- Rewards come from pre-allocated pools
- No dilution through minting

#### 2. **Security Benefits**
- Eliminates minting attack vectors
- No need for complex minting controls
- Simpler contract with fewer risks
- No infinite mint bugs possible

#### 3. **Sustainable Rewards**
Instead of minting new tokens for rewards, we use:
- **Treasury Allocations**: Pre-funded reward pools
- **Revenue Sharing**: Protocol fees distributed to stakers
- **Limited Programs**: Rewards end when pools deplete
- **Market-Based**: Creates natural supply/demand dynamics

#### 4. **Implementation Details**
```solidity
uint256 public constant TOTAL_SUPPLY = 100_000_000 * 10**18; // 100M fixed
uint256 public constant MIGRATION_ALLOCATION = 30_000_000 * 10**18; // 30M reserved

function initialize(address treasury, address admin, address migrationContract) {
    // Mint ENTIRE supply at deployment
    _mint(treasury, TOTAL_SUPPLY - MIGRATION_ALLOCATION); // 70M to treasury
    _mint(migrationContract, MIGRATION_ALLOCATION); // 30M to migration contract
    
    // No MINTER_ROLE granted - minting is complete
}

// Mint function exists only to satisfy interface - always reverts
function mint(address, uint256) external pure {
    revert("Minting is disabled - all tokens minted at deployment");
}
```

### Q: How are staking rewards distributed without minting?

**A:** Through the modular rewards architecture:

1. **Treasury Pre-funds Modules**: Treasury allocates RDAT to reward modules
2. **Modules Hold Tokens**: Each reward module holds its allocation
3. **Users Claim from Modules**: Rewards transferred from module balance
4. **Revenue Supplements**: Protocol fees add to reward pools

This creates sustainable, predictable reward economics without inflation.

### Q: Why does RDAT have a mint() function if supply is fixed?

**A:** The mint function exists only to satisfy the IRDAT interface but always reverts:

1. **100M Pre-minted**: Full supply minted at deployment
2. **70M to Treasury**: For rewards and liquidity
3. **30M to Migration**: Pre-allocated to migration contract
4. **No MINTER_ROLE**: Role doesn't exist, can't be granted
5. **Always Reverts**: mint() throws error if called

This is the most secure approach - no minting bugs possible.

### Q: How do we ensure the migration contract can't mint extra tokens?

**A:** The migration contract receives exactly 30M tokens at deployment:

1. **Pre-allocated**: 30M tokens transferred to migration contract in `initialize()`
2. **No Special Powers**: Migration contract has no minting rights
3. **Simple Transfers**: It can only transfer its balance to V1 holders
4. **Auditable**: On-chain balance shows exactly how many tokens remain
5. **Time-Limited**: Can implement deadline after which unclaimed tokens return to treasury

This eliminates any risk of the migration contract creating new tokens.

### Q: What happens if we need to mint tokens in the future?

**A:** We can't, and that's by design:

1. **Immutable Supply**: 100M tokens is the absolute maximum
2. **No Backdoors**: No way to add minting functionality
3. **Governance Alternative**: If more tokens needed, must deploy new contract
4. **Community Trust**: Fixed supply promise cannot be broken

This protects token holders from dilution.

### Q: Why doesn't StakingPositions calculate or distribute rewards?

**A:** Separation of concerns for security and flexibility:

1. **Single Responsibility**: StakingPositions only manages staking logic
2. **Modular Rewards**: RewardsManager handles all reward calculations
3. **No Token Access**: StakingPositions can't mint or transfer reward tokens
4. **Upgrade Safety**: Can upgrade rewards without touching staking

This architecture prevents many common DeFi exploits where staking contracts have too much power.

### Q: How does the TreasuryWallet handle DAO allocations?

**A:** TreasuryWallet is a UUPS upgradeable contract that manages the 70M RDAT with vesting schedules:

1. **Receives 70M at Deployment**: Gets tokens from RDATUpgradeable initialization
2. **Vesting Schedules**: Each allocation has its own schedule per DAO vote
3. **Immediate TGE Distribution**:
   - 4.95M to liquidity (33% of Liquidity allocation)
   - 2.5M available for ecosystem (10% of Treasury allocation)
4. **Phase 3 Gated**: Future Rewards (30M) locked until Phase 3 activation
5. **On-chain Transparency**: All distributions tracked with reasons

This ensures DAO-approved allocations are enforced programmatically.

### Q: Why separate Phase 1 and Phase 3 rewards?

**A:** Strategic rollout for security and community building:

**Phase 1 (Launch)**:
- Only vRDAT governance rewards
- Encourages participation without token inflation
- Builds governance community first
- Simpler security surface for initial launch

**Phase 3 (Future)**:
- RDAT staking rewards activate
- 30M allocation unlocked from TreasuryWallet
- Community decides readiness via governance
- More complex tokenomics after proven stability

This phased approach reduces launch risk while maintaining flexibility.

### Q: How does the migration process work with fixed supply?

**A:** The migration uses pre-allocated tokens, not minting:

1. **30M Pre-allocated**: MigrationBridge receives tokens at RDAT deployment
2. **1:1 Exchange**: V1 holders get exact amount in V2
3. **No Special Powers**: Bridge only transfers its balance
4. **1-Year Deadline**: Unclaimed tokens return to TreasuryWallet
5. **Auditable**: On-chain balance shows remaining tokens

This eliminates any risk of the migration contract creating new tokens.

### Q: How do staking rewards work without minting?

**A:** All rewards come from pre-allocated pools:

**vRDAT Rewards**:
- Soul-bound governance tokens
- Only contract that can mint vRDAT
- Proportional to lock duration (days/365)
- Immediate distribution on stake

**RDAT Rewards (Phase 3)**:
- From 30M Future Rewards allocation
- RDATRewardModule holds token balance
- Time-based accumulation with multipliers
- Transfers from module balance, no minting

**Revenue Sharing**:
- Fees collected in VANA/USDC/USDT
- Swapped to RDAT via Vana DEX
- 50% distributed to stakers
- Creates buy pressure, not inflation

### Q: Why use CREATE2 for deployment?

**A:** Solves circular dependency in contract initialization:

**The Problem**:
- RDAT needs MigrationBridge address at initialization
- MigrationBridge needs RDAT address for configuration
- Circular dependency prevents deployment

**The Solution**:
1. Calculate MigrationBridge address with CREATE2
2. Deploy RDAT with calculated address
3. Deploy MigrationBridge at exact address
4. No post-deployment configuration needed

This enables clean, secure deployment in correct order.

### Q: What happens if Phase 3 never activates?

**A:** The system continues functioning with vRDAT rewards only:

1. **Staking Works**: Users can stake and earn vRDAT
2. **Governance Active**: vRDAT holders vote on proposals
3. **30M Locked**: Future Rewards remain in TreasuryWallet
4. **Revenue Sharing**: Still distributes fees to stakers
5. **DAO Decision**: Community controls Phase 3 timing

The protocol is fully functional without RDAT staking rewards.

### Q: How are fees distributed with fixed supply?

**A:** RevenueCollector manages fee distribution without burning:

1. **Collection**: Accepts fees in any token (VANA, USDC, USDT, RDAT)
2. **Admin Triggered Swap**: Not automatic, admin initiates
3. **DEX Integration**: Swaps to RDAT via Vana's DEX
4. **Distribution Split**:
   - 50% to stakers (via StakingPositions)
   - 30% to treasury
   - 20% to contributors (not burned)
5. **No Burning**: Fixed supply means no burn mechanism

This creates sustainable buy pressure and rewards.

---

## Emergency Pause Architecture

### Q: Why build a custom EmergencyPause instead of using OpenZeppelin's Pausable?

**A:** The custom EmergencyPause contract serves fundamentally different purposes than OpenZeppelin's Pausable:

#### 1. **Protocol-Wide vs Contract-Specific Pausing**

- **OpenZeppelin's Pausable:** Designed for individual contract pausing, each contract manages its own pause state with no coordination
- **Our EmergencyPause:** Centralized emergency coordination system where multiple contracts can check a single pause state for protocol-wide response

#### 2. **Auto-Expiry Feature**

Our key innovation is the 72-hour auto-expiry that prevents indefinite protocol lockup:

```solidity
uint256 public constant PAUSE_DURATION = 72 hours;

function _isPaused() internal view returns (bool) {
    if (!_paused) return false;
    
    // Auto-expiry check
    if (block.timestamp >= pausedAt + PAUSE_DURATION) {
        return false;
    }
    
    return true;
}
```

#### 3. **Multiple Authorized Pausers**

Unlike Pausable's single-pauser model, we support multiple pausers:

```solidity
mapping(address => bool) public pausers;
```

This allows multiple security monitors, automated systems, or team members to respond to emergencies.

#### 4. **Flexible Integration Patterns**

Current pattern (manual coordination):
```solidity
// 1. Emergency system signals
emergencyPause.emergencyPause();

// 2. Individual contracts respond
rdat.pause();
```

Alternative patterns for tighter integration:
```solidity
// Option 1: Check EmergencyPause in modifiers
modifier whenNotPaused() {
    require(!paused(), "Contract paused");
    require(!emergencyPause.emergencyPaused(), "Emergency pause active");
    _;
}

// Option 2: Inherit and override hooks
function _beforeTokenTransfer(...) internal override {
    super._beforeTokenTransfer(...);
    require(!emergencyPause.emergencyPaused(), "Emergency pause");
}
```

#### 5. **Key Benefits**

- **Separation of Concerns:** Emergency system is independent of individual contract logic
- **Flexibility:** Contracts maintain their own pause logic AND respond to emergencies
- **Auto-Recovery:** Prevents permanent lockup if guardians are unavailable
- **Multi-Sig Alternative:** Multiple pausers without complex multi-sig setup
- **Audit Trail:** Centralized emergency events for monitoring

---

## Emergency Migration Architecture

### Q: Why use Emergency Migration instead of Contract Upgrades?

**A:** We chose Emergency Migration over UUPS upgrades for several critical reasons:

1. **Architectural Clarity:** Each contract version is immutable and independently auditable
2. **No Upgrade Complexity:** Eliminates storage collision, proxy patterns, and upgrade testing overhead
3. **User Benefits:** Penalty-free migration is better than forced upgrades
4. **Security:** No upgrade vulnerabilities or complex proxy attack vectors
5. **Development Velocity:** Complete freedom to redesign architecture between versions

### Q: How does Emergency Migration work?

**A:** The migration process has three phases:

1. **Migration Declaration:** Admin enables emergency migration (requires multi-sig)
2. **User Migration Window:** Users can penalty-free unstake with proportional rewards
3. **New Contract Deployment:** Users stake in new contract with improved features

**Migration Flow:**
```solidity
// Phase 1: Admin declares migration
function enableEmergencyMigration() external onlyRole(ADMIN_ROLE)

// Phase 2: Users migrate positions
function emergencyMigratePosition(uint256 positionId) external 
    returns (uint256 stakedAmount, uint256 rewardsEarned)

// Phase 3: Users stake in new contract
newStakingContract.stake(stakedAmount + rewardsEarned, preferredLockPeriod)
```

### Q: How are proportional rewards calculated during migration?

**A:** Fair compensation algorithm:

1. **Base Stake:** Full original stake amount (no penalty)
2. **Time-Proportional Rewards:** `(timeStaked / totalLockPeriod) * fullRewards`
3. **No Early Withdrawal Penalty:** Migration is penalty-free
4. **vRDAT Handling:** Soul-bound tokens burned, governance paused during migration

**Example:**
```solidity
// User staked 1000 RDAT for 12 months (4x multiplier)
// After 3 months, migration declared
// User receives:
// - Original stake: 1000 RDAT (100%)
// - Proportional rewards: (3/12) * fullRewards = 25% of expected rewards
// - No penalty: 0 RDAT lost
```

### Q: What are the tradeoffs of Emergency Migration vs Upgrades?

**A:** Comprehensive comparison:

| Aspect | Emergency Migration | UUPS Upgrades |
|--------|-------------------|---------------|
| **User Experience** | ✅ Penalty-free migration | ❌ Forced upgrade, potential issues |
| **Security** | ✅ Immutable, independently auditable | ❌ Complex proxy patterns, upgrade vulnerabilities |
| **Development** | ✅ Complete architectural freedom | ❌ Storage layout constraints, upgrade complexity |
| **Testing** | ✅ Simple: test each contract independently | ❌ Complex: upgrade scenarios, storage collisions |
| **Gas Costs** | ✅ No proxy overhead | ❌ Extra gas for delegate calls |
| **Migration Effort** | ⚠️ Manual user action required | ✅ Seamless for users |
| **Governance** | ⚠️ Temporary pause in governance | ✅ Continuous governance |

### Q: How do we mitigate the manual migration effort?

**A:** User experience optimization:

1. **Incentivized Migration:** Users get better terms (no penalties)
2. **Clear Communication:** Dashboard showing migration status and benefits
3. **Batch Migration:** Frontend tools to migrate all positions at once
4. **Extended Window:** Generous migration period (e.g., 30-90 days)
5. **Support:** Help desk and tutorials for migration process

---

## Token Architecture

### Q: Why are vRDAT tokens non-transferable (soul-bound)?

**A:** Soul-bound tokens ensure:

1. **Sybil Resistance:** Can't buy voting power on secondary markets
2. **True Governance:** Voting power tied to actual participation
3. **Prevents Vote Trading:** No vote buying/selling
4. **Long-term Alignment:** Holders can't exit positions quickly

### Q: What is quadratic voting and why use it?

**A:** Quadratic voting means the cost to vote increases quadratically:
- 1 vote costs 1 token
- 2 votes cost 4 tokens  
- 10 votes cost 100 tokens

Benefits:
- **Minority Protection:** Prevents whale domination
- **Preference Intensity:** Allows expressing strong preferences at a cost
- **Fair Distribution:** More democratic than 1-token-1-vote

---

## Security Decisions

### Q: Why no mint delay for vRDAT?

**A:** vRDAT is a soul-bound token that cannot be transferred or flash loaned:

1. **Soul-Bound Design:** Tokens are permanently tied to addresses
2. **No Flash Loans:** Cannot borrow/return vRDAT in same transaction
3. **Simpler UX:** Users can stake multiple times without delays
4. **Attack Prevention:** Transfer restrictions prevent all flash loan vectors

### Q: Why separate MINTER_ROLE and BURNER_ROLE?

**A:** Role separation follows principle of least privilege:

1. **Minting:** Only treasury/rewards contracts need this
2. **Burning:** Only staking/penalty contracts need this
3. **Reduces Risk:** Compromise of one role doesn't affect the other
4. **Audit Trail:** Different events for different actions

---

## Staking Architecture

### Q: Why use a modular rewards architecture instead of built-in rewards?

**A:** The modular rewards architecture separates staking logic from reward distribution, providing unprecedented flexibility:

**Problems with Traditional Monolithic Design:**
1. Rewards logic tightly coupled with staking
2. Cannot add new reward types without upgrades
3. Complex migrations when reward logic changes
4. Limited flexibility for partnerships and campaigns

**Modular Architecture Benefits:**
1. **Clean Separation**: StakingManager only handles positions, RewardsManager handles distributions
2. **Unlimited Reward Programs**: Add new tokens, campaigns, partners without touching core staking
3. **Retroactive Rewards**: Can distribute rewards based on historical staking data
4. **Independent Upgrades**: Upgrade reward logic without migrating stakes
5. **Better Security**: Immutable staking contract with flexible reward modules

**Example Architecture:**
```solidity
// Core immutable staking
StakingManager (handles positions only)
    ↓ emits events
RewardsManager (orchestrator - upgradeable)
    ↓ notifies modules
    ├── vRDATRewardModule (immediate mint on stake)
    ├── RDATRewardModule (time-based accumulation)
    ├── PartnerTokenModule (special campaigns)
    └── RetroactiveModule (historical rewards)
```

**Implementation Details:**
- StakingManager: Immutable, only manages stake state
- RewardsManager: UUPS upgradeable orchestrator
- Reward Modules: Pluggable contracts implementing IRewardModule
- Event-driven: Modules listen to staking events
- Flexible claiming: Batch claims across all programs

**Gas Considerations:**
- Slightly higher initial stake gas (event emissions)
- Lower claim gas (batch operations)
- No migration gas costs for new rewards
- Worth it for unlimited flexibility

### Q: Why use stake IDs instead of NFTs for positions?

**A:** We use simple uint256 stake IDs for efficiency and simplicity:

1. **Gas Efficiency**: No NFT minting costs
2. **Simpler Logic**: Direct mapping lookups
3. **Multiple Stakes**: Users can have unlimited positions
4. **Better UX**: No NFT approvals needed
5. **Future Compatible**: Can add NFT wrapper later if needed

### Q: How do we handle gas costs as the number of stakers grows?

**A:** This is a critical consideration that led to our gas-optimized design:

**The Problem with Arrays:**
```solidity
// BAD: Unbounded array approach
mapping(address => uint256[]) userStakeIds;
userStakeIds[user].push(stakeId); // Gas increases with array size!
```

As users create more stakes, the array grows and push operations become more expensive due to:
- Dynamic array allocation
- Storage slot calculations
- Potential array resizing

**Our Solution: EnumerableSet**
```solidity
// GOOD: EnumerableSet approach
using EnumerableSet for EnumerableSet.UintSet;
mapping(address => EnumerableSet.UintSet) private userActiveStakes;
userActiveStakes[user].add(stakeId); // O(1) always!
```

**Gas Cost Comparison:**
| Operation | Array Approach | EnumerableSet | Savings |
|-----------|---------------|---------------|---------|
| 1st stake | ~60k gas | ~60k gas | 0% |
| 10th stake | ~65k gas | ~60k gas | 8% |
| 50th stake | ~80k gas | ~60k gas | 25% |
| 100th stake | ~100k gas | ~60k gas | 40% |

**Additional Optimizations:**
1. **Separate Active/Inactive**: Only track active stakes in the set
2. **Single Global Mapping**: `mapping(uint256 => StakeInfo)` for all stakes
3. **Lazy Deletion**: Mark as inactive instead of array shifting
4. **Batch Operations**: When needed, process multiple stakes together

**Why Not NFTs?**
NFTs (ERC-721) have similar enumeration challenges:
- Must track token ownership: `mapping(uint256 => address)`
- Must enumerate user tokens: similar gas issues
- Additional overhead: transfer logic, approval mappings
- Higher minting gas than simple mappings

**Trade-offs:**
- Slightly higher deployment cost (EnumerableSet library)
- More complex code structure
- Worth it for long-term gas savings
- Critical for protocol scalability

### Q: Why is vRDAT distribution implemented as a reward module?

**A:** This design choice proves the modularity and sets important patterns:

1. **Dogfooding**: Core functionality uses the same system as external rewards
2. **Access Control**: Only vRDATRewardModule has MINTER_ROLE, enforcing staking as the only way to get vRDAT
3. **Flexibility**: Can update vRDAT distribution logic without touching staking
4. **Consistency**: All rewards follow the same pattern
5. **Security**: Minting logic isolated in auditable module

**Critical Setup:**
```solidity
// Only the reward module can mint/burn vRDAT
vRDAT.grantRole(MINTER_ROLE, address(vRDATRewardModule));
vRDAT.grantRole(BURNER_ROLE, address(vRDATRewardModule));
```

### Q: How does the vRDAT proportional distribution prevent gaming?

**A:** The system uses lock duration proportional distribution to ensure fair governance power:

**The Formula:**
```solidity
vRDAT_received = RDAT_staked × (lock_days / 365)
```

**Anti-Gaming Properties:**
1. **Sequential Staking Prevention**: 
   - 12 × 30-day stakes = 12 × 8.3% = 99.6% vRDAT
   - 1 × 365-day stake = 100% vRDAT
   - Result: Long-term stakers always get more

2. **No Unlock/Relock Benefit**:
   - Unlocking and relocking doesn't increase vRDAT
   - Each stake's vRDAT is fixed at creation based on lock duration

3. **Sybil Resistance**:
   - Splitting across addresses provides no advantage
   - 1000 RDAT in one address = same vRDAT as 10×100 RDAT

4. **Optimal Strategy is Honest**:
   - Maximum governance power requires maximum commitment
   - Aligns voting power with long-term protocol interest

**Example Calculations:**
```solidity
// 10,000 RDAT staked
30 days:  10,000 × 0.083 = 830 vRDAT
90 days:  10,000 × 0.247 = 2,470 vRDAT  
180 days: 10,000 × 0.493 = 4,930 vRDAT
365 days: 10,000 × 1.000 = 10,000 vRDAT
```

### Q: How would partner token rewards work with proportional distribution?

**A:** Here's a worked example with a VANA partnership reward:

**Scenario**: Vana offers 1,000 VANA tokens as rewards for new stakers over the next 30 days.

**Implementation**:
```solidity
contract VANARewardModule is IRewardModule {
    IERC20 public constant VANA = IERC20(0x...); // VANA token address
    uint256 public constant TOTAL_ALLOCATION = 1000e18; // 1000 VANA
    uint256 public programStart;
    uint256 public programEnd;
    
    mapping(uint256 => uint256) public lockMultipliers;
    
    constructor() {
        programStart = block.timestamp;
        programEnd = block.timestamp + 30 days;
        
        // Same proportional system as vRDAT
        lockMultipliers[30 days] = 833;    // 8.33%
        lockMultipliers[90 days] = 2466;   // 24.66%
        lockMultipliers[180 days] = 4932;  // 49.32%
        lockMultipliers[365 days] = 10000; // 100%
    }
}
```

**Distribution Example**:
If 5 users stake during the program with equal amounts (1000 RDAT each):

| User | Lock Period | Share % | VANA Received |
|------|------------|---------|---------------|
| Alice | 365 days | 100% | 357.1 VANA |
| Bob | 180 days | 49.3% | 176.1 VANA |
| Carol | 90 days | 24.7% | 88.2 VANA |
| Dave | 30 days | 8.3% | 29.6 VANA |
| Eve | 365 days | 100% | 357.1 VANA |

**Calculation**:
1. Total weighted shares = 100% + 49.3% + 24.7% + 8.3% + 100% = 282.3%
2. VANA per 1% share = 1000 / 282.3 = 3.54 VANA
3. Each user gets: their % × 3.54 VANA

**Key Points**:
- 365-day stakers get 12x more rewards than 30-day stakers
- Fair distribution based on commitment level
- No gaming possible through multiple short stakes
- Partner satisfied that rewards go to committed users

This proportional system ensures that partner rewards (like VANA's promotional tokens) go primarily to long-term aligned users rather than short-term farmers.

## Integration Patterns

### Q: How should new contracts integrate with EmergencyPause?

**A:** Three recommended patterns:

1. **Loose Coupling (Current):** Check pause state manually when needed
2. **Modifier Integration:** Add emergency check to existing modifiers
3. **Hook Integration:** Override transfer/critical functions to check emergency state

Choose based on criticality and gas considerations.

---

## Deployment Decisions

### Q: Why use CREATE2 for deployment?

**A:** CREATE2 provides:

1. **Deterministic Addresses:** Same address across all chains
2. **Pre-verification:** Can verify deployment address before deploying
3. **Cross-chain Consistency:** Simplifies multi-chain deployments
4. **Recovery Options:** Can redeploy to same address if needed

---

## Future Considerations

### Q: What if we need to change the emergency pause duration?

**A:** Current design has fixed 72-hour duration. For flexibility, consider:

1. Making duration configurable (with limits)
2. Different durations for different severity levels
3. Governance-controlled duration changes

### Q: How do we handle multi-chain emergency pausing?

**A:** Future enhancement could include:

1. Cross-chain message passing for coordinated pauses
2. Chain-specific pause durations
3. Automated bridge pausing on emergency

---

## Soul-Bound Token Design

### Q: Why is vRDAT designed as a soul-bound token?

**A:** Soul-bound design provides superior security and aligns with governance principles:

#### Security Benefits:
1. **No Flash Loan Attacks:** Cannot borrow vRDAT for temporary voting power
2. **No Vote Trading:** Prevents vote buying/selling markets
3. **Simplified Security Model:** No need for mint delays or transfer restrictions
4. **Governance Integrity:** Voting power stays with actual stakers

#### Design Trade-offs:
- **Pro:** Eliminates entire classes of attacks
- **Pro:** Simpler code with fewer edge cases
- **Pro:** Better UX (no waiting periods)
- **Con:** Cannot transfer governance rights
- **Con:** Lost keys mean lost voting power

This is a deliberate design choice that prioritizes security and governance integrity over transferability.

---

## Security Hardening

### Q: Why implement minimum stake amounts and position limits?

**A:** These security measures prevent two critical attack vectors while maintaining system usability:

#### 1. **Dust Attack Prevention**

**The Problem:**
Attackers could create extremely small stakes (1 wei) with high multipliers to exploit precision:

```solidity
// Before fix: Attacker stakes 1 wei for 365 days
stake(1, 365 days);  // Gets 4 wei vRDAT (4x multiplier)

// Problems:
// 1. Minimal cost, disproportionate rewards
// 2. Precision rounding exploits
// 3. Could spam system with thousands of dust stakes
```

**The Solution:**
```solidity
uint256 public constant MIN_STAKE_AMOUNT = 1e18; // 1 RDAT minimum

function stake(uint256 amount, uint256 lockPeriod) external {
    if (amount < MIN_STAKE_AMOUNT) revert BelowMinimumStake();
    // ... rest of implementation
}
```

**Impact:**
- Prevents precision exploits with minimal amounts
- Ensures meaningful economic commitment
- Maintains reasonable gas costs for legitimate users
- 1 RDAT minimum is accessible but prevents abuse

#### 2. **DoS Attack Prevention**

**The Problem:**
Attackers could create unlimited positions to DoS the system:

```solidity
// Before fix: Attacker creates thousands of positions
for (uint i = 0; i < 10000; i++) {
    stake(minimumAmount, 30 days);  // Creates 10,000 positions
}

// Problems:
// 1. Unbounded gas costs for position enumeration
// 2. Storage bloat
// 3. Potential to crash frontend/indexers
```

**The Solution:**
```solidity
uint256 public constant MAX_POSITIONS_PER_USER = 100; // Reasonable limit

function stake(uint256 amount, uint256 lockPeriod) external {
    if (balanceOf(msg.sender) >= MAX_POSITIONS_PER_USER) revert TooManyPositions();
    // ... rest of implementation
}
```

**Impact:**
- Prevents position spam attacks
- Maintains O(1) performance characteristics
- 100 positions is generous for legitimate use while preventing abuse
- Users can still unstake and create new positions if needed

#### 3. **Implementation Details**

**Security Validation Order:**
```solidity
function stake(uint256 amount, uint256 lockPeriod) external {
    // 1. Basic validation
    if (amount == 0) revert ZeroAmount();
    
    // 2. Security hardening (NEW)
    if (amount < MIN_STAKE_AMOUNT) revert BelowMinimumStake();
    if (balanceOf(msg.sender) >= MAX_POSITIONS_PER_USER) revert TooManyPositions();
    
    // 3. Business logic validation
    if (lockMultipliers[lockPeriod] == 0) revert InvalidLockDuration();
    
    // ... implementation continues
}
```

**Custom Error Messages:**
```solidity
error BelowMinimumStake();    // Clear error for minimum stake requirement
error TooManyPositions();     // Clear error for position limit
```

#### 4. **Testing Impact**

**Before Fix (Vulnerable):**
```solidity
function test_DustAttack() public {
    // Could succeed with 1 wei stake
    uint256 positionId = stakingPositions.stake(1, 365 days);
    // Attacker gets 4 wei vRDAT for minimal cost
}
```

**After Fix (Protected):**
```solidity
function test_DustAttack() public {
    // Now correctly fails
    vm.expectRevert(IStakingPositions.BelowMinimumStake.selector);
    stakingPositions.stake(1, 365 days);
}
```

#### 5. **User Experience Considerations**

**Legitimate Users:**
- 1 RDAT minimum ($X USD) is reasonable for meaningful staking
- 100 position limit is generous for portfolio diversification
- Clear error messages guide proper usage

**Gas Efficiency:**
- Early validation prevents wasted gas on invalid operations
- Position limit maintains predictable gas costs
- No impact on legitimate staking operations

#### 6. **Future Considerations**

**Potential Enhancements:**
```solidity
// Could make configurable if needed
function setMinStakeAmount(uint256 newMin) external onlyRole(ADMIN_ROLE) {
    require(newMin >= 1e17 && newMin <= 1e20, "Reasonable bounds");
    MIN_STAKE_AMOUNT = newMin;
}
```

**Economic Parameters:**
- Monitor if 1 RDAT becomes too expensive/cheap over time
- Could implement sliding scale based on market conditions
- Position limit could vary based on user tier/reputation

This security hardening significantly improves system robustness while maintaining excellent usability for legitimate users.

---

## Deployment Strategy

### Q: Why deploy with only vRDAT rewards initially?

**A:** Risk mitigation and focused launch strategy:

1. **Reduced Complexity**: Fewer moving parts at launch
2. **Security Focus**: Smaller attack surface to audit
3. **Community Building**: Governance participants first
4. **Token Preservation**: 30M RDAT safely locked
5. **Sprint Timeline**: Meets tight 13-day deadline

Phase 3 deployment is a feature, not a limitation.

### Q: How does the sprint timeline affect architecture decisions?

**A:** Strategic deferrals to meet audit deadline:

**Included in Sprint (Phase 1)**:
- Core staking functionality
- vRDAT governance rewards
- TreasuryWallet with vesting
- Basic fee collection
- Emergency pause system

**Deferred to Phase 3**:
- RDAT staking rewards
- Automatic DEX swaps
- Full ProofOfContribution
- Governance contracts
- Additional reward modules

This ensures a secure, auditable launch within timeline constraints.

### Q: What are the key deployment dependencies?

**A:** Critical ordering for successful deployment:

1. **CREATE2 Factory** → Calculate deterministic addresses
2. **vRDAT** → Independent, no dependencies
3. **TreasuryWallet** → Needs to exist before RDAT
4. **RDAT** → Needs TreasuryWallet and MigrationBridge addresses
5. **MigrationBridge** → Deploy at CREATE2 address
6. **StakingPositions** → Needs RDAT and vRDAT
7. **RewardsManager** → Needs StakingPositions
8. **vRDATRewardModule** → Needs all above

Proper sequencing prevents deployment failures.

### Q: Why is TreasuryWallet upgradeable but StakingPositions isn't?

**A:** Different security and flexibility requirements:

**TreasuryWallet (Upgradeable)**:
- Holds funds but doesn't define core logic
- May need updates for new DAO proposals
- Vesting schedules might need adjustments
- Lower risk profile for upgrades

**StakingPositions (Immutable)**:
- Defines core staking rules
- Users trust these rules won't change
- Upgrade would be major protocol change
- Manual migration preserves user choice

This balances flexibility with security guarantees.

---

*Last Updated: August 6, 2025*

## Contributing to this FAQ

When adding new entries:
1. Include the question that prompted the explanation
2. Provide code examples where relevant
3. Explain the "why" not just the "what"
4. Include any considered alternatives
5. Date your additions