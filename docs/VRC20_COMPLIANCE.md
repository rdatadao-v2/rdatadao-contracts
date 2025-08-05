# VRC-20 Compliance Documentation

**Version**: 1.1 (Updated for V2 Beta)  
**Last Updated**: August 2025  
**Implementation Status**: Basic VRC-20 stubs in V2 Beta, full compliance in Phase 3

## Overview

This document outlines how the RDAT V2 token implementation complies with VRC-20 requirements, specifically focusing on team token vesting requirements for DLP (Data Liquidity Pool) rewards eligibility and the ProofOfContribution system integration.

## VRC-20 Requirements

### 1. Team Token Vesting (MANDATORY)

**Requirement**: "Team, founder, and early contributor allocations must be subject to a vesting schedule of at least 6 months, followed by linear vesting for the remainder."

**V2 Beta Implementation**:
- All team allocations are drawn from the Treasury & Ecosystem bucket (25M total)
- Minimum 6-month cliff period enforced in smart contract
- Linear vesting for 12 months after cliff
- Vesting starts on DLP reward eligibility date, not before
- ProofOfContribution.sol tracks contributor quality scores

### 2. Public Disclosure

**Requirement**: Teams must clearly disclose token allocations including amounts, timelines, and vesting mechanics.

**Implementation**:
- All team vesting schedules are recorded on-chain in `RDATVesting.sol`
- Public view functions allow anyone to verify vesting schedules
- Events emitted for all vesting schedule creations

### 3. Smart Contract Locking

**Requirement**: Tokens must be locked in a contract consistent with disclosures.

**V2 Beta Implementation**:
- Vesting contract enforces all rules (Phase 2 implementation)
- Tokens are held by multi-sig treasury until vesting contract deployment
- No ability to bypass vesting periods
- RDAT.sol includes VRC-20 compliance flags:
  ```solidity
  bool public constant isVRC20 = true;
  address public pocContract; // ProofOfContribution
  address public dataRefiner; // Phase 2
  ```

## Token Allocation Breakdown

Per DAO vote, the 100M RDAT tokens are allocated as follows:

| Allocation | Amount | Available for Team |
|------------|--------|-------------------|
| Migration Reserve | 30M | No - Reserved for 1:1 swap |
| Future Rewards | 30M | No - Locked until Phase 3 |
| Treasury & Ecosystem | 25M | Yes - After TGE release |
| Liquidity & Staking | 15M | No - Reserved for liquidity |

**Team Token Budget**:
- Maximum available: 22.5M (90% of Treasury after 10% TGE release)
- Must maintain sufficient treasury for ecosystem development
- Recommended team allocation: ≤ 10M tokens

## Vesting Schedule Details

### Team Member Vesting
```solidity
// Example team vesting schedule
createTeamVesting(
    teamMemberAddress,
    1_000_000e18, // 1M tokens
    dlpEligibilityTimestamp // Start date when DLP eligible for rewards
);
```

**Schedule**:
- Months 0-6: 0% (cliff period)
- Month 6: ~8.33% released (1/12 of total)
- Months 7-18: ~8.33% released monthly
- Month 18: 100% vested

### Treasury Vesting (Non-Team)
- TGE: 10% (2.5M tokens)
- Months 0-6: 0% (cliff)
- Months 6-24: 5% monthly (1.25M/month)

## Compliance Checklist

Before DLP reward eligibility:

- [ ] Deploy `RDATVesting.sol` contract
- [ ] Create vesting schedules for all team members
- [ ] Ensure 6-month minimum cliff from eligibility date
- [ ] Publish team allocations publicly
- [ ] Transfer team tokens to vesting contract
- [ ] Provide vesting contract address for verification
- [ ] Document total team allocation amount
- [ ] Confirm vesting cannot be accelerated

## Verification

To verify compliance:

1. **Check vesting contract**:
```solidity
// View team member vesting
vestingSchedules[teamMemberAddress]
```

2. **Verify cliff period**:
```solidity
// Must be at least 180 days
vestingSchedule.cliffDuration >= 180 days
```

3. **Confirm lock status**:
```solidity
// Tokens held by vesting contract
rdatToken.balanceOf(vestingContract) >= totalTeamAllocation
```

## Non-Compliance Consequences

Failure to comply with VRC-20 vesting requirements will result in:
- Loss of DLP reward eligibility
- Potential suspension from Vana ecosystem
- Reputational damage

## Contact

For assistance with VRC-20 compliance:
- Review Vana's VestingWallet template
- Contact Vana team for compliance verification
- Submit vesting contract for audit before deployment

## V2 Beta DLP Integration

### ProofOfContribution System

The V2 Beta includes ProofOfContribution.sol for basic Vana DLP compliance:

1. **Contributor Registration**:
   - Contributors must be registered via `registerContributor()`
   - Only REGISTRAR_ROLE (multi-sig) can register contributors

2. **Contribution Validation**:
   - Quality scores (0-100) tracked per contribution
   - Duplicate data hash prevention
   - Validator role required for scoring

3. **DLP Readiness**:
   ```solidity
   // Check if address is valid contributor
   poc.isValidContributor(address) // returns bool
   
   // Get contributor's cumulative score
   poc.getContributorScore(address) // returns uint256
   ```

### Revenue Distribution Integration

RevenueCollector.sol enables sustainable rewards beyond initial allocation:
- 20% of all protocol revenue allocated to data contributors
- Distribution based on contribution scores
- Creates long-term incentive alignment

### Phase 2-3 Enhancements

Full VRC-20 compliance will include:
- Complete data refiner implementation
- TEE (Trusted Execution Environment) integration
- Automated quality consensus mechanisms
- Cross-chain contribution tracking

---

**Last Updated**: August 2025  
**V2 Beta Status**: Basic VRC-20 compliance with upgrade path  
**Full Compliance Target**: Phase 3 (Month 5+)