#!/bin/bash

# Script to extract ABI files from Foundry artifacts for frontend integration

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Create ABI directory if it doesn't exist
ABI_DIR="./abi"
mkdir -p "$ABI_DIR"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   r/datadao V2 ABI Extraction Tool${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# First, ensure contracts are compiled
echo -e "${YELLOW}Step 1: Ensuring contracts are compiled...${NC}"
forge build

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Compilation failed. Please fix compilation errors first.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Compilation successful${NC}"
echo ""

# Function to extract ABI from artifact
extract_abi_from_artifact() {
    local contract_name=$1
    local artifact_path=$2
    
    if [ -f "$artifact_path" ]; then
        # Extract just the ABI array from the JSON artifact
        jq '.abi' "$artifact_path" > "$ABI_DIR/${contract_name}.json" 2>/dev/null
        
        if [ $? -eq 0 ] && [ -s "$ABI_DIR/${contract_name}.json" ]; then
            # Verify it's valid JSON
            if jq empty "$ABI_DIR/${contract_name}.json" 2>/dev/null; then
                echo -e "  ${GREEN}✓${NC} $contract_name"
                return 0
            fi
        fi
        
        rm -f "$ABI_DIR/${contract_name}.json"
        return 1
    fi
    
    return 1
}

echo -e "${YELLOW}Step 2: Extracting ABI files from artifacts...${NC}"

# Core contracts
echo -e "\n${YELLOW}Core Contracts:${NC}"
extract_abi_from_artifact "RDATUpgradeable" "out/RDATUpgradeable.sol/RDATUpgradeable.json"
extract_abi_from_artifact "vRDAT" "out/vRDAT.sol/vRDAT.json"
extract_abi_from_artifact "StakingPositions" "out/StakingPositions.sol/StakingPositions.json"
extract_abi_from_artifact "TreasuryWallet" "out/TreasuryWallet.sol/TreasuryWallet.json"
extract_abi_from_artifact "TokenVesting" "out/TokenVesting.sol/TokenVesting.json"
extract_abi_from_artifact "BaseMigrationBridge" "out/BaseMigrationBridge.sol/BaseMigrationBridge.json"
extract_abi_from_artifact "VanaMigrationBridge" "out/VanaMigrationBridge.sol/VanaMigrationBridge.json"
extract_abi_from_artifact "EmergencyPause" "out/EmergencyPause.sol/EmergencyPause.json"
extract_abi_from_artifact "RevenueCollector" "out/RevenueCollector.sol/RevenueCollector.json"
extract_abi_from_artifact "RewardsManager" "out/RewardsManager.sol/RewardsManager.json"
extract_abi_from_artifact "ProofOfContributionStub" "out/ProofOfContributionStub.sol/ProofOfContributionStub.json"
extract_abi_from_artifact "Create2Factory" "out/Create2Factory.sol/Create2Factory.json"

# Governance contracts
echo -e "\n${YELLOW}Governance Contracts:${NC}"
extract_abi_from_artifact "GovernanceCore" "out/GovernanceCore.sol/GovernanceCore.json"
extract_abi_from_artifact "GovernanceVoting" "out/GovernanceVoting.sol/GovernanceVoting.json"
extract_abi_from_artifact "GovernanceExecution" "out/GovernanceExecution.sol/GovernanceExecution.json"

# Create TypeScript index file
echo -e "\n${YELLOW}Step 3: Creating TypeScript integration files...${NC}"

cat > "$ABI_DIR/index.ts" << 'EOF'
// Auto-generated ABI exports for r/datadao V2
// Generated on: 
EOF

echo "// $(date)" >> "$ABI_DIR/index.ts"

cat >> "$ABI_DIR/index.ts" << 'EOF'

// Core Contracts
export { default as RDATUpgradeableABI } from './RDATUpgradeable.json';
export { default as vRDATABI } from './vRDAT.json';
export { default as StakingPositionsABI } from './StakingPositions.json';
export { default as TreasuryWalletABI } from './TreasuryWallet.json';
export { default as TokenVestingABI } from './TokenVesting.json';
export { default as BaseMigrationBridgeABI } from './BaseMigrationBridge.json';
export { default as VanaMigrationBridgeABI } from './VanaMigrationBridge.json';
export { default as EmergencyPauseABI } from './EmergencyPause.json';
export { default as RevenueCollectorABI } from './RevenueCollector.json';
export { default as RewardsManagerABI } from './RewardsManager.json';
export { default as ProofOfContributionStubABI } from './ProofOfContributionStub.json';
export { default as Create2FactoryABI } from './Create2Factory.json';

// Governance Contracts
export { default as GovernanceCoreABI } from './GovernanceCore.json';
export { default as GovernanceVotingABI } from './GovernanceVoting.json';
export { default as GovernanceExecutionABI } from './GovernanceExecution.json';

// Contract addresses (update after deployment)
export const CONTRACT_ADDRESSES = {
  // Vana Mainnet (Chain ID: 1480)
  1480: {
    RDAT: '',
    vRDAT: '',
    StakingPositions: '',
    TreasuryWallet: '',
    TokenVesting: '',
    VanaMigrationBridge: '',
    RevenueCollector: '',
    RewardsManager: '',
    EmergencyPause: '',
    ProofOfContribution: '',
  },
  // Base Mainnet (Chain ID: 8453)
  8453: {
    BaseMigrationBridge: '',
    V1Token: '', // Existing V1 token address
  },
  // Vana Moksha Testnet (Chain ID: 14800)
  14800: {
    RDAT: '0xEb0c43d5987de0672A22e350930F615Af646e28c', // Predicted
    vRDAT: '',
    StakingPositions: '',
    TreasuryWallet: '',
    TokenVesting: '',
    VanaMigrationBridge: '',
    RevenueCollector: '',
    RewardsManager: '',
    EmergencyPause: '',
    ProofOfContribution: '',
  },
  // Base Sepolia (Chain ID: 84532)
  84532: {
    BaseMigrationBridge: '',
    V1TokenMock: '',
  }
} as const;

// Helper function to get addresses by chain ID
export function getAddresses(chainId: number) {
  const addresses = CONTRACT_ADDRESSES[chainId as keyof typeof CONTRACT_ADDRESSES];
  if (!addresses) {
    throw new Error(`Unsupported chain ID: ${chainId}`);
  }
  return addresses;
}

// Type exports for better TypeScript support
export type ChainId = keyof typeof CONTRACT_ADDRESSES;
export type ContractName = keyof typeof CONTRACT_ADDRESSES[1480];
EOF

echo -e "${GREEN}✓ Created TypeScript index file${NC}"

# Create package.json for the ABI module
cat > "$ABI_DIR/package.json" << 'EOF'
{
  "name": "@rdatadao/abi",
  "version": "2.0.0",
  "description": "ABI files for r/datadao V2 smart contracts",
  "main": "index.ts",
  "types": "index.ts",
  "files": [
    "*.json",
    "index.ts",
    "README.md"
  ],
  "repository": {
    "type": "git",
    "url": "https://github.com/rdatadao/contracts"
  },
  "keywords": [
    "rdatadao",
    "abi",
    "ethereum",
    "vana",
    "base",
    "smart-contracts",
    "web3"
  ],
  "author": "r/datadao",
  "license": "MIT"
}
EOF

echo -e "${GREEN}✓ Created package.json${NC}"

# Create README for the ABI package
cat > "$ABI_DIR/README.md" << 'EOF'
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
EOF

echo -e "${GREEN}✓ Created README.md${NC}"

# Count exported ABIs
TOTAL_ABIS=$(ls -1 "$ABI_DIR"/*.json 2>/dev/null | wc -l)

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}         Export Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "📁 ABI files location: ${GREEN}$ABI_DIR/${NC}"
echo -e "📊 Total ABIs exported: ${GREEN}$TOTAL_ABIS${NC}"
echo ""

# List exported files
if [ $TOTAL_ABIS -gt 0 ]; then
    echo -e "${GREEN}Exported ABI files:${NC}"
    ls -1 "$ABI_DIR"/*.json | xargs -n1 basename | sed 's/^/  ✓ /'
fi

echo ""
echo -e "${YELLOW}Frontend Integration:${NC}"
echo "1. Copy the ${GREEN}abi/${NC} folder to your frontend project"
echo "2. Import: ${GREEN}import { RDATUpgradeableABI, CONTRACT_ADDRESSES } from './abi'${NC}"
echo "3. Use with your preferred Web3 library (ethers, viem, wagmi)"
echo ""
echo -e "${YELLOW}Quick Start:${NC}"
echo -e "${GREEN}npm install ethers${NC} or ${GREEN}npm install viem wagmi${NC}"
echo "See ${GREEN}abi/README.md${NC} for detailed usage examples"