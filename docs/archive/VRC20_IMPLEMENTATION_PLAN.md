# 🚀 VRC-20 Compliance Implementation Plan

**Priority**: CRITICAL  
**Timeline**: 2-3 weeks  
**Goal**: Achieve full VRC-20 compliance for DLP reward eligibility

## Phase 1: Critical Blockers (Week 1)

### Task 1: Implement Address Blocklisting

**File**: `src/RDATUpgradeable.sol`

```solidity
// Add to storage section
mapping(address => bool) private _blocklist;
uint256 private _blocklistCount;

// Add events
event AddressBlocked(address indexed account, address indexed admin);
event AddressUnblocked(address indexed account, address indexed admin);

// Add modifier
modifier notBlocked(address account) {
    require(!_blocklist[account], "VRC20: Address is blocked");
    _;
}

// Add functions
function blockAddress(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
    require(account != address(0), "Cannot block zero address");
    require(!_blocklist[account], "Already blocked");
    _blocklist[account] = true;
    _blocklistCount++;
    emit AddressBlocked(account, msg.sender);
}

function unblockAddress(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
    require(_blocklist[account], "Not blocked");
    _blocklist[account] = false;
    _blocklistCount--;
    emit AddressUnblocked(account, msg.sender);
}

function isBlocked(address account) external view returns (bool) {
    return _blocklist[account];
}

// Override _update to check blocklist
function _update(address from, address to, uint256 value) 
    internal 
    override(ERC20Upgradeable, ERC20PausableUpgradeable)
    notBlocked(from)
    notBlocked(to)
{
    super._update(from, to, value);
}
```

### Task 2: Add 48-Hour Timelocks

**File**: `src/RDATUpgradeable.sol`

```solidity
// Add to storage
uint256 constant TIMELOCK_DURATION = 48 hours;

struct PendingAction {
    address target;
    bytes data;
    uint256 executeTime;
    bool executed;
}

mapping(bytes32 => PendingAction) public pendingActions;

// Events
event ActionScheduled(bytes32 indexed actionId, address target, uint256 executeTime);
event ActionExecuted(bytes32 indexed actionId);
event ActionCancelled(bytes32 indexed actionId);

// Functions
function scheduleAction(address target, bytes calldata data) 
    external 
    onlyRole(DEFAULT_ADMIN_ROLE) 
    returns (bytes32) 
{
    bytes32 actionId = keccak256(abi.encode(target, data, block.timestamp));
    pendingActions[actionId] = PendingAction({
        target: target,
        data: data,
        executeTime: block.timestamp + TIMELOCK_DURATION,
        executed: false
    });
    emit ActionScheduled(actionId, target, block.timestamp + TIMELOCK_DURATION);
    return actionId;
}

function executeAction(bytes32 actionId) external onlyRole(DEFAULT_ADMIN_ROLE) {
    PendingAction storage action = pendingActions[actionId];
    require(action.executeTime != 0, "Action not found");
    require(!action.executed, "Already executed");
    require(block.timestamp >= action.executeTime, "Timelock not expired");
    
    action.executed = true;
    (bool success,) = action.target.call(action.data);
    require(success, "Action failed");
    
    emit ActionExecuted(actionId);
}

// Override upgrade function to use timelock
function _authorizeUpgrade(address newImplementation) 
    internal 
    override 
    onlyRole(UPGRADER_ROLE) 
{
    // Schedule upgrade through timelock
    bytes memory data = abi.encodeWithSignature("upgradeToAndCall(address,bytes)", newImplementation, "");
    scheduleAction(address(this), data);
}
```

---

## Phase 2: DLP Integration (Week 2)

### Task 3: Complete DLP Registration

**File**: `src/RDATUpgradeable.sol`

```solidity
// Enhanced DLP registration
contract DLPRegistry {
    function registerDLP(
        address token,
        string memory name,
        string memory metadata,
        address[] memory validators
    ) external returns (uint256);
}

function registerWithDLPRegistry(
    address registryAddress,
    string memory name,
    string memory metadata,
    address[] memory validators
) external onlyRole(DEFAULT_ADMIN_ROLE) returns (uint256) {
    require(!dlpRegistered, "Already registered");
    
    DLPRegistry registry = DLPRegistry(registryAddress);
    uint256 dlpId = registry.registerDLP(
        address(this),
        name,
        metadata,
        validators
    );
    
    dlpAddress = registryAddress;
    dlpRegistered = true;
    dlpRegistrationBlock = block.number;
    
    emit DLPRegistered(registryAddress, block.timestamp);
    return dlpId;
}
```

### Task 4: Implement Data Validation

**File**: `src/ProofOfContributionStub.sol` → `src/ProofOfContribution.sol`

```solidity
pragma solidity 0.8.23;

import "./interfaces/IProofOfContribution.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract ProofOfContribution is IProofOfContribution, AccessControl {
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
    
    struct DataContribution {
        address contributor;
        bytes32 dataHash;
        uint256 timestamp;
        uint256 quality; // 0-100
        bool validated;
        address validator;
    }
    
    mapping(bytes32 => DataContribution) public contributions;
    mapping(address => uint256) public contributorScores;
    mapping(uint256 => mapping(address => uint256)) public epochContributions;
    
    event ContributionSubmitted(bytes32 indexed id, address indexed contributor);
    event ContributionValidated(bytes32 indexed id, uint256 quality, address validator);
    
    function submitContribution(
        bytes32 dataHash,
        string memory metadata
    ) external returns (bytes32) {
        bytes32 contributionId = keccak256(
            abi.encode(msg.sender, dataHash, block.timestamp)
        );
        
        contributions[contributionId] = DataContribution({
            contributor: msg.sender,
            dataHash: dataHash,
            timestamp: block.timestamp,
            quality: 0,
            validated: false,
            validator: address(0)
        });
        
        emit ContributionSubmitted(contributionId, msg.sender);
        return contributionId;
    }
    
    function validateContribution(
        bytes32 contributionId,
        uint256 quality
    ) external onlyRole(VALIDATOR_ROLE) {
        DataContribution storage contribution = contributions[contributionId];
        require(!contribution.validated, "Already validated");
        require(quality <= 100, "Invalid quality score");
        
        contribution.quality = quality;
        contribution.validated = true;
        contribution.validator = msg.sender;
        
        // Update contributor score
        contributorScores[contribution.contributor] += quality;
        
        // Track for epoch rewards
        uint256 currentEpoch = block.timestamp / 1 days;
        epochContributions[currentEpoch][contribution.contributor] += quality;
        
        emit ContributionValidated(contributionId, quality, msg.sender);
    }
}
```

---

## Phase 3: Testing & Deployment (Week 3)

### Task 5: Create Comprehensive Tests

**File**: `test/VRC20Compliance.t.sol`

```solidity
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../src/RDATUpgradeable.sol";

contract VRC20ComplianceTest is Test {
    RDATUpgradeable public rdat;
    address admin = address(0x1);
    address user1 = address(0x2);
    address user2 = address(0x3);
    address blocked = address(0x4);
    
    function setUp() public {
        // Deploy with new features
    }
    
    function test_Blocklist() public {
        // Test blocking functionality
        vm.prank(admin);
        rdat.blockAddress(blocked);
        
        // Should revert on transfer
        vm.expectRevert("VRC20: Address is blocked");
        vm.prank(blocked);
        rdat.transfer(user1, 100);
    }
    
    function test_Timelock() public {
        // Test 48-hour timelock
        vm.prank(admin);
        bytes32 actionId = rdat.scheduleAction(
            address(rdat),
            abi.encodeWithSignature("pause()")
        );
        
        // Should fail before timelock
        vm.expectRevert("Timelock not expired");
        vm.prank(admin);
        rdat.executeAction(actionId);
        
        // Fast forward 48 hours
        vm.warp(block.timestamp + 48 hours);
        
        // Should succeed after timelock
        vm.prank(admin);
        rdat.executeAction(actionId);
        
        assertTrue(rdat.paused());
    }
    
    function test_DLPRegistration() public {
        // Test DLP registry integration
    }
}
```

### Task 6: Deploy to Moksha Testnet

```bash
# Deploy script
forge script script/DeployVRC20Compliant.s.sol \
  --rpc-url https://rpc.moksha.vana.org \
  --broadcast \
  --verify

# Verify compliance
cast call $RDAT_ADDRESS "isBlocked(address)" $TEST_ADDRESS \
  --rpc-url https://rpc.moksha.vana.org
```

---

## Checklist

### Pre-Deployment
- [ ] Implement blocklisting with tests
- [ ] Add 48-hour timelocks with tests
- [ ] Complete DLP registration logic
- [ ] Implement data validation
- [ ] Update all documentation
- [ ] Run Slither analysis
- [ ] Get security review

### Deployment
- [ ] Deploy to Moksha testnet
- [ ] Verify all contracts
- [ ] Test blocklist functionality
- [ ] Test timelock operations
- [ ] Register with DLP Registry
- [ ] Submit for Vana approval

### Post-Deployment
- [ ] Monitor for 48 hours
- [ ] Document any issues
- [ ] Prepare mainnet deployment
- [ ] Coordinate with Vana team

---

## Alternative: Use Vana's Factory

If time is critical, consider using Vana's DATFactory:

```solidity
// Deploy using Vana's factory
IDATFactory factory = IDATFactory(0x40f8bccF35a75ecef63BC3B1B3E06ffEB9220644);

address newToken = factory.deployDATPausable(
    "r/datadao",
    "RDAT",
    100_000_000e18, // total supply
    admin,          // admin address
    vestingSchedules // team vesting
);
```

Benefits:
- Instant VRC-20 compliance
- Pre-audited code
- Standard implementation
- Faster approval

Drawbacks:
- Less customization
- May need migration
- Different architecture

---

## Support Resources

- **Vana Discord**: Technical support channel
- **GitHub Issues**: https://github.com/vana-com/vana-smart-contracts
- **Documentation**: https://docs.vana.org
- **Testnet Faucet**: https://faucet.vana.org

---

*Implementation Plan Created: December 19, 2024*