# 📜 RDAT V2 Beta Smart Contracts Specification

**Version**: 1.0  
**Sprint Duration**: August 5-18, 2025 (13 days)  
**Audit Target**: August 12-13, 2025  
**Framework**: Foundry/Forge  
**Solidity Version**: 0.8.23  
**License**: MIT

## 📋 Executive Summary

This document provides the complete smart contract specifications for RDAT V2 Beta, focusing on the contracts to be developed during the 13-day sprint. All contracts are designed for security audit readiness with comprehensive testing requirements.

## 🎯 V2 Beta Contract Scope

### Core Contracts (5 Total)
1. **RDAT_V2.sol** - Main token contract (100M supply)
2. **vRDAT_V2.sol** - Soul-bound governance token
3. **StakingV2.sol** - Simplified staking without NFTs
4. **MigrationBridge_V2.sol** - V1→V2 cross-chain bridge
5. **EmergencyPause.sol** - Emergency response system

### Support Contracts
- **MockRDAT.sol** - V1 token mock for testing
- **Interfaces/** - All contract interfaces
- **Libraries/** - Shared libraries

## 📦 Contract Specifications

### 1. RDAT_V2.sol

**Purpose**: Main ERC-20 token with VRC-20 compliance stubs

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IVRC20Basic.sol";

contract RDAT_V2 is 
    ERC20,
    ERC20Burnable,
    ERC20Pausable,
    ERC20Permit,
    AccessControl,
    IVRC20Basic 
{
    // Roles
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    
    // Constants
    uint256 public constant TOTAL_SUPPLY = 100_000_000 * 10**18; // 100M tokens
    uint256 public constant MIGRATION_ALLOCATION = 30_000_000 * 10**18; // 30M for V1 holders
    
    // VRC-20 Compliance
    bool public constant isVRC20 = true;
    address public pocContract; // Proof of Contribution
    address public dataRefiner;
    
    // Events
    event VRCContractSet(string contractType, address indexed contractAddress);
    
    constructor(address treasury) 
        ERC20("r/datadao", "RDAT") 
        ERC20Permit("r/datadao") 
    {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        
        // Mint non-migration supply to treasury
        _mint(treasury, TOTAL_SUPPLY - MIGRATION_ALLOCATION);
    }
    
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        require(totalSupply() + amount <= TOTAL_SUPPLY, "Exceeds max supply");
        _mint(to, amount);
    }
    
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
    
    // VRC-20 Compliance Functions
    function setPoCContract(address _poc) external onlyRole(DEFAULT_ADMIN_ROLE) {
        pocContract = _poc;
        emit VRCContractSet("PoC", _poc);
    }
    
    function setDataRefiner(address _refiner) external onlyRole(DEFAULT_ADMIN_ROLE) {
        dataRefiner = _refiner;
        emit VRCContractSet("DataRefiner", _refiner);
    }
    
    // Required overrides
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Pausable) {
        super._beforeTokenTransfer(from, to, amount);
    }
}
```

**Key Requirements**:
- ✅ Total supply: 100M tokens
- ✅ 30M reserved for V1 migration
- ✅ Pausable for emergencies
- ✅ Permit functionality for gasless approvals
- ✅ VRC-20 basic compliance
- ✅ Access control for admin functions

**Testing Requirements**:
- 100% code coverage
- Fuzz testing for mint/burn operations
- Integration tests with migration bridge
- Gas optimization benchmarks

---

### 2. vRDAT_V2.sol

**Purpose**: Non-transferable governance token earned through staking

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IvRDAT.sol";

contract vRDAT_V2 is AccessControl, IvRDAT {
    // Roles
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    
    // State
    mapping(address => uint256) private _balances;
    mapping(address => uint256) public lastMintTime;
    uint256 public totalSupply;
    
    // Constants
    uint256 public constant MINT_DELAY = 48 hours; // Flash loan protection
    uint256 public constant MAX_PER_ADDRESS = 10_000_000 * 10**18; // 10M cap per address
    
    // Events
    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);
    
    // Errors
    error NonTransferableToken();
    error MintDelayNotMet();
    error ExceedsMaxBalance();
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        if (block.timestamp < lastMintTime[to] + MINT_DELAY) {
            revert MintDelayNotMet();
        }
        if (_balances[to] + amount > MAX_PER_ADDRESS) {
            revert ExceedsMaxBalance();
        }
        
        _balances[to] += amount;
        totalSupply += amount;
        lastMintTime[to] = block.timestamp;
        
        emit Mint(to, amount);
    }
    
    function burn(address from, uint256 amount) external onlyRole(BURNER_ROLE) {
        require(_balances[from] >= amount, "Insufficient balance");
        
        _balances[from] -= amount;
        totalSupply -= amount;
        
        emit Burn(from, amount);
    }
    
    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }
    
    // Block all transfer functions
    function transfer(address, uint256) external pure returns (bool) {
        revert NonTransferableToken();
    }
    
    function transferFrom(address, address, uint256) external pure returns (bool) {
        revert NonTransferableToken();
    }
    
    function approve(address, uint256) external pure returns (bool) {
        revert NonTransferableToken();
    }
}
```

**Key Requirements**:
- ✅ Completely non-transferable (soul-bound)
- ✅ 48-hour mint delay for flash loan protection
- ✅ 10M token cap per address
- ✅ Minting only through staking contract
- ✅ Burning for governance voting (future)

**Testing Requirements**:
- Test all transfer functions revert
- Test mint delay enforcement
- Test max balance enforcement
- Fuzz testing for edge cases

---

### 3. StakingV2.sol

**Purpose**: Simple staking contract without NFT complexity

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IvRDAT.sol";

contract StakingV2 is AccessControl, ReentrancyGuard, Pausable {
    // Roles
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant REWARDS_ROLE = keccak256("REWARDS_ROLE");
    
    // Contracts
    IERC20 public immutable rdatToken;
    IvRDAT public immutable vrdatToken;
    
    // Structs
    struct StakeInfo {
        uint256 amount;
        uint256 startTime;
        uint256 lockPeriod;
        uint256 vrdatMinted;
        uint256 rewardsClaimed;
    }
    
    // State
    mapping(address => StakeInfo) public stakes;
    uint256 public totalStaked;
    
    // Lock period multipliers (basis points)
    mapping(uint256 => uint256) public lockMultipliers;
    
    // Events
    event Staked(address indexed user, uint256 amount, uint256 lockPeriod);
    event Unstaked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    
    constructor(address _rdat, address _vrdat) {
        rdatToken = IERC20(_rdat);
        vrdatToken = IvRDAT(_vrdat);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        
        // Set lock period multipliers
        lockMultipliers[30 days] = 10000;   // 1x (100%)
        lockMultipliers[90 days] = 15000;   // 1.5x
        lockMultipliers[180 days] = 20000;  // 2x
        lockMultipliers[365 days] = 40000;  // 4x
    }
    
    function stake(uint256 amount, uint256 lockPeriod) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        require(amount > 0, "Amount must be > 0");
        require(stakes[msg.sender].amount == 0, "Already staking");
        require(lockMultipliers[lockPeriod] > 0, "Invalid lock period");
        
        // Transfer RDAT tokens
        rdatToken.transferFrom(msg.sender, address(this), amount);
        
        // Calculate vRDAT amount
        uint256 vrdatAmount = (amount * lockMultipliers[lockPeriod]) / 10000;
        
        // Create stake
        stakes[msg.sender] = StakeInfo({
            amount: amount,
            startTime: block.timestamp,
            lockPeriod: lockPeriod,
            vrdatMinted: vrdatAmount,
            rewardsClaimed: 0
        });
        
        totalStaked += amount;
        
        // Mint vRDAT
        vrdatToken.mint(msg.sender, vrdatAmount);
        
        emit Staked(msg.sender, amount, lockPeriod);
    }
    
    function unstake() external nonReentrant {
        StakeInfo storage userStake = stakes[msg.sender];
        require(userStake.amount > 0, "No active stake");
        require(
            block.timestamp >= userStake.startTime + userStake.lockPeriod,
            "Lock period not ended"
        );
        
        uint256 amount = userStake.amount;
        totalStaked -= amount;
        
        // Clear stake
        delete stakes[msg.sender];
        
        // Return RDAT tokens
        rdatToken.transfer(msg.sender, amount);
        
        emit Unstaked(msg.sender, amount);
    }
    
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
}
```

**Key Requirements**:
- ✅ Simple mapping storage (no NFTs)
- ✅ Fixed lock periods with multipliers
- ✅ vRDAT minting based on lock duration
- ✅ No early exit in V2 Beta
- ✅ Pausable for emergencies

**Testing Requirements**:
- Test all lock period scenarios
- Test vRDAT calculation accuracy
- Test unstake timing enforcement
- Integration tests with token contracts

---

### 4. MigrationBridge_V2.sol

**Purpose**: Secure V1→V2 token migration with 2-of-3 multi-sig

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/IRDAT_V2.sol";

contract MigrationBridge_V2 is AccessControl, Pausable {
    // Roles
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    // Contracts
    IRDAT_V2 public immutable rdatV2;
    
    // Migration tracking
    mapping(bytes32 => MigrationRequest) public migrationRequests;
    mapping(address => uint256) public migratedAmounts;
    mapping(address => bool) public hasClaimedBonus;
    
    // State
    uint256 public totalMigrated;
    uint256 public migrationStartTime;
    uint256 public constant DAILY_LIMIT = 1_000_000 * 10**18; // 1M tokens/day
    uint256 public dailyMigrated;
    uint256 public lastResetTime;
    
    // Migration bonuses
    uint256 public constant WEEK_1_2_BONUS = 500; // 5%
    uint256 public constant WEEK_3_4_BONUS = 300; // 3%
    uint256 public constant WEEK_5_8_BONUS = 100; // 1%
    
    struct MigrationRequest {
        address user;
        uint256 amount;
        uint256 bonus;
        bytes32 burnTxHash;
        uint256 validations;
        mapping(address => bool) hasValidated;
        bool executed;
    }
    
    // Events
    event MigrationInitiated(bytes32 indexed requestId, address indexed user, uint256 amount, bytes32 burnTxHash);
    event MigrationValidated(bytes32 indexed requestId, address indexed validator);
    event MigrationExecuted(bytes32 indexed requestId, address indexed user, uint256 amount, uint256 bonus);
    
    constructor(address _rdatV2) {
        rdatV2 = IRDAT_V2(_rdatV2);
        migrationStartTime = block.timestamp;
        lastResetTime = block.timestamp;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }
    
    function submitMigration(
        address user,
        uint256 amount,
        bytes32 burnTxHash
    ) external onlyRole(VALIDATOR_ROLE) whenNotPaused {
        bytes32 requestId = keccak256(abi.encodePacked(user, amount, burnTxHash));
        require(migrationRequests[requestId].amount == 0, "Request exists");
        
        // Reset daily limit if needed
        if (block.timestamp > lastResetTime + 1 days) {
            dailyMigrated = 0;
            lastResetTime = block.timestamp;
        }
        
        require(dailyMigrated + amount <= DAILY_LIMIT, "Daily limit exceeded");
        
        // Calculate bonus
        uint256 bonus = calculateBonus(amount);
        
        // Create request
        MigrationRequest storage request = migrationRequests[requestId];
        request.user = user;
        request.amount = amount;
        request.bonus = bonus;
        request.burnTxHash = burnTxHash;
        request.validations = 1;
        request.hasValidated[msg.sender] = true;
        
        emit MigrationInitiated(requestId, user, amount, burnTxHash);
    }
    
    function validateMigration(bytes32 requestId) 
        external 
        onlyRole(VALIDATOR_ROLE) 
        whenNotPaused 
    {
        MigrationRequest storage request = migrationRequests[requestId];
        require(request.amount > 0, "Invalid request");
        require(!request.hasValidated[msg.sender], "Already validated");
        require(!request.executed, "Already executed");
        
        request.hasValidated[msg.sender] = true;
        request.validations++;
        
        emit MigrationValidated(requestId, msg.sender);
        
        // Execute if 2-of-3 validations
        if (request.validations >= 2) {
            executeMigration(requestId);
        }
    }
    
    function executeMigration(bytes32 requestId) private {
        MigrationRequest storage request = migrationRequests[requestId];
        
        uint256 totalAmount = request.amount + request.bonus;
        
        // Update tracking
        migratedAmounts[request.user] += request.amount;
        totalMigrated += request.amount;
        dailyMigrated += request.amount;
        request.executed = true;
        
        // Mark bonus claimed
        if (request.bonus > 0) {
            hasClaimedBonus[request.user] = true;
        }
        
        // Mint tokens
        rdatV2.mint(request.user, totalAmount);
        
        emit MigrationExecuted(requestId, request.user, request.amount, request.bonus);
    }
    
    function calculateBonus(uint256 amount) public view returns (uint256) {
        uint256 elapsed = block.timestamp - migrationStartTime;
        
        if (elapsed <= 2 weeks) {
            return (amount * WEEK_1_2_BONUS) / 10000;
        } else if (elapsed <= 4 weeks) {
            return (amount * WEEK_3_4_BONUS) / 10000;
        } else if (elapsed <= 8 weeks) {
            return (amount * WEEK_5_8_BONUS) / 10000;
        }
        
        return 0;
    }
    
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
}
```

**Key Requirements**:
- ✅ 2-of-3 multi-sig validation
- ✅ Daily migration limits (1M tokens)
- ✅ Time-based bonus structure
- ✅ Duplicate prevention
- ✅ Pausable for emergencies

**Testing Requirements**:
- Test multi-sig validation flow
- Test bonus calculation at all time periods
- Test daily limit enforcement
- Test duplicate prevention
- Integration tests with RDAT_V2

---

### 5. EmergencyPause.sol

**Purpose**: Shared emergency pause functionality

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/access/AccessControl.sol";

abstract contract EmergencyPause is AccessControl {
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
    
    bool public emergencyPaused;
    uint256 public pausedAt;
    uint256 public constant PAUSE_DURATION = 72 hours;
    
    mapping(address => bool) public pausers;
    
    event EmergencyPaused(address indexed pauser);
    event EmergencyUnpaused(address indexed guardian);
    
    modifier whenNotEmergencyPaused() {
        require(
            !emergencyPaused || block.timestamp > pausedAt + PAUSE_DURATION,
            "Emergency pause active"
        );
        _;
    }
    
    constructor() {
        _grantRole(GUARDIAN_ROLE, msg.sender);
        pausers[msg.sender] = true;
    }
    
    function addPauser(address pauser) external onlyRole(GUARDIAN_ROLE) {
        pausers[pauser] = true;
    }
    
    function removePauser(address pauser) external onlyRole(GUARDIAN_ROLE) {
        pausers[pauser] = false;
    }
    
    function emergencyPause() external {
        require(pausers[msg.sender] || hasRole(GUARDIAN_ROLE, msg.sender), "Not authorized");
        require(!emergencyPaused, "Already paused");
        
        emergencyPaused = true;
        pausedAt = block.timestamp;
        
        emit EmergencyPaused(msg.sender);
    }
    
    function emergencyUnpause() external onlyRole(GUARDIAN_ROLE) {
        require(emergencyPaused, "Not paused");
        
        emergencyPaused = false;
        
        emit EmergencyUnpaused(msg.sender);
    }
}
```

**Key Requirements**:
- ✅ Multiple authorized pausers
- ✅ Auto-unpause after 72 hours
- ✅ Guardian role for management
- ✅ Inheritable by other contracts

---

## 🧪 Testing Requirements

### Unit Tests (Target: 100% Coverage)
```bash
forge test --match-contract RDAT_V2Test -vvv
forge test --match-contract vRDAT_V2Test -vvv
forge test --match-contract StakingV2Test -vvv
forge test --match-contract MigrationBridge_V2Test -vvv
forge test --match-contract EmergencyPauseTest -vvv
```

### Integration Tests
```bash
forge test --match-contract IntegrationTest -vvv
```

### Fuzz Tests
```bash
forge test --match-test testFuzz -vvv
```

### Gas Reports
```bash
forge test --gas-report
```

### Coverage Report
```bash
forge coverage --report lcov
```

## 🔒 Security Considerations

### Access Control Matrix
| Contract | Role | Functions | Multi-sig Required |
|----------|------|-----------|-------------------|
| RDAT_V2 | DEFAULT_ADMIN | setPoCContract, setDataRefiner | Yes (3/5) |
| RDAT_V2 | PAUSER | pause, unpause | Yes (2/5) |
| RDAT_V2 | MINTER | mint | Yes (Bridge only) |
| vRDAT_V2 | MINTER | mint | No (Staking only) |
| StakingV2 | PAUSER | pause, unpause | Yes (2/5) |
| MigrationBridge | VALIDATOR | submitMigration, validateMigration | No (2/3 required) |

### Known Limitations (V2 Beta)
1. No upgradability (UUPS deferred to Phase 3)
2. No on-chain governance (using Snapshot)
3. No NFT staking positions (simple mapping)
4. No compound/restake functionality
5. No early exit from staking

### Audit Focus Areas
1. Access control implementation
2. Integer overflow/underflow
3. Reentrancy protection
4. Flash loan vulnerabilities
5. Multi-sig validation logic
6. Token minting constraints

## 📊 Gas Optimization Targets

| Function | Target Gas | Max Acceptable |
|----------|------------|----------------|
| RDAT transfer | < 65,000 | 75,000 |
| Stake (first time) | < 150,000 | 200,000 |
| Unstake | < 100,000 | 120,000 |
| Migration claim | < 120,000 | 150,000 |

## 🚀 Deployment Plan

### Day 3-4: Testnet Deployment
1. Deploy to Vana Moksha testnet
2. Deploy to Base Sepolia testnet
3. Verify all contracts on explorers
4. Set up multi-sig roles

### Day 12-13: Mainnet Deployment
1. Gnosis Safe already deployed:
   - Vana: `0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319`
   - Base: `0x90013583c66D2bf16327cB5Bc4a647AcceCF4B9A`
2. Deploy contracts in order:
   - EmergencyPause
   - RDAT_V2
   - vRDAT_V2
   - StakingV2
   - MigrationBridge_V2
3. Configure all roles and permissions
4. Transfer ownership to Gnosis Safe

## ✅ Audit Readiness Checklist

- [ ] 100% test coverage achieved
- [ ] All functions have NatSpec documentation
- [ ] Slither analysis passing
- [ ] Mythril analysis complete
- [ ] Gas optimization complete
- [ ] Emergency procedures documented
- [ ] Deployment scripts tested
- [ ] Multi-sig setup verified

---

**Document Status**: Ready for Development  
**Next Steps**: Begin implementation following 13-day sprint plan  
**Audit Timeline**: Days 7-8 for focused security review