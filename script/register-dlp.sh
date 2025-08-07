#!/bin/bash

# r/datadao DLP Registration Script
# Registers the r/datadao token as a Data Liquidity Pool on Vana

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 r/datadao DLP Registration Script${NC}"
echo "======================================"

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${RED}Error: .env file not found${NC}"
    echo "Please create a .env file with the following variables:"
    echo "  RDAT_TOKEN_ADDRESS=<deployed RDAT token address>"
    echo "  TREASURY_ADDRESS=<treasury multisig address>"
    echo "  ADMIN_ADDRESS=<admin multisig address>"
    echo "  DEPLOYER_PRIVATE_KEY=<private key with 1+ VANA for registration>"
    echo "  VANA_RPC_URL=<Vana RPC URL>"
    exit 1
fi

# Load environment variables
source .env

# Validate required environment variables
if [ -z "$RDAT_TOKEN_ADDRESS" ]; then
    echo -e "${RED}Error: RDAT_TOKEN_ADDRESS not set in .env${NC}"
    exit 1
fi

if [ -z "$TREASURY_ADDRESS" ]; then
    echo -e "${RED}Error: TREASURY_ADDRESS not set in .env${NC}"
    exit 1
fi

if [ -z "$ADMIN_ADDRESS" ]; then
    echo -e "${RED}Error: ADMIN_ADDRESS not set in .env${NC}"
    exit 1
fi

if [ -z "$DEPLOYER_PRIVATE_KEY" ]; then
    echo -e "${RED}Error: DEPLOYER_PRIVATE_KEY not set in .env${NC}"
    exit 1
fi

# Determine network based on RPC URL
if [[ "$1" == "mainnet" ]] || [[ "$VANA_RPC_URL" == *"rpc.vana.org"* ]]; then
    NETWORK="mainnet"
    RPC_URL="${VANA_RPC_URL:-https://rpc.vana.org}"
    CHAIN_ID=1480
    echo -e "${YELLOW}Network: Vana Mainnet${NC}"
elif [[ "$1" == "testnet" ]] || [[ "$VANA_RPC_URL" == *"moksha"* ]]; then
    NETWORK="testnet"
    RPC_URL="${VANA_MOKSHA_RPC_URL:-https://rpc.moksha.vana.org}"
    CHAIN_ID=14800
    echo -e "${YELLOW}Network: Vana Moksha Testnet${NC}"
else
    echo -e "${YELLOW}Usage: ./register-dlp.sh [mainnet|testnet|check]${NC}"
    echo ""
    echo "Commands:"
    echo "  mainnet  - Register on Vana Mainnet"
    echo "  testnet  - Register on Vana Moksha Testnet"
    echo "  check    - Check registration status only"
    exit 1
fi

echo "RPC URL: $RPC_URL"
echo ""

# Check if we're just checking status
if [[ "$2" == "check" ]] || [[ "$1" == "check" ]]; then
    echo -e "${YELLOW}Checking DLP registration status...${NC}"
    forge script script/RegisterDLP.s.sol:RegisterDLP \
        --rpc-url $RPC_URL \
        --sig "check()" \
        -vvv
    exit 0
fi

# Display configuration
echo "Configuration:"
echo "=============="
echo "RDAT Token:    $RDAT_TOKEN_ADDRESS"
echo "Treasury:      $TREASURY_ADDRESS"
echo "Admin:         $ADMIN_ADDRESS"
echo "Chain ID:      $CHAIN_ID"
echo ""

# Check deployer balance
echo -e "${YELLOW}Checking deployer balance...${NC}"
DEPLOYER_ADDRESS=$(cast wallet address $DEPLOYER_PRIVATE_KEY)
BALANCE=$(cast balance $DEPLOYER_ADDRESS --rpc-url $RPC_URL)
BALANCE_ETHER=$(cast to-unit $BALANCE ether)

echo "Deployer: $DEPLOYER_ADDRESS"
echo "Balance:  $BALANCE_ETHER VANA"

# Check if balance is sufficient (need 1 VANA + gas)
MIN_BALANCE="1100000000000000000" # 1.1 VANA (1 for registration + 0.1 for gas)
if [ $(echo "$BALANCE < $MIN_BALANCE" | bc) -eq 1 ]; then
    echo -e "${RED}Error: Insufficient balance. Need at least 1.1 VANA (1 for registration + gas)${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Balance sufficient for registration ✓${NC}"
echo ""

# Confirm before proceeding
echo -e "${YELLOW}⚠️  This will:${NC}"
echo "1. Register r/datadao as a DLP on Vana"
echo "2. Pay 1 VANA registration fee"
echo "3. Update RDAT contract with DLP ID"
echo ""
read -p "Continue with registration? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Registration cancelled${NC}"
    exit 1
fi

# Run the registration script
echo ""
echo -e "${GREEN}Starting DLP registration...${NC}"
echo "======================================"

forge script script/RegisterDLP.s.sol:RegisterDLP \
    --rpc-url $RPC_URL \
    --broadcast \
    --private-key $DEPLOYER_PRIVATE_KEY \
    --slow \
    --gas-estimate-multiplier 120 \
    -vvvv

# Check if registration was successful
if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ DLP Registration Complete!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Save your DLP ID from the output above"
    echo "2. Verify registration at: https://vanascan.io/address/0x4D59880a924526d1dD33260552Ff4328b1E18a43"
    echo "3. Update documentation with DLP ID"
else
    echo ""
    echo -e "${RED}❌ Registration failed. Check the error above.${NC}"
    exit 1
fi