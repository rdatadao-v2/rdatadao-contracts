# Test Deployment Plan for r/datadao V2

## Overview

This document outlines the test deployment plan for r/datadao V2 contracts on testnets before mainnet deployment. All testnet deployments are for validation purposes only.

## Deployment Sequence

### Phase 1: Vana Moksha Testnet

#### 1.1 Core Contracts
```bash
# Deploy RDAT Token (UUPS Proxy)
forge script script/DeployRDATUpgradeableSimple.s.sol \
  --rpc-url https://rpc.moksha.vana.org \
  --broadcast \
  --private-key $DEPLOYER_PRIVATE_KEY

# Expected addresses:
# - RDAT Proxy: 0xEb0c43d5987de0672A22e350930F615Af646e28c
# - Implementation: 0xd546C45872eeA596155EAEAe9B8495f02ca4fc58
```

#### 1.2 Supporting Contracts
```bash
# Deploy vRDAT (soul-bound governance token)
forge script script/DeployvRDAT.s.sol \
  --rpc-url https://rpc.moksha.vana.org \
  --broadcast

# Deploy StakingPositions
forge script script/DeployStakingPositions.s.sol \
  --rpc-url https://rpc.moksha.vana.org \
  --broadcast

# Deploy TreasuryWallet
forge script script/DeployTreasuryWallet.s.sol \
  --rpc-url https://rpc.moksha.vana.org \
  --broadcast
```

#### 1.3 DLP Registration
```bash
# Register as Data Liquidity Pool
./script/register-dlp.sh testnet

# Cost: 1 VANA + gas
# Registry: 0x4D59880a924526d1dD33260552Ff4328b1E18a43
```

### Phase 2: Base Sepolia Testnet

#### 2.1 Migration Infrastructure
```bash
# Deploy MigrationBridge
forge script script/DeployMigrationBridge.s.sol \
  --rpc-url https://sepolia.base.org \
  --broadcast

# Deploy V1 RDAT Mock (for testing)
forge script script/DeployV1Mock.s.sol \
  --rpc-url https://sepolia.base.org \
  --broadcast
```

### Phase 3: Cross-Chain Testing

#### 3.1 Migration Flow Test
1. Mint test V1 tokens on Base Sepolia
2. Approve and initiate migration
3. Generate burn proof
4. Submit to Vana Moksha bridge
5. Verify V2 token receipt

#### 3.2 Staking Flow Test
1. Stake RDAT for various lock periods
2. Verify vRDAT minting
3. Test rewards distribution
4. Test emergency exit

#### 3.3 Governance Flow Test
1. Create test proposal
2. Vote with vRDAT
3. Execute via treasury
4. Verify execution

## Configuration

### Environment Variables
```bash
# Network RPCs
VANA_MOKSHA_RPC_URL=https://rpc.moksha.vana.org
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org

# Addresses
DEPLOYER_ADDRESS=0x58eCB94e6F5e6521228316b55c465ad2A2938FbB
TREASURY_ADDRESS=0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319
ADMIN_ADDRESS=0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319

# Private key (testnet only!)
DEPLOYER_PRIVATE_KEY=<testnet_key>
```

### Gas Requirements
- Vana Moksha: ~0.05 ETH for all contracts
- Base Sepolia: ~0.01 ETH for migration contracts
- DLP Registration: 1 VANA + 0.1 VANA gas

## Verification Checklist

### Contract Functionality
- [ ] RDAT token transfers work
- [ ] Fixed supply enforced (100M)
- [ ] Minting disabled after deployment
- [ ] Pausing mechanism works
- [ ] Upgrade mechanism works (UUPS)

### Staking System
- [ ] Can stake with 30/90/180/365 day locks
- [ ] vRDAT minted proportionally
- [ ] NFT positions created
- [ ] Rewards claimable
- [ ] Emergency exit works

### Migration Bridge
- [ ] V1 tokens lockable on Base
- [ ] Burn proofs generated
- [ ] V2 tokens claimable on Vana
- [ ] 30M allocation tracked
- [ ] Deadline enforced

### Treasury Operations
- [ ] 70M RDAT received
- [ ] Vesting schedules creatable
- [ ] DAO proposals executable
- [ ] Phase 3 gating works
- [ ] Emergency withdrawal works

### DLP Integration
- [ ] Registration successful
- [ ] DLP ID assigned
- [ ] Contract updated with ID
- [ ] Vana integration ready

## Testing Scripts

### Quick Test Suite
```bash
# Run integration tests
forge test --match-contract Integration

# Run security tests
forge test --match-path test/security

# Run scenario tests
forge test --match-path test/scenarios
```

### Manual Testing
```bash
# Check deployment status
./script/deployment-summary.sh

# Check balances
./script/check-balances.sh

# Verify contracts
forge verify-contract <address> <contract> \
  --chain-id 14800 \
  --etherscan-api-key $VANASCAN_API_KEY
```

## Risk Mitigation

### Testnet-Only Features
1. Test faucets for token distribution
2. Accelerated vesting for testing
3. Reduced lock periods for demos
4. Mock oracles for price feeds

### Security Measures
1. All admin functions use multisig
2. Emergency pause available
3. Timelocks on critical operations
4. Reentrancy guards on all functions

### Rollback Plan
1. Save all deployment artifacts
2. Document contract addresses
3. Keep upgrade implementations ready
4. Have emergency pause ready

## Success Criteria

### Technical
- All 370+ tests passing
- Gas usage within limits
- No security vulnerabilities
- Cross-chain flow working

### Functional
- Users can migrate tokens
- Staking generates vRDAT
- Governance proposals execute
- Treasury distributes funds
- DLP registered successfully

### Performance
- Transaction costs acceptable
- Response times reasonable
- No bottlenecks identified
- Scalability validated

## Timeline

### Week 1: Vana Moksha
- Day 1-2: Deploy core contracts
- Day 3-4: Deploy supporting contracts
- Day 5: Register DLP
- Day 6-7: Integration testing

### Week 2: Base Sepolia
- Day 1-2: Deploy migration contracts
- Day 3-4: Cross-chain testing
- Day 5-7: End-to-end validation

### Week 3: Documentation
- Compile test results
- Document issues found
- Prepare audit package
- Create deployment guide

## Support Resources

### Documentation
- [Vana Docs](https://docs.vana.org)
- [Base Docs](https://docs.base.org)
- [OpenZeppelin Upgrades](https://docs.openzeppelin.com/upgrades)

### Tools
- [Vanascan](https://vanascan.io)
- [Base Sepolia Explorer](https://sepolia.basescan.org)
- [Foundry Book](https://book.getfoundry.sh)

### Contacts
- Technical Lead: @dev
- Security Lead: @security
- Community: Discord #testnet

## Appendix: Common Issues

### Issue: Gas estimation failed
**Solution**: Increase gas limit multiplier
```bash
--gas-estimate-multiplier 150
```

### Issue: Nonce mismatch
**Solution**: Reset nonce or wait for pending tx
```bash
cast nonce $DEPLOYER_ADDRESS --rpc-url $RPC
```

### Issue: DLP registration fails
**Solution**: Ensure 1+ VANA in deployer account

### Issue: Cross-chain message fails
**Solution**: Wait for finality (10-15 minutes)

---

**Status**: Ready for Execution
**Last Updated**: August 7, 2024
**Version**: 1.0