# Deployment Considerations for Modular Rewards Architecture

## vRDAT Token and Reward Module Setup

### Critical Setup Steps

1. **Deploy vRDAT Token**
   ```solidity
   vRDAT = new vRDAT(adminAddress);
   ```

2. **Deploy vRDATRewardModule**
   ```solidity
   vRDATRewardModule = new vRDATRewardModule(
       address(vRDAT),
       address(stakingManager),
       address(rewardsManager),
       adminAddress
   );
   ```

3. **Grant Minting and Burning Roles** ⚠️ CRITICAL
   ```solidity
   // The vRDATRewardModule needs permission to mint/burn vRDAT
   vRDAT.grantRole(vRDAT.MINTER_ROLE(), address(vRDATRewardModule));
   vRDAT.grantRole(vRDAT.BURNER_ROLE(), address(vRDATRewardModule));
   ```

### Key Design Points

1. **vRDAT as First Reward Module**
   - vRDAT distribution is implemented as a reward module, not built into staking
   - This proves the modular architecture works for core functionality
   - Sets the pattern for future reward modules

2. **Unlimited Supply**
   - vRDAT has no max supply as it's a governance token
   - Minting happens on stake, burning on emergency withdrawal
   - Supply grows with staking participation

3. **Soul-bound Implementation**
   - vRDAT is non-transferable (soul-bound)
   - The module handles minting on stake
   - Burns tokens if user emergency withdraws (penalty)

4. **Access Control**
   - Only vRDATRewardModule should have MINTER_ROLE
   - Only vRDATRewardModule should have BURNER_ROLE
   - This ensures vRDAT can only be created through staking

### Deployment Order

1. Deploy Core Infrastructure
   - RDATUpgradeable (with proxy)
   - vRDAT
   - StakingManager

2. Deploy Rewards Infrastructure
   - RewardsManager (with proxy)
   - vRDATRewardModule
   - RDATRewardModule

3. Configure Permissions
   - Grant vRDATRewardModule minting/burning roles on vRDAT
   - Grant StakingManager role on RewardsManager
   - Set RewardsManager on StakingManager

4. Register Reward Programs
   ```solidity
   rewardsManager.registerProgram(
       address(vRDATRewardModule),
       "vRDAT Governance Rewards",
       block.timestamp, // Start immediately
       0 // Perpetual program
   );
   ```

### Security Considerations

1. **Role Management**
   - Never grant MINTER_ROLE to EOAs
   - Only the reward module should mint/burn
   - Use multi-sig for role management

2. **Module Verification**
   - Verify module code before granting roles
   - Ensure module can't mint arbitrary amounts
   - Check burn conditions are correct

3. **Emergency Response**
   - Admin can pause reward programs
   - Admin can revoke minting roles if needed
   - Consider timelock for role changes

### Testing Checklist

- [ ] vRDATRewardModule can mint vRDAT on stake
- [ ] vRDATRewardModule can burn vRDAT on emergency withdrawal
- [ ] No other contracts can mint vRDAT
- [ ] Minting amounts match stake amounts and multipliers
- [ ] Burns only happen on emergency withdrawal
- [ ] Normal unstake doesn't burn vRDAT