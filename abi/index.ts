// Auto-generated ABI exports for r/datadao V2
// Generated on: 
// Fri  8 Aug 2025 00:33:38 AEST

// Core Contracts
export { default as RDATUpgradeableABI } from './RDATUpgradeable.json';
export { default as vRDATABI } from './vRDAT.json';
export { default as StakingPositionsABI } from './StakingPositions.json';
export { default as TreasuryWalletABI } from './TreasuryWallet.json';
export { default as TokenVestingABI } from './TokenVesting.json';
export { default as BaseMigrationBridgeABI } from './BaseMigrationBridge.json';
export { default as VanaMigrationBridgeABI } from './VanaMigrationBridge.json';
export { default as EmergencyPauseABI } from './EmergencyPause.json';
export { default as RevenueCollectorABI } from './RevenueCollector.json';
export { default as RewardsManagerABI } from './RewardsManager.json';
export { default as ProofOfContributionStubABI } from './ProofOfContributionStub.json';
export { default as Create2FactoryABI } from './Create2Factory.json';

// Governance Contracts
export { default as GovernanceCoreABI } from './GovernanceCore.json';
export { default as GovernanceVotingABI } from './GovernanceVoting.json';
export { default as GovernanceExecutionABI } from './GovernanceExecution.json';

// Contract addresses (update after deployment)
export const CONTRACT_ADDRESSES = {
  // Vana Mainnet (Chain ID: 1480)
  1480: {
    RDAT: '',
    vRDAT: '',
    StakingPositions: '',
    TreasuryWallet: '',
    TokenVesting: '',
    VanaMigrationBridge: '',
    RevenueCollector: '',
    RewardsManager: '',
    EmergencyPause: '',
    ProofOfContribution: '',
  },
  // Base Mainnet (Chain ID: 8453)
  8453: {
    BaseMigrationBridge: '',
    V1Token: '', // Existing V1 token address
  },
  // Vana Moksha Testnet (Chain ID: 14800)
  14800: {
    RDAT: '0xEb0c43d5987de0672A22e350930F615Af646e28c', // DEPLOYED!
    RDATImplementation: '0xd546C45872eeA596155EAEAe9B8495f02ca4fc58',
    CREATE2Factory: '0x87C5F9661E7223D9d97899B3Ba89327FCaf51EFB',
    vRDAT: '0x386f44505DB03a387dF1402884d5326247DCaaC8', // DEPLOYED!
    StakingPositions: '0x3f2236ef5360BEDD999378672A145538f701E662', // DEPLOYED!
    TreasuryWallet: '0x31C3e3F091FB2A25d4dac82474e7dc709adE754a', // DEPLOYED!
    TokenVesting: '',
    VanaMigrationBridge: '',
    RevenueCollector: '0x5588e399206880Fcd2C7Ca8dE04126854ce273cE', // DEPLOYED!
    RewardsManager: '',
    EmergencyPause: '0xF73c6216d7D6218d722968e170Cfff6654A8936c', // DEPLOYED!
    ProofOfContribution: '0xdbb1926C6cA2a68A8832d550d94C648c19Dbae6b', // DEPLOYED!
  },
  // Base Sepolia (Chain ID: 84532)
  84532: {
    BaseMigrationBridge: '0xb7d6f8eadfD4415cb27686959f010771FE94561b', // DEPLOYED!
    V1TokenMock: '0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E', // DEPLOYED!
  }
} as const;

// Helper function to get addresses by chain ID
export function getAddresses(chainId: number) {
  const addresses = CONTRACT_ADDRESSES[chainId as keyof typeof CONTRACT_ADDRESSES];
  if (!addresses) {
    throw new Error(`Unsupported chain ID: ${chainId}`);
  }
  return addresses;
}

// Type exports for better TypeScript support
export type ChainId = keyof typeof CONTRACT_ADDRESSES;
export type ContractName = keyof typeof CONTRACT_ADDRESSES[1480];
