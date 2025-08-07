#!/bin/bash

# Script to export ABI files for r/datadao V2 frontend integration

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Create ABI directory if it doesn't exist
ABI_DIR="./abi"
mkdir -p "$ABI_DIR"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   r/datadao V2 ABI Export Tool${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# First, ensure contracts are compiled
echo -e "${YELLOW}Step 1: Compiling contracts...${NC}"
forge build

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Compilation failed. Please fix compilation errors first.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Compilation successful${NC}"
echo ""

# List of contracts to export (in order of importance)
echo -e "${YELLOW}Step 2: Exporting ABI files...${NC}"

# Core contracts (12 production contracts)
CORE_CONTRACTS=(
    "RDATUpgradeable"
    "vRDAT"
    "StakingPositions"
    "TreasuryWallet"
    "TokenVesting"
    "BaseMigrationBridge"
    "VanaMigrationBridge"
    "EmergencyPause"
    "RevenueCollector"
    "RewardsManager"
    "ProofOfContributionStub"
    "Create2Factory"
    "MigrationBonusVesting"
)

# Interface contracts (for frontend typing)
INTERFACE_CONTRACTS=(
    "IRDAT"
    "IvRDAT"
    "IStakingPositions"
    "ITreasuryWallet"
    "ITokenVesting"
    "IMigrationBridge"
    "IRevenueCollector"
    "IRewardsManager"
    "IProofOfContribution"
    "IEmergencyPause"
)

# Governance contracts
GOVERNANCE_CONTRACTS=(
    "GovernanceCore"
    "GovernanceVoting"
    "GovernanceExecution"
)

# DLP contracts (Vana ecosystem)
DLP_CONTRACTS=(
    "RDATDataDAO"
    "SimpleVanaDLP"
)

# Reward module contracts  
REWARD_CONTRACTS=(
    "RDATRewardModule"
    "vRDATRewardModule" 
    "VRC14LiquidityModule"
)

# Export function
export_abi() {
    local contract=$1
    local category=$2
    
    # Look for the compiled artifact
    local artifact_path="out/${contract}.sol/${contract}.json"
    
    if [ -f "$artifact_path" ]; then
        # Extract ABI using Python
        python3 -c "
import json
import sys

try:
    with open('$artifact_path', 'r') as f:
        artifact = json.load(f)
    
    # Extract just the ABI
    abi = artifact['abi']
    
    with open('$ABI_DIR/${contract}.json', 'w') as f:
        json.dump(abi, f, indent=2)
    
    print('success')
except Exception as e:
    print(f'error: {e}', file=sys.stderr)
    sys.exit(1)
" > /dev/null 2>&1
        
        if [ $? -eq 0 ] && [ -s "$ABI_DIR/${contract}.json" ]; then
            echo -e "  ${GREEN}✓${NC} $contract"
            return 0
        else
            rm -f "$ABI_DIR/${contract}.json"
            return 1
        fi
    else
        return 1
    fi
}

# Export Core Contracts
echo -e "\n${YELLOW}Core Contracts:${NC}"
for contract in "${CORE_CONTRACTS[@]}"; do
    export_abi "$contract" "core"
done

# Export Interface Contracts
echo -e "\n${YELLOW}Interface Contracts:${NC}"
for contract in "${INTERFACE_CONTRACTS[@]}"; do
    export_abi "$contract" "interface"
done

# Export Governance Contracts
echo -e "\n${YELLOW}Governance Contracts:${NC}"
for contract in "${GOVERNANCE_CONTRACTS[@]}"; do
    export_abi "$contract" "governance"
done

# Export DLP Contracts
echo -e "\n${YELLOW}DLP Contracts:${NC}"
for contract in "${DLP_CONTRACTS[@]}"; do
    export_abi "$contract" "dlp"
done

# Export Reward Contracts
echo -e "\n${YELLOW}Reward Module Contracts:${NC}"
for contract in "${REWARD_CONTRACTS[@]}"; do
    export_abi "$contract" "reward"
done

# Create a combined ABI file for common operations
echo -e "\n${YELLOW}Step 3: Creating combined ABI file...${NC}"

# Create TypeScript export file
cat > "$ABI_DIR/index.ts" << EOF
// Auto-generated ABI exports for r/datadao V2
// Generated on: $(date)

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
export { default as Create2FactoryABI } from './Create2Factory.json';
export { default as ProofOfContributionStubABI } from './ProofOfContributionStub.json';
export { default as MigrationBonusVestingABI } from './MigrationBonusVesting.json';

// DLP Contracts (Vana ecosystem)
export { default as RDATDataDAOABI } from './RDATDataDAO.json';
export { default as SimpleVanaDLPABI } from './SimpleVanaDLP.json';

// Reward Module Contracts
export { default as RDATRewardModuleABI } from './RDATRewardModule.json';
export { default as vRDATRewardModuleABI } from './vRDATRewardModule.json';
export { default as VRC14LiquidityModuleABI } from './VRC14LiquidityModule.json';

// Governance Contracts
export { default as GovernanceCoreABI } from './GovernanceCore.json';
export { default as GovernanceVotingABI } from './GovernanceVoting.json';
export { default as GovernanceExecutionABI } from './GovernanceExecution.json';

// Interfaces (for typing)
export { default as IRDATABI } from './IRDAT.json';
export { default as IvRDATABI } from './IvRDAT.json';
export { default as IStakingPositionsABI } from './IStakingPositions.json';
export { default as ITreasuryWalletABI } from './ITreasuryWallet.json';
export { default as ITokenVestingABI } from './ITokenVesting.json';
export { default as IMigrationBridgeABI } from './IMigrationBridge.json';
export { default as IRevenueCollectorABI } from './IRevenueCollector.json';
export { default as IRewardsManagerABI } from './IRewardsManager.json';
export { default as IProofOfContributionABI } from './IProofOfContribution.json';
export { default as IEmergencyPauseABI } from './IEmergencyPause.json';

// Contract addresses (update after deployment)
export const CONTRACT_ADDRESSES = {
  // Vana Mainnet (Chain ID: 1480)
  vana: {
    RDAT: '',
    vRDAT: '',
    StakingPositions: '',
    TreasuryWallet: '',
    TokenVesting: '',
    VanaMigrationBridge: '',
    RevenueCollector: '',
    RewardsManager: '',
    EmergencyPause: '',
  },
  // Base Mainnet (Chain ID: 8453)
  base: {
    BaseMigrationBridge: '',
    V1Token: '', // Existing V1 token address
  },
  // Vana Moksha Testnet (Chain ID: 14800) - DEPLOYED
  vanaMoksha: {
    RDAT: '0xC1aC75130533c7F93BDa67f6645De65C9DEE9a3A',
    vRDAT: '0x386f44505DB03a387dF1402884d5326247DCaaC8',
    StakingPositions: '0x3f2236ef5360BEDD999378672A145538f701E662',
    TreasuryWallet: '0x31C3e3F091FB2A25d4dac82474e7dc709adE754a',
    TokenVesting: '0xdCa8b322c11515A3B5e6e806170b573bDe179328',
    VanaMigrationBridge: '0xEb0c43d5987de0672A22e350930F615Af646e28c',
    EmergencyPause: '0x254A9344AAb674530D47B6F2dDd8e328A17Da860',
    RevenueCollector: '0x31C3e3F091FB2A25d4dac82474e7dc709adE754a',
    RewardsManager: '',
    Create2Factory: '',
    RDATDataDAO: '0x254A9344AAb674530D47B6F2dDd8e328A17Da860',
    SimpleVanaDLP: '0xC1aC75130533c7F93BDa67f6645De65C9DEE9a3A',
  },
  // Base Sepolia (Chain ID: 84532)
  baseSepolia: {
    BaseMigrationBridge: '',
    V1TokenMock: '',
  }
};

// Helper function to get addresses by chain ID
export function getAddresses(chainId: number) {
  switch (chainId) {
    case 1480:
      return CONTRACT_ADDRESSES.vana;
    case 8453:
      return CONTRACT_ADDRESSES.base;
    case 14800:
      return CONTRACT_ADDRESSES.vanaMoksha;
    case 84532:
      return CONTRACT_ADDRESSES.baseSepolia;
    default:
      throw new Error(`Unsupported chain ID: ${chainId}`);
  }
}
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
    "index.ts"
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
    "smart-contracts"
  ],
  "author": "r/datadao",
  "license": "MIT"
}
EOF

echo -e "${GREEN}✓ Created package.json${NC}"

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
echo -e "${YELLOW}Frontend Integration:${NC}"
echo "1. Copy the ${GREEN}abi/${NC} folder to your frontend project"
echo "2. Import ABIs: ${GREEN}import { RDATUpgradeableABI } from './abi'${NC}"
echo "3. Use with ethers/viem/wagmi for contract interaction"
echo ""
echo -e "${YELLOW}For wagmi v2 integration:${NC}"
echo "1. Install: ${GREEN}npm install wagmi viem@2.x${NC}"
echo "2. Import: ${GREEN}import { CONTRACT_ADDRESSES, RDATUpgradeableABI } from './abi'${NC}"
echo "3. Use with wagmi hooks for React integration"
echo ""
echo -e "${YELLOW}Example usage:${NC}"
cat << 'EXAMPLE'
// With viem
import { createPublicClient, http } from 'viem';
import { vana } from 'viem/chains';
import { RDATUpgradeableABI, CONTRACT_ADDRESSES } from './abi';

const client = createPublicClient({
  chain: vana,
  transport: http()
});

const balance = await client.readContract({
  address: CONTRACT_ADDRESSES.vana.RDAT,
  abi: RDATUpgradeableABI,
  functionName: 'balanceOf',
  args: [userAddress]
});
EXAMPLE