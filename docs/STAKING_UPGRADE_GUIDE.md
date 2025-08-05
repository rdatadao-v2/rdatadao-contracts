# StakingPositions Upgrade Guide

## Overview

The StakingPositions contract is upgradeable using OpenZeppelin's UUPS pattern. This guide outlines best practices for safe upgrades that preserve NFT positions and user data.

## Key Principles

### 1. Storage Layout Preservation

**Critical**: Never change the order or type of existing storage variables. Only add new variables at the end, using storage gap space.

```solidity
// ✅ CORRECT: Add new variables using storage gap
contract StakingPositionsV2 is StakingPositions {
    // Existing storage layout preserved...
    
    // New variables consume gap space
    uint256 public newFeature;
    mapping(uint256 => uint256) public positionBoosts;
    
    // Reduce gap by number of slots used
    uint256[39] private __gap; // Was 41, now 39 (used 2 slots)
}

// ❌ WRONG: Never do this
contract BadUpgrade {
    // Changed order or removed variables - BREAKS STORAGE
    mapping(uint256 => uint256) public lockMultipliers;
    uint256 private _nextPositionId; // Swapped order!
}
```

### 2. NFT Data Preservation

All NFT positions are automatically preserved because:
- Token ownership is stored in ERC721 storage slots
- Position data in `_positions` mapping remains intact
- Token IDs continue from where they left off

### 3. Safe Upgrade Pattern

```solidity
contract StakingPositionsV2 is StakingPositions {
    // New storage variables
    uint256 public constant VERSION = 2;
    bool public newFeatureEnabled;
    
    // Storage gap adjusted
    uint256[39] private __gap;
    
    // New initializer for V2
    function initializeV2() public reinitializer(2) {
        // Initialize new features
        newFeatureEnabled = true;
    }
    
    // Override existing functions carefully
    function stake(uint256 amount, uint256 lockPeriod) 
        external 
        override 
        nonReentrant 
        whenNotPaused 
        returns (uint256 positionId) 
    {
        // Add new logic while preserving existing behavior
        if (newFeatureEnabled) {
            // New feature logic
        }
        
        // Call parent implementation
        return super.stake(amount, lockPeriod);
    }
    
    // Add new functions
    function newFeature(uint256 positionId) external {
        require(_ownerOf(positionId) != address(0), "Invalid position");
        // New functionality
    }
}
```

## Upgrade Checklist

### Pre-Upgrade
- [ ] Run storage layout verification
- [ ] Test upgrade on fork
- [ ] Audit storage slot assignments
- [ ] Verify all existing functions still work
- [ ] Test with existing NFT positions

### Storage Layout Verification
```bash
# Compare storage layouts
forge inspect StakingPositions storage-layout > layout-v1.json
forge inspect StakingPositionsV2 storage-layout > layout-v2.json
diff layout-v1.json layout-v2.json
```

### Upgrade Script
```solidity
// script/UpgradeStakingPositions.s.sol
contract UpgradeStakingPositions is Script {
    function run() external {
        address proxy = 0x...; // Existing proxy address
        
        vm.startBroadcast();
        
        // Deploy new implementation
        StakingPositionsV2 newImpl = new StakingPositionsV2();
        
        // Upgrade proxy
        StakingPositions(proxy).upgradeToAndCall(
            address(newImpl),
            abi.encodeCall(StakingPositionsV2.initializeV2, ())
        );
        
        vm.stopBroadcast();
    }
}
```

## Common Upgrade Scenarios

### 1. Adding New Reward Mechanisms
```solidity
contract StakingPositionsV2 is StakingPositions {
    // New reward tracking
    mapping(uint256 => uint256) public positionMultipliers;
    uint256 public globalBoostFactor;
    
    uint256[39] private __gap;
    
    function initializeV2() public reinitializer(2) {
        globalBoostFactor = 10000; // 1x default
    }
}
```

### 2. Integrating New Protocols
```solidity
contract StakingPositionsV2 is StakingPositions {
    address public yieldOptimizer;
    mapping(uint256 => bool) public positionOptimized;
    
    uint256[39] private __gap;
}
```

### 3. Emergency Features
```solidity
contract StakingPositionsV2 is StakingPositions {
    bool public emergencyExitEnabled;
    uint256 public emergencyExitDeadline;
    
    uint256[39] private __gap;
    
    function emergencyExitAll() external {
        require(emergencyExitEnabled, "Not enabled");
        require(block.timestamp <= emergencyExitDeadline, "Deadline passed");
        // Allow users to exit all positions without penalties
    }
}
```

## Testing Upgrades

### Test Contract
```solidity
contract StakingPositionsUpgradeTest is Test {
    function testUpgradePreservesNFTs() public {
        // 1. Create positions in V1
        uint256 position1 = stakingV1.stake(1000e18, 30 days);
        uint256 position2 = stakingV1.stake(2000e18, 90 days);
        
        // 2. Record state
        address owner1 = stakingV1.ownerOf(position1);
        Position memory pos1Before = stakingV1.getPosition(position1);
        
        // 3. Upgrade to V2
        upgradeToV2();
        
        // 4. Verify NFTs preserved
        assertEq(stakingV2.ownerOf(position1), owner1);
        Position memory pos1After = stakingV2.getPosition(position1);
        assertEq(pos1After.amount, pos1Before.amount);
        assertEq(pos1After.lockPeriod, pos1Before.lockPeriod);
        
        // 5. Verify can create new positions
        uint256 position3 = stakingV2.stake(3000e18, 180 days);
        assertEq(position3, 3); // Continues from V1
    }
}
```

## Blue-Chip Examples

### 1. **Aave** - Upgradeable staking with safety module
- Uses transparent proxy pattern
- Preserves user positions across upgrades
- Emergency pause mechanisms

### 2. **Compound** - Upgradeable governance and rewards
- COMP staking preserves balances
- Careful storage layout management

### 3. **Curve** - Upgradeable gauge system  
- veToken positions preserved
- Complex upgrade paths handled safely

### 4. **Synthetix** - Modular upgradeable staking
- SNX staking with preserved positions
- Module-based architecture

## Security Considerations

1. **Timelock**: Use a timelock for upgrade execution
2. **Multi-sig**: Require multiple signatures for upgrades
3. **Upgrade Delay**: Announce upgrades in advance
4. **Emergency Pause**: Can pause before upgrades
5. **Rollback Plan**: Have a plan to rollback if issues arise

## Post-Upgrade Verification

```solidity
// Verification script
contract VerifyUpgrade is Script {
    function run() external view {
        StakingPositions staking = StakingPositions(PROXY_ADDRESS);
        
        // 1. Check existing positions
        for (uint i = 1; i <= lastKnownTokenId; i++) {
            try staking.ownerOf(i) returns (address owner) {
                console.log("Position", i, "owner:", owner);
                Position memory pos = staking.getPosition(i);
                require(pos.amount > 0, "Position data lost!");
            } catch {
                // Position was burned, this is ok
            }
        }
        
        // 2. Verify core functionality
        require(staking.totalStaked() == expectedTotalStaked, "Total staked mismatch");
        
        // 3. Check new features
        if (address(staking).code.length > 0) {
            console.log("Upgrade successful");
        }
    }
}
```

## Conclusion

The StakingPositions contract is designed for safe upgrades that preserve all NFT positions and user data. By following these guidelines and the storage layout rules, you can safely add features while maintaining the integrity of existing positions.

Key takeaways:
- Never modify existing storage layout
- Always use storage gaps
- Test thoroughly with existing positions
- Follow blue-chip patterns for safety
- Use timelocks and multi-sigs for production