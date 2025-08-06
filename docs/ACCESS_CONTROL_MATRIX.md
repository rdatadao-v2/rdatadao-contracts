# 🔐 RDAT V2 Access Control Matrix

**Date**: August 6, 2025  
**Version**: 1.0 - Complete Role Definitions  
**Multi-sig Setup**: Gnosis Safe (3-of-5 signatures required)  
**Security Model**: External multi-sig with role-based access control  

---

## 🎯 Overview

This document defines all access control roles across the RDAT V2 smart contract ecosystem, specifying which operations require multi-sig approval versus single admin permissions, and providing the exact multi-sig addresses for each network.

### **Security Philosophy**
- **Critical Operations**: Require 3-of-5 multi-sig approval through Gnosis Safe
- **Operational Tasks**: Single admin or automated systems for efficiency
- **Emergency Response**: Fast multi-sig coordination with hardware wallet support
- **External Multi-sig**: Leverage proven Gnosis Safe infrastructure instead of custom logic

---

## 🌍 Network-Specific Multi-sig Addresses

### **Gnosis Safe Multi-sig Addresses (3-of-5 Threshold)**

#### **Vana Networks**
```
Vana Mainnet:  0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319
Vana Moksha:   0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319
```

#### **Base Networks**  
```
Base Mainnet:  0x90013583c66D2bf16327cB5Bc4a647AcceCF4B9A
Base Sepolia:  0x90013583c66D2bf16327cB5Bc4a647AcceCF4B9A
```

### **Multi-sig Configuration**
- **Threshold**: 3-of-5 signatures required for all multi-sig operations
- **Signers**: 5 trusted community members with hardware wallets
- **Emergency Response**: Mobile app available for time-sensitive operations
- **Transaction Batching**: Multiple operations can be bundled for efficiency

---

## 🛡️ Role Definitions by Contract

### **1. RDATUpgradeable.sol**

#### **Multi-sig Controlled Roles**
```solidity
DEFAULT_ADMIN_ROLE → Gnosis Safe Multi-sig
├─ Contract upgrades (UUPS proxy)
├─ VRC-20 contract configuration (PoC, DataRefiner)  
├─ Revenue collector configuration
└─ Emergency parameter changes

PAUSER_ROLE → Gnosis Safe Multi-sig
├─ Emergency pause activation
├─ Emergency unpause (coordination required)
└─ Protocol-wide emergency response
```

#### **No Minting Roles**
```solidity
// REMOVED: No MINTER_ROLE exists - fixed supply model
// REMOVED: No mint() function - completely eliminated
// SECURITY: Zero minting capability ensures true fixed supply
```

#### **Operations Summary**
- **Multi-sig Required**: All administrative functions, VRC-20 config, pausing
- **Single Admin**: None - all operations require multi-sig
- **Automated**: None - all operations require human approval

---

### **2. vRDAT.sol (Governance Token)**

#### **Multi-sig Controlled Roles**
```solidity
DEFAULT_ADMIN_ROLE → Gnosis Safe Multi-sig
├─ Contract administration
├─ Emergency parameter changes
└─ Role management

PAUSER_ROLE → Gnosis Safe Multi-sig  
├─ Emergency pause activation
└─ Emergency unpause coordination
```

#### **Reward Module Roles**
```solidity
MINTER_ROLE → vRDATRewardModule Contract Address
├─ Automatic minting when positions created
├─ Proportional to staked amount and lock duration
└─ No human intervention required

BURNER_ROLE → vRDATRewardModule Contract Address
├─ Automatic burning when positions unstaked
├─ Maintains governance token accuracy  
└─ No human intervention required
```

#### **Operations Summary**
- **Multi-sig Required**: Admin functions, pausing, role changes
- **Automated**: Minting/burning via reward modules
- **Single Admin**: None

---

### **3. StakingPositions.sol**

#### **Multi-sig Controlled Roles**
```solidity
DEFAULT_ADMIN_ROLE → Gnosis Safe Multi-sig
├─ RewardsManager configuration
├─ Emergency parameter changes
└─ Contract administration

PAUSER_ROLE → Gnosis Safe Multi-sig
├─ Emergency pause of staking operations
├─ Emergency migration activation
└─ Coordination with other pause systems

UPGRADER_ROLE → Gnosis Safe Multi-sig
├─ Contract upgrades (UUPS proxy)
├─ Storage layout changes
└─ Implementation updates
```

#### **Operational Roles**
```solidity
// No operational roles - all functions are user-facing or automated
// Emergency migration is multi-sig controlled for security
```

#### **Operations Summary**
- **Multi-sig Required**: Upgrades, emergency actions, RewardsManager changes
- **User Operations**: Staking, unstaking, position management  
- **Automated**: Reward notifications to RewardsManager

---

### **4. RewardsManager.sol**

#### **Multi-sig Controlled Roles**
```solidity
DEFAULT_ADMIN_ROLE → Gnosis Safe Multi-sig
├─ Reward program registration
├─ Program parameter updates
├─ Phase 3 activation
└─ Emergency program suspension

UPGRADER_ROLE → Gnosis Safe Multi-sig
├─ Contract upgrades (UUPS proxy)
├─ Architecture improvements
└─ New module integration

PROGRAM_MANAGER_ROLE → Gnosis Safe Multi-sig
├─ Create new reward programs
├─ Update program parameters
├─ Suspend/resume programs
└─ Module configuration
```

#### **Phase 3 Activation**
```solidity
// Phase 3 Activation Process
function activatePhase3() external onlyRole(DEFAULT_ADMIN_ROLE) {
    // Controlled by multi-sig
    // Requires DAO vote approval via Snapshot
    // Sets boolean flag for 30M token unlock eligibility
}
```

#### **Operations Summary**
- **Multi-sig Required**: All administrative functions, Phase 3 activation
- **Automated**: Reward distribution coordination
- **User Operations**: Claim rewards from all active programs

---

### **5. RevenueCollector.sol**

#### **Multi-sig Controlled Roles**
```solidity
DEFAULT_ADMIN_ROLE → Gnosis Safe Multi-sig
├─ Revenue distribution configuration
├─ Pool address updates (treasury, contributors)
├─ RewardsManager integration updates
└─ Emergency parameter changes

UPGRADER_ROLE → Gnosis Safe Multi-sig
├─ Contract upgrades (UUPS proxy)
├─ Distribution logic improvements  
└─ Automation enhancements
```

#### **Operational Roles**
```solidity
REVENUE_REPORTER_ROLE → Automated Bot OR Multi-sig
├─ Report revenue from various sources
├─ Trigger manual revenue distribution
├─ Update revenue metrics
└─ Operational efficiency role

// DECISION: Can be granted to automated systems for efficiency
// FALLBACK: Multi-sig retains ability to report revenue manually
```

#### **Operations Summary**
- **Multi-sig Required**: Configuration, upgrades, pool addresses
- **Automated/Bot**: Revenue reporting (with multi-sig oversight)
- **Manual**: Revenue distribution (V2), automated in V3

---

### **6. TreasuryWallet.sol**

#### **Multi-sig Controlled Roles**
```solidity
DEFAULT_ADMIN_ROLE → Gnosis Safe Multi-sig
├─ Treasury operations
├─ Vesting schedule management
├─ Phase 3 token allocation (30M unlock)
└─ Emergency treasury actions

UPGRADER_ROLE → Gnosis Safe Multi-sig
├─ Contract upgrades (UUPS proxy)
├─ Treasury functionality improvements
└─ Governance integration updates
```

#### **Operations Summary**
- **Multi-sig Required**: All treasury operations, Phase 3 unlocks
- **Automated**: Vesting schedule execution
- **DAO Governance**: Major allocation decisions via Snapshot

---

### **7. Migration Contracts**

#### **VanaMigrationBridge.sol**
```solidity
DEFAULT_ADMIN_ROLE → Gnosis Safe Multi-sig
├─ Bridge configuration
├─ Validator management
├─ Daily limit adjustments
└─ Emergency bridge suspension

VALIDATOR_ROLE → Multiple Independent Validators
├─ Migration request validation (2-of-3 minimum)
├─ Cross-chain verification
├─ Fraud prevention
└─ Consensus mechanism
```

#### **BaseMigrationBridge.sol**
```solidity
DEFAULT_ADMIN_ROLE → Gnosis Safe Multi-sig
├─ Bridge configuration
├─ Migration deadline management
└─ Emergency suspension

PAUSER_ROLE → Gnosis Safe Multi-sig
├─ Emergency pause migration
└─ Security incident response
```

#### **Operations Summary**
- **Multi-sig Required**: Bridge configuration, validator management
- **Validator Network**: Independent validation of cross-chain operations
- **Automated**: Migration processing after validation

---

### **8. Emergency Systems**

#### **EmergencyPause.sol**
```solidity
DEFAULT_ADMIN_ROLE → Gnosis Safe Multi-sig
├─ Protocol-wide pause coordination
├─ 72-hour auto-expiry configuration
├─ Cross-contract pause management
└─ Emergency response coordination

PAUSER_ROLE → Gnosis Safe Multi-sig
├─ Immediate pause activation
├─ Emergency unpause (coordination required)
└─ Incident response management
```

#### **Emergency Response Workflow**
1. **Incident Detection**: Automated monitoring or community report
2. **Multi-sig Activation**: 3-of-5 signers coordinate emergency pause
3. **Assessment Period**: Team evaluates incident severity
4. **Resolution**: Fix deployment or 72-hour auto-expiry
5. **Recovery**: Coordinated unpause across all contracts

---

## 🚨 Emergency Response Procedures

### **Immediate Response (0-1 hours)**
1. **Incident Verification**: Confirm threat legitimacy  
2. **Multi-sig Coordination**: Contact available signers via secure channels
3. **Emergency Pause**: Execute pause across affected contracts
4. **Public Communication**: Notify community via Discord/Twitter

### **Assessment Phase (1-24 hours)**
1. **Technical Analysis**: Evaluate vulnerability scope and impact
2. **Solution Development**: Prepare fix or mitigation strategy
3. **Testing**: Validate solution on testnet environments
4. **Stakeholder Communication**: Update community on progress

### **Recovery Phase (24-72 hours)**  
1. **Fix Deployment**: Deploy updates if needed
2. **Security Review**: Final validation of resolution
3. **Coordinated Unpause**: Resume operations across contracts
4. **Post-mortem**: Document incident and improve procedures

### **Multi-sig Response Tools**
- **Hardware Wallets**: All signers use hardware wallets for security
- **Mobile App**: Gnosis Safe app for urgent responses
- **Transaction Batching**: Bundle multiple emergency actions
- **Timelock Override**: Critical functions can bypass normal delays

---

## 🔧 Role Management Procedures

### **Role Granting Process**
1. **Multi-sig Proposal**: Create transaction in Gnosis Safe
2. **Community Discussion**: Discord discussion for transparency  
3. **Signer Review**: 3-of-5 signers review and approve
4. **Execution**: Role granted via multi-sig transaction
5. **Verification**: Confirm role assignment on-chain

### **Role Revocation Process**
1. **Security Assessment**: Evaluate need for role removal
2. **Multi-sig Coordination**: Prepare revocation transaction
3. **Emergency Protocol**: Immediate revocation if security threat
4. **Documentation**: Record reason and process

### **Regular Audits**
- **Monthly**: Review all active roles and permissions
- **Quarterly**: Full access control audit with security team
- **Annually**: Comprehensive security review with external auditors
- **Post-incident**: Role review after any security event

---

## 📋 Implementation Checklist

### **Deployment Phase**
- [ ] Deploy all contracts with placeholder admin addresses
- [ ] Configure Gnosis Safe with 3-of-5 threshold on each network
- [ ] Transfer all admin roles to multi-sig addresses
- [ ] Verify role assignments on-chain
- [ ] Test emergency pause procedures

### **Operational Phase**  
- [ ] Grant REVENUE_REPORTER_ROLE to automated systems
- [ ] Configure reward module permissions (MINTER/BURNER roles)
- [ ] Set up monitoring for unauthorized role changes
- [ ] Document emergency response procedures
- [ ] Train multi-sig signers on procedures

### **Governance Phase**
- [ ] Implement Phase 3 activation procedures
- [ ] Connect treasury management to DAO governance
- [ ] Establish role change governance processes
- [ ] Regular security audits and role reviews

---

## 🎯 Security Benefits

### **Gnosis Safe Integration**
- **Battle-tested**: Securing $100B+ across DeFi
- **Hardware Wallet Support**: All signers use hardware wallets
- **Mobile Emergency Response**: Critical for time-sensitive incidents
- **Transaction Batching**: Efficient multi-operation execution
- **Upgrade Path**: No contract changes needed for multi-sig updates

### **Role Separation**
- **Critical vs. Operational**: Multi-sig for critical, automation for operational
- **Emergency Response**: Fast coordination without single points of failure
- **Governance Integration**: DAO oversight of major decisions
- **Audit Trail**: Complete history of all administrative actions

### **Risk Mitigation**
- **No Single Admin**: All critical functions require multi-sig
- **Hardware Security**: Private keys stored in hardware wallets
- **Emergency Procedures**: Well-defined response protocols  
- **Regular Audits**: Ongoing security review processes
- **Community Oversight**: Transparent role management

---

*This access control matrix ensures secure, efficient, and transparent management of the RDAT V2 ecosystem while maintaining operational flexibility for growth and emergency response.*