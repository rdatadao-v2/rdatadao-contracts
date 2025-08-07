# Access Control Matrix - RDAT V2

**Last Updated**: August 6, 2025  
**Status**: Complete specification of all roles and assignments  

---

## 🔐 Overview

This document defines all access control roles across the RDAT V2 ecosystem, their permissions, and recommended assignments. All contracts use OpenZeppelin's AccessControl pattern with role-based permissions.

---

## 📋 Role Assignments by Contract

### 1. RDATUpgradeable.sol

| Role | Permission | Assignment | Notes |
|------|------------|------------|-------|
| DEFAULT_ADMIN_ROLE | Grant/revoke all roles | Multisig | 3/5 signatures required |
| PAUSER_ROLE | Pause token transfers | Multisig + Emergency Team | 2/5 for emergency |
| UPGRADER_ROLE | Upgrade contract logic | Multisig only | 3/5 signatures + timelock |

**Note**: No MINTER_ROLE exists - all 100M tokens minted at deployment

### 2. vRDAT.sol

| Role | Permission | Assignment | Notes |
|------|------------|------------|-------|
| DEFAULT_ADMIN_ROLE | Grant/revoke roles | Multisig | Cannot mint directly |
| MINTER_ROLE | Mint vRDAT tokens | vRDATRewardModule ONLY | Soul-bound tokens |
| BURNER_ROLE | Burn vRDAT tokens | vRDATRewardModule ONLY | For emergency exits |

### 3. StakingPositions.sol

| Role | Permission | Assignment | Notes |
|------|------------|------------|-------|
| ADMIN_ROLE | Set parameters, pause | Multisig | Non-upgradeable |
| REWARDS_MANAGER_ROLE | Update reward rates | RewardsManager contract | Automated only |

### 4. RewardsManager.sol

| Role | Permission | Assignment | Notes |
|------|------------|------------|-------|
| DEFAULT_ADMIN_ROLE | Register reward programs | Multisig | Program governance |
| STAKING_NOTIFIER_ROLE | Notify stake/unstake | StakingPositions contract | Automated only |
| UPGRADER_ROLE | Upgrade contract | Multisig | 3/5 + timelock |

### 5. vRDATRewardModule.sol

| Role | Permission | Assignment | Notes |
|------|------------|------------|-------|
| DEFAULT_ADMIN_ROLE | Emergency functions | Multisig | Circuit breaker |
| REWARDS_MANAGER_ROLE | Call reward functions | RewardsManager contract | Automated only |

### 6. RDATRewardModule.sol (Phase 3)

| Role | Permission | Assignment | Notes |
|------|------------|------------|-------|
| DEFAULT_ADMIN_ROLE | Set reward parameters | Multisig | Phase 3 activation |
| REWARDS_MANAGER_ROLE | Distribute rewards | RewardsManager contract | Automated only |

### 7. MigrationBridge.sol

| Role | Permission | Assignment | Notes |
|------|------------|------------|-------|
| DEFAULT_ADMIN_ROLE | Emergency pause | Multisig | Both chains |
| VALIDATOR_ROLE | Validate migrations | 3 validators minimum | 2/3 consensus |
| CHALLENGER_ROLE | Challenge migrations | Security monitors | 6-hour window |

**Validators** (TBD at deployment):
- Validator 1: `0x...` (Independent security firm)
- Validator 2: `0x...` (Community validator)
- Validator 3: `0x...` (Team validator)

### 8. EmergencyPause.sol

| Role | Permission | Assignment | Notes |
|------|------------|------------|-------|
| PAUSER_ROLE | Trigger emergency pause | Multisig + Emergency Team | 72-hour auto-expiry |
| UNPAUSER_ROLE | Unpause before expiry | Multisig only | 3/5 required |

### 9. RevenueCollector.sol

| Role | Permission | Assignment | Notes |
|------|------------|------------|-------|
| DEFAULT_ADMIN_ROLE | Set distribution params | Multisig | 50/30/20 split |
| DISTRIBUTOR_ROLE | Trigger distribution | Multisig + Automation | Weekly basis |

### 10. ProofOfContribution.sol

| Role | Permission | Assignment | Notes |
|------|------------|------------|-------|
| DEFAULT_ADMIN_ROLE | System configuration | Multisig | VRC-20 params |
| VALIDATOR_ROLE | Validate contributions | Oracle network | Multiple validators |
| REGISTRAR_ROLE | Register contributors | Multisig | KYC compliance |

---

## 🏛️ Multisig Addresses

### Vana Network
- **Primary Multisig**: `0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319`
- **Signers**: 5 (require 3/5 for critical, 2/5 for emergency)
- **Timelock**: 48 hours for upgrades

### Base Network (Legacy)
- **Monitoring Only**: `0x90013583c66D2bf16327cB5Bc4a647AcceCF4B9A`
- **Purpose**: Monitor V1 token burns only
- **No V2 permissions**

---

## 🚨 Emergency Response Team

**Purpose**: Rapid response to security incidents

**Members** (addresses to be set at deployment):
1. **Technical Lead**: `0x...` (24/7 availability)
2. **Security Lead**: `0x...` (Incident response)
3. **Operations Lead**: `0x...` (Communication)

**Permissions**:
- Can pause critical contracts (with multisig member)
- Cannot unpause (requires full multisig)
- Cannot upgrade or modify parameters

---

## 🔄 Role Management Procedures

### Adding a New Role Member
1. Proposal created with justification
2. 48-hour discussion period
3. Multisig vote (3/5 required)
4. 24-hour timelock before execution
5. On-chain execution with event emission

### Removing a Role Member
1. Immediate removal for security incidents
2. Standard removal follows add procedure
3. Document reason in transaction

### Emergency Role Changes
1. 2/5 multisig can remove compromised addresses
2. Full documentation required within 24 hours
3. Community notification mandatory

---

## 📊 Permission Matrix Summary

| Action | Required Signatures | Timelock | Notes |
|--------|-------------------|----------|-------|
| Token Upgrade | 3/5 | 48 hours | UUPS pattern |
| Emergency Pause | 2/5 | None | 72-hour auto-expiry |
| Unpause | 3/5 | None | Before auto-expiry |
| Add Reward Program | 3/5 | 24 hours | RewardsManager |
| Set Parameters | 3/5 | 24 hours | Most contracts |
| Role Grant/Revoke | 3/5 | 24 hours | All contracts |
| Revenue Distribution | 2/5 | None | Manual trigger |

---

## 🔍 Audit Trail

All role assignments and changes are:
1. Recorded on-chain via events
2. Documented in multisig transaction notes
3. Announced to community via official channels
4. Tracked in this document with version history

---

## 📞 Contact Information

**For deployment, actual contacts will be**:
- Technical Issues: [Technical Lead Contact]
- Security Incidents: [Security Email]
- General Inquiries: [Community Channels]

**Response Times**:
- Critical Security: < 1 hour
- High Priority: < 4 hours
- Normal Operations: < 24 hours

---

## 🔄 Document Maintenance

This document must be updated:
- Before any mainnet deployment
- After any role assignment changes
- When emergency procedures are invoked
- During regular quarterly reviews

**Version Control**: Track all changes in git with clear commit messages