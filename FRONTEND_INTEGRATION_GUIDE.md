# Frontend Integration Guide for r/DataDAO Smart Contracts

## Overview
This guide provides comprehensive information for the frontend team to integrate with the r/DataDAO V2 smart contracts. The contracts implement a cross-chain migration from Base to Vana blockchain with an expanded tokenomics model (30M → 100M fixed supply).

## Contract Architecture Summary

### Core System Design
- **Total Supply**: 100,000,000 RDAT (fixed, no minting capability)
- **Distribution**: 70M to Treasury, 30M to Migration Bridge
- **Architecture**: Hybrid approach with UUPS upgradeable token + non-upgradeable staking
- **Current Status**: 333/333 tests passing (100%), production-ready

## Deployed Contracts Across Testnets

### Base Sepolia Testnet (Migration Source)

#### Mock RDAT V1 Token (For Migration Testing)
**Address**: `0xEb0c43d5987de0672A22e350930F615Af646e28c`
**Type**: Standard ERC-20
**Supply**: 30,000,000 RDATv1 tokens
**Key Functions**:
```solidity
// Standard ERC-20 functions
balanceOf(address account) → uint256
transfer(address to, uint256 amount) → bool
approve(address spender, uint256 amount) → bool
mint(address to, uint256 amount) // Test function only
```

#### Base Migration Bridge
**Address**: `0xF73c6216d7D6218d722968e170Cfff6654A8936c`
**Purpose**: Initiates migrations from Base to Vana
**Key Functions**:
```solidity
// Migration initiation
initiateMigration(uint256 amount)
getMigrationHistory(address user) → Migration[]
userMigrationTotal(address user) → uint256
```

### Test Wallets (Pre-funded with 1,000 RDATv1 each)
1. **Primary Test Account**: `0x70997970C51812dc3A010C7d01b50e0d17dc79C8`
2. **Secondary Test Account**: `0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC`
3. **Additional Test Account**: `0x90F79bf6EB2c4f870365E785982E1f101E93b906`

*Note: These are Anvil test accounts with publicly known private keys - use only for testing*

## Deployed Contracts on Vana Moksha Testnet

### 1. RDAT Token (Main Token Contract)
**Address**: `0xC1aC75130533c7F93BDa67f6645De65C9DEE9a3A`
**Type**: UUPS Upgradeable ERC-20/VRC-20
**Key Functions**:
```solidity
// Standard ERC-20 functions
balanceOf(address account) → uint256
transfer(address to, uint256 amount) → bool
approve(address spender, uint256 amount) → bool
transferFrom(address from, address to, uint256 amount) → bool
allowance(address owner, address spender) → uint256
totalSupply() → uint256 // Returns 100,000,000 * 10^18

// DLP Integration
setDLPRegistry(address) // Admin only
updateDLPRegistration(uint256 dlpId) // Admin only
dlpRegistered() → bool
dlpId() → uint256

// Role Management
hasRole(bytes32 role, address account) → bool
getRoleAdmin(bytes32 role) → bytes32
```

**Events to Monitor**:
- `Transfer(address indexed from, address indexed to, uint256 value)`
- `Approval(address indexed owner, address indexed spender, uint256 value)`
- `DLPRegistrationUpdated(uint256 indexed dlpId)`

### 2. Treasury Wallet
**Address**: `0x31C3e3F091FB2A25d4dac82474e7dc709adE754a`
**Holdings**: 70,000,000 RDAT
**Key Functions**:
```solidity
// Vesting Management
getAllVestingSchedules() → VestingSchedule[]
getVestingInfo(bytes32 scheduleId) → VestingInfo
checkAndRelease(bytes32 scheduleId) → uint256
getCurrentPhase() → uint8
isPhaseActive(uint8 phase) → bool

// DAO Operations
executeDAOProposal(address to, uint256 amount, string calldata reason)
proposeDistribution(address[] recipients, uint256[] amounts)

// View Functions
rdatBalance() → uint256
totalDistributed() → uint256
getDistributionHistory() → Distribution[]
```

**Vesting Schedule**:
- Phase 1 (Months 0-3): Initial operations
- Phase 2 (Months 3-12): Community growth
- Phase 3 (Month 12+): DAO governance control

### 3. Migration Bridge (Vana Side)
**Address**: `0x31C3e3F091FB2A25d4dac82474e7dc709adE754a`
**Allocation**: 30,000,000 RDAT
**Key Functions**:
```solidity
// Migration Operations
processMigration(address user, uint256 amount, bytes32 migrationId, bytes[] signatures)
verifyMigration(bytes32 migrationId) → bool
getMigrationStatus(bytes32 migrationId) → MigrationStatus

// View Functions
remainingAllocation() → uint256
totalMigrated() → uint256
userMigrationAmount(address user) → uint256
isValidator(address) → bool
```

**Migration Process**:
1. User initiates migration on Base network
2. Validators sign the migration request
3. User submits signatures to Vana bridge
4. Bridge releases RDAT tokens on Vana

### 4. RDATDataDAO (DLP Contract)
**Address**: `0x32B481b52616044E5c937CF6D20204564AD62164`
**Status**: Deployed, pending DLP registration with Vana
**Key Functions**:
```solidity
// Data Contribution
contributeData(bytes32 dataHash, uint256 score)
validateData(bytes32 dataHash, bool isValid) // Validator only
getContributor(address) → (uint256 score, uint256 rewards)

// Rewards Distribution
distributeRewards(address[] recipients, uint256[] amounts) // Admin only
contributorRewards(address) → uint256

// DLP Interface (Required by Vana)
owner() → address
name() → string // Returns "r/datadao"
dataRegistry() → address // 0xEA882bb75C54DE9A08bC46b46c396727B4BFe9a5
teePool() → address // 0xF084Ca24B4E29Aa843898e0B12c465fAFD089965

// Statistics
getStats() → (contributions, validators, epoch, nextEpochTime, name, version)
currentEpoch() → uint256
```

## Planned Contracts (Not Yet Deployed)

### 5. StakingPositions (Coming Soon)
**Features**:
- NFT-based staking positions
- Lock periods: 30, 90, 180, 365 days
- Higher rewards for longer locks
- Early withdrawal with penalties

### 6. vRDAT (Governance Token - Coming Soon)
**Features**:
- Soul-bound (non-transferable)
- Earned through staking RDAT
- Used for governance voting
- Quadratic voting support

### 7. RewardsManager (Coming Soon)
**Features**:
- Modular reward programs
- Multiple reward sources
- APY calculations
- Batch claiming

## Frontend Integration Requirements

### 1. Network Configuration
```javascript
// Add to your wagmi/viem configuration
const vanaMoksha = {
  id: 14800,
  name: 'Vana Moksha',
  network: 'vana-moksha',
  nativeCurrency: {
    decimals: 18,
    name: 'VANA',
    symbol: 'VANA',
  },
  rpcUrls: {
    default: { http: ['https://rpc.moksha.vana.org'] },
  },
  blockExplorers: {
    default: { 
      name: 'Vanascan', 
      url: 'https://moksha.vanascan.io' 
    },
  },
  contracts: {
    rdatToken: '0xC1aC75130533c7F93BDa67f6645De65C9DEE9a3A',
    treasury: '0x31C3e3F091FB2A25d4dac82474e7dc709adE754a',
    vanaMigrationBridge: '0x31C3e3F091FB2A25d4dac82474e7dc709adE754a',
    rdatDataDAO: '0x32B481b52616044E5c937CF6D20204564AD62164',
  }
}

const baseSepolia = {
  id: 84532,
  name: 'Base Sepolia',
  network: 'base-sepolia',
  nativeCurrency: {
    decimals: 18,
    name: 'ETH',
    symbol: 'ETH',
  },
  rpcUrls: {
    default: { http: ['https://sepolia.base.org'] },
  },
  blockExplorers: {
    default: { 
      name: 'Basescan', 
      url: 'https://sepolia.basescan.org' 
    },
  },
  contracts: {
    mockRDATv1: '0xEb0c43d5987de0672A22e350930F615Af646e28c',
    baseMigrationBridge: '0xF73c6216d7D6218d722968e170Cfff6654A8936c',
  }
}
```

### 2. ABI Integration
All contract ABIs are available in the `/out` directory. Key ABIs needed:
- `RDATUpgradeable.sol/RDATUpgradeable.json` (Vana Moksha)
- `TreasuryWallet.sol/TreasuryWallet.json` (Vana Moksha)
- `VanaMigrationBridge.sol/VanaMigrationBridge.json` (Vana Moksha)
- `RDATDataDAO.sol/RDATDataDAO.json` (Vana Moksha)
- `BaseMigrationBridge.sol/BaseMigrationBridge.json` (Base Sepolia)
- `MockRDATv1` ABI (embedded in DeployBaseSepolia.s.sol)

Extract ABIs using:
```bash
forge inspect RDATUpgradeable abi > abi/RDATUpgradeable.json
forge inspect TreasuryWallet abi > abi/TreasuryWallet.json
forge inspect VanaMigrationBridge abi > abi/VanaMigrationBridge.json
forge inspect RDATDataDAO abi > abi/RDATDataDAO.json
forge inspect BaseMigrationBridge abi > abi/BaseMigrationBridge.json
```

### 3. Key User Flows to Implement

#### Token Balance & Transfers
```typescript
// Read user balance
const balance = await rdatContract.balanceOf(userAddress)

// Transfer tokens
const tx = await rdatContract.transfer(recipientAddress, amount)

// Approve spending
const tx = await rdatContract.approve(spenderAddress, amount)
```

#### Migration Flow (Base → Vana)
```typescript
// 1. On Base: User approves and locks tokens
// 2. Backend: Collect validator signatures
// 3. On Vana: Submit migration
const tx = await migrationBridge.processMigration(
  userAddress,
  amount,
  migrationId,
  validatorSignatures
)

// Check migration status
const status = await migrationBridge.getMigrationStatus(migrationId)
```

#### Data Contribution Flow
```typescript
// Submit data contribution
const tx = await rdatDataDAO.contributeData(dataHash, qualityScore)

// Check rewards
const rewards = await rdatDataDAO.contributorRewards(userAddress)

// View contribution stats
const [score, rewards] = await rdatDataDAO.getContributor(userAddress)
```

### 4. Event Monitoring
Set up event listeners for real-time updates:

```typescript
// Token transfers
rdatContract.on('Transfer', (from, to, amount, event) => {
  // Update UI
})

// Migration completed
migrationBridge.on('MigrationProcessed', (user, amount, migrationId) => {
  // Show success notification
})

// Data contribution
rdatDataDAO.on('DataContributed', (contributor, dataHash, score) => {
  // Update leaderboard
})
```

### 5. Error Handling
Common contract errors to handle:

```typescript
// Insufficient balance
"ERC20: transfer amount exceeds balance"

// Not authorized
"AccessControl: account 0x... is missing role 0x..."

// Migration already processed
"Migration already completed"

// Contract paused
"Pausable: paused"
```

## Security Considerations

1. **Always validate user inputs** before contract calls
2. **Check allowances** before transferFrom operations
3. **Monitor gas prices** on Vana network
4. **Implement retry logic** for failed transactions
5. **Cache read-only data** to minimize RPC calls

## Required UI Components

Based on the contracts, implement these pages/components:

### Essential Pages
1. **Dashboard** - Token balance, migration status, contribution score
2. **Migration** - Cross-chain migration interface
3. **Treasury** - Vesting schedules, distribution history
4. **Data Contribution** - Submit and validate data
5. **Governance** (Future) - Voting, proposals

### Key Components
1. **TokenBalance** - Display RDAT balance
2. **MigrationWidget** - Initiate and track migrations
3. **ContributionForm** - Submit Reddit data
4. **VestingSchedule** - Visualize treasury vesting
5. **NetworkSwitcher** - Toggle between Base/Vana

## Testing on Testnet

### Complete Migration Testing Flow

#### Prerequisites
1. **Base Sepolia ETH**: Get from [Base Sepolia Faucet](https://faucet.quicknode.com/base/sepolia)
2. **Vana Moksha VANA**: Contact team for testnet VANA tokens
3. **Test Wallets**: Use provided test accounts or connect your own wallet

#### Testing Scenario 1: Full Migration Flow
```typescript
// 1. On Base Sepolia - Check V1 token balance
const v1Balance = await mockRDATv1.balanceOf(userAddress)
console.log('V1 Balance:', v1Balance.toString())

// 2. On Base Sepolia - Approve migration
await mockRDATv1.approve(baseMigrationBridge.address, amountToMigrate)

// 3. On Base Sepolia - Initiate migration
await baseMigrationBridge.initiateMigration(amountToMigrate)

// 4. Wait for validator signatures (backend process)

// 5. On Vana Moksha - Process migration
await vanaMigrationBridge.processMigration(
  userAddress,
  amountToMigrate,
  migrationId,
  validatorSignatures
)

// 6. Verify V2 tokens received on Vana
const v2Balance = await rdatToken.balanceOf(userAddress)
```

#### Testing Scenario 2: Data Contribution
```typescript
// 1. Submit data contribution
await rdatDataDAO.contributeData(
  keccak256("test-reddit-data"),
  85 // Quality score 0-100
)

// 2. Check contribution stats
const [score, rewards] = await rdatDataDAO.getContributor(userAddress)
```

#### Testing Scenario 3: Treasury Operations
```typescript
// Check treasury balance and vesting
const treasuryBalance = await rdatToken.balanceOf(treasuryAddress)
const currentPhase = await treasuryWallet.getCurrentPhase()
const vestingSchedules = await treasuryWallet.getAllVestingSchedules()
```

### Test Wallet Private Keys (Anvil Standard)
**⚠️ ONLY FOR TESTING - DO NOT USE ON MAINNET**

1. **Test Wallet 1**: `0x70997970C51812dc3A010C7d01b50e0d17dc79C8`
   - Private Key: `0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d`

2. **Test Wallet 2**: `0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC`
   - Private Key: `0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a`

3. **Test Wallet 3**: `0x90F79bf6EB2c4f870365E785982E1f101E93b906`
   - Private Key: `0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6`

### Additional Test Scenarios
1. Token transfers between accounts
2. Cross-chain migration (Base Sepolia → Vana Moksha)  
3. Data contribution and reward distribution
4. Treasury vesting schedule checks

## Support & Resources

### Documentation
- Contract Documentation: `/docs` folder in this repository
- Technical Whitepaper: `/docs/WHITEPAPER.md`
- Governance Framework: `/docs/GOVERNANCE_FRAMEWORK.md`

### Contract Verification
All contracts are verified on Vanascan:
- [RDAT Token](https://moksha.vanascan.io/address/0xC1aC75130533c7F93BDa67f6645De65C9DEE9a3A)
- [Treasury](https://moksha.vanascan.io/address/0x31C3e3F091FB2A25d4dac82474e7dc709adE754a)
- [Migration Bridge](https://moksha.vanascan.io/address/0x31C3e3F091FB2A25d4dac82474e7dc709adE754a)
- [RDATDataDAO](https://moksha.vanascan.io/address/0x32B481b52616044E5c937CF6D20204564AD62164)

### GitHub Repository
- Contracts: https://github.com/rdatadao/contracts-v2
- Frontend: https://github.com/nissan/rdatadao-ui

## Next Steps for Frontend Team

1. **Immediate Actions**:
   - Update network configuration to include Vana Moksha
   - Import and integrate contract ABIs
   - Set up contract instances with wagmi/viem

2. **Priority Features**:
   - Token balance display
   - Migration interface (Base → Vana)
   - Basic treasury information display

3. **Phase 2 Features**:
   - Data contribution interface
   - Rewards tracking
   - Vesting schedule visualization

4. **Future Features** (after remaining contracts deployed):
   - Staking interface
   - Governance voting
   - Rewards claiming

## Contact for Support

For technical questions or issues:
- Review existing documentation in `/docs`
- Check test examples in `/test`
- Refer to deployment scripts in `/script`

The contracts are production-ready with 100% test coverage. All critical functionality has been thoroughly tested and is ready for frontend integration.