# 🔒 TokenVesting Contract Specification

**Version**: 1.0  
**Contract**: TokenVesting.sol (VestingWallet)  
**Type**: Uses Vana's VestingWallet implementation  
**Purpose**: VRC-20 compliant team token vesting

## Overview

TokenVesting implements Vana's strict requirements for team, founder, and early contributor token allocations. This ensures DLP reward eligibility by properly locking team tokens with transparent vesting schedules.

## Vana VRC-20 Requirements

Per Vana's notice to DLPs:

1. **Public Disclosure**: Team allocations must be clearly disclosed (amounts, timelines, mechanics)
2. **Contract Locking**: Tokens must be locked in a contract (VestingWallet recommended)
3. **Vesting Schedule**: Minimum 6-month cliff, followed by linear vesting
4. **Start Date**: 6-month period begins on DLP reward eligibility date (not before)
5. **Compliance**: Failure to meet conditions means no DLP rewards

## Implementation Strategy

### Use Vana's VestingWallet

```solidity
// From Vana's template repository
import "@vana/contracts/VestingWallet.sol";

contract TokenVesting is VestingWallet {
    // Inherits all required functionality
    // Add any r/datadao specific features
}
```

### Key Features Required

1. **Admin-Settable Start Date**
   - Cannot start vesting before DLP eligibility
   - Admin sets date when eligibility confirmed
   - All vesting calculations based on this date

2. **6-Month Cliff**
   - No tokens released for first 6 months
   - After cliff, linear vesting begins
   - Standard Vana requirement

3. **Beneficiary Management**
   - Multiple beneficiaries (team members)
   - Individual vesting schedules
   - Transparent allocation tracking

4. **10M RDAT Allocation**
   - From Treasury & Ecosystem bucket
   - Requires DAO vote to transfer
   - One-time setup from TreasuryWallet

## Contract Design

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@vana/contracts/VestingWallet.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract TokenVesting is VestingWallet, AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    // DLP eligibility date (set by admin when confirmed)
    uint256 public eligibilityDate;
    bool public eligibilitySet;
    
    // Vesting parameters
    uint256 public constant CLIFF_DURATION = 180 days; // 6 months
    uint256 public constant VESTING_DURATION = 540 days; // 18 months after cliff
    
    // Beneficiary allocations
    mapping(address => uint256) public beneficiaryAllocations;
    address[] public beneficiaries;
    uint256 public totalAllocated;
    
    event EligibilityDateSet(uint256 date);
    event BeneficiaryAdded(address beneficiary, uint256 allocation);
    
    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
    }
    
    /**
     * @notice Set DLP eligibility date (starts vesting clock)
     * @dev Can only be set once, must be in future or recent past
     */
    function setEligibilityDate(uint256 _date) external onlyRole(ADMIN_ROLE) {
        require(!eligibilitySet, "Already set");
        require(_date <= block.timestamp + 30 days, "Too far in future");
        require(_date >= block.timestamp - 7 days, "Too far in past");
        
        eligibilityDate = _date;
        eligibilitySet = true;
        
        emit EligibilityDateSet(_date);
    }
    
    /**
     * @notice Add team member beneficiary
     * @dev Must be called before tokens received
     */
    function addBeneficiary(address beneficiary, uint256 allocation) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        require(beneficiary != address(0), "Invalid address");
        require(allocation > 0, "Invalid allocation");
        require(beneficiaryAllocations[beneficiary] == 0, "Already added");
        
        beneficiaryAllocations[beneficiary] = allocation;
        beneficiaries.push(beneficiary);
        totalAllocated += allocation;
        
        emit BeneficiaryAdded(beneficiary, allocation);
    }
    
    /**
     * @notice Calculate vested amount for beneficiary
     * @dev Implements 6-month cliff + linear vesting
     */
    function vestedAmount(address beneficiary) public view returns (uint256) {
        if (!eligibilitySet) return 0;
        if (beneficiaryAllocations[beneficiary] == 0) return 0;
        
        uint256 timeElapsed = block.timestamp - eligibilityDate;
        
        // Before cliff: no tokens vested
        if (timeElapsed < CLIFF_DURATION) {
            return 0;
        }
        
        // After cliff: linear vesting
        uint256 vestingElapsed = timeElapsed - CLIFF_DURATION;
        if (vestingElapsed >= VESTING_DURATION) {
            return beneficiaryAllocations[beneficiary];
        }
        
        return (beneficiaryAllocations[beneficiary] * vestingElapsed) / VESTING_DURATION;
    }
    
    /**
     * @notice Claim vested tokens
     * @dev Transfers vested amount minus already claimed
     */
    function claim() external {
        address beneficiary = msg.sender;
        uint256 vested = vestedAmount(beneficiary);
        uint256 claimable = vested - claimed[beneficiary];
        
        require(claimable > 0, "Nothing to claim");
        
        claimed[beneficiary] = vested;
        require(token.transfer(beneficiary, claimable), "Transfer failed");
        
        emit TokensClaimed(beneficiary, claimable);
    }
}
```

## Integration with r/datadao

### 1. Deployment Process
```solidity
// 1. Deploy TokenVesting
TokenVesting vesting = new TokenVesting(multisig);

// 2. Add beneficiaries (before token transfer)
vesting.addBeneficiary(alice, 3_000_000e18);  // 3M RDAT
vesting.addBeneficiary(bob, 2_000_000e18);    // 2M RDAT
vesting.addBeneficiary(carol, 2_000_000e18);  // 2M RDAT
vesting.addBeneficiary(dave, 1_500_000e18);   // 1.5M RDAT
vesting.addBeneficiary(eve, 1_500_000e18);    // 1.5M RDAT
// Total: 10M RDAT

// 3. DAO approves transfer (governance vote)
// proposalId = createProposal("Transfer 10M RDAT to team vesting");

// 4. After DAO approval, transfer from TreasuryWallet
treasuryWallet.distribute(
    address(vesting),
    10_000_000e18,
    "Team vesting per DAO proposal #123"
);

// 5. When DLP eligibility confirmed
vesting.setEligibilityDate(eligibilityTimestamp);
```

### 2. Vesting Timeline

```
DLP Eligibility ──────> 6 Month Cliff ──────> 18 Month Linear Vesting ──────> Fully Vested
     Day 0                Day 180                    Day 181-720                 Day 720
       │                     │                            │                         │
   No tokens            No tokens              Linear release                 All tokens
   available            available              (5.5% monthly)                  available
```

### 3. Example Calculation

For a team member with 1M RDAT allocation:
- Months 0-6: 0 RDAT available
- Month 7: ~55,555 RDAT available (1M ÷ 18 months)
- Month 12: ~333,333 RDAT available 
- Month 24: 1,000,000 RDAT available (fully vested)

## Compliance Verification

### Public Disclosure Requirements

```markdown
## Team Token Allocation

Total Allocation: 10,000,000 RDAT (10% of total supply)
Source: Treasury & Ecosystem allocation (requires DAO approval)

Vesting Schedule:
- 6-month cliff from DLP eligibility date
- 18-month linear vesting after cliff
- Total vesting period: 24 months

Contract: TokenVesting.sol (VestingWallet implementation)
Address: [To be deployed]

Beneficiaries: [To be disclosed after DAO approval]
```

### Proof of Locking

1. **On-chain Verification**: 
   - Contract holds 10M RDAT
   - Beneficiaries cannot withdraw before vesting
   - All vesting math is transparent

2. **Event Emissions**:
   - `EligibilityDateSet`: When vesting starts
   - `BeneficiaryAdded`: Each team allocation
   - `TokensClaimed`: Each withdrawal

3. **Query Functions**:
   - `vestedAmount()`: Check vested tokens
   - `beneficiaryAllocations()`: View allocations
   - `totalAllocated()`: Verify total matches disclosure

## Security Considerations

1. **Access Control**: Only admin can set eligibility date and beneficiaries
2. **One-time Setup**: Eligibility date cannot be changed once set
3. **Overflow Protection**: Safe math for vesting calculations
4. **Reentrancy**: Protected claim function
5. **Beneficiary Validation**: Cannot add zero address or duplicate

## Testing Requirements

1. **Vesting Math**: Verify cliff and linear calculations
2. **Edge Cases**: Test boundary conditions
3. **Access Control**: Ensure only admin functions work
4. **Integration**: Test with TreasuryWallet transfers
5. **Time-based**: Use time manipulation for vesting tests

## Deployment Checklist

- [ ] Deploy TokenVesting contract
- [ ] Add all team beneficiaries with allocations
- [ ] Create DAO proposal for 10M transfer
- [ ] After DAO approval, transfer tokens
- [ ] Monitor for DLP eligibility
- [ ] Set eligibility date when confirmed
- [ ] Public disclosure on website/docs
- [ ] Verify contract on Etherscan

## FAQ

**Q: Why not start vesting at TGE?**
A: Vana requires vesting to start from DLP eligibility date, not before.

**Q: Can vesting be accelerated?**
A: No, the 6-month cliff and 18-month vesting are fixed per Vana requirements.

**Q: What if a beneficiary leaves?**
A: They can still claim vested tokens. Unvested tokens remain locked.

**Q: Can allocations be changed?**
A: No, once set they are immutable for transparency.

---

**Note**: This implementation ensures full VRC-20 compliance and DLP reward eligibility. Any deviation risks losing Vana ecosystem rewards.