# Frontend Integration Guide

**Last Updated**: September 20, 2025
**Status**: MAINNET DEPLOYED ✅
**Target Audience**: Frontend developers building the r/datadao UI

## 🚀 Quick Start

### Network Configuration

```javascript
// Vana Mainnet Configuration
const VANA_CONFIG = {
  chainId: 1480,
  chainName: 'Vana',
  rpcUrl: 'https://rpc.vana.org',
  explorer: 'https://vanascan.io',
  nativeCurrency: {
    name: 'VANA',
    symbol: 'VANA',
    decimals: 18
  }
};

// Base Mainnet Configuration
const BASE_CONFIG = {
  chainId: 8453,
  chainName: 'Base',
  rpcUrl: 'https://mainnet.base.org',
  explorer: 'https://basescan.org',
  nativeCurrency: {
    name: 'ETH',
    symbol: 'ETH',
    decimals: 18
  }
};
```

### Contract Addresses

```javascript
const CONTRACTS = {
  vana: {
    rdatToken: '0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E',
    treasury: '0x77D2713972af12F1E3EF39b5395bfD65C862367C',
    migrationBridge: '0x9d4aB2d3fb25D414dba1d9D22200356b5984D35E',
    dataDAO: '0xBbB0B59163b850dDC5139e98118774557c5d9F92',
    dlpId: 40
  },
  base: {
    rdatV1: '0x4498cd8Ba045E00673402353f5a4347562707e7D',
    migrationBridge: '0xa4435b45035a483d364de83B9494BDEFA8322626'
  },
  multisigs: {
    vana: '0xe4F7Eca807C57311e715C3Ef483e72Fa8D5bCcDF',
    base: '0x90013583c66D2bf16327cB5Bc4a647AcceCF4B9A'
  },
  validators: [
    '0xd36B49f2DB6aA708Ce7245e8ab2453C6DfFc9d6f', // Angela
    '0xC9Af4E56741f255743e8f4877d4cfa9971E910C2', // monkfenix.eth
    '0x08Cc5ed1bA3C95AA741f8AaEf631f716b037444b'  // Base multisig
  ]
};
```

## 🔄 V1 to V2 Migration Flow

### User Journey

1. **Check Balance**: Display V1 balance on Base
2. **Initiate Migration**: Lock tokens on Base
3. **Wait for Signatures**: Backend collects validator signatures
4. **Claim on Vana**: Complete migration with signatures

### Implementation

```typescript
import { ethers } from 'ethers';
import { ERC20_ABI, BRIDGE_ABI } from './abis';

class MigrationService {
  private baseProvider: ethers.Provider;
  private vanaProvider: ethers.Provider;

  constructor() {
    this.baseProvider = new ethers.JsonRpcProvider(BASE_CONFIG.rpcUrl);
    this.vanaProvider = new ethers.JsonRpcProvider(VANA_CONFIG.rpcUrl);
  }

  // Step 1: Check V1 Balance
  async getV1Balance(userAddress: string): Promise<string> {
    const v1Token = new ethers.Contract(
      CONTRACTS.base.rdatV1,
      ERC20_ABI,
      this.baseProvider
    );
    const balance = await v1Token.balanceOf(userAddress);
    return ethers.formatEther(balance);
  }

  // Step 2: Approve and Initiate Migration
  async initiateMigration(signer: ethers.Signer, amount: string) {
    // Approve tokens
    const v1Token = new ethers.Contract(
      CONTRACTS.base.rdatV1,
      ERC20_ABI,
      signer
    );
    const amountWei = ethers.parseEther(amount);
    await v1Token.approve(CONTRACTS.base.migrationBridge, amountWei);

    // Initiate migration
    const baseBridge = new ethers.Contract(
      CONTRACTS.base.migrationBridge,
      BRIDGE_ABI,
      signer
    );
    const tx = await baseBridge.initiateMigration(amountWei);
    const receipt = await tx.wait();

    // Extract migration ID from events
    const event = receipt.logs.find(
      log => log.topics[0] === ethers.id('MigrationInitiated(address,uint256,bytes32)')
    );
    const migrationId = event.topics[3];

    return { txHash: receipt.hash, migrationId };
  }

  // Step 3: Poll for signatures (backend service)
  async waitForSignatures(migrationId: string): Promise<string[]> {
    // This would connect to your backend API
    const response = await fetch(`/api/migration/${migrationId}/signatures`);
    const data = await response.json();

    if (data.signatures.length >= 2) {
      return data.signatures;
    }

    // Poll every 5 seconds
    await new Promise(resolve => setTimeout(resolve, 5000));
    return this.waitForSignatures(migrationId);
  }

  // Step 4: Complete migration on Vana
  async completeMigration(
    signer: ethers.Signer,
    userAddress: string,
    amount: string,
    migrationId: string,
    signatures: string[]
  ) {
    const vanaBridge = new ethers.Contract(
      CONTRACTS.vana.migrationBridge,
      BRIDGE_ABI,
      signer
    );

    const amountWei = ethers.parseEther(amount);
    const tx = await vanaBridge.processMigration(
      userAddress,
      amountWei,
      migrationId,
      signatures
    );

    return await tx.wait();
  }

  // Check migration status
  async getMigrationStatus(userAddress: string) {
    const vanaBridge = new ethers.Contract(
      CONTRACTS.vana.migrationBridge,
      BRIDGE_ABI,
      this.vanaProvider
    );

    const hasMigrated = await vanaBridge.hasMigrated(userAddress);
    const totalMigrated = await vanaBridge.totalMigrated();

    return {
      hasMigrated,
      totalMigrated: ethers.formatEther(totalMigrated),
      remaining: ethers.formatEther(30_000_000n * 10n**18n - totalMigrated)
    };
  }
}
```

## 👛 Wallet Integration

### Detecting User Role

```typescript
async function getUserRole(address: string): Promise<UserRole> {
  const roles = {
    isVanaAdmin: address.toLowerCase() === CONTRACTS.multisigs.vana.toLowerCase(),
    isBaseAdmin: address.toLowerCase() === CONTRACTS.multisigs.base.toLowerCase(),
    isValidator: CONTRACTS.validators.some(
      v => v.toLowerCase() === address.toLowerCase()
    ),
    isUser: true
  };

  return {
    type: roles.isVanaAdmin ? 'vana-admin' :
          roles.isBaseAdmin ? 'base-admin' :
          roles.isValidator ? 'validator' : 'user',
    permissions: getPermissionsForRole(roles)
  };
}
```

### Network Switching

```typescript
async function switchToVana() {
  if (!window.ethereum) throw new Error('No wallet detected');

  try {
    await window.ethereum.request({
      method: 'wallet_switchEthereumChain',
      params: [{ chainId: '0x5c8' }], // 1480 in hex
    });
  } catch (error) {
    if (error.code === 4902) {
      // Chain not added, add it
      await window.ethereum.request({
        method: 'wallet_addEthereumChain',
        params: [{
          chainId: '0x5c8',
          chainName: 'Vana',
          nativeCurrency: {
            name: 'VANA',
            symbol: 'VANA',
            decimals: 18,
          },
          rpcUrls: ['https://rpc.vana.org'],
          blockExplorerUrls: ['https://vanascan.io'],
        }],
      });
    }
  }
}
```

## 🎯 Core Features Implementation

### 1. Token Balance Display

```typescript
async function getTokenBalances(userAddress: string) {
  const rdatContract = new ethers.Contract(
    CONTRACTS.vana.rdatToken,
    ERC20_ABI,
    vanaProvider
  );

  const [balance, totalSupply, decimals] = await Promise.all([
    rdatContract.balanceOf(userAddress),
    rdatContract.totalSupply(),
    rdatContract.decimals()
  ]);

  return {
    balance: ethers.formatUnits(balance, decimals),
    totalSupply: ethers.formatUnits(totalSupply, decimals),
    percentage: (Number(balance) * 100n / Number(totalSupply)).toString()
  };
}
```

### 2. Token Transfer

```typescript
async function transferTokens(
  signer: ethers.Signer,
  recipient: string,
  amount: string
) {
  const rdatContract = new ethers.Contract(
    CONTRACTS.vana.rdatToken,
    ERC20_ABI,
    signer
  );

  const amountWei = ethers.parseEther(amount);
  const tx = await rdatContract.transfer(recipient, amountWei);
  return await tx.wait();
}
```

### 3. Treasury Information

```typescript
async function getTreasuryInfo() {
  const treasury = new ethers.Contract(
    CONTRACTS.vana.treasury,
    TREASURY_ABI,
    vanaProvider
  );

  const rdatContract = new ethers.Contract(
    CONTRACTS.vana.rdatToken,
    ERC20_ABI,
    vanaProvider
  );

  const [balance, totalAllocated] = await Promise.all([
    rdatContract.balanceOf(CONTRACTS.vana.treasury),
    treasury.totalAllocated()
  ]);

  return {
    currentBalance: ethers.formatEther(balance),
    totalAllocated: ethers.formatEther(totalAllocated),
    distributions: {
      team: '10,000,000',
      development: '20,000,000',
      community: '30,000,000',
      reserve: '10,000,000'
    }
  };
}
```

## 🛡️ Admin Features

### Admin Dashboard Components

```typescript
interface AdminDashboard {
  // Treasury Management
  treasuryBalance: string;
  vestingSchedules: VestingSchedule[];
  pendingProposals: Proposal[];

  // Migration Management
  totalMigrated: string;
  migrationsPending: number;
  validatorStatus: ValidatorStatus[];

  // System Health
  contractStatus: ContractHealth[];
  pauseStatus: boolean;
  lastActivity: Date;
}

// Admin Actions
class AdminService {
  async executeProposal(
    signer: ethers.Signer,
    to: string,
    amount: string,
    reason: string
  ) {
    const treasury = new ethers.Contract(
      CONTRACTS.vana.treasury,
      TREASURY_ABI,
      signer
    );

    const amountWei = ethers.parseEther(amount);
    const tx = await treasury.executeDAOProposal(to, amountWei, reason);
    return await tx.wait();
  }

  async pauseSystem(signer: ethers.Signer) {
    const rdatContract = new ethers.Contract(
      CONTRACTS.vana.rdatToken,
      RDAT_ABI,
      signer
    );

    const tx = await rdatContract.pause();
    return await tx.wait();
  }

  async addValidator(signer: ethers.Signer, validator: string) {
    const bridge = new ethers.Contract(
      CONTRACTS.vana.migrationBridge,
      BRIDGE_ABI,
      signer
    );

    const tx = await bridge.addValidator(validator);
    return await tx.wait();
  }
}
```

## 📊 Data Display Components

### Migration Progress

```jsx
function MigrationProgress() {
  const [progress, setProgress] = useState({
    migrated: '0',
    total: '30000000',
    percentage: 0
  });

  useEffect(() => {
    async function fetchProgress() {
      const bridge = new ethers.Contract(
        CONTRACTS.vana.migrationBridge,
        BRIDGE_ABI,
        vanaProvider
      );

      const totalMigrated = await bridge.totalMigrated();
      const migrated = Number(ethers.formatEther(totalMigrated));

      setProgress({
        migrated: migrated.toLocaleString(),
        total: '30,000,000',
        percentage: (migrated / 30_000_000) * 100
      });
    }

    fetchProgress();
    const interval = setInterval(fetchProgress, 30000); // Update every 30s
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="migration-progress">
      <h3>Migration Progress</h3>
      <div className="progress-bar">
        <div
          className="progress-fill"
          style={{ width: `${progress.percentage}%` }}
        />
      </div>
      <p>{progress.migrated} / {progress.total} RDAT Migrated</p>
      <p>{progress.percentage.toFixed(2)}% Complete</p>
    </div>
  );
}
```

### Token Statistics

```jsx
function TokenStats() {
  const [stats, setStats] = useState({
    price: '0',
    marketCap: '0',
    holders: '0',
    transfers24h: '0'
  });

  return (
    <div className="token-stats">
      <div className="stat">
        <label>Total Supply</label>
        <value>100,000,000 RDAT</value>
      </div>
      <div className="stat">
        <label>Circulating Supply</label>
        <value>30,000,000 RDAT</value>
      </div>
      <div className="stat">
        <label>Treasury</label>
        <value>70,000,000 RDAT</value>
      </div>
      <div className="stat">
        <label>DLP ID</label>
        <value>40</value>
      </div>
    </div>
  );
}
```

## 🔧 Error Handling

```typescript
class ErrorHandler {
  static handle(error: any): UserFriendlyError {
    // Wallet errors
    if (error.code === 4001) {
      return { message: 'Transaction rejected by user', severity: 'info' };
    }

    // Contract errors
    if (error.reason) {
      const errorMap = {
        'MigrationBridge: Already migrated':
          'This address has already completed migration',
        'MigrationBridge: Invalid signatures':
          'Waiting for validator signatures. Please try again in a few minutes.',
        'MigrationBridge: Insufficient balance':
          'Insufficient V1 RDAT balance for migration',
        'Pausable: paused':
          'System is temporarily paused for maintenance',
        'AccessControl: account':
          'You do not have permission to perform this action'
      };

      for (const [key, message] of Object.entries(errorMap)) {
        if (error.reason.includes(key)) {
          return { message, severity: 'error' };
        }
      }
    }

    // Network errors
    if (error.code === 'NETWORK_ERROR') {
      return {
        message: 'Network connection error. Please check your connection.',
        severity: 'error'
      };
    }

    // Default
    return {
      message: 'An unexpected error occurred. Please try again.',
      severity: 'error',
      details: error.message
    };
  }
}
```

## 📦 Required ABIs

ABIs are available in the `/abi` directory:
- `RDATUpgradeable.json` - Main token contract
- `TreasuryWallet.json` - Treasury management
- `VanaMigrationBridge.json` - Vana-side bridge
- `BaseMigrationBridge.json` - Base-side bridge
- `RDATDataDAO.json` - DLP integration

Generate ABIs:
```bash
forge inspect RDATUpgradeable abi > abi/RDATUpgradeable.json
forge inspect TreasuryWallet abi > abi/TreasuryWallet.json
forge inspect VanaMigrationBridge abi > abi/VanaMigrationBridge.json
forge inspect BaseMigrationBridge abi > abi/BaseMigrationBridge.json
forge inspect RDATDataDAO abi > abi/RDATDataDAO.json
```

## 🧪 Testing Your Integration

### Testnet Configuration

```javascript
const TESTNET_CONTRACTS = {
  vanaMoksha: { // Chain ID: 14800
    rdatToken: '0xEb0c43d5987de0672A22e350930F615Af646e28c',
    treasury: '0x31C3e3F091FB2A25d4dac82474e7dc709adE754a',
    multisig: '0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319'
  },
  baseSepolia: { // Chain ID: 84532
    rdatV1: '0xEb0c43d5987de0672A22e350930F615Af646e28c',
    migrationBridge: '0xF73c6216d7D6218d722968e170Cfff6654A8936c'
  }
};
```

### Mock Migration Testing

```bash
# Get test tokens on Base Sepolia
forge script script/MockRDATFaucet.s.sol \
  --sig "distributeToTester(address,uint256)" \
  YOUR_ADDRESS 1000 \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast \
  --private-key $DEPLOYER_PRIVATE_KEY
```

## 📞 Support & Resources

- **Discord**: [discord.gg/rdatadao](https://discord.gg/rdatadao)
- **GitHub**: [github.com/rdatadao/contracts-v2](https://github.com/rdatadao/contracts-v2)
- **Documentation**: [docs.rdatadao.org](https://docs.rdatadao.org)
- **Email**: dev@rdatadao.org

## ⚠️ Important Notes

1. **Fixed Supply**: RDAT has a fixed supply of 100M tokens. No new tokens can be minted.
2. **Migration Window**: V1 holders should migrate promptly. 30M tokens are allocated for migration.
3. **Validator Requirement**: Migration requires 2/3 validator signatures for security.
4. **Network Costs**: Users pay gas on both Base and Vana networks for migration.
5. **One-Time Migration**: Each address can only migrate once.