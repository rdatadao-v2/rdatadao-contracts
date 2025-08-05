# Frontend Integration Guide

**Version**: 1.1 (Updated for V2 Beta with 7 Contracts)  
**Last Updated**: August 2025

This guide explains how to integrate the RDAT V2 Beta smart contracts with your frontend application using wagmi and viem.

## Quick Start

### 1. Generate ABI Files

From the contracts directory, run:

```bash
# Compile contracts and export ABIs
forge build
./scripts/export-abi.sh
```

This creates JSON ABI files in the `abi/` directory for all compiled contracts.

### 2. Install Frontend Dependencies

In your frontend project:

```bash
npm install wagmi viem @tanstack/react-query
npm install -D @wagmi/cli
```

### 3. Configure Wagmi

Copy the `wagmi.config.ts` file from this repository to your frontend project:

```typescript
import { defineConfig } from '@wagmi/cli'
import { foundry, react } from '@wagmi/cli/plugins'

export default defineConfig({
  out: 'src/generated.ts',
  contracts: [],
  plugins: [
    foundry({
      project: '../rdatadao-contracts', // Path to contracts
      include: [
        // V2 Beta Core Contracts (7 total)
        'RDAT.sol/RDAT.json',
        'vRDAT.sol/vRDAT.json',
        'Staking.sol/Staking.json',
        'MigrationBridge.sol/MigrationBridge.json',
        'EmergencyPause.sol/EmergencyPause.json',
        'RevenueCollector.sol/RevenueCollector.json',
        'ProofOfContribution.sol/ProofOfContribution.json',
        // Test/Mock Contracts
        'MockRDAT.sol/MockRDAT.json',
      ],
    }),
    react(),
  ],
})
```

### 4. Generate TypeScript Types

```bash
npx wagmi generate
```

This creates a `src/generated.ts` file with:
- Fully typed contract ABIs
- React hooks for reading/writing contracts
- Event listeners with proper types

### 5. Use in Your React App

```typescript
import { 
  useReadMockRdat,
  useWriteMockRdat,
  useWatchMockRdatEvent 
} from './generated'
import { formatEther, parseEther } from 'viem'

function TokenBalance({ address }: { address: `0x${string}` }) {
  // Read token balance
  const { data: balance, isLoading } = useReadMockRdat({
    functionName: 'balanceOf',
    args: [address],
  })

  if (isLoading) return <div>Loading...</div>
  
  return <div>{formatEther(balance || 0n)} RDAT</div>
}

function TransferForm() {
  const { writeContract, isPending } = useWriteMockRdat({
    functionName: 'transfer',
  })

  const handleTransfer = async (to: string, amount: string) => {
    await writeContract({
      args: [to as `0x${string}`, parseEther(amount)],
    })
  }

  return (
    <form onSubmit={handleSubmit}>
      {/* Form implementation */}
    </form>
  )
}
```

## Contract Addresses

### Base Mainnet (V1 - Migration Only)
- **RDAT Token V1**: `0x4498cd8ba045e00673402353f5a4347562707e7d`
- **Migration Bridge**: TBD (Day 12-13)

### Base Sepolia (Testing)
- **Mock RDAT**: TBD
- **Migration Bridge**: TBD

### Vana Mainnet (V2 Beta Primary)
- **RDAT**: TBD (Day 12-13)
- **vRDAT**: TBD
- **Staking**: TBD
- **MigrationBridge**: TBD
- **RevenueCollector**: TBD
- **ProofOfContribution**: TBD

### Vana Moksha Testnet
- **All V2 Beta Contracts**: TBD (Day 3-4)

## Advanced Usage

### Multi-Chain Support

```typescript
import { useAccount, useChainId } from 'wagmi'
import { base, baseSepolia } from 'wagmi/chains'

const CONTRACT_ADDRESSES = {
  [base.id]: {
    rdat: '0x4498cd8ba045e00673402353f5a4347562707e7d',
  },
  [baseSepolia.id]: {
    rdat: '0x...', // Your testnet deployment
  },
  // Add Vana chains...
} as const

function useRDATContract() {
  const chainId = useChainId()
  const addresses = CONTRACT_ADDRESSES[chainId]
  
  return {
    rdatAddress: addresses?.rdat,
    isSupported: !!addresses,
  }
}
```

### Migration Flow Integration

```typescript
import { 
  useWriteRdatMigration,
  useReadRdatDistributor,
  useWatchRdatMigrationEvent 
} from './generated'

function MigrationInterface() {
  // Deposit on Base
  const { writeContract: deposit } = useWriteRdatMigration({
    functionName: 'deposit',
  })
  
  // Watch for deposit events
  useWatchRdatMigrationEvent({
    eventName: 'Deposit',
    onLogs(logs) {
      console.log('New deposits:', logs)
    },
  })
  
  // Check claim status on Vana
  const { data: hasClaimed } = useReadRdatDistributor({
    functionName: 'hasClaimed',
    args: [userAddress, batchId],
  })
  
  return (
    // UI implementation
  )
}
```

### Error Handling

```typescript
import { useWriteMockRdat } from './generated'
import { BaseError, ContractFunctionRevertedError } from 'viem'

function TransferWithErrorHandling() {
  const { writeContract, error } = useWriteMockRdat({
    functionName: 'transfer',
  })

  if (error) {
    if (error instanceof BaseError) {
      const revertError = error.walk(
        err => err instanceof ContractFunctionRevertedError
      )
      
      if (revertError instanceof ContractFunctionRevertedError) {
        const errorName = revertError.data?.errorName
        // Handle specific errors like 'UnauthorizedUserAction'
        if (errorName === 'UnauthorizedUserAction') {
          return <div>Your address is blocked from transfers</div>
        }
      }
    }
  }
  
  return (
    // UI implementation
  )
}
```

## Manual ABI Export

If you need to manually export specific contract ABIs:

```bash
# Export single contract ABI
forge inspect MockRDAT abi > abi/MockRDAT.json

# Export contract storage layout
forge inspect MockRDAT storage > abi/MockRDAT.storage.json

# Export all contract metadata
forge inspect MockRDAT metadata > abi/MockRDAT.metadata.json
```

## Troubleshooting

### ABIs not generating
- Ensure contracts are compiled: `forge build`
- Check contract names match exactly
- Verify contracts are in the `src/` directory

### TypeScript types not working
- Run `npx wagmi generate` after any contract changes
- Ensure `wagmi.config.ts` points to correct paths
- Check that ABIs are valid JSON

### Wrong chain errors
- Verify chain IDs in your config match the networks
- Ensure RPC URLs are correct
- Check wallet is connected to the right network

## Resources

- [Wagmi Documentation](https://wagmi.sh)
- [Viem Documentation](https://viem.sh)
- [Foundry Book](https://book.getfoundry.sh)
- [RDAT Contract Repository](https://github.com/yourusername/rdatadao-contracts)