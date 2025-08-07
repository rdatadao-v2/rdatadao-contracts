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
    RDAT: '0xEb0c43d5987de0672A22e350930F615Af646e28c', // Predicted
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
  // Base Sepolia (Chain ID: 84532)
  84532: {
    BaseMigrationBridge: '',
    V1TokenMock: '',
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
