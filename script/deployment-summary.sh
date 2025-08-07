#!/bin/bash

# Deployment Summary Script for r/datadao contracts

echo "=========================================="
echo "       r/datadao Deployment Summary       "
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to check contract deployment
check_contract() {
    local chain_name=$1
    local rpc_url=$2
    local contract_name=$3
    local address=$4
    
    code=$(cast code $address --rpc-url $rpc_url 2>/dev/null || echo "0x")
    
    if [ "$code" != "0x" ] && [ -n "$code" ]; then
        echo -e "  ${GREEN}✓${NC} $contract_name: $address"
        return 0
    else
        echo -e "  ${RED}✗${NC} $contract_name: Not deployed"
        return 1
    fi
}

# Vana Moksha Testnet
echo "📍 Vana Moksha Testnet (Chain ID: 14800)"
echo "==========================================="
check_contract "Moksha" "https://rpc.moksha.vana.org" "RDAT Token (Proxy)" "0xEb0c43d5987de0672A22e350930F615Af646e28c"
check_contract "Moksha" "https://rpc.moksha.vana.org" "RDAT Implementation" "0xd546C45872eeA596155EAEAe9B8495f02ca4fc58"
check_contract "Moksha" "https://rpc.moksha.vana.org" "CREATE2 Factory" "0x87C5F9661E7223D9d97899B3Ba89327FCaf51EFB"
check_contract "Moksha" "https://rpc.moksha.vana.org" "TreasuryWallet" "0x31C3e3F091FB2A25d4dac82474e7dc709adE754a"
check_contract "Moksha" "https://rpc.moksha.vana.org" "StakingPositions" "0x3f2236ef5360BEDD999378672A145538f701E662"
check_contract "Moksha" "https://rpc.moksha.vana.org" "vRDAT" "0x386f44505DB03a387dF1402884d5326247DCaaC8"
check_contract "Moksha" "https://rpc.moksha.vana.org" "EmergencyPause" "0xF73c6216d7D6218d722968e170Cfff6654A8936c"
check_contract "Moksha" "https://rpc.moksha.vana.org" "RevenueCollector" "0x5588e399206880Fcd2C7Ca8dE04126854ce273cE"
echo ""

# Base Sepolia Testnet
echo "📍 Base Sepolia Testnet (Chain ID: 84532)"
echo "==========================================="
check_contract "Sepolia" "https://sepolia.base.org" "MigrationBridge" "0xb7d6f8eadfD4415cb27686959f010771FE94561b"
check_contract "Sepolia" "https://sepolia.base.org" "V1 RDAT Mock" "0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E"
echo ""

# Vana Mainnet
echo "📍 Vana Mainnet (Chain ID: 1480)"
echo "==========================================="
check_contract "Vana" "https://rpc.vana.org" "RDAT Token" "0x0000000000000000000000000000000000000000"
check_contract "Vana" "https://rpc.vana.org" "TreasuryWallet" "0x0000000000000000000000000000000000000000"
check_contract "Vana" "https://rpc.vana.org" "StakingPositions" "0x0000000000000000000000000000000000000000"
check_contract "Vana" "https://rpc.vana.org" "vRDAT" "0x0000000000000000000000000000000000000000"
echo ""

# Base Mainnet
echo "📍 Base Mainnet (Chain ID: 8453)"
echo "==========================================="
check_contract "Base" "https://mainnet.base.org" "MigrationBridge" "0x0000000000000000000000000000000000000000"
check_contract "Base" "https://mainnet.base.org" "V1 RDAT" "0x0000000000000000000000000000000000000000"
echo ""

# Deployment Status
echo "=========================================="
echo "             Status Summary                "
echo "=========================================="
echo ""
echo "🔹 Testnets:"
echo "  - Vana Moksha: Ready for deployment"
echo "  - Base Sepolia: Ready for deployment"
echo ""
echo "🔹 Mainnets:"
echo "  - Vana: Not deployed (post-audit)"
echo "  - Base: Not deployed (post-audit)"
echo ""
echo "🔹 DLP Registration:"
echo "  - Status: Implementation ready"
echo "  - Registry: 0x4D59880a924526d1dD33260552Ff4328b1E18a43"
echo "  - Fee: 1 VANA required"
echo ""
echo "=========================================="
echo "            Next Steps                    "
echo "=========================================="
echo ""
echo "1. Deploy to Vana Moksha testnet"
echo "2. Deploy to Base Sepolia testnet"
echo "3. Test cross-chain migration flow"
echo "4. Register DLP on testnets"
echo "5. Complete audit documentation"
echo ""