#!/bin/bash

# Load environment variables
source .env

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to deploy to a specific chain
deploy_to_chain() {
    local chain=$1
    local script=$2
    local profile=$3
    
    echo -e "${GREEN}Deploying $script to $chain...${NC}"
    
    forge script $script \
        --rpc-url $profile \
        --broadcast \
        --verify \
        -vvvv
}

# Check command line arguments
if [ $# -eq 0 ]; then
    echo "Usage: ./deploy.sh [base|base-sepolia|vana|vana-moksha|local-base|local-vana] [contract-name]"
    echo "Example: ./deploy.sh base-sepolia BaseOnly"
    echo "Example: ./deploy.sh local-base Counter"
    exit 1
fi

CHAIN=$1
CONTRACT=$2

case $CHAIN in
    "base")
        case $CONTRACT in
            "Counter")
                deploy_to_chain "Base Mainnet" "script/base/DeployCounter.s.sol:DeployCounterBase" "$BASE_RPC_URL"
                ;;
            "BaseOnly")
                deploy_to_chain "Base Mainnet" "script/base/DeployBaseOnly.s.sol:DeployBaseOnly" "$BASE_RPC_URL"
                ;;
            "Registry")
                deploy_to_chain "Base Mainnet" "script/shared/DeployMultiChainRegistry.s.sol:DeployMultiChainRegistry" "$BASE_RPC_URL"
                ;;
            *)
                echo -e "${RED}Unknown contract: $CONTRACT${NC}"
                exit 1
                ;;
        esac
        ;;
    "base-sepolia")
        case $CONTRACT in
            "Counter")
                deploy_to_chain "Base Sepolia" "script/base/DeployCounter.s.sol:DeployCounterBase" "$BASE_SEPOLIA_RPC_URL"
                ;;
            "BaseOnly")
                deploy_to_chain "Base Sepolia" "script/base/DeployBaseOnly.s.sol:DeployBaseOnly" "$BASE_SEPOLIA_RPC_URL"
                ;;
            "Registry")
                deploy_to_chain "Base Sepolia" "script/shared/DeployMultiChainRegistry.s.sol:DeployMultiChainRegistry" "$BASE_SEPOLIA_RPC_URL"
                ;;
            *)
                echo -e "${RED}Unknown contract: $CONTRACT${NC}"
                exit 1
                ;;
        esac
        ;;
    "vana")
        case $CONTRACT in
            "Counter")
                deploy_to_chain "Vana Mainnet" "script/vana/DeployCounter.s.sol:DeployCounterVana" "$VANA_RPC_URL"
                ;;
            "VanaData")
                deploy_to_chain "Vana Mainnet" "script/vana/DeployVanaData.s.sol:DeployVanaData" "$VANA_RPC_URL"
                ;;
            "Registry")
                deploy_to_chain "Vana Mainnet" "script/shared/DeployMultiChainRegistry.s.sol:DeployMultiChainRegistry" "$VANA_RPC_URL"
                ;;
            *)
                echo -e "${RED}Unknown contract: $CONTRACT${NC}"
                exit 1
                ;;
        esac
        ;;
    "vana-moksha")
        case $CONTRACT in
            "Counter")
                deploy_to_chain "Vana Moksha Testnet" "script/vana/DeployCounter.s.sol:DeployCounterVana" "$VANA_MOKSHA_RPC_URL"
                ;;
            "VanaData")
                deploy_to_chain "Vana Moksha Testnet" "script/vana/DeployVanaData.s.sol:DeployVanaData" "$VANA_MOKSHA_RPC_URL"
                ;;
            "Registry")
                deploy_to_chain "Vana Moksha Testnet" "script/shared/DeployMultiChainRegistry.s.sol:DeployMultiChainRegistry" "$VANA_MOKSHA_RPC_URL"
                ;;
            *)
                echo -e "${RED}Unknown contract: $CONTRACT${NC}"
                exit 1
                ;;
        esac
        ;;
    "local-base")
        case $CONTRACT in
            "Counter")
                deploy_to_chain "Local Base" "script/base/DeployCounter.s.sol:DeployCounterBase" "http://localhost:8545"
                ;;
            "BaseOnly")
                deploy_to_chain "Local Base" "script/base/DeployBaseOnly.s.sol:DeployBaseOnly" "http://localhost:8545"
                ;;
            "Registry")
                deploy_to_chain "Local Base" "script/shared/DeployMultiChainRegistry.s.sol:DeployMultiChainRegistry" "http://localhost:8545"
                ;;
            *)
                echo -e "${RED}Unknown contract: $CONTRACT${NC}"
                exit 1
                ;;
        esac
        ;;
    "local-vana")
        case $CONTRACT in
            "Counter")
                deploy_to_chain "Local Vana" "script/vana/DeployCounter.s.sol:DeployCounterVana" "http://localhost:8546"
                ;;
            "VanaData")
                deploy_to_chain "Local Vana" "script/vana/DeployVanaData.s.sol:DeployVanaData" "http://localhost:8546"
                ;;
            "Registry")
                deploy_to_chain "Local Vana" "script/shared/DeployMultiChainRegistry.s.sol:DeployMultiChainRegistry" "http://localhost:8546"
                ;;
            *)
                echo -e "${RED}Unknown contract: $CONTRACT${NC}"
                exit 1
                ;;
        esac
        ;;
    *)
        echo -e "${RED}Unknown chain: $CHAIN${NC}"
        echo "Available chains: base, base-sepolia, vana, vana-moksha, local-base, local-vana"
        exit 1
        ;;
esac