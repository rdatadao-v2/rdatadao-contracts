# Admin Action Required: Update RDAT Contract with DLP Registration

## Overview
The DLP has been successfully registered with Vana (ID: 155), but the RDAT token contract needs to be updated with this information. This requires admin privileges.

## Required Actions

The admin/multisig (`0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319`) needs to execute two transactions:

### Transaction 1: Set DLP Registry
```solidity
// Contract: 0xC1aC75130533c7F93BDa67f6645De65C9DEE9a3A (RDAT Token)
// Function: setDLPRegistry(address _dlpRegistry)
// Parameter: 0x4D59880a924526d1dD33260552Ff4328b1E18a43

rdatToken.setDLPRegistry(0x4D59880a924526d1dD33260552Ff4328b1E18a43)
```

### Transaction 2: Update DLP Registration
```solidity
// Contract: 0xC1aC75130533c7F93BDa67f6645De65C9DEE9a3A (RDAT Token)
// Function: updateDLPRegistration(uint256 _dlpId)
// Parameter: 155

rdatToken.updateDLPRegistration(155)
```

## Using Gnosis Safe

If using Gnosis Safe interface:

1. **New Transaction** → **Contract Interaction**
2. **Contract Address**: `0xC1aC75130533c7F93BDa67f6645De65C9DEE9a3A`
3. **ABI**: Upload the RDATUpgradeable ABI or use the following:

### For setDLPRegistry:
```json
{
  "inputs": [{"name": "_dlpRegistry", "type": "address"}],
  "name": "setDLPRegistry",
  "outputs": [],
  "stateMutability": "nonpayable",
  "type": "function"
}
```
**Value**: `0x4D59880a924526d1dD33260552Ff4328b1E18a43`

### For updateDLPRegistration:
```json
{
  "inputs": [{"name": "_dlpId", "type": "uint256"}],
  "name": "updateDLPRegistration",
  "outputs": [],
  "stateMutability": "nonpayable",
  "type": "function"
}
```
**Value**: `155`

## Alternative: Script Execution

If the admin can provide a signature or execute via script:

```bash
# Set environment variables
export ADMIN_PRIVATE_KEY=<admin_private_key_or_ledger>
export RDAT_DATA_DAO_ADDRESS=0x32B481b52616044E5c937CF6D20204564AD62164
export RDAT_TOKEN_ADDRESS=0xC1aC75130533c7F93BDa67f6645De65C9DEE9a3A

# Run the update function
forge script script/RegisterDLP.s.sol:RegisterDLP \
  --rpc-url https://rpc.moksha.vana.org \
  --sig "updateRDATContract()" \
  --broadcast \
  --sender 0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319 \
  --private-key $ADMIN_PRIVATE_KEY
```

## Verification

After execution, verify the updates:

```bash
# Check DLP Registry is set
cast call 0xC1aC75130533c7F93BDa67f6645De65C9DEE9a3A "dlpRegistry()" --rpc-url https://rpc.moksha.vana.org

# Check DLP ID is set
cast call 0xC1aC75130533c7F93BDa67f6645De65C9DEE9a3A "dlpId()" --rpc-url https://rpc.moksha.vana.org

# Check registration status
cast call 0xC1aC75130533c7F93BDa67f6645De65C9DEE9a3A "dlpRegistered()" --rpc-url https://rpc.moksha.vana.org
```

Expected results:
- dlpRegistry: `0x4D59880a924526d1dD33260552Ff4328b1E18a43`
- dlpId: `155`
- dlpRegistered: `true`

## Why This Is Important

Updating the RDAT contract with the DLP registration:
1. Links the token to the registered Data Liquidity Pool
2. Enables data contribution rewards to be distributed in RDAT
3. Allows the DLP to interact with the token for reward mechanisms
4. Completes the integration with Vana's ecosystem

## Timeline

Please execute these transactions as soon as possible to complete the DLP integration.

## Support

If you need assistance with the multisig execution or have questions, the deployer can help prepare the transactions but cannot execute them directly due to role restrictions.