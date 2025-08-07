#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Array of all main contracts
contracts=(
    "src/BaseMigrationBridge.sol"
    "src/Create2Factory.sol"
    "src/EmergencyPause.sol"
    "src/examples/StakingPositionsV2Example.sol"
    "src/governance/GovernanceCore.sol"
    "src/governance/GovernanceExecution.sol"
    "src/governance/GovernanceVoting.sol"
    "src/MigrationBonusVesting.sol"
    "src/ProofOfContributionStub.sol"
    "src/RDATUpgradeable.sol"
    "src/RevenueCollector.sol"
    "src/rewards/RDATRewardModule.sol"
    "src/rewards/VRC14LiquidityModule.sol"
    "src/rewards/vRDATRewardModule.sol"
    "src/RewardsManager.sol"
    "src/StakingPositions.sol"
    "src/TokenVesting.sol"
    "src/TreasuryWallet.sol"
    "src/VanaMigrationBridge.sol"
    "src/vRDAT.sol"
)

echo "Building contracts individually to identify warnings..."
echo "=================================================="

# Clean build artifacts first
forge clean

# Track contracts with warnings
contracts_with_warnings=()

for contract in "${contracts[@]}"; do
    echo -e "\n${YELLOW}Building: $contract${NC}"
    echo "-------------------------------------------"
    
    # Build the specific contract and capture output
    output=$(forge build --contracts "$contract" 2>&1)
    
    # Check if build was successful
    if echo "$output" | grep -q "Compiler run successful"; then
        # Check for warnings
        if echo "$output" | grep -q "Warning:"; then
            echo -e "${YELLOW}⚠️  Warnings found${NC}"
            echo "$output" | grep -A 5 "Warning:"
            contracts_with_warnings+=("$contract")
        else
            echo -e "${GREEN}✓ No warnings${NC}"
        fi
    else
        echo -e "${RED}✗ Build failed${NC}"
        echo "$output"
    fi
done

echo -e "\n=================================================="
echo "Summary:"
echo "--------"

if [ ${#contracts_with_warnings[@]} -eq 0 ]; then
    echo -e "${GREEN}All contracts build without warnings!${NC}"
else
    echo -e "${YELLOW}Contracts with warnings (${#contracts_with_warnings[@]}):${NC}"
    for contract in "${contracts_with_warnings[@]}"; do
        echo "  - $contract"
    done
fi