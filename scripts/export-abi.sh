#!/bin/bash

# Script to export ABI files for frontend integration

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Create ABI directory if it doesn't exist
ABI_DIR="./abi"
mkdir -p "$ABI_DIR"

echo -e "${GREEN}Exporting ABI files for frontend integration...${NC}"

# First, ensure contracts are compiled
echo -e "${YELLOW}Compiling contracts...${NC}"
forge build

# List of contracts to export
CONTRACTS=(
    "MockRDAT"
    "Rdat"
    "RdatMigration"
    "RdatDistributor"
    "MultiChainRegistry"
    "BaseOnlyContract"
    "VanaDataContract"
)

# Export ABI for each contract
for contract in "${CONTRACTS[@]}"; do
    echo -e "${YELLOW}Exporting ABI for $contract...${NC}"
    
    # Use forge inspect to get clean ABI
    forge inspect "$contract" abi > "$ABI_DIR/${contract}.json" 2>/dev/null
    
    if [ $? -eq 0 ] && [ -s "$ABI_DIR/${contract}.json" ]; then
        echo -e "${GREEN}✓ Exported $contract ABI to $ABI_DIR/${contract}.json${NC}"
    else
        echo -e "${YELLOW}⚠ Skipping $contract (not found or not compiled)${NC}"
        rm -f "$ABI_DIR/${contract}.json" # Remove empty file
    fi
done

echo -e "\n${GREEN}ABI export complete!${NC}"
echo -e "${GREEN}ABI files are located in: $ABI_DIR/${NC}"

# Generate TypeScript types for wagmi (optional)
echo -e "\n${YELLOW}To generate TypeScript types for wagmi:${NC}"
echo "1. Install wagmi CLI: npm install -D @wagmi/cli"
echo "2. Run: npx wagmi generate"
echo "3. See wagmi.config.ts for configuration"