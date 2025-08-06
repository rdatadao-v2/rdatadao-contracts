import { defineConfig } from '@wagmi/cli'
import { foundry, react } from '@wagmi/cli/plugins'
import { base, baseSepolia } from 'viem/chains'

// Define Vana chains
const vana = {
  id: 1480,
  name: 'Vana',
  nativeCurrency: {
    decimals: 18,
    name: 'VANA',
    symbol: 'VANA',
  },
  rpcUrls: {
    default: { http: ['https://rpc.vana.network'] },
  },
  blockExplorers: {
    default: { name: 'Vana Explorer', url: 'https://explorer.vana.network' },
  },
} as const

const vanaMoksha = {
  id: 14800,
  name: 'Vana Moksha Testnet',
  nativeCurrency: {
    decimals: 18,
    name: 'Vana',
    symbol: 'VANA',
  },
  rpcUrls: {
    default: { http: ['https://moksha-rpc.vana.network'] },
  },
  blockExplorers: {
    default: { name: 'Vana Moksha Explorer', url: 'https://moksha-explorer.vana.network' },
  },
  testnet: true,
} as const

export default defineConfig({
  out: 'src/generated.ts',
  contracts: [],
  plugins: [
    /**
     * Foundry plugin to automatically load contracts from forge artifacts
     * This will read from out/ directory and generate types
     */
    foundry({
      project: './',
      include: [
        // Token contracts
        'MockRDAT.sol/MockRDAT.json',
        'RDATUpgradeable.sol/RDATUpgradeable.json',
        
        // Migration contracts
        'RdatMigration.sol/RdatMigration.json',
        'RdatDistributor.sol/RdatDistributor.json',
        
        // Chain-specific contracts
        'BaseOnlyContract.sol/BaseOnlyContract.json',
        'VanaDataContract.sol/VanaDataContract.json',
        'MultiChainRegistry.sol/MultiChainRegistry.json',
      ],
    }),
    
    /**
     * React plugin to generate React hooks
     */
    react(),
  ],
})

/**
 * Usage in frontend:
 * 
 * 1. Install dependencies:
 *    npm install wagmi viem @tanstack/react-query
 *    npm install -D @wagmi/cli
 * 
 * 2. Generate types:
 *    npx wagmi generate
 * 
 * 3. Use in React:
 *    import { useMockRdatRead, useMockRdatWrite } from './generated'
 *    
 *    // Read contract
 *    const { data: balance } = useMockRdatRead({
 *      functionName: 'balanceOf',
 *      args: [address],
 *    })
 *    
 *    // Write contract
 *    const { write: transfer } = useMockRdatWrite({
 *      functionName: 'transfer',
 *      args: [recipient, amount],
 *    })
 */