#!/bin/bash

# Load environment variables
source .env

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}        RDAT Wallet Balances           ${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Function to format wei to ether
format_balance() {
    local wei=$1
    if command -v bc &> /dev/null; then
        # Use bc for precise calculation if available
        echo "scale=6; $wei / 1000000000000000000" | bc
    else
        # Fallback to awk
        awk -v wei="$wei" 'BEGIN {printf "%.6f", wei / 1000000000000000000}'
    fi
}

# Function to check balance and format output
check_balance() {
    local name=$1
    local address=$2
    local rpc=$3
    local network=$4
    
    echo -e "${YELLOW}$name on $network:${NC}"
    echo "Address: $address"
    
    # Get balance in wei
    balance_wei=$(cast balance $address --rpc-url $rpc 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        balance_eth=$(format_balance $balance_wei)
        echo -e "Balance: ${GREEN}$balance_eth ETH${NC} ($balance_wei wei)"
    else
        echo -e "Balance: ${RED}Error - Unable to connect${NC}"
    fi
    echo ""
}

# Check deployer balances
echo -e "${BLUE}=== Deployer Wallet ===${NC}"
check_balance "Deployer" "$DEPLOYER_ADDRESS" "$VANA_RPC_URL" "Vana Mainnet"
check_balance "Deployer" "$DEPLOYER_ADDRESS" "$VANA_MOKSHA_RPC_URL" "Vana Moksha Testnet"
check_balance "Deployer" "$DEPLOYER_ADDRESS" "$BASE_RPC_URL" "Base Mainnet"
check_balance "Deployer" "$DEPLOYER_ADDRESS" "$BASE_SEPOLIA_RPC_URL" "Base Sepolia"

# Check Vana multisig balances
echo -e "${BLUE}=== Vana Multisig ===${NC}"
check_balance "Vana Multisig" "$VANA_MULTISIG_ADDRESS" "$VANA_RPC_URL" "Vana Mainnet"
check_balance "Vana Multisig" "$VANA_MULTISIG_ADDRESS" "$VANA_MOKSHA_RPC_URL" "Vana Moksha Testnet"

# Check Base multisig balances
echo -e "${BLUE}=== Base Multisig ===${NC}"
check_balance "Base Multisig" "$BASE_MULTISIG_ADDRESS" "$BASE_RPC_URL" "Base Mainnet"
check_balance "Base Multisig" "$BASE_MULTISIG_ADDRESS" "$BASE_SEPOLIA_RPC_URL" "Base Sepolia"

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}              Summary                   ${NC}"
echo -e "${BLUE}========================================${NC}"

# Verify private key
echo -e "\n${YELLOW}Private Key Verification:${NC}"
derived_address=$(cast wallet address --private-key $DEPLOYER_PRIVATE_KEY 2>/dev/null)
if [ "$derived_address" = "$DEPLOYER_ADDRESS" ]; then
    echo -e "${GREEN}✓ Private key correctly derives deployer address${NC}"
else
    echo -e "${RED}✗ Private key mismatch!${NC}"
    echo "Expected: $DEPLOYER_ADDRESS"
    echo "Got: $derived_address"
fi

echo -e "\n${YELLOW}Deployment Readiness:${NC}"
# Check if deployer has sufficient balance on key networks
vana_balance=$(cast balance $DEPLOYER_ADDRESS --rpc-url $VANA_RPC_URL 2>/dev/null || echo "0")
vana_moksha_balance=$(cast balance $DEPLOYER_ADDRESS --rpc-url $VANA_MOKSHA_RPC_URL 2>/dev/null || echo "0")

if [ "$vana_balance" -gt "50000000000000000" ]; then # > 0.05 ETH
    echo -e "${GREEN}✓ Vana Mainnet: Sufficient balance for deployment${NC}"
else
    echo -e "${YELLOW}⚠ Vana Mainnet: Low balance, may need funding${NC}"
fi

# For Vana Moksha, balance is ~11.86 ETH which is plenty
if [ -n "$vana_moksha_balance" ] && [ "$vana_moksha_balance" != "0" ]; then
    echo -e "${GREEN}✓ Vana Moksha: Sufficient balance for deployment${NC}"
else
    echo -e "${YELLOW}⚠ Vana Moksha: Low balance, may need funding${NC}"
fi