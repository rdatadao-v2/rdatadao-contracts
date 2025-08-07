#!/bin/bash

# Test Cross-Chain Migration Flow
# This script tests the migration from Base to Vana using local testnets

set -e

echo "========================================"
echo "Testing Cross-Chain Migration Flow"
echo "========================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
BASE_RPC="http://localhost:8545"
VANA_RPC="http://localhost:8546"
DEPLOYER="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
USER="0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
USER_PRIVATE_KEY="0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --base-rpc)
            BASE_RPC="$2"
            shift 2
            ;;
        --vana-rpc)
            VANA_RPC="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --base-rpc URL     Base chain RPC URL (default: http://localhost:8545)"
            echo "  --vana-rpc URL     Vana chain RPC URL (default: http://localhost:8546)"
            echo "  --help             Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "Configuration:"
echo "  Base RPC: $BASE_RPC"
echo "  Vana RPC: $VANA_RPC"
echo ""

# Step 1: Deploy contracts if not already deployed
echo -e "${YELLOW}Step 1: Checking contract deployments...${NC}"

# Check if contracts exist on Base
BASE_V1_TOKEN=$(cast call --rpc-url $BASE_RPC $DEPLOYER "nonce()" 2>/dev/null | xargs -I {} cast compute-address $DEPLOYER --nonce {})
echo "  Expected V1 token on Base: $BASE_V1_TOKEN"

# Check if contracts exist on Vana
VANA_V2_TOKEN=$(cast call --rpc-url $VANA_RPC $DEPLOYER "nonce()" 2>/dev/null | xargs -I {} cast compute-address $DEPLOYER --nonce {})
echo "  Expected V2 token on Vana: $VANA_V2_TOKEN"

# Step 2: Deploy mock V1 token on Base
echo -e "${YELLOW}Step 2: Deploying mock V1 token on Base...${NC}"

# Deploy a simple ERC20 for testing
V1_TOKEN=$(forge create --rpc-url $BASE_RPC \
    --private-key $PRIVATE_KEY \
    src/mocks/MockERC20.sol:MockERC20 \
    --constructor-args "OldRDAT" "RDAT_V1" 18 \
    2>/dev/null | grep "Deployed to:" | awk '{print $3}')

if [ -z "$V1_TOKEN" ]; then
    echo -e "${RED}Failed to deploy V1 token${NC}"
    exit 1
fi

echo -e "${GREEN}  V1 Token deployed at: $V1_TOKEN${NC}"

# Mint some V1 tokens to user
echo "  Minting 1000 V1 tokens to user..."
cast send --rpc-url $BASE_RPC \
    --private-key $PRIVATE_KEY \
    $V1_TOKEN \
    "mint(address,uint256)" \
    $USER \
    1000000000000000000000 > /dev/null

# Step 3: Deploy migration bridges
echo -e "${YELLOW}Step 3: Deploying migration bridges...${NC}"

# Deploy BaseMigrationBridge
BASE_BRIDGE=$(forge create --rpc-url $BASE_RPC \
    --private-key $PRIVATE_KEY \
    src/BaseMigrationBridge.sol:BaseMigrationBridge \
    --constructor-args $V1_TOKEN $DEPLOYER \
    2>/dev/null | grep "Deployed to:" | awk '{print $3}')

if [ -z "$BASE_BRIDGE" ]; then
    echo -e "${RED}Failed to deploy Base bridge${NC}"
    exit 1
fi

echo -e "${GREEN}  Base Bridge deployed at: $BASE_BRIDGE${NC}"

# Deploy V2 contracts on Vana (simplified for testing)
echo "  Deploying V2 system on Vana..."

# Deploy RDATUpgradeable implementation
RDAT_IMPL=$(forge create --rpc-url $VANA_RPC \
    --private-key $PRIVATE_KEY \
    src/RDATUpgradeable.sol:RDATUpgradeable \
    2>/dev/null | grep "Deployed to:" | awk '{print $3}')

# Deploy proxy and initialize
INIT_DATA=$(cast abi-encode "initialize(address,address,address)" $DEPLOYER $DEPLOYER $BASE_BRIDGE)
V2_TOKEN=$(forge create --rpc-url $VANA_RPC \
    --private-key $PRIVATE_KEY \
    lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy \
    --constructor-args $RDAT_IMPL $INIT_DATA \
    2>/dev/null | grep "Deployed to:" | awk '{print $3}')

echo -e "${GREEN}  V2 Token deployed at: $V2_TOKEN${NC}"

# Deploy VanaMigrationBridge
VANA_BRIDGE=$(forge create --rpc-url $VANA_RPC \
    --private-key $PRIVATE_KEY \
    src/VanaMigrationBridge.sol:VanaMigrationBridge \
    --constructor-args $V2_TOKEN $DEPLOYER \
    2>/dev/null | grep "Deployed to:" | awk '{print $3}')

echo -e "${GREEN}  Vana Bridge deployed at: $VANA_BRIDGE${NC}"

# Step 4: Configure bridges
echo -e "${YELLOW}Step 4: Configuring bridges...${NC}"

# Set target bridge on Base
cast send --rpc-url $BASE_RPC \
    --private-key $PRIVATE_KEY \
    $BASE_BRIDGE \
    "setTargetBridge(address)" \
    $VANA_BRIDGE > /dev/null

# Add validators on Vana bridge
VALIDATOR1="0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"
VALIDATOR2="0x90F79bf6EB2c4f870365E785982E1f101E93b906"
VALIDATOR3="0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65"

for VALIDATOR in $VALIDATOR1 $VALIDATOR2 $VALIDATOR3; do
    cast send --rpc-url $VANA_RPC \
        --private-key $PRIVATE_KEY \
        $VANA_BRIDGE \
        "addValidator(address)" \
        $VALIDATOR > /dev/null
done

echo -e "${GREEN}  Bridges configured successfully${NC}"

# Step 5: Test migration flow
echo -e "${YELLOW}Step 5: Testing migration flow...${NC}"

# Check initial balances
echo "  Initial balances:"
V1_BALANCE=$(cast call --rpc-url $BASE_RPC $V1_TOKEN "balanceOf(address)" $USER | xargs -I {} cast to-dec {})
echo "    User V1 balance: $(echo "scale=2; $V1_BALANCE / 1000000000000000000" | bc) RDAT_V1"

V2_BALANCE=$(cast call --rpc-url $VANA_RPC $V2_TOKEN "balanceOf(address)" $USER | xargs -I {} cast to-dec {})
echo "    User V2 balance: $(echo "scale=2; $V2_BALANCE / 1000000000000000000" | bc) RDAT"

# Approve and initiate migration
AMOUNT="100000000000000000000" # 100 tokens
echo "  Migrating 100 tokens..."

# Approve
cast send --rpc-url $BASE_RPC \
    --private-key $USER_PRIVATE_KEY \
    $V1_TOKEN \
    "approve(address,uint256)" \
    $BASE_BRIDGE \
    $AMOUNT > /dev/null

# Initiate migration
TX_HASH=$(cast send --rpc-url $BASE_RPC \
    --private-key $USER_PRIVATE_KEY \
    $BASE_BRIDGE \
    "initiateMigration(uint256)" \
    $AMOUNT \
    2>/dev/null | grep "transactionHash" | awk '{print $2}')

echo "  Migration initiated: $TX_HASH"

# Get migration request ID from events
REQUEST_ID=$(cast logs --rpc-url $BASE_RPC \
    --from-block latest \
    --address $BASE_BRIDGE \
    "MigrationInitiated(bytes32,address,uint256,uint256)" \
    | grep "data:" | head -1 | awk '{print $2}')

echo "  Request ID: $REQUEST_ID"

# Simulate validator signatures (for testing)
echo "  Simulating validator consensus..."

# In production, validators would observe the Base chain and sign
# For testing, we simulate the process

# Execute migration on Vana (validators would normally do this)
echo "  Executing migration on Vana..."

# Create migration data
MIGRATION_DATA=$(cast abi-encode "f(bytes32,address,uint256,uint256,address[])" \
    $REQUEST_ID \
    $USER \
    $AMOUNT \
    1 \
    "[$VALIDATOR1,$VALIDATOR2,$VALIDATOR3]")

# Execute (simplified for testing - normally requires validator signatures)
cast send --rpc-url $VANA_RPC \
    --private-key $PRIVATE_KEY \
    $VANA_BRIDGE \
    "executeMigration(bytes32)" \
    $REQUEST_ID > /dev/null 2>&1 || true

# Step 6: Verify migration
echo -e "${YELLOW}Step 6: Verifying migration...${NC}"

# Check final balances
V1_BALANCE_AFTER=$(cast call --rpc-url $BASE_RPC $V1_TOKEN "balanceOf(address)" $USER | xargs -I {} cast to-dec {})
V2_BALANCE_AFTER=$(cast call --rpc-url $VANA_RPC $V2_TOKEN "balanceOf(address)" $USER | xargs -I {} cast to-dec {})

echo "  Final balances:"
echo "    User V1 balance: $(echo "scale=2; $V1_BALANCE_AFTER / 1000000000000000000" | bc) RDAT_V1"
echo "    User V2 balance: $(echo "scale=2; $V2_BALANCE_AFTER / 1000000000000000000" | bc) RDAT"

# Calculate changes
V1_CHANGE=$(echo "$V1_BALANCE - $V1_BALANCE_AFTER" | bc)
V2_CHANGE=$(echo "$V2_BALANCE_AFTER - $V2_BALANCE" | bc)

echo ""
echo "  Migration summary:"
echo "    V1 tokens burned: $(echo "scale=2; $V1_CHANGE / 1000000000000000000" | bc)"
echo "    V2 tokens minted: $(echo "scale=2; $V2_CHANGE / 1000000000000000000" | bc)"

# Verify migration success
if [ "$V1_CHANGE" -eq "$AMOUNT" ] && [ "$V2_CHANGE" -gt "0" ]; then
    echo -e "${GREEN}✅ Migration successful!${NC}"
    echo "  User successfully migrated tokens from Base to Vana"
    
    # Calculate bonus
    BONUS_RATE=$(echo "scale=4; ($V2_CHANGE - $V1_CHANGE) / $V1_CHANGE * 100" | bc)
    echo "  Bonus received: ${BONUS_RATE}%"
else
    echo -e "${RED}❌ Migration verification failed${NC}"
    echo "  Expected changes not observed"
    exit 1
fi

echo ""
echo "========================================"
echo -e "${GREEN}Cross-Chain Migration Test Complete${NC}"
echo "========================================"