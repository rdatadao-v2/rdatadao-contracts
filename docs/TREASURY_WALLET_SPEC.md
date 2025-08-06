# 💰 TreasuryWallet Contract Specification

**Version**: 1.0  
**Contract**: TreasuryWallet.sol  
**Type**: UUPS Upgradeable  
**Purpose**: Manage DAO token allocations with vesting schedules

## Overview

TreasuryWallet is a critical infrastructure contract that receives 70M RDAT at deployment and manages the distribution according to DAO-approved allocations. It handles complex vesting schedules, phase-gated releases, and provides on-chain transparency for all distributions.

## Contract Design

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TreasuryWallet is 
    UUPSUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable 
{
    // Roles
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");
    bytes32 public constant DAO_ROLE = keccak256("DAO_ROLE");
    
    // Allocation identifiers
    bytes32 public constant FUTURE_REWARDS = keccak256("FUTURE_REWARDS");
    bytes32 public constant TREASURY_ECOSYSTEM = keccak256("TREASURY_ECOSYSTEM");
    bytes32 public constant LIQUIDITY_STAKING = keccak256("LIQUIDITY_STAKING");
    
    struct VestingSchedule {
        uint256 total;              // Total allocation
        uint256 released;           // Amount already released
        uint256 tgeUnlock;          // Amount unlocked at TGE
        uint256 cliffDuration;      // Cliff period in seconds
        uint256 vestingDuration;    // Total vesting duration after cliff
        uint256 vestingStart;       // Timestamp when vesting starts
        uint256 lastRelease;        // Last release timestamp
        bool isPhase3Gated;         // Whether this requires Phase 3
        bool initialized;           // Whether schedule is set up
    }
    
    // State variables
    mapping(bytes32 => VestingSchedule) public vestingSchedules;
    mapping(address => uint256) public distributionHistory;
    bool public phase3Active;
    IERC20 public rdat;
    uint256 public totalDistributed;
    
    // Events
    event VestingScheduleCreated(bytes32 indexed allocation, uint256 total, uint256 tgeUnlock);
    event TokensReleased(bytes32 indexed allocation, uint256 amount);
    event TokensDistributed(address indexed recipient, uint256 amount, string reason);
    event Phase3Activated(uint256 timestamp);
    event DAOProposalExecuted(uint256 indexed proposalId);
    
    function initialize(address _admin, address _rdat) public initializer {
        __UUPSUpgradeable_init();
        __AccessControl_init();
        __ReentrancyGuard_init();
        
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(UPGRADER_ROLE, _admin);
        _grantRole(DISTRIBUTOR_ROLE, _admin);
        
        rdat = IERC20(_rdat);
        
        // Setup vesting schedules based on DAO vote
        _setupInitialSchedules();
    }
    
    function _setupInitialSchedules() private {
        // Future Rewards: 30M, locked until Phase 3
        vestingSchedules[FUTURE_REWARDS] = VestingSchedule({
            total: 30_000_000e18,
            released: 0,
            tgeUnlock: 0,
            cliffDuration: 0,
            vestingDuration: 0,
            vestingStart: block.timestamp,
            lastRelease: 0,
            isPhase3Gated: true,
            initialized: true
        });
        
        // Treasury & Ecosystem: 25M, 10% TGE, 6mo cliff, 18mo vest
        vestingSchedules[TREASURY_ECOSYSTEM] = VestingSchedule({
            total: 25_000_000e18,
            released: 0,
            tgeUnlock: 2_500_000e18, // 10% at TGE
            cliffDuration: 180 days,
            vestingDuration: 540 days, // 18 months
            vestingStart: block.timestamp,
            lastRelease: block.timestamp,
            isPhase3Gated: false,
            initialized: true
        });
        
        // Liquidity & Staking: 15M, 33% TGE
        vestingSchedules[LIQUIDITY_STAKING] = VestingSchedule({
            total: 15_000_000e18,
            released: 0,
            tgeUnlock: 4_950_000e18, // 33% at TGE
            cliffDuration: 0,
            vestingDuration: 0, // Remainder for staking incentives
            vestingStart: block.timestamp,
            lastRelease: block.timestamp,
            isPhase3Gated: false,
            initialized: true
        });
    }
    
    function checkAndRelease() external nonReentrant {
        _releaseVested(TREASURY_ECOSYSTEM);
        _releaseVested(LIQUIDITY_STAKING);
        
        if (phase3Active) {
            _releaseVested(FUTURE_REWARDS);
        }
    }
    
    function _releaseVested(bytes32 allocation) private {
        VestingSchedule storage schedule = vestingSchedules[allocation];
        
        if (!schedule.initialized || schedule.released >= schedule.total) {
            return;
        }
        
        if (schedule.isPhase3Gated && !phase3Active) {
            return;
        }
        
        uint256 available = _calculateAvailable(schedule);
        if (available > 0) {
            schedule.released += available;
            schedule.lastRelease = block.timestamp;
            emit TokensReleased(allocation, available);
        }
    }
    
    function _calculateAvailable(VestingSchedule memory schedule) 
        private 
        view 
        returns (uint256) 
    {
        // Handle TGE unlock
        if (schedule.released == 0 && schedule.tgeUnlock > 0) {
            return schedule.tgeUnlock;
        }
        
        // Check cliff
        if (block.timestamp < schedule.vestingStart + schedule.cliffDuration) {
            return 0;
        }
        
        // Calculate vested amount
        if (schedule.vestingDuration == 0) {
            // No vesting, everything available after cliff
            return schedule.total - schedule.released;
        }
        
        uint256 timeSinceCliff = block.timestamp - 
            (schedule.vestingStart + schedule.cliffDuration);
        uint256 vestedAmount = schedule.total * 
            timeSinceCliff / schedule.vestingDuration;
            
        if (vestedAmount > schedule.total) {
            vestedAmount = schedule.total;
        }
        
        return vestedAmount - schedule.released;
    }
    
    function distribute(address recipient, uint256 amount, string calldata reason) 
        external 
        onlyRole(DISTRIBUTOR_ROLE) 
        nonReentrant 
    {
        require(rdat.balanceOf(address(this)) >= amount, "Insufficient balance");
        
        distributionHistory[recipient] += amount;
        totalDistributed += amount;
        
        require(rdat.transfer(recipient, amount), "Transfer failed");
        
        emit TokensDistributed(recipient, amount, reason);
    }
    
    function setPhase3Active() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!phase3Active, "Already active");
        phase3Active = true;
        emit Phase3Activated(block.timestamp);
    }
    
    function executeDAOProposal(
        uint256 proposalId,
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas
    ) external onlyRole(DAO_ROLE) nonReentrant {
        require(targets.length == values.length, "Length mismatch");
        require(targets.length == calldatas.length, "Length mismatch");
        
        for (uint256 i = 0; i < targets.length; i++) {
            (bool success, ) = targets[i].call{value: values[i]}(calldatas[i]);
            require(success, "Call failed");
        }
        
        emit DAOProposalExecuted(proposalId);
    }
    
    function getVestingInfo(bytes32 allocation) 
        external 
        view 
        returns (
            uint256 total,
            uint256 released,
            uint256 available,
            bool isActive
        ) 
    {
        VestingSchedule memory schedule = vestingSchedules[allocation];
        total = schedule.total;
        released = schedule.released;
        available = _calculateAvailable(schedule);
        isActive = schedule.initialized && 
            (!schedule.isPhase3Gated || phase3Active);
    }
    
    function _authorizeUpgrade(address newImplementation) 
        internal 
        override 
        onlyRole(UPGRADER_ROLE) 
    {}
}
```

## Key Features

### 1. Vesting Management
- Handles complex vesting schedules with cliffs and linear release
- TGE (Token Generation Event) unlocks
- Phase-gated releases (e.g., Future Rewards wait for Phase 3)

### 2. Distribution Control
- Role-based access for distributions
- On-chain history of all distributions
- Reason tracking for transparency

### 3. DAO Integration
- Execute on-chain proposals
- Upgrade capability for future changes
- Transparent allocation tracking

### 4. Security
- ReentrancyGuard on all external functions
- Role-based access control
- Balance checks before transfers

## Initial State at Deployment

### Immediate Actions (TGE):
1. Receive 70M RDAT from token contract
2. Process TGE unlocks via `checkAndRelease()`:
   - 2.5M available for Treasury/Ecosystem
   - 4.95M available for Liquidity
3. Admin calls `distribute()` to send liquidity allocation

### Vesting Schedules:
- **Future Rewards**: Locked until Phase 3 activation
- **Treasury/Ecosystem**: 6-month cliff, then linear over 18 months
- **Liquidity/Staking**: Immediate access to remainder after TGE

## Integration Points

### With RDATUpgradeable:
```solidity
// In RDATUpgradeable.initialize()
_mint(treasuryWallet, 70_000_000e18);
```

### With RDATRewardModule (Phase 3):
```solidity
// After Phase 3 activation
treasuryWallet.distribute(
    rdatRewardModule, 
    30_000_000e18, 
    "Fund staking rewards"
);
```

### With MigrationBridge:
```solidity
// After 1 year deadline
treasuryWallet.distribute(
    treasuryWallet,
    unclaimedAmount,
    "Return unclaimed migration tokens"
);
```

## Gas Optimization

- Lazy vesting calculation (only on demand)
- Batch release in single transaction
- Minimal storage updates

## Testing Requirements

1. Vesting calculations across time periods
2. Phase 3 activation and unlock
3. Distribution role permissions
4. Upgrade functionality
5. Edge cases (cliff boundaries, full vesting)

## Security Considerations

1. **Upgrade Risk**: UUPS pattern requires careful implementation review
2. **Role Management**: Critical to properly manage distributor role
3. **Time Manipulation**: Vesting relies on block.timestamp
4. **Balance Tracking**: Must ensure consistency with RDAT balances

## Future Enhancements

1. Multi-token support for diversified treasury
2. Streaming payments integration
3. Automated distribution schedules
4. Governance proposal queuing