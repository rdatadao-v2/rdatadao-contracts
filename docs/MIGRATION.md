# V1 to V2 Migration Guide

**Last Updated**: September 20, 2025
**Status**: LIVE on Mainnet ✅
**Migration Pool**: 30,000,000 RDAT available

## 🔄 Migration Overview

### What is the Migration?
r/datadao is upgrading from V1 (Base network) to V2 (Vana network):
- **Token Supply**: Expanding from 30M to 100M RDAT
- **Network**: Moving from Base to Vana blockchain
- **Ratio**: 1:1 exchange (1 V1 RDAT = 1 V2 RDAT)
- **Allocation**: 30M V2 tokens reserved for V1 holders

### Why Migrate?
- Access to Vana ecosystem and DLP rewards
- Participation in enhanced tokenomics
- Future staking and governance features
- Better scalability and lower fees

## 👤 User Migration Guide

### Prerequisites
- V1 RDAT tokens in your wallet on Base
- ETH on Base for gas fees (~$5-10)
- VANA tokens on Vana for claiming gas (~$1-2)
- MetaMask or compatible Web3 wallet

### Step-by-Step Migration Process

#### Step 1: Check Your V1 Balance
```javascript
// Base Network
Network: Base Mainnet
Chain ID: 8453
RPC: https://mainnet.base.org

// V1 Token Contract
Address: 0x4498cd8Ba045E00673402353f5a4347562707e7D

// Check balance at:
https://basescan.org/token/0x4498cd8Ba045E00673402353f5a4347562707e7D
```

#### Step 2: Connect to Migration dApp
1. Visit: [migration.rdatadao.org](https://migration.rdatadao.org)
2. Connect your wallet
3. Switch to Base network
4. Verify your V1 balance displays correctly

#### Step 3: Initiate Migration on Base
1. Enter amount to migrate (or click "Max")
2. Click "Approve" transaction
3. Confirm approval in wallet
4. Click "Initiate Migration"
5. Confirm migration transaction
6. Save the migration ID shown

#### Step 4: Wait for Validator Signatures
- Takes 5-30 minutes typically
- Need 2 of 3 validators to sign
- Status updates automatically
- Email notification when ready (if registered)

#### Step 5: Claim on Vana Network
1. Switch wallet to Vana network:
```javascript
Network Name: Vana
Chain ID: 1480
RPC URL: https://rpc.vana.org
Currency: VANA
Explorer: https://vanascan.io
```
2. Click "Claim V2 Tokens"
3. Confirm transaction
4. V2 RDAT appears in wallet

#### Step 6: Add V2 Token to Wallet
```javascript
Token Address: 0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E
Symbol: RDAT
Decimals: 18
```

### Migration Status Check
```javascript
// Check if you've migrated
https://vanascan.io/address/0x9d4aB2d3fb25D414dba1d9D22200356b5984D35E#readContract
→ hasMigrated(YOUR_ADDRESS)

// Check total migrated
→ totalMigrated()

// Check remaining capacity
→ 30000000 - totalMigrated()
```

## 🛠️ Technical Migration Details

### Contract Addresses

#### Base Network (Chain 8453)
```solidity
V1_RDAT_TOKEN = 0x4498cd8Ba045E00673402353f5a4347562707e7D
BASE_MIGRATION_BRIDGE = 0xa4435b45035a483d364de83B9494BDEFA8322626
```

#### Vana Network (Chain 1480)
```solidity
V2_RDAT_TOKEN = 0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E
VANA_MIGRATION_BRIDGE = 0x9d4aB2d3fb25D414dba1d9D22200356b5984D35E
```

### Migration Flow Architecture
```
Base Network                         Vana Network
────────────                         ────────────

1. approve()
   V1 Token → Bridge

2. initiateMigration()
   Lock & Burn V1
   ↓
   Event Emitted
   ↓

Backend Service
────────────
3. Monitor Events
4. Collect Signatures
   (2 of 3 validators)

                                     5. processMigration()
                                        Verify Signatures
                                        ↓
                                        Mint V2 Tokens
                                        ↓
                                        Transfer to User
```

### Validator Signatures
```javascript
// Required validators (need 2 of 3)
const VALIDATORS = [
    "0xd36B49f2DB6aA708Ce7245e8ab2453C6DfFc9d6f", // Angela
    "0xC9Af4E56741f255743e8f4877d4cfa9971E910C2", // monkfenix.eth
    "0x08Cc5ed1bA3C95AA741f8AaEf631f716b037444b"  // Base multisig
];

// Signature format
const signature = await validator.signMessage(
    ethers.utils.solidityKeccak256(
        ["address", "uint256", "bytes32"],
        [userAddress, amount, migrationId]
    )
);
```

## 💻 Developer Integration

### JavaScript/TypeScript Integration
```typescript
import { ethers } from 'ethers';

class MigrationService {
    private baseProvider: ethers.Provider;
    private vanaProvider: ethers.Provider;
    private baseBridge: ethers.Contract;
    private vanaBridge: ethers.Contract;

    constructor() {
        // Initialize providers
        this.baseProvider = new ethers.JsonRpcProvider("https://mainnet.base.org");
        this.vanaProvider = new ethers.JsonRpcProvider("https://rpc.vana.org");

        // Initialize contracts
        this.baseBridge = new ethers.Contract(
            "0xa4435b45035a483d364de83B9494BDEFA8322626",
            BASE_BRIDGE_ABI,
            this.baseProvider
        );

        this.vanaBridge = new ethers.Contract(
            "0x9d4aB2d3fb25D414dba1d9D22200356b5984D35E",
            VANA_BRIDGE_ABI,
            this.vanaProvider
        );
    }

    async initiateMigration(signer: ethers.Signer, amount: string) {
        // Step 1: Approve V1 tokens
        const v1Token = new ethers.Contract(
            "0x4498cd8Ba045E00673402353f5a4347562707e7D",
            ERC20_ABI,
            signer
        );
        await v1Token.approve(this.baseBridge.address, ethers.parseEther(amount));

        // Step 2: Initiate migration
        const tx = await this.baseBridge.connect(signer).initiateMigration(
            ethers.parseEther(amount)
        );
        const receipt = await tx.wait();

        // Extract migration ID
        const event = receipt.logs.find(
            log => log.topics[0] === ethers.id("MigrationInitiated(address,uint256,bytes32)")
        );
        return event.topics[3]; // migration ID
    }

    async completeMigration(
        signer: ethers.Signer,
        amount: string,
        migrationId: string,
        signatures: string[]
    ) {
        return await this.vanaBridge.connect(signer).processMigration(
            await signer.getAddress(),
            ethers.parseEther(amount),
            migrationId,
            signatures
        );
    }

    async checkMigrationStatus(userAddress: string) {
        const hasMigrated = await this.vanaBridge.hasMigrated(userAddress);
        const amount = await this.vanaBridge.getMigrationAmount(userAddress);
        return { hasMigrated, amount: ethers.formatEther(amount) };
    }
}
```

### Smart Contract Integration
```solidity
// For protocols integrating with V2 RDAT

interface IRDATV2 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract YourProtocol {
    IRDATV2 public rdatToken = IRDATV2(0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E);

    function stakeRDAT(uint256 amount) external {
        // Transfer RDAT from user
        require(rdatToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        // Your staking logic
        // ...
    }
}
```

## 🔧 Backend Service Setup

### Validator Service Requirements
```javascript
// Environment variables
VALIDATOR_PRIVATE_KEY=<validator_private_key>
BASE_RPC_URL=https://mainnet.base.org
VANA_RPC_URL=https://rpc.vana.org

// Service responsibilities
1. Monitor MigrationInitiated events on Base
2. Verify migration validity
3. Sign migration attestation
4. Store signature in database
5. Provide signatures via API
```

### API Endpoints
```typescript
// GET /api/migration/:migrationId
{
    "migrationId": "0x123...",
    "user": "0xabc...",
    "amount": "10000",
    "status": "pending_signatures",
    "signatures": ["0xsig1...", "0xsig2..."],
    "readyToClaim": true
}

// POST /api/migration/initiate
{
    "txHash": "0xdef...",
    "migrationId": "0x123..."
}

// WebSocket subscription
ws://api.rdatadao.org/migration/subscribe
→ Receives updates when signatures are ready
```

## ⚠️ Common Issues & Solutions

### Issue: Transaction Fails on Base
**Cause**: Insufficient gas or approval
**Solution**:
1. Ensure enough ETH for gas
2. Check V1 token approval
3. Verify V1 balance sufficient

### Issue: Signatures Not Available
**Cause**: Validators haven't signed yet
**Solution**:
1. Wait 5-30 minutes
2. Check migration ID is correct
3. Contact support if >1 hour

### Issue: Cannot Claim on Vana
**Cause**: Invalid signatures or already claimed
**Solution**:
1. Verify you haven't already migrated
2. Ensure using correct address
3. Check signatures are valid

### Issue: Tokens Not Showing in Wallet
**Cause**: Token not added to wallet
**Solution**:
Add custom token:
- Address: `0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E`
- Symbol: RDAT
- Decimals: 18

## 📊 Migration Analytics

### Track Migration Progress
```javascript
// Total migrated
const totalMigrated = await vanaBridge.totalMigrated();
console.log(`Total Migrated: ${ethers.formatEther(totalMigrated)} RDAT`);

// Remaining capacity
const remaining = 30_000_000 - Number(ethers.formatEther(totalMigrated));
console.log(`Remaining: ${remaining.toLocaleString()} RDAT`);

// Migration percentage
const percentage = (Number(ethers.formatEther(totalMigrated)) / 30_000_000) * 100;
console.log(`Migration Progress: ${percentage.toFixed(2)}%`);
```

### Historical Migration Data
```sql
-- Query migration events
SELECT
    user_address,
    amount,
    migration_id,
    timestamp,
    status
FROM migrations
WHERE status = 'completed'
ORDER BY timestamp DESC;
```

## 🆘 Support Resources

### Getting Help
- **Discord**: [discord.gg/rdatadao](https://discord.gg/rdatadao) #migration-support
- **Email**: migration@rdatadao.org
- **Documentation**: [docs.rdatadao.org/migration](https://docs.rdatadao.org/migration)

### FAQ

**Q: How long does migration take?**
A: Typically 10-30 minutes total (5 min on Base, 5-25 min for signatures, 5 min on Vana)

**Q: Can I migrate partially?**
A: Yes, you can migrate any amount up to your V1 balance

**Q: Can I migrate multiple times?**
A: No, each address can only migrate once

**Q: What happens to my V1 tokens?**
A: They are permanently burned (sent to 0xdead address)

**Q: Is there a deadline?**
A: No deadline, but earlier migration ensures availability

**Q: Are there fees?**
A: Only network gas fees (~$6-12 total)

**Q: What if validators don't sign?**
A: After 7 days, admin can override with multisig

## 🔒 Security Considerations

### For Users
1. **Verify contract addresses** - Always check you're interacting with official contracts
2. **Use official dApp** - Only use migration.rdatadao.org
3. **Check signatures** - Ensure 2/3 validators have signed
4. **One-time process** - You can only migrate once per address
5. **Save migration ID** - Keep for reference

### For Developers
1. **Validate signatures** - Always verify validator signatures on-chain
2. **Check migration status** - Prevent double migrations
3. **Handle errors gracefully** - Provide clear error messages
4. **Monitor events** - Track MigrationInitiated and MigrationCompleted
5. **Rate limiting** - Implement API rate limits

## 📈 Post-Migration

### What's Next?
Once migrated to V2, you can:
1. **Hold** - Benefit from expanded tokenomics
2. **Trade** - On Vana DEXs (coming soon)
3. **Stake** - Earn rewards (Phase 2)
4. **Govern** - Vote on proposals (Phase 2)
5. **Contribute** - Earn via DLP (Active)

### Phase 2 Features (Coming Q4 2025)
- Staking with 30/90/180/365 day locks
- vRDAT governance token rewards
- On-chain voting
- Revenue sharing
- Liquidity provisions

## 📝 Audit Notes

The migration system has been audited with the following key security features:
- 6-hour challenge period for migrations
- 7-day admin override capability
- 2/3 validator signature requirement
- One-time migration per address
- Permanent V1 token burning

## ⚡ Quick Links

- **Migration dApp**: [migration.rdatadao.org](https://migration.rdatadao.org)
- **V2 Token**: [Vanascan](https://vanascan.io/token/0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E)
- **Migration Bridge**: [Vanascan](https://vanascan.io/address/0x9d4aB2d3fb25D414dba1d9D22200356b5984D35E)
- **Support**: [Discord](https://discord.gg/rdatadao)