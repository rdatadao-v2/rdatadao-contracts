# Vana Network Multisig Configuration

## Overview

The r/datadao Vana multisig (`0xe4F7Eca807C57311e715C3Ef483e72Fa8D5bCcDF`) is the primary governance and treasury control mechanism for the RDAT V2 token ecosystem on Vana network.

## Multisig Address

**Vana Network Multisig**: `0xe4F7Eca807C57311e715C3Ef483e72Fa8D5bCcDF`
- **Network**: Vana Mainnet and Vana Moksha Testnet
- **Type**: Gnosis Safe (or equivalent multisig)
- **Required Signers**: TBD (recommend 3-of-5 or 4-of-7)

## Roles and Responsibilities

### 1. Treasury Management

The Vana multisig controls the **TreasuryWallet** contract which holds 70M RDAT (70% of total supply):

```
Treasury Allocation (70M RDAT):
├── Team Vesting (10M - 10%)
├── Development Fund (20M - 20%)
├── Community Rewards (30M - 30%)
└── Reserve Fund (10M - 10%)
```

**Key Functions**:
- Execute DAO proposals for token distributions
- Manage vesting schedules for team members
- Release community rewards (Phase 3 gated)
- Emergency fund management

### 2. Administrative Roles

The multisig holds critical administrative roles in the RDAT ecosystem:

#### DEFAULT_ADMIN_ROLE
- Manage all other roles
- Add/remove validators for migration bridge
- Update system parameters
- Emergency response coordination

#### PAUSER_ROLE
- Pause token transfers in emergencies
- Pause migration bridge operations
- Maximum pause duration: 72 hours (auto-expires)

#### UPGRADER_ROLE
- Authorize smart contract upgrades (RDAT token only)
- Should be transferred to TimelockController in production
- Requires 48-hour delay for upgrades

#### TREASURY_ROLE
- Withdraw emergency exit penalties from staking
- Manage treasury operations
- Execute approved distributions

### 3. Migration Bridge Administration

The multisig manages the cross-chain migration system:

- **Validator Management**: Add/remove migration validators
- **Daily Limits**: Adjust daily migration limits (default: 300,000 RDAT)
- **Challenge Resolution**: Override challenged migrations after 7-day review
- **Emergency Actions**: Pause bridge if under attack

## Token Distribution at Deployment

When RDAT V2 is deployed on Vana, the constructor automatically mints and distributes:

```solidity
constructor(
    address _treasury,      // 0xe4F7Eca807C57311e715C3Ef483e72Fa8D5bCcDF (Vana multisig)
    address _migration,     // VanaMigrationBridge address
    address _defaultAdmin   // 0xe4F7Eca807C57311e715C3Ef483e72Fa8D5bCcDF (Vana multisig)
) {
    // Mint to treasury (70M)
    _mint(_treasury, 70_000_000 * 10**18);

    // Mint to migration bridge (30M)
    _mint(_migration, 30_000_000 * 10**18);

    // Grant roles to admin
    _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
    _grantRole(PAUSER_ROLE, _defaultAdmin);
    _grantRole(UPGRADER_ROLE, _defaultAdmin);
}
```

## Deployment Configuration

### Environment Variables

```bash
# .env configuration for Vana deployment
VANA_MULTISIG_ADDRESS=0xe4F7Eca807C57311e715C3Ef483e72Fa8D5bCcDF
TREASURY_ADDRESS=0xe4F7Eca807C57311e715C3Ef483e72Fa8D5bCcDF
ADMIN_ADDRESS=0xe4F7Eca807C57311e715C3Ef483e72Fa8D5bCcDF
```

### Deployment Commands

#### Vana Moksha Testnet
```bash
# Deploy full system to Vana Moksha testnet
TREASURY_ADDRESS=$VANA_MULTISIG_ADDRESS \
ADMIN_ADDRESS=$VANA_MULTISIG_ADDRESS \
forge script script/DeployRDATUpgradeableProduction.s.sol \
  --rpc-url $VANA_MOKSHA_RPC_URL \
  --broadcast \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --verify
```

#### Vana Mainnet
```bash
# Deploy full system to Vana mainnet
TREASURY_ADDRESS=$VANA_MULTISIG_ADDRESS \
ADMIN_ADDRESS=$VANA_MULTISIG_ADDRESS \
forge script script/DeployRDATUpgradeableProduction.s.sol \
  --rpc-url $VANA_RPC_URL \
  --broadcast \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --verify \
  --slow
```

## Post-Deployment Setup

### 1. Verify Token Distribution

```bash
# Check treasury balance (should be 70M RDAT)
cast call $RDAT_TOKEN "balanceOf(address)" $VANA_MULTISIG_ADDRESS \
  --rpc-url $VANA_RPC_URL

# Check migration bridge balance (should be 30M RDAT)
cast call $RDAT_TOKEN "balanceOf(address)" $MIGRATION_BRIDGE_ADDRESS \
  --rpc-url $VANA_RPC_URL
```

### 2. Verify Role Assignments

```bash
# Check DEFAULT_ADMIN_ROLE
cast call $RDAT_TOKEN "hasRole(bytes32,address)" \
  $(cast keccak "DEFAULT_ADMIN_ROLE") \
  $VANA_MULTISIG_ADDRESS \
  --rpc-url $VANA_RPC_URL

# Check PAUSER_ROLE
cast call $RDAT_TOKEN "hasRole(bytes32,address)" \
  $(cast keccak "PAUSER_ROLE") \
  $VANA_MULTISIG_ADDRESS \
  --rpc-url $VANA_RPC_URL

# Check UPGRADER_ROLE
cast call $RDAT_TOKEN "hasRole(bytes32,address)" \
  $(cast keccak "UPGRADER_ROLE") \
  $VANA_MULTISIG_ADDRESS \
  --rpc-url $VANA_RPC_URL
```

### 3. Configure Treasury Vesting

The multisig must set up vesting schedules for team allocations:

```solidity
// Example: Set up team vesting (10M tokens)
// 6-month cliff, 18-month linear vesting
treasury.createVestingSchedule(
    teamMemberAddress,
    tokenAmount,
    cliffDuration,
    vestingDuration
);
```

### 4. Transfer to TimelockController (Production)

For production, transfer UPGRADER_ROLE to a TimelockController:

```bash
# Deploy TimelockController
forge script script/DeployTimelockController.s.sol \
  --rpc-url $VANA_RPC_URL \
  --broadcast \
  --private-key $DEPLOYER_PRIVATE_KEY

# Transfer UPGRADER_ROLE to timelock
cast send $RDAT_TOKEN "grantRole(bytes32,address)" \
  $(cast keccak "UPGRADER_ROLE") \
  $TIMELOCK_ADDRESS \
  --private-key $MULTISIG_SIGNER_KEY

# Revoke UPGRADER_ROLE from multisig
cast send $RDAT_TOKEN "revokeRole(bytes32,address)" \
  $(cast keccak "UPGRADER_ROLE") \
  $VANA_MULTISIG_ADDRESS \
  --private-key $MULTISIG_SIGNER_KEY
```

## Treasury Operations

### Execute DAO Proposal

```solidity
// Multisig executes approved DAO proposals
treasury.executeDAOProposal(
    recipientAddress,
    amount,
    "Proposal #123: Community grant for XYZ"
);
```

### Manage Staking Rewards

```solidity
// Configure rewards manager
rewardsManager.updateRewardRate(newRate);
rewardsManager.addRewardProgram(programId, allocation);
```

### Emergency Actions

```solidity
// Pause all transfers (max 72 hours)
rdatToken.pause();

// Unpause when resolved
rdatToken.unpause();

// Pause migration bridge
migrationBridge.pause();
```

## Security Considerations

### Multisig Best Practices

1. **Signer Diversity**
   - Geographic distribution
   - Different hardware wallets
   - Mix of team and community members

2. **Operational Security**
   - Regular signer rotation (annual)
   - Documented signing procedures
   - Emergency replacement process

3. **Transaction Review**
   - All transactions require detailed description
   - 24-hour review period for non-emergency
   - Public announcement for major changes

### Emergency Procedures

1. **Compromised Signer**
   - Immediately remove from multisig
   - Add replacement signer
   - Review recent transactions

2. **Contract Vulnerability**
   - Pause affected contracts
   - Coordinate patch deployment
   - Use timelock for upgrade

3. **Migration Attack**
   - Pause migration bridge
   - Challenge suspicious migrations
   - Coordinate with validators

## Governance Integration

### Phase 1: Multisig Control (Months 0-6)
- Direct multisig control of treasury
- Manual execution of operations
- Building community trust

### Phase 2: Hybrid Governance (Months 6-12)
- Community proposals via snapshot
- Multisig executes approved proposals
- Gradual decentralization

### Phase 3: Full DAO Control (Month 12+)
- On-chain governance via vRDAT
- Timelock-controlled execution
- Multisig retained for emergency only

## Contact and Support

### Multisig Signers
- Signer information kept private for security
- Contact via governance channel
- Emergency contact list maintained separately

### Technical Support
- Discord: #governance channel
- Email: governance@rdatadao.org
- Emergency: security@rdatadao.org

---

**Document Version**: 1.0.0
**Created**: December 2024
**Last Updated**: December 2024
**Next Review**: Before mainnet deployment