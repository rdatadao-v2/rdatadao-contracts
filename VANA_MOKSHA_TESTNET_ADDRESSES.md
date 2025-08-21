# Vana Moksha Testnet Contract Addresses

## Overview
All contracts deployed on **Vana Moksha Testnet** (Chain ID: 14800)
- **Network RPC**: https://rpc.moksha.vana.org
- **Explorer**: https://moksha.vanascan.io

## Core Contracts

### 1. RDAT Token (ERC-20/VRC-20)
- **Address**: `0xC1aC75130533c7F93BDa67f6645De65C9DEE9a3A`
- **Type**: UUPS Upgradeable
- **Total Supply**: 100,000,000 RDAT (fixed, no minting)
- **Explorer**: [View on Vanascan](https://moksha.vanascan.io/address/0xC1aC75130533c7F93BDa67f6645De65C9DEE9a3A)

### 2. Treasury Wallet
- **Address**: `0x31C3e3F091FB2A25d4dac82474e7dc709adE754a`
- **Holdings**: 70,000,000 RDAT
- **Purpose**: Manages treasury funds with phased vesting
- **Explorer**: [View on Vanascan](https://moksha.vanascan.io/address/0x31C3e3F091FB2A25d4dac82474e7dc709adE754a)

### 3. Migration Bridge (Vana Side)
- **Address**: `0x31C3e3F091FB2A25d4dac82474e7dc709adE754a`
- **Allocation**: 30,000,000 RDAT
- **Purpose**: Handles V1→V2 token migration from Base
- **Explorer**: [View on Vanascan](https://moksha.vanascan.io/address/0x31C3e3F091FB2A25d4dac82474e7dc709adE754a)

### 4. RDATDataDAO (DLP Contract) 
- **Address**: `0x32B481b52616044E5c937CF6D20204564AD62164` *(Latest version with all interfaces)*
- **Status**: Deployed, pending DLP registration
- **Purpose**: Data Liquidity Pool for Reddit data contribution
- **Explorer**: [View on Vanascan](https://moksha.vanascan.io/address/0x32B481b52616044E5c937CF6D20204564AD62164)

### Previous DLP Deployment Attempts:
- `0x254A9344AAb674530D47B6F2dDd8e328A17Da860` (v1 - missing methods)
- `0xCB3C48cb2a20F06d41BF15dF943D797421c56207` (v2 - added owner())
- `0x32B481b52616044E5c937CF6D20204564AD62164` (v3 - current, full interface)

## Key Addresses & Roles

### Admin/Multisig
- **Address**: `0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319`
- **Role**: Admin for all contracts, treasury control

### Deployer
- **Address**: `0x58eCB94e6F5e6521228316b55c465ad2A2938FbB`
- **Role**: Contract deployment and initial setup

## Vana Ecosystem Contracts (Referenced)

### DLP Registry
- **Proxy**: `0x4D59880a924526d1dD33260552Ff4328b1E18a43`
- **Implementation**: `0x72bA0c4DF3122e8aACe5066443eEb33B0491909C`
- **Purpose**: Registers and manages DLPs on Vana

### Data Registry
- **Address**: `0xEA882bb75C54DE9A08bC46b46c396727B4BFe9a5`
- **Purpose**: Vana's data contribution registry

### TEE Pool
- **Address**: `0xF084Ca24B4E29Aa843898e0B12c465fAFD089965`
- **Purpose**: Trusted Execution Environment pool

## Integration Notes for Frontend

### Primary Integration Points:
1. **RDAT Token**: `0xC1aC75130533c7F93BDa67f6645De65C9DEE9a3A`
   - Standard ERC-20 interface
   - Use for balance queries, transfers, approvals

2. **Treasury**: `0x31C3e3F091FB2A25d4dac82474e7dc709adE754a`
   - Query vesting schedules
   - Track treasury holdings

3. **Migration Bridge**: `0x31C3e3F091FB2A25d4dac82474e7dc709adE754a`
   - Monitor migration status
   - Check remaining allocation (30M RDAT)

4. **RDATDataDAO**: `0x32B481b52616044E5c937CF6D20204564AD62164`
   - Data contribution interface
   - Validator interactions
   - Rewards distribution

### ABI Files
ABIs for all contracts are available in:
- `/out/` directory (Foundry artifacts)
- Can be extracted using `forge inspect <ContractName> abi`

### Network Configuration
```javascript
const vanaTestnet = {
  id: 14800,
  name: 'Vana Moksha',
  network: 'vana-moksha',
  nativeCurrency: {
    decimals: 18,
    name: 'VANA',
    symbol: 'VANA',
  },
  rpcUrls: {
    default: { http: ['https://rpc.moksha.vana.org'] },
  },
  blockExplorers: {
    default: { 
      name: 'Vanascan', 
      url: 'https://moksha.vanascan.io' 
    },
  },
}
```

## Status Notes

### ✅ Deployed & Operational:
- RDAT Token contract
- Treasury Wallet
- Migration Bridge
- RDATDataDAO contract

### ⏳ Pending:
- DLP Registration (awaiting Vana team assistance)
- Staking contracts (to be deployed after DLP registration)
- vRDAT governance token (to be deployed after DLP registration)

## Contact
For technical questions or issues, please refer to:
- GitHub: https://github.com/rdatadao/contracts-v2
- Failed DLP registration report: `DLP_REGISTRATION_REPORT.md`