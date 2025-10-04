#!/bin/bash

# Generate Safe transaction JSON for RDAT V2 upgrade
# Usage: ./generate-upgrade-tx.sh <V2_IMPLEMENTATION_ADDRESS>

if [ -z "$1" ]; then
  echo "Error: V2 implementation address required"
  echo "Usage: ./generate-upgrade-tx.sh <V2_IMPLEMENTATION_ADDRESS>"
  exit 1
fi

V2_IMPL="$1"
RDAT_PROXY="0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E"
SAFE_ADDRESS="0xe4F7Eca807C57311e715C3Ef483e72Fa8D5bCcDF"

# Generate upgrade call data
CALL_DATA=$(cast calldata "upgradeToAndCall(address,bytes)" "$V2_IMPL" "0x")

echo "Generating Safe transaction JSON..."
echo "V2 Implementation: $V2_IMPL"
echo "Call Data: $CALL_DATA"

# Create JSON file
cat > safe-transactions/step2-upgrade-to-v2.json <<EOF
{
  "version": "1.0",
  "chainId": "1480",
  "createdAt": $(date +%s)000,
  "meta": {
    "name": "Step 2: Upgrade RDAT to V2",
    "description": "Upgrade RDAT proxy to V2 implementation with rescueBrokenBridgeFunds() function",
    "txBuilderVersion": "1.16.5",
    "createdFromSafeAddress": "$SAFE_ADDRESS",
    "createdFromOwnerAddress": "",
    "checksum": ""
  },
  "transactions": [
    {
      "to": "$RDAT_PROXY",
      "value": "0",
      "data": "$CALL_DATA",
      "contractMethod": {
        "inputs": [
          {
            "name": "newImplementation",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "data",
            "type": "bytes",
            "internalType": "bytes"
          }
        ],
        "name": "upgradeToAndCall",
        "payable": false
      },
      "contractInputsValues": {
        "newImplementation": "$V2_IMPL",
        "data": "0x"
      }
    }
  ]
}
EOF

echo ""
echo "✅ Created: safe-transactions/step2-upgrade-to-v2.json"
echo ""
echo "Next steps:"
echo "1. Load safe-transactions/step2-upgrade-to-v2.json in Safe Transaction Builder"
echo "2. Execute from multisig: $SAFE_ADDRESS"
echo "3. After confirmation, load safe-transactions/step3-rescue-30m-rdat.json"
