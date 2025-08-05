# Mock Contracts

This directory contains mock contracts used for testing purposes.

## MockRDAT Token

The `MockRDAT.sol` contract is an exact replica of the existing RDAT token deployed on Base mainnet at address `0x4498cd8ba045e00673402353f5a4347562707e7d`.

### Purpose

1. **Local Development**: Provides an exact copy of the RDAT token for local chain testing
2. **Testnet Testing**: Allows testing migration flows on testnets without using real RDAT tokens
3. **Integration Testing**: Ensures compatibility with the existing token interface

### Features (Matching Base Mainnet RDAT)

- **ERC20 with Extensions**: Standard ERC20 + Permit + Votes functionality
- **Ownable2Step**: Two-step ownership transfer for security
- **Admin Role**: Separate admin role for blocklist management
- **Blocklist**: Admin can block addresses from transferring tokens
- **Mint Blocking**: Owner can permanently disable minting
- **Governance Support**: ERC20Votes for on-chain governance

### Usage

```solidity
// Deploy MockRDAT with owner address
MockRDAT mockRDAT = new MockRDAT(ownerAddress);

// The owner receives 30 million tokens (total supply)
uint256 balance = mockRDAT.balanceOf(ownerAddress); // 30_000_000 * 10**18

// Owner sets admin for blocklist management
mockRDAT.changeAdmin(adminAddress);

// Admin can block/unblock addresses
mockRDAT.blockAddress(maliciousAddress);
mockRDAT.unblockAddress(maliciousAddress);

// Owner can mint additional tokens (until minting is blocked)
mockRDAT.mint(recipient, 1000 * 10**18);

// Owner can permanently disable minting
mockRDAT.blockMint();

// Supports permit for gasless approvals
mockRDAT.permit(owner, spender, value, deadline, v, r, s);

// Supports voting delegation
mockRDAT.delegate(delegatee);
```

### Deployment

```bash
# Local deployment
forge script script/mocks/DeployMockRDAT.s.sol:DeployMockRDAT --rpc-url http://localhost:8545 --broadcast

# Testnet deployment
forge script script/mocks/DeployMockRDAT.s.sol:DeployMockRDAT --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast
```

### Important Notes

1. **Verification**: Before using this mock in production tests, verify that it matches the actual RDAT token interface on Base mainnet
2. **Additional Features**: The mock includes a `mint` function for testing purposes that doesn't exist in the real token
3. **Migration Testing**: Use this token to test the migration flow from Base to Vana without requiring real RDAT tokens

### Base Mainnet RDAT Reference

- **Address**: `0x4498cd8ba045e00673402353f5a4347562707e7d`
- **Explorer**: https://basescan.org/token/0x4498cd8ba045e00673402353f5a4347562707e7d
- **Total Supply**: 30,000,000 RDAT
- **Decimals**: 18
- **Symbol**: RDAT
- **Name**: RDataDAO Token