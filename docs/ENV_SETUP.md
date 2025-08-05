# 🔐 Environment Setup Guide

## Setting Up Your Private Keys

### 1. Create your `.env` file

Copy the example file and update with your actual values:

```bash
cp .env.example .env
```

### 2. Update the `.env` file

Edit the `.env` file and replace the placeholder with your actual private key:

```bash
# Replace this line:
DEPLOYER_PRIVATE_KEY=0x0000000000000000000000000000000000000000000000000000000000000000

# With your actual private key:
DEPLOYER_PRIVATE_KEY=your_actual_private_key_here
```

### 3. Verify `.env` is gitignored

```bash
# This should show .env is ignored
git status --ignored | grep .env
```

### 4. Set proper file permissions

```bash
# Restrict access to your .env file
chmod 600 .env
```

## Security Best Practices

1. **NEVER commit `.env` to version control**
2. **Use different keys for testnet and mainnet**
3. **Only fund deployer wallet with necessary amounts**
4. **Transfer ownership to multisig immediately after deployment**
5. **Consider using hardware wallets for mainnet deployments**

## Alternative: Environment Variables

Instead of using a `.env` file, you can export environment variables:

```bash
export DEPLOYER_PRIVATE_KEY=your_private_key_here
export VANA_RPC_URL=https://rpc.vana.org
# ... other variables
```

## Deployment Commands

The deployment scripts will automatically look for `DEPLOYER_PRIVATE_KEY`:

```bash
# Testnet deployment
forge script script/DeployV2Beta.s.sol \
  --rpc-url $VANA_MOKSHA_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --broadcast

# Mainnet deployment  
forge script script/DeployV2Beta.s.sol \
  --rpc-url $VANA_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --broadcast \
  --verify
```

## Troubleshooting

If you get "missing private key" errors:
1. Ensure `.env` file exists and contains `DEPLOYER_PRIVATE_KEY`
2. Check that you've sourced the `.env` file: `source .env`
3. Verify the key format (should start with 0x)
4. Ensure no extra spaces or quotes in the `.env` file