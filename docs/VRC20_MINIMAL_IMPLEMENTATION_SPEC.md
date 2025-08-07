# 📋 VRC-20 Minimal Implementation Specification

**Version**: 1.0  
**Date**: August 7, 2025  
**Sprint**: August 7-18, 2025 (11 days)  
**Approach**: Option B - Minimal Compliance with Updateable DLP Registry

## Executive Summary

This specification defines the minimal VRC-20 compliance implementation for r/datadao V2, focusing on essential features required before audit while deferring complex functionality to post-audit phases.

## Core Design Principles

1. **Minimal Viable Compliance**: Implement only what's required to pass VRC-20 verification
2. **Updateable Configuration**: DLP Registry can be set/changed post-deployment
3. **Clean Audit Focus**: Simple, testable code that auditors can verify easily
4. **Future Extensibility**: Architecture supports adding features without breaking changes

## Required VRC-20 Features (Must Have)

### 1. Address Blocklisting ❌ → 🆕
**Current Status**: Not implemented  
**Implementation**: Days 3-4

```solidity
// Required functionality
mapping(address => bool) private _blacklist;

function blacklist(address account) external onlyAdmin;
function unBlacklist(address account) external onlyAdmin;
function isBlacklisted(address) external view returns (bool);

// Transfer restriction
function _update(address from, address to, uint256 value) internal override {
    require(!_blacklist[from] && !_blacklist[to], "Blacklisted");
    super._update(from, to, value);
}
```

### 2. 48-Hour Timelocks ⚠️ → 🆕
**Current Status**: Partial (only in RewardsManager)  
**Implementation**: Days 5-6

```solidity
// Required for critical operations
mapping(bytes32 => uint256) private _timelocks;
uint256 constant TIMELOCK_DURATION = 48 hours;

function scheduleTimelock(string description) returns (bytes32);
function executeTimelock(bytes32 actionId) external;
function cancelTimelock(bytes32 actionId) external;

// Apply to: upgrades, admin transfers, critical parameters
```

### 3. DLP Registry Integration ❌ → 🆕
**Current Status**: Stub only  
**Implementation**: Days 8-9

```solidity
// Updateable registry pattern
address public dlpRegistry;  // Can be set post-deployment
bool public isDLPRegistered;

function setDLPRegistry(address _registry) external onlyAdmin {
    dlpRegistry = _registry;
    emit DLPRegistryUpdated(_registry);
}

function registerWithDLP(uint256 dlpId) external onlyAdmin {
    require(dlpRegistry != address(0), "Registry not set");
    isDLPRegistered = true;
    emit DLPRegistered(dlpId, dlpRegistry);
}
```

### 4. Fixed Supply ✅
**Current Status**: Already implemented  
**No Changes Needed**: 100M fixed supply, no minting

### 5. Team Vesting ✅
**Current Status**: Already implemented  
**No Changes Needed**: 6-month cliff + 18-month linear

## Implementation Plan

### Phase 1: Setup & Review (Aug 7-8)
**Goal**: Understand V2 requirements and prepare branches

- [ ] Review RDATUpgradeableV2Minimal.sol
- [ ] Set up feature branches
- [ ] Review test requirements
- [ ] Coordinate with team on approach

### Phase 2: Blocklisting (Aug 9-10)
**Goal**: Implement VRC-20 required blocklisting

- [ ] Port blocklist mappings from V2Minimal
- [ ] Add admin functions (blacklist/unBlacklist)
- [ ] Override transfer functions
- [ ] Write comprehensive tests
- [ ] Document gas impact

### Phase 3: Timelocks (Aug 11-12)
**Goal**: Add 48-hour delays to critical operations

- [ ] Implement timelock mapping system
- [ ] Add schedule/execute/cancel functions
- [ ] Apply to upgrade functions
- [ ] Apply to admin transfers
- [ ] Test all timelock scenarios

### Phase 4: Integration (Aug 13)
**Goal**: Merge and test all features

- [ ] Merge blocklist + timelock branches
- [ ] Run full test suite
- [ ] Deploy to local testnet
- [ ] Test upgrade from V1 to V2
- [ ] Fix any integration issues

### Phase 5: DLP Registry (Aug 14-15)
**Goal**: Implement updateable DLP registry

- [ ] Add dlpRegistry state variable
- [ ] Implement setDLPRegistry function
- [ ] Add registerWithDLP function
- [ ] Add updateDLPRegistration function
- [ ] Test registry updates

### Phase 6: Testnet Deployment (Aug 16)
**Goal**: Deploy to public testnets

- [ ] Deploy to Vana Moksha testnet
- [ ] Deploy to Base Sepolia
- [ ] Verify all contracts
- [ ] Test cross-chain scenarios
- [ ] Document deployment addresses

### Phase 7: Audit Preparation (Aug 17-18)
**Goal**: Prepare for audit submission

- [ ] Freeze code (no more changes)
- [ ] Update all documentation
- [ ] Create audit package
- [ ] Tag release v2.0.0-audit
- [ ] Submit to auditors (Aug 19)

## Testing Requirements

### Unit Tests
- Blocklist functionality (10+ tests)
- Timelock mechanisms (8+ tests)
- DLP registry updates (5+ tests)
- Admin transfer delays (5+ tests)
- Integration scenarios (10+ tests)

### Integration Tests
- V1 → V2 upgrade path
- Cross-contract interactions
- Multi-sig scenarios
- Emergency procedures

### Gas Profiling
- Measure blocklist check overhead
- Timelock storage costs
- Registry update costs
- Compare to V1 baseline

## Security Considerations

### Blocklisting
- Cannot blacklist zero address
- Cannot blacklist token contract itself
- Admin-only function with reentrancy guard
- Events for all blacklist changes

### Timelocks
- 48-hour minimum delay (non-configurable)
- Cannot execute before expiry
- Can cancel if not executed
- Clear event trail for governance

### DLP Registry
- Only admin can set/update
- Cannot set to zero address
- Registry changes emit events
- Registration requires valid registry

### Admin Transfer
- 48-hour delay enforced
- Must be accepted by new admin
- Can be cancelled by current admin
- All roles transferred atomically

## Deployment Configuration

### Environment Variables
```bash
# Required
TREASURY_ADDRESS=0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319
ADMIN_ADDRESS=0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319

# Optional (can be set later)
DLP_REGISTRY=0x0000000000000000000000000000000000000000

# Deployment
DEPLOYER_PRIVATE_KEY=0x...
```

### Deployment Commands
```bash
# Dry run
forge script script/DeployRDATUpgradeableV2Minimal.s.sol --sig "dryRun()"

# Deploy fresh
forge script script/DeployRDATUpgradeableV2Minimal.s.sol --rpc-url $VANA_MOKSHA_RPC --broadcast

# Upgrade existing
EXISTING_PROXY=0x... forge script script/DeployRDATUpgradeableV2Minimal.s.sol --rpc-url $VANA_MOKSHA_RPC --broadcast
```

### Post-Deployment Setup
```javascript
// 1. Set DLP Registry (when available)
await rdat.setDLPRegistry("0x...vana_registry...");

// 2. Register with DLP
await rdat.registerWithDLP(1);

// 3. Configure blocklist (if needed)
await rdat.blacklist("0x...bad_actor...");

// 4. Verify compliance
assert(await rdat.isVRC20Compliant() === true);
```

## Success Metrics

### Must Complete (Pass/Fail)
- [ ] Blocklisting implemented and tested
- [ ] 48-hour timelocks working
- [ ] DLP registry updateable
- [ ] All existing tests pass
- [ ] Deployed to testnets
- [ ] VRC-20 compliance check passes

### Should Complete (Quality)
- [ ] Gas optimization completed
- [ ] Documentation updated
- [ ] Integration tests comprehensive
- [ ] Code coverage > 95%

### Nice to Have (Enhancement)
- [ ] Basic PoC scoring
- [ ] Compliance dashboard
- [ ] Automated verification scripts

## Risk Mitigation

### Timeline Risk
**Mitigation**: Use existing V2Minimal code, parallel work streams

### Complexity Risk
**Mitigation**: Minimal features only, defer enhancements

### Integration Risk
**Mitigation**: Daily testing, feature flags if needed

### Audit Risk
**Mitigation**: Simple, well-tested code with clear documentation

## Post-Audit Roadmap

### Phase 2: Enhanced VRC-20 (2 weeks)
- Full DLP Registry integration
- Complete PoC implementation
- Data pool management
- Epoch reward system

### Phase 3: Advanced Features (2 weeks)
- Kismet formula
- Data licensing
- Cross-DLP communication
- Revenue optimization

## Conclusion

This minimal implementation provides:
1. **VRC-20 Compliance**: Pass verification requirements
2. **DLP Eligibility**: Can register for rewards
3. **Flexibility**: Registry updateable post-deployment
4. **Clean Audit**: Simple, focused code
5. **Future-Proof**: Can enhance without breaking changes

The 11-day timeline is aggressive but achievable with focused execution on essential features only.