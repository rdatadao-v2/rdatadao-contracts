# Deployment Addresses

## Local Anvil Deployments

### Vana Chain (Chain ID: 1480, Port: 8546)

| Contract | Address | Description |
|----------|---------|-------------|
| **RDAT Token** | `0x95401dc811bb5740090279Ba06cfA8fcF6113778` | Main V2 token (100M supply) |
| **Treasury Wallet** | `0x1613beB3B2C4f22Ee086B2b38C1476A3cE7f78E8` | Holds 70M RDAT |
| **Vana Migration Bridge** | `0x851356ae760d987E095750cCeb3bC6014560891C` | Holds 30M RDAT for V1 migration |
| **Staking Positions** | `0x70e0bA845a1A0F2DA3359C97E0285013525FFC49` | NFT-based staking |
| **vRDAT Token** | `0x9E545E3C0baAB3E08CdfD552C960A1050f373042` | Soul-bound governance token |
| **Rewards Manager** | `0x99bbA657f2BbC93c02D617f8bA121cB8Fc104Acf` | Manages reward programs |
| **vRDAT Reward Module** | `0x0E801D84Fa97b50751Dbf25036d067dCf18858bF` | Distributes vRDAT rewards |
| **Emergency Pause** | `0x84eA74d481Ee0A5332c457a4d796187F6Ba67fEB` | Emergency pause mechanism |

### Base Chain (Chain ID: 8453, Port: 8545)

| Contract | Address | Description |
|----------|---------|-------------|
| **Base Migration Bridge** | `0x0B306BF915C4d645ff596e518fAf3F9669b97016` | Handles V1→V2 migration on Base |

## Testnet Deployments

### Vana Moksha (Chain ID: 14800)
*To be deployed*

### Base Sepolia (Chain ID: 84532)
*To be deployed*

## Mainnet Deployments

### Vana Mainnet (Chain ID: 1480)
*Not yet deployed*

### Base Mainnet (Chain ID: 8453)
*Not yet deployed*

## Key Configuration

### Admin Addresses
- **Local Testing**: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` (Anvil account #0)
- **Vana Networks**: `0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319` (Multisig)
- **Base Networks**: `0x90013583c66D2bf16327cB5Bc4a647AcceCF4B9A` (Multisig)

### Deployer Address
- **All Networks**: `0x58eCB94e6F5e6521228316b55c465ad2A2938FbB`

## Supply Distribution

| Allocation | Amount | Location | Purpose |
|------------|--------|----------|---------|
| Treasury | 70M RDAT | TreasuryWallet | DAO-managed allocations |
| Migration | 30M RDAT | VanaMigrationBridge | V1 holder migration |
| **Total** | **100M RDAT** | | Fixed supply |

## VRC-20 Compliance Status

- ✅ Fixed Supply (100M)
- ✅ Blocklisting System
- ✅ 48-hour Timelocks
- ✅ Updateable DLP Registry
- ⏳ DLP Registration (post-deployment)

## Deployment Scripts

### Deploy to Local Anvil
```bash
# Start multi-chain Anvil
./script/anvil-multichain.sh start

# Deploy to Vana (port 8546)
ADMIN_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
forge script script/DeployTestnets.s.sol \
  --rpc-url http://localhost:8546 \
  --broadcast \
  --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Deploy to Base (port 8545)
ADMIN_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
forge script script/DeployTestnets.s.sol \
  --rpc-url http://localhost:8545 \
  --broadcast \
  --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

### Verify Deployment
```bash
# Verify Vana
forge script script/VerifyDeployment.s.sol --rpc-url http://localhost:8546

# Verify Base
forge script script/VerifyDeployment.s.sol --rpc-url http://localhost:8545
```

### Deploy to Testnets
```bash
# Vana Moksha
ADMIN_ADDRESS=0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319 \
TREASURY_ADDRESS=0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319 \
forge script script/DeployTestnets.s.sol \
  --rpc-url $VANA_MOKSHA_RPC_URL \
  --broadcast \
  --verify \
  --private-key $DEPLOYER_PRIVATE_KEY

# Base Sepolia
ADMIN_ADDRESS=0x90013583c66D2bf16327cB5Bc4a647AcceCF4B9A \
forge script script/DeployTestnets.s.sol \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  --private-key $DEPLOYER_PRIVATE_KEY
```

## Post-Deployment Steps

1. **Configure DLP Registry** (when Vana provides address)
   ```solidity
   rdat.setDLPRegistry(dlpRegistryAddress);
   rdat.updateDLPRegistration(dlpId);
   ```

2. **Update Migration Bridge Addresses** (if using placeholders)
   - Update VanaMigrationBridge with actual RDAT address
   - Update BaseMigrationBridge with actual V1 token address

3. **Set Up Cross-Chain Bridge**
   - Configure validators on VanaMigrationBridge
   - Set up bridge monitoring

4. **Initialize Governance**
   - Deploy Governor contract (if needed)
   - Configure vRDAT voting power

5. **Security Verification**
   - Run security test suite
   - Verify all role assignments
   - Check emergency pause functionality