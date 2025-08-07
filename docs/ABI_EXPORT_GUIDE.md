# ABI Export Guide for Frontend Integration

## Overview

The Application Binary Interface (ABI) files are essential for frontend applications to interact with the r/datadao V2 smart contracts. These files define the contract functions, events, and data structures that can be called from Web3 libraries.

## Generated Files

The ABI export process generates the following structure:

```
abi/
├── RDATUpgradeable.json       # Main token contract (40KB)
├── vRDAT.json                 # Governance token (35KB)
├── StakingPositions.json      # Staking NFT system (33KB)
├── TreasuryWallet.json        # Treasury management (16KB)
├── TokenVesting.json          # Vesting schedules (15KB)
├── BaseMigrationBridge.json   # Base chain bridge (20KB)
├── VanaMigrationBridge.json   # Vana chain bridge (21KB)
├── EmergencyPause.json        # Emergency system (8KB)
├── RevenueCollector.json      # Revenue distribution (23KB)
├── RewardsManager.json        # Rewards orchestrator (23KB)
├── ProofOfContributionStub.json # PoC integration (15KB)
├── GovernanceCore.json        # Governance core (12KB)
├── GovernanceVoting.json      # Voting mechanism (11KB)
├── GovernanceExecution.json   # Execution logic (9KB)
├── Create2Factory.json        # Deployment helper (3KB)
├── index.ts                   # TypeScript exports
├── package.json              # NPM package config
└── README.md                 # Usage documentation
```

## How to Generate ABIs

### Method 1: Quick Export (Recommended)
```bash
# Run the extraction script
./scripts/extract-abi.sh
```

This script:
1. Compiles all contracts
2. Extracts ABIs from compiled artifacts
3. Creates TypeScript integration files
4. Generates documentation

### Method 2: Manual Export
```bash
# Compile contracts
forge build

# Extract specific ABI
forge inspect RDATUpgradeable abi > abi/RDATUpgradeable.json

# Or use jq to extract from artifact
jq '.abi' out/RDATUpgradeable.sol/RDATUpgradeable.json > abi/RDATUpgradeable.json
```

## Frontend Integration

### 1. Installation

Copy the `abi` folder to your frontend project:
```bash
cp -r abi ../frontend/src/contracts/
```

### 2. Basic Usage with ethers.js

```typescript
import { ethers } from 'ethers';
import RDATUpgradeableABI from './contracts/abi/RDATUpgradeable.json';
import { getAddresses } from './contracts/abi';

// Setup provider
const provider = new ethers.JsonRpcProvider('https://rpc.vana.org');

// Get contract addresses for current chain
const addresses = getAddresses(1480); // Vana mainnet

// Create contract instance
const rdatContract = new ethers.Contract(
  addresses.RDAT,
  RDATUpgradeableABI,
  provider
);

// Read data
const totalSupply = await rdatContract.totalSupply();
const balance = await rdatContract.balanceOf(userAddress);

// Write data (requires signer)
const signer = await provider.getSigner();
const rdatWithSigner = rdatContract.connect(signer);
const tx = await rdatWithSigner.transfer(recipient, amount);
```

### 3. Usage with wagmi/viem (React)

```tsx
import { useReadContract, useWriteContract } from 'wagmi';
import { parseEther } from 'viem';
import RDATUpgradeableABI from './contracts/abi/RDATUpgradeable.json';
import { getAddresses } from './contracts/abi';

function RDATBalance({ address }: { address: `0x${string}` }) {
  const chainId = 1480; // Vana mainnet
  const addresses = getAddresses(chainId);
  
  // Read balance
  const { data: balance } = useReadContract({
    address: addresses.RDAT as `0x${string}`,
    abi: RDATUpgradeableABI,
    functionName: 'balanceOf',
    args: [address],
  });
  
  // Write transaction
  const { writeContract } = useWriteContract();
  
  const handleTransfer = () => {
    writeContract({
      address: addresses.RDAT as `0x${string}`,
      abi: RDATUpgradeableABI,
      functionName: 'transfer',
      args: [recipientAddress, parseEther('100')],
    });
  };
  
  return (
    <div>
      <p>Balance: {balance?.toString()}</p>
      <button onClick={handleTransfer}>Transfer 100 RDAT</button>
    </div>
  );
}
```

### 4. Common Operations

#### Token Operations
```typescript
// Check balance
await rdatContract.balanceOf(address);

// Transfer tokens
await rdatContract.transfer(to, amount);

// Approve spending
await rdatContract.approve(spender, amount);

// Check allowance
await rdatContract.allowance(owner, spender);
```

#### Staking Operations
```typescript
import StakingPositionsABI from './abi/StakingPositions.json';

const stakingContract = new ethers.Contract(
  addresses.StakingPositions,
  StakingPositionsABI,
  signer
);

// Stake tokens (30 day lock)
await stakingContract.stake(amount, 0); // 0 = THIRTY_DAYS

// Check positions
await stakingContract.getPositions(address);

// Unstake (after lock period)
await stakingContract.unstake(positionId);

// Emergency exit (50% penalty)
await stakingContract.emergencyExit(positionId);
```

#### Migration Operations
```typescript
import BaseMigrationBridgeABI from './abi/BaseMigrationBridge.json';

const bridgeContract = new ethers.Contract(
  addresses.BaseMigrationBridge,
  BaseMigrationBridgeABI,
  signer
);

// Initiate migration from Base
await bridgeContract.initiateMigration(amount);

// Check migration status
await bridgeContract.getUserMigrationInfo(address);
```

## Contract Addresses

### Mainnet (Post-Audit)
```typescript
const MAINNET_ADDRESSES = {
  vana: {  // Chain ID: 1480
    RDAT: 'TBD',
    vRDAT: 'TBD',
    StakingPositions: 'TBD',
    TreasuryWallet: '0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319',
    // ... more contracts
  },
  base: {  // Chain ID: 8453
    BaseMigrationBridge: 'TBD',
    V1Token: 'EXISTING_V1_ADDRESS',
  }
};
```

### Testnet (Current)
```typescript
const TESTNET_ADDRESSES = {
  vanaMoksha: {  // Chain ID: 14800
    RDAT: '0xEb0c43d5987de0672A22e350930F615Af646e28c', // Predicted
    // ... more contracts
  },
  baseSepolia: {  // Chain ID: 84532
    BaseMigrationBridge: 'TBD',
    V1TokenMock: 'TBD',
  }
};
```

## TypeScript Support

The exported TypeScript file (`index.ts`) provides:

1. **ABI Exports**: All contract ABIs as named exports
2. **Address Mapping**: Contract addresses by chain ID
3. **Helper Functions**: `getAddresses(chainId)` utility
4. **Type Definitions**: Full TypeScript support

```typescript
import { 
  RDATUpgradeableABI,
  CONTRACT_ADDRESSES,
  getAddresses,
  type ChainId,
  type ContractName
} from './abi';

// Type-safe chain ID
const chainId: ChainId = 1480;

// Type-safe contract access
const addresses = getAddresses(chainId);
const rdatAddress: string = addresses.RDAT;
```

## Updating ABIs

When contracts are modified:

1. **Recompile Contracts**
   ```bash
   forge build
   ```

2. **Re-export ABIs**
   ```bash
   ./scripts/extract-abi.sh
   ```

3. **Update Frontend**
   - Copy new ABI files to frontend
   - Update contract addresses if deployed to new addresses
   - Test integration

## Best Practices

1. **Version Control**: Commit ABI files to git for frontend consistency
2. **Type Safety**: Use TypeScript for compile-time contract validation
3. **Error Handling**: Always handle contract call failures gracefully
4. **Gas Estimation**: Estimate gas before transactions
5. **Event Listening**: Subscribe to contract events for real-time updates

## Troubleshooting

### Issue: ABI not found
**Solution**: Run `forge build` then `./scripts/extract-abi.sh`

### Issue: Contract call fails
**Solution**: Verify:
- Correct network/chain ID
- Contract is deployed at address
- User has sufficient balance/allowance
- Function parameters are correct

### Issue: TypeScript errors
**Solution**: Ensure ABI types match contract version

## Resources

- [ethers.js Documentation](https://docs.ethers.org/)
- [viem Documentation](https://viem.sh/)
- [wagmi Documentation](https://wagmi.sh/)
- [Foundry Book](https://book.getfoundry.sh/)

---

**Last Updated**: August 7, 2024
**ABI Version**: 2.0.0
**Status**: Production Ready