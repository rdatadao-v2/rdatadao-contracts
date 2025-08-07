# ⚠️ SECURITY WARNING ⚠️

## CRITICAL: Private Key Security

**Deployer Address**: `0x58eCB94e6F5e6521228316b55c465ad2A2938FbB`  
**Private Key**: Store securely in `.env` file (NEVER commit to version control)

### Security Guidelines:

1. **NEVER commit this private key to version control**
2. **ONLY use this key for deployment purposes**
3. **Store securely in environment variables or secure key management**
4. **Fund only with necessary deployment amounts**
5. **After deployment, transfer all remaining funds**
6. **Consider this key compromised if exposed publicly**

### Recommended Setup:

```bash
# Store in .env file (which is gitignored)
echo "DEPLOYER_PRIVATE_KEY=your_private_key_here" >> .env

# Or use environment variable
export DEPLOYER_PRIVATE_KEY=your_private_key_here
```

### Post-Deployment:

1. Transfer contract ownership to Gnosis Safe multisigs
2. Remove all funds from deployer wallet
3. Consider the deployer wallet retired

### Gnosis Safe Addresses (Secure):

- **Vana/Vana Moksha**: `0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319`
- **Base/Base Sepolia**: `0x90013583c66D2bf16327cB5Bc4a647AcceCF4B9A`

These multisig addresses are the secure long-term owners of the contracts.

---

**IF THIS KEY IS COMPROMISED**: 
1. Immediately transfer any funds from the deployer wallet
2. Do not proceed with deployment
3. Generate a new deployment wallet
4. Update all documentation with new addresses