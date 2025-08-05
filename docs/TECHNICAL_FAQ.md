# Technical FAQ and Architectural Decisions

This document captures important technical decisions, architectural patterns, and frequently asked questions about the r/datadao V2 smart contract implementation.

## Table of Contents
1. [Emergency Pause Architecture](#emergency-pause-architecture)
2. [Upgradeability Patterns](#upgradeability-patterns)
3. [Token Architecture](#token-architecture)
4. [Security Decisions](#security-decisions)

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

## Upgradeability Patterns

### Q: Why use UUPS instead of Transparent Proxy?

**A:** We chose UUPS (Universal Upgradeable Proxy Standard) for several reasons:

1. **Gas Efficiency:** UUPS has lower overhead per transaction
2. **Flexibility:** Upgrade logic in implementation allows custom authorization
3. **Storage Safety:** Built-in storage gap pattern prevents collisions
4. **Industry Standard:** Widely adopted and battle-tested pattern

### Q: How do we ensure safe upgrades?

**A:** Multiple safety mechanisms:

1. **Storage Gaps:** 50-slot gaps in each contract
2. **Initializer Guards:** Prevent re-initialization
3. **Version Tracking:** Semantic versioning in contracts
4. **Access Control:** Only authorized upgraders can upgrade
5. **Testing:** Comprehensive upgrade test suite

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

### Q: Why 48-hour mint delay for vRDAT?

**A:** The mint delay prevents flash loan attacks and ensures:

1. **No Flash Minting:** Can't mint and vote in same transaction
2. **Time for Review:** Community can detect suspicious minting
3. **Stable Governance:** Voting power can't change suddenly

### Q: Why separate MINTER_ROLE and BURNER_ROLE?

**A:** Role separation follows principle of least privilege:

1. **Minting:** Only treasury/rewards contracts need this
2. **Burning:** Only staking/penalty contracts need this
3. **Reduces Risk:** Compromise of one role doesn't affect the other
4. **Audit Trail:** Different events for different actions

---

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

*Last Updated: August 5, 2025*

## Contributing to this FAQ

When adding new entries:
1. Include the question that prompted the explanation
2. Provide code examples where relevant
3. Explain the "why" not just the "what"
4. Include any considered alternatives
5. Date your additions