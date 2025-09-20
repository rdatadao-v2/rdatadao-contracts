# RDATDataDAO - Vana Data Liquidity Pool (DLP)

## Overview

RDATDataDAO is r/datadao's Data Liquidity Pool (DLP) contract designed to integrate with the Vana ecosystem. It manages data contributions, validator consensus, and reward distribution for Reddit data processed through the network.

**Contract Addresses**:
- **Mainnet (Vana)**: `0xBbB0B59163b850dDC5139e98118774557c5d9F92`
- **Testnet (Moksha)**: `0x254A9344AAb674530D47B6F2dDd8e328A17Da860`

## Architecture

### Core Components

1. **Data Contribution System**
   - Contributors submit data hashes with quality scores (0-100)
   - Tracks contributor scores and rewards
   - Prevents duplicate data submissions

2. **Validator Network**
   - Multi-signature validation system (same as migration bridge)
   - Validates data quality and authenticity
   - Consensus-based data approval

3. **Epoch Management**
   - 21-hour epochs aligned with Vana network
   - Periodic reward distribution
   - Automated epoch advancement

4. **Reward Distribution**
   - RDAT token-based rewards
   - Proportional to contribution quality and validation
   - Emergency withdrawal capabilities

### Key Features

- **Access Control**: Role-based permissions (admin, validator, contributor)
- **Emergency Mechanisms**: Pausable operations and emergency withdrawals
- **Integration Ready**: Designed for Vana DLP Registry registration
- **Scalable**: Supports unlimited contributors and validators

## Contract Interface

### Core Functions

#### Data Management
```solidity
function contributeData(bytes32 dataHash, uint256 score) external
function validateData(bytes32 dataHash, bool isValid) external
function isDataValidated(bytes32 dataHash) external view returns (bool)
```

#### Reward System
```solidity
function distributeRewards(address[] calldata recipients, uint256[] calldata amounts) external
function getContributor(address contributor) external view returns (uint256 score, uint256 rewards)
```

#### Validator Management
```solidity
function addValidator(address validator) external
function removeValidator(address validator) external  
function isValidator(address account) external view returns (bool)
```

#### Epoch Control
```solidity
function advanceEpoch() external
function getStats() external view returns (uint256, uint256, uint256, uint256, string, string)
```

## Deployment Configuration

### Constructor Parameters
- `_rdatToken`: RDAT token address (`0xEb0c43d5987de0672A22e350930F615Af646e28c`)
- `_treasury`: Treasury wallet address (`0x31C3e3F091FB2A25d4dac82474e7dc709adE754a`)
- `_admin`: Admin address (`0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319`)
- `_initialValidators`: Array of initial validator addresses

### Initial Validators
1. **Multisig**: `0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319`
2. **Deployer**: `0x58eCB94e6F5e6521228316b55c465ad2A2938FbB`  
3. **Additional**: `0xC9Af4E56741f255743e8f4877d4cfa9971E910C2`

## Integration with Vana

### DLP Registration
The contract is designed to be registered with Vana's DLP Registry:
- **DLP Name**: "r/datadao"
- **Version**: "1.0.0"
- **Registration Fee**: 1 VANA
- **Registry Address**: `0x4D59880a924526d1dD33260552Ff4328b1E18a43`

### Data Flow
1. **Contribution**: Users submit Reddit data hashes with quality scores
2. **Validation**: Network validators verify data authenticity
3. **Consensus**: Multi-validator consensus determines validity
4. **Rewards**: Proportional RDAT rewards distributed to contributors
5. **Epochs**: 21-hour cycles align with Vana network timing

## Security Features

### Access Control
- **DEFAULT_ADMIN_ROLE**: Full contract control (multisig)
- **VALIDATOR_ROLE**: Data validation permissions
- **PAUSER_ROLE**: Emergency pause capabilities
- **CONTRIBUTOR_ROLE**: Data submission (public by default)

### Safety Mechanisms
- **Reentrancy Guards**: All state-changing functions protected
- **Pausable Operations**: Emergency pause with admin override
- **Input Validation**: Comprehensive parameter checking
- **Balance Checks**: Reward distribution safeguards

### Emergency Procedures
- **Pause**: Halt all operations except views
- **Emergency Withdraw**: Recover tokens to treasury
- **Validator Management**: Add/remove validators as needed

## Economic Model

### Reward Structure
- **Contributors**: Receive RDAT based on data quality scores
- **Validators**: Earn from validation activities
- **Treasury**: Manages reward pools and distributions

### Quality Scoring
- **Range**: 0-100 points per data contribution
- **Criteria**: Data authenticity, uniqueness, relevance
- **Validation**: Multi-validator consensus required

## Testing & Verification

### Test Coverage
- ✅ Data contribution flow
- ✅ Validator consensus mechanism
- ✅ Reward distribution logic
- ✅ Access control enforcement
- ✅ Emergency procedures
- ✅ Epoch advancement

### Deployment Verification
```bash
# Check deployment
forge script script/DeployRDATDataDAO.s.sol --sig "check()" --rpc-url https://rpc.moksha.vana.org

# Verify contract stats
cast call 0x254A9344AAb674530D47B6F2dDd8e328A17Da860 "getStats()" --rpc-url https://rpc.moksha.vana.org
```

## Integration Points

### RDAT Token Integration
- **Rewards**: RDAT tokens distributed to contributors
- **Funding**: Contract must be funded with RDAT for rewards
- **Treasury**: Emergency withdrawals go to TreasuryWallet

### Migration Bridge Integration
- **Shared Validators**: Same validator set as VanaMigrationBridge
- **Consistent Security**: Aligned security model across systems
- **Unified Governance**: Same multisig controls both systems

### Vana Network Integration
- **DLP Registry**: Registered as official Data Liquidity Pool
- **Epoch Alignment**: 21-hour cycles match Vana network
- **Reward Cycles**: Coordinated with network reward distribution

## Known Limitations

1. **Registry Dependency**: Requires Vana DLP Registry registration
2. **Manual Epochs**: Epoch advancement requires manual trigger
3. **Centralized Validation**: Limited to configured validators initially
4. **Fixed Quality Range**: 0-100 scoring system may need expansion

## Future Enhancements

1. **Automated Epochs**: Self-advancing epoch system
2. **Dynamic Scoring**: Adaptive quality scoring algorithms
3. **Decentralized Validation**: Open validator network
4. **Cross-DLP Integration**: Inter-DLP data sharing

## Audit Focus Areas

### Critical Security
- [ ] Validator consensus mechanism
- [ ] Reward calculation accuracy
- [ ] Access control enforcement
- [ ] Emergency procedure testing

### Economic Model
- [ ] Reward distribution fairness
- [ ] Quality scoring integrity
- [ ] Treasury management
- [ ] Token flow validation

### Integration Testing
- [ ] Vana DLP Registry compatibility
- [ ] RDAT token interaction
- [ ] Multi-validator coordination
- [ ] Epoch synchronization