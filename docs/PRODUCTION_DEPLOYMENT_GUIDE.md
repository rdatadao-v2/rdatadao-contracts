# Production Deployment Guide

## Overview
This guide ensures all audit remediations are production-ready, leveraging battle-tested OpenZeppelin contracts and industry best practices.

## Audit Remediations - Production Status

### HIGH Severity ✅

#### H-01: Trapped Funds (Production-Ready ✅)
**Implementation**: `StakingPositions.withdrawPenalties()`
- ✅ Role-based access control (TREASURY_ROLE)
- ✅ Reentrancy protection (state change before transfer)
- ✅ SafeERC20 for secure transfers
- ✅ Comprehensive event logging
- ✅ Input validation

#### H-02: Migration Challenge (Production-Ready ✅)
**Implementation**: `VanaMigrationBridge` challenge mechanism
- ✅ Time-based challenge windows (6 hours)
- ✅ Admin override after 7-day review period
- ✅ Role-based access control
- ⚠️ **Recommendation**: Deploy with TimelockController holding admin role

### MEDIUM Severity ✅

#### M-01: V1 Token Burning (Production-Ready ✅)
**Implementation**: `BaseMigrationBridge` sends to burn address
- ✅ Standard burn address (0xdEaD)
- ✅ Irreversible token removal
- ✅ Event logging for transparency

#### M-02: NFT Transfer Fix (Production-Ready ✅)
**Implementation**: Removed blocking condition in `StakingPositions`
- ✅ NFTs transferable after lock period
- ✅ Maintains security checks

#### M-03: Front-Running Prevention (Production-Ready ✅)
**Implementation**: Internal poolId generation in `RDATUpgradeable`
- ✅ Uses counter + timestamp + sender
- ✅ Cryptographically secure
- ✅ Prevents prediction attacks

#### M-04: Challenge Period Enforcement (Production-Ready ✅)
**Implementation**: Time window validation
- ✅ Enforced 6-hour challenge window
- ✅ Cannot challenge after period

### LOW Severity ✅

#### L-01: Event Emissions (Production-Ready ✅)
- ✅ TokensRescued events added
- ✅ All critical actions logged

#### L-02: Role Separation (Production-Ready ✅)
- ✅ Deployment documentation added
- ✅ Multi-sig recommendations included

#### L-03: Documentation (Production-Ready ✅)
- ✅ Verified correct (100 position limit)

#### L-04: Timelock Implementation (Production-Ready ✅)
**Implementation**: OpenZeppelin TimelockController
- ✅ Deployment script: `DeployTimelockController.s.sol`
- ✅ Integration guide: `TimelockIntegration.sol`
- ✅ 48-hour minimum delay
- ✅ Separate proposer/executor roles
- ✅ Multi-sig compatible
- ✅ Emergency cancellation support

#### L-05: Reward Accounting (Production-Ready ✅)
**Implementation**: Comprehensive tracking in `StakingPositions`
- ✅ User lifetime rewards tracking
- ✅ Pending rewards visibility
- ✅ Distribution timestamps
- ✅ Comprehensive statistics functions

#### L-06: Error Clarity (Production-Ready ✅)
- ✅ Renamed to MigrationIsChallenged

#### L-07: Event Coverage (Production-Ready ✅)
- ✅ BonusVestingSet event
- ✅ UnclaimedTokensReturned event

## Production Deployment Steps

### 1. Deploy TimelockController (CRITICAL)

```bash
# Set environment variables
export ADMIN_ADDRESS=<YOUR_MULTISIG>
export RPC_URL=<YOUR_RPC>
export PRIVATE_KEY=<DEPLOYER_KEY>

# Deploy timelock
forge script script/DeployTimelockController.s.sol \
  --rpc-url $RPC_URL \
  --broadcast \
  --private-key $PRIVATE_KEY \
  --verify
```

### 2. Configure Role Architecture

```solidity
// Production role setup (use multi-sigs)
address multisig = 0x...; // Your Gnosis Safe
address timelock = 0x...; // Deployed TimelockController

// Grant critical roles to timelock
rdatToken.grantRole(UPGRADER_ROLE, timelock);
rdatToken.grantRole(DEFAULT_ADMIN_ROLE, timelock);

// Keep emergency roles with multisig
rdatToken.grantRole(PAUSER_ROLE, multisig);

// Revoke direct access
rdatToken.revokeRole(UPGRADER_ROLE, deployer);
rdatToken.revokeRole(DEFAULT_ADMIN_ROLE, deployer);
```

### 3. Migration Bridge Setup

```solidity
// Deploy with proper validator set
address[] memory validators = [
    0x..., // Validator 1 (ideally different entities)
    0x..., // Validator 2
    0x...  // Validator 3
];

// Deploy bridge with timelock as admin
VanaMigrationBridge bridge = new VanaMigrationBridge(
    v2Token,
    timelock, // Admin is timelock, not EOA
    validators
);
```

### 4. Staking Positions Configuration

```solidity
// Deploy with proper role separation
StakingPositions staking = new StakingPositions();
staking.initialize(rdatToken, vrdatToken, timelock);

// Grant operational roles
staking.grantRole(TREASURY_ROLE, treasuryMultisig);
staking.grantRole(REVENUE_COLLECTOR_ROLE, revenueCollector);
staking.grantRole(PAUSER_ROLE, emergencyMultisig);
```

## Security Checklist

### Pre-Deployment
- [ ] All contracts compiled without errors
- [ ] All 382 tests passing
- [ ] Slither/Mythril security scan clean
- [ ] Multi-sig wallets created and tested
- [ ] TimelockController deployed and tested
- [ ] Deployment scripts tested on testnet

### Deployment
- [ ] Use hardware wallet or secure key management
- [ ] Deploy TimelockController first
- [ ] Verify all contracts on Etherscan/Vanascan
- [ ] Transfer ownership to timelock
- [ ] Revoke deployer privileges
- [ ] Test emergency pause functionality

### Post-Deployment
- [ ] Monitor first 24 hours closely
- [ ] Schedule re-audit after 30 days
- [ ] Document all admin actions
- [ ] Set up monitoring alerts
- [ ] Establish incident response plan

## Role Recommendations

### Multi-Sig Setup (Gnosis Safe)
```
Treasury Multi-Sig: 3/5 threshold
- CFO
- CEO  
- Board Member 1
- Board Member 2
- External Auditor

Emergency Multi-Sig: 2/3 threshold (24/7 availability)
- CTO
- Security Lead
- DevOps Lead

Timelock Proposers: 3/5 threshold
- Same as Treasury Multi-Sig

Timelock Executors: 2/3 threshold
- Subset of proposers or automated after delay
```

### Validator Network (Migration Bridge)
```
Minimum 3 validators from different entities:
- Internal validator (company-operated)
- Partner validator (trusted partner)
- Community validator (DAO-elected)

Require 2/3 consensus for migrations
```

## Monitoring & Alerts

### Critical Events to Monitor
1. **Upgrades**: Any upgrade proposal or execution
2. **Role Changes**: Grant/revoke of any role
3. **Large Migrations**: Migrations > $100k value
4. **Challenge Events**: Any migration challenge
5. **Emergency Actions**: Pause/unpause events
6. **Penalty Withdrawals**: Treasury withdrawing penalties

### Recommended Tools
- OpenZeppelin Defender for monitoring
- Tenderly for real-time alerts
- Grafana dashboard for metrics
- PagerDuty for incident management

## Emergency Response Plan

### Level 1: Suspicious Activity
1. Monitor closely
2. Alert security team
3. Prepare pause if needed

### Level 2: Confirmed Exploit Attempt
1. Pause affected contracts
2. Alert all stakeholders
3. Begin investigation
4. Prepare remediation

### Level 3: Active Exploit
1. Emergency pause all contracts
2. War room activation
3. Public communication
4. Work with security partners
5. Plan recovery/migration

## Upgrade Process (via Timelock)

### Step 1: Prepare Upgrade
```solidity
// Deploy new implementation
RDATUpgradeableV2 newImpl = new RDATUpgradeableV2();

// Verify on Etherscan
```

### Step 2: Schedule via Timelock
```solidity
TimelockController timelock = TimelockController(TIMELOCK_ADDRESS);

bytes memory upgradeCall = abi.encodeWithSignature(
    "upgradeToAndCall(address,bytes)",
    address(newImpl),
    ""
);

// Schedule (requires proposer role)
timelock.schedule(
    PROXY_ADDRESS,
    0,
    upgradeCall,
    bytes32(0),
    salt,
    48 hours
);
```

### Step 3: Wait 48 Hours
- Community review period
- Security analysis
- Emergency cancellation if issues found

### Step 4: Execute Upgrade
```solidity
// After 48 hours, execute (requires executor role)
timelock.execute(
    PROXY_ADDRESS,
    0,
    upgradeCall,
    bytes32(0),
    salt
);
```

## Compliance & Audit Trail

### Documentation Requirements
1. **Every Admin Action**: Document in governance forum
2. **Timelock Operations**: Public announcement 48h before
3. **Emergency Actions**: Post-mortem within 72h
4. **Validator Actions**: Monthly transparency report

### Audit Schedule
- Initial audit: Completed (Hashlock)
- Re-audit: 30 days post-deployment
- Quarterly reviews: Ongoing
- Annual comprehensive audit: Required

## Contact & Support

### Security Issues
- Email: security@rdatadao.org
- Bug Bounty: https://immunefi.com/bounty/rdatadao

### Technical Support
- Discord: https://discord.gg/rdatadao
- Telegram: https://t.me/rdatadao_dev

### Emergency Contacts
- Security Lead: [Encrypted contact]
- CTO: [Encrypted contact]
- External Security: [Audit firm hotline]

---

*Last Updated: August 2025*
*Version: 1.0.0*
*Status: Production-Ready*