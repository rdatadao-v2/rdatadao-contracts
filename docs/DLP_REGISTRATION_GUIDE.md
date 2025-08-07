# DLP Registration Guide for r/datadao

## Overview

This guide explains how to register r/datadao as a Data Liquidity Pool (DLP) on the Vana network. DLP registration is required for:
- Participating in Vana's data economy
- Enabling Proof of Contribution rewards
- Integration with Vana's DLP ecosystem

## Prerequisites

1. **Deployed RDAT Token**: The RDATUpgradeable contract must be deployed
2. **1 VANA**: Registration fee (plus ~0.1 VANA for gas)
3. **Admin Access**: Account with DEFAULT_ADMIN_ROLE on RDAT contract
4. **Network Access**: Connection to Vana Mainnet or Moksha Testnet

## Registration Methods

### Method 1: Using Registration Script (Recommended)

#### Step 1: Configure Environment

Create or update `.env` file:
```bash
# Required variables
RDAT_TOKEN_ADDRESS=0x... # Your deployed RDAT token
TREASURY_ADDRESS=0x...    # Treasury multisig
ADMIN_ADDRESS=0x...        # Admin multisig
DEPLOYER_PRIVATE_KEY=0x... # Private key with 1+ VANA

# Network URLs
VANA_RPC_URL=https://rpc.vana.org
VANA_MOKSHA_RPC_URL=https://rpc.moksha.vana.org
```

#### Step 2: Check Registration Status

```bash
# Check if already registered
./script/register-dlp.sh check
```

#### Step 3: Register on Testnet First

```bash
# Register on Moksha testnet
./script/register-dlp.sh testnet
```

#### Step 4: Register on Mainnet

```bash
# Register on Vana mainnet
./script/register-dlp.sh mainnet
```

### Method 2: Using Forge Script Directly

```bash
# Set environment variables
export RDAT_TOKEN_ADDRESS=0x...
export TREASURY_ADDRESS=0x...
export ADMIN_ADDRESS=0x...

# Run registration
forge script script/RegisterDLP.s.sol:RegisterDLP \
  --rpc-url https://rpc.vana.org \
  --broadcast \
  --private-key $DEPLOYER_PRIVATE_KEY \
  -vvvv
```

### Method 3: Manual Registration via Vanascan

1. Go to [DLPRegistryProxy on Vanascan](https://vanascan.io/address/0x4D59880a924526d1dD33260552Ff4328b1E18a43?tab=write_proxy)
2. Connect your wallet (must have 1+ VANA)
3. Find `registerDlp` function
4. Fill in parameters:
   - `dlpAddress`: Your RDAT token address
   - `ownerAddress`: Admin multisig address
   - `treasuryAddress`: Treasury multisig address
   - `name`: "r/datadao"
   - `iconUrl`: "https://rdatadao.org/logo.png"
   - `website`: "https://rdatadao.org"
   - `metadata`: JSON description
5. Send 1 VANA with the transaction
6. Confirm and wait for transaction

## Contract Addresses

### DLP Registry Addresses
- **Vana Mainnet**: `0x4D59880a924526d1dD33260552Ff4328b1E18a43`
- **Vana Moksha**: `0x4D59880a924526d1dD33260552Ff4328b1E18a43`

### Registration Parameters
```json
{
  "name": "r/datadao",
  "iconUrl": "https://rdatadao.org/logo.png",
  "website": "https://rdatadao.org",
  "metadata": {
    "description": "Reddit Data DAO - Empowering Reddit users to own and monetize their data",
    "type": "SocialMedia",
    "dataSource": "Reddit",
    "version": "2.0"
  }
}
```

## Post-Registration Steps

### 1. Verify Registration

```bash
# Check DLP ID
cast call 0x4D59880a924526d1dD33260552Ff4328b1E18a43 \
  "dlpIds(address)(uint256)" \
  $RDAT_TOKEN_ADDRESS \
  --rpc-url https://rpc.vana.org
```

### 2. Update RDAT Contract

The registration script automatically updates the RDAT contract, but you can verify:

```solidity
// Check DLP info in RDAT contract
(address registry, bool registered, uint256 dlpId, uint256 block) = rdat.getDLPInfo();
```

### 3. Document DLP ID

Save your DLP ID in project documentation:
- Update README with DLP ID
- Add to deployment documentation
- Include in frontend configuration

## Architecture

```
┌──────────────────────────────────────┐
│        Vana DLP Registry             │
│   (0x4D59880a924526d1dD3326...)      │
└────────────┬─────────────────────────┘
             │ registerDlp()
             │ (1 VANA fee)
             ▼
┌──────────────────────────────────────┐
│         r/datadao DLP                │
│     (RDAT Token Contract)            │
├──────────────────────────────────────┤
│ DLP ID: [Assigned by Registry]       │
│ Owner: Admin Multisig                │
│ Treasury: Treasury Multisig          │
│ Status: Active                       │
└──────────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────┐
│    RDAT Contract State Updates       │
├──────────────────────────────────────┤
│ dlpRegistry: 0x4D5988...             │
│ dlpRegistered: true                  │
│ dlpId: [Your DLP ID]                 │
│ dlpRegistrationBlock: [Block #]      │
└──────────────────────────────────────┘
```

## Troubleshooting

### Issue: "Insufficient VANA for registration fee"
**Solution**: Ensure deployer has at least 1.1 VANA (1 for fee + gas)

### Issue: "DLP already registered"
**Solution**: Check existing registration with `dlpIds()` method

### Issue: "Invalid DLP address"
**Solution**: Ensure RDAT token is deployed and address is correct

### Issue: Transaction fails
**Solutions**:
1. Check network connection
2. Verify account has DEFAULT_ADMIN_ROLE
3. Ensure gas price is sufficient
4. Check if name is already taken

## Security Considerations

1. **Private Key Security**: Never commit private keys to git
2. **Multisig Control**: Use multisig for admin/treasury addresses
3. **Verification**: Always verify registration on Vanascan
4. **Test First**: Register on testnet before mainnet

## Costs

- **Registration Fee**: 1 VANA (one-time)
- **Gas Fees**: ~0.05-0.1 VANA
- **Total Required**: ~1.1 VANA

## FAQ

### Q: Can we change DLP details after registration?
A: Yes, the owner can update certain fields through the registry contract.

### Q: What happens to the 1 VANA fee?
A: It's held by the DLP Registry as a stake/deposit.

### Q: Can we register multiple DLPs?
A: Yes, but each requires a unique address and 1 VANA fee.

### Q: Is registration required for mainnet?
A: Yes, DLP registration is required for Vana ecosystem participation.

## Support

- [Vana Documentation](https://docs.vana.org)
- [DLP Registry Contract](https://vanascan.io/address/0x4D59880a924526d1dD33260552Ff4328b1E18a43)
- [r/datadao Discord](https://discord.gg/rdatadao)

---

**Last Updated**: August 7, 2024
**Version**: 1.0
**Status**: Ready for Registration