# r/datadao V2 Contract ABIs

This directory contains the Application Binary Interface (ABI) files for all r/datadao V2 smart contracts.

## Installation

### Option 1: Direct Import
Copy the `abi` folder to your project and import directly:

```typescript
import { RDATUpgradeableABI, CONTRACT_ADDRESSES } from './abi';
```

### Option 2: NPM Package (if published)
```bash
npm install @rdatadao/abi
```

## Usage

### With ethers.js v6

```typescript
import { ethers } from 'ethers';
import { RDATUpgradeableABI, getAddresses } from '@rdatadao/abi';

// Connect to Vana network
const provider = new ethers.JsonRpcProvider('https://rpc.vana.org');
const addresses = getAddresses(1480); // Vana mainnet

// Create contract instance
const rdatContract = new ethers.Contract(
  addresses.RDAT,
  RDATUpgradeableABI,
  provider
);

// Read contract data
const totalSupply = await rdatContract.totalSupply();
```

### With viem

```typescript
import { createPublicClient, http } from 'viem';
import { RDATUpgradeableABI, getAddresses } from '@rdatadao/abi';

const client = createPublicClient({
  transport: http('https://rpc.vana.org')
});

const addresses = getAddresses(1480);

const balance = await client.readContract({
  address: addresses.RDAT,
  abi: RDATUpgradeableABI,
  functionName: 'balanceOf',
  args: [userAddress]
});
```

### With wagmi v2 (React)

```tsx
import { useReadContract } from 'wagmi';
import { RDATUpgradeableABI, getAddresses } from '@rdatadao/abi';

function TokenBalance({ address }: { address: `0x${string}` }) {
  const chainId = 1480; // Vana mainnet
  const addresses = getAddresses(chainId);
  
  const { data: balance } = useReadContract({
    address: addresses.RDAT,
    abi: RDATUpgradeableABI,
    functionName: 'balanceOf',
    args: [address],
  });
  
  return <div>Balance: {balance?.toString()}</div>;
}
```

## Available ABIs

### Core Contracts
- `RDATUpgradeableABI` - Main RDAT token contract
- `vRDATABI` - Soul-bound governance token
- `StakingPositionsABI` - NFT-based staking system
- `TreasuryWalletABI` - DAO treasury management
- `TokenVestingABI` - Vesting schedules
- `BaseMigrationBridgeABI` - Base chain migration bridge
- `VanaMigrationBridgeABI` - Vana chain migration bridge
- `EmergencyPauseABI` - Emergency pause mechanism
- `RevenueCollectorABI` - Revenue distribution
- `RewardsManagerABI` - Rewards management
- `ProofOfContributionStubABI` - PoC integration

### Governance Contracts
- `GovernanceCoreABI` - Core governance logic
- `GovernanceVotingABI` - Voting mechanism
- `GovernanceExecutionABI` - Proposal execution

## Supported Networks

| Network | Chain ID | Status |
|---------|----------|--------|
| Vana Mainnet | 1480 | Post-audit |
| Base Mainnet | 8453 | Post-audit |
| Vana Moksha (Testnet) | 14800 | Ready |
| Base Sepolia (Testnet) | 84532 | Ready |

## Contract Addresses

Contract addresses are available via the `CONTRACT_ADDRESSES` export or the `getAddresses()` helper function.

```typescript
import { CONTRACT_ADDRESSES, getAddresses } from '@rdatadao/abi';

// Access directly
const vanaAddresses = CONTRACT_ADDRESSES[1480];

// Or use helper
const addresses = getAddresses(1480);
console.log(addresses.RDAT); // RDAT token address on Vana
```

## TypeScript Support

This package includes full TypeScript definitions for:
- All contract ABIs
- Contract addresses by chain
- Helper functions
- Chain IDs and contract names

## License

MIT
