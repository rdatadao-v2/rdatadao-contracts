// Auto-generated ABI exports for r/datadao V2
// Generated on: Fri  8 Aug 2025 09:30:51 AEST

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
export { default as Create2FactoryABI } from './Create2Factory.json';
export { default as ProofOfContributionStubABI } from './ProofOfContributionStub.json';
export { default as MigrationBonusVestingABI } from './MigrationBonusVesting.json';

// DLP Contracts (Vana ecosystem)
export { default as RDATDataDAOABI } from './RDATDataDAO.json';
export { default as SimpleVanaDLPABI } from './SimpleVanaDLP.json';

// Reward Module Contracts
export { default as RDATRewardModuleABI } from './RDATRewardModule.json';
export { default as vRDATRewardModuleABI } from './vRDATRewardModule.json';
export { default as VRC14LiquidityModuleABI } from './VRC14LiquidityModule.json';

// Governance Contracts
export { default as GovernanceCoreABI } from './GovernanceCore.json';
export { default as GovernanceVotingABI } from './GovernanceVoting.json';
export { default as GovernanceExecutionABI } from './GovernanceExecution.json';

// Interfaces (for typing)
export { default as IRDATABI } from './IRDAT.json';
export { default as IvRDATABI } from './IvRDAT.json';
export { default as IStakingPositionsABI } from './IStakingPositions.json';
export { default as ITreasuryWalletABI } from './ITreasuryWallet.json';
export { default as ITokenVestingABI } from './ITokenVesting.json';
export { default as IMigrationBridgeABI } from './IMigrationBridge.json';
export { default as IRevenueCollectorABI } from './IRevenueCollector.json';
export { default as IRewardsManagerABI } from './IRewardsManager.json';
export { default as IProofOfContributionABI } from './IProofOfContribution.json';
export { default as IEmergencyPauseABI } from './IEmergencyPause.json';

// Contract addresses (update after deployment)
export const CONTRACT_ADDRESSES = {
  // Vana Mainnet (Chain ID: 1480)
  vana: {
    RDAT: '',
    vRDAT: '',
    StakingPositions: '',
    TreasuryWallet: '',
    TokenVesting: '',
    VanaMigrationBridge: '',
    RevenueCollector: '',
    RewardsManager: '',
    EmergencyPause: '',
  },
  // Base Mainnet (Chain ID: 8453)
  base: {
    BaseMigrationBridge: '',
    V1Token: '', // Existing V1 token address
  },
  // Vana Moksha Testnet (Chain ID: 14800) - DEPLOYED
  vanaMoksha: {
    RDAT: '0xC1aC75130533c7F93BDa67f6645De65C9DEE9a3A',
    vRDAT: '0x386f44505DB03a387dF1402884d5326247DCaaC8',
    StakingPositions: '0x3f2236ef5360BEDD999378672A145538f701E662',
    TreasuryWallet: '0x31C3e3F091FB2A25d4dac82474e7dc709adE754a',
    TokenVesting: '0xdCa8b322c11515A3B5e6e806170b573bDe179328',
    VanaMigrationBridge: '0xEb0c43d5987de0672A22e350930F615Af646e28c',
    EmergencyPause: '0x254A9344AAb674530D47B6F2dDd8e328A17Da860',
    RevenueCollector: '0x31C3e3F091FB2A25d4dac82474e7dc709adE754a',
    RewardsManager: '',
    Create2Factory: '',
    RDATDataDAO: '0x254A9344AAb674530D47B6F2dDd8e328A17Da860',
    SimpleVanaDLP: '0xC1aC75130533c7F93BDa67f6645De65C9DEE9a3A',
  },
  // Base Sepolia (Chain ID: 84532)
  baseSepolia: {
    BaseMigrationBridge: '',
    V1TokenMock: '',
  }
};

// Helper function to get addresses by chain ID
export function getAddresses(chainId: number) {
  switch (chainId) {
    case 1480:
      return CONTRACT_ADDRESSES.vana;
    case 8453:
      return CONTRACT_ADDRESSES.base;
    case 14800:
      return CONTRACT_ADDRESSES.vanaMoksha;
    case 84532:
      return CONTRACT_ADDRESSES.baseSepolia;
    default:
      throw new Error();
  }
}
