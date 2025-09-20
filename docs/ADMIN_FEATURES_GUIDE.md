# Admin Features Guide for r/DataDAO Frontend

## Overview
This guide details all administrative features that need to be implemented in the frontend for multisig wallet holders and validators. These features are critical for managing the protocol but should only be accessible to authorized wallets.

## Wallet Roles & Permissions

### 1. Multisig Wallets (Highest Privileges)

#### Vana Multisig: `0xe4F7Eca807C57311e715C3Ef483e72Fa8D5bCcDF`
- **Network**: Vana Mainnet (Chain 1480)
- **Signers Required**: 3 of 5
- **Capabilities**:
  - Treasury management
  - Contract upgrades
  - Emergency pause
  - Validator management
  - DLP configuration
  - Vesting administration

#### Base Multisig: `0x90013583c66D2bf16327cB5Bc4a647AcceCF4B9A`
- **Network**: Base Mainnet (Chain 8453)
- **Capabilities**:
  - Migration bridge administration
  - Emergency pause on Base

### 2. Validators (Migration Signatures)
```javascript
const validators = {
  angela: '0xd36B49f2DB6aA708Ce7245e8ab2453C6DfFc9d6f',
  monkfenix: '0xC9Af4E56741f255743e8f4877d4cfa9971E910C2',
  baseMultisig: '0x08Cc5ed1bA3C95AA741f8AaEf631f716b037444b'
}
```
- **Required**: 2 of 3 signatures for migration approval
- **Capabilities**:
  - Sign migration requests
  - Validate data contributions
  - Monitor bridge operations

### 3. Individual Admin Roles
- **PAUSER_ROLE**: Can pause/unpause contracts
- **UPGRADER_ROLE**: Can upgrade UUPS contracts
- **TREASURY_ROLE**: Can execute treasury operations

## Admin Interface Requirements

### 1. Authentication & Access Control

```typescript
interface AdminAuth {
  // Check if connected wallet is admin
  isAdmin(): Promise<boolean>;

  // Check specific role
  hasRole(role: string): Promise<boolean>;

  // Get all roles for address
  getRoles(address: string): Promise<string[]>;

  // Verify multisig ownership
  isMultisigOwner(address: string): Promise<boolean>;
}

// Implementation
async function checkAdminAccess(userAddress: string): Promise<AdminAccess> {
  const access = {
    isVanaMultisig: userAddress.toLowerCase() === '0xe4f7eca807c57311e715c3ef483e72fa8d5bccdcf',
    isBaseMultisig: userAddress.toLowerCase() === '0x90013583c66d2bf16327cb5bc4a647accecf4b9a',
    isValidator: VALIDATORS.includes(userAddress.toLowerCase()),
    roles: await fetchUserRoles(userAddress)
  };

  return {
    hasAdminAccess: access.isVanaMultisig || access.isBaseMultisig,
    canPause: access.roles.includes('PAUSER_ROLE'),
    canUpgrade: access.roles.includes('UPGRADER_ROLE'),
    canManageTreasury: access.roles.includes('TREASURY_ROLE'),
    ...access
  };
}
```

### 2. Treasury Management Panel

```typescript
interface TreasuryManagement {
  // View Functions
  getTreasuryBalance(): Promise<BigNumber>;
  getVestingSchedules(): Promise<VestingSchedule[]>;
  getDistributionHistory(): Promise<Distribution[]>;
  getPenaltyPool(): Promise<BigNumber>;

  // Admin Actions
  executeProposal(params: ProposalParams): Promise<Transaction>;
  withdrawPenalties(): Promise<Transaction>;
  updateVesting(scheduleId: string, params: VestingParams): Promise<Transaction>;
}

// UI Components
<TreasuryDashboard>
  <BalanceCard balance={treasuryBalance} />
  <VestingTimeline schedules={vestingSchedules} />
  <DistributionHistory entries={distributions} />

  {/* Admin Only */}
  {isMultisig && (
    <>
      <ProposalExecutor onExecute={handleProposal} />
      <PenaltyWithdrawal
        amount={penaltyPool}
        onWithdraw={handlePenaltyWithdraw}
      />
      <VestingManager
        schedules={vestingSchedules}
        onUpdate={handleVestingUpdate}
      />
    </>
  )}
</TreasuryDashboard>
```

### 3. Emergency Controls

```typescript
interface EmergencyControls {
  // Pause Functions
  pauseContract(contractAddress: string): Promise<Transaction>;
  unpauseContract(contractAddress: string): Promise<Transaction>;
  isPaused(contractAddress: string): Promise<boolean>;

  // Emergency Actions
  emergencyWithdraw(): Promise<Transaction>;
  setEmergencyAdmin(address: string): Promise<Transaction>;
}

// UI Implementation
<EmergencyPanel>
  <PauseControls>
    {contracts.map(contract => (
      <ContractPauseCard
        key={contract.address}
        contract={contract}
        isPaused={pauseStates[contract.address]}
        onPause={() => handlePause(contract.address)}
        onUnpause={() => handleUnpause(contract.address)}
      />
    ))}
  </PauseControls>

  <EmergencyActions>
    <Button
      variant="danger"
      onClick={handleEmergencyPauseAll}
    >
      Emergency Pause All
    </Button>

    <Button
      variant="warning"
      onClick={handleWithdrawPenalties}
    >
      Withdraw Penalty Pool
    </Button>
  </EmergencyActions>
</EmergencyPanel>
```

### 4. Validator Management

```typescript
interface ValidatorManagement {
  // View Functions
  getValidators(): Promise<string[]>;
  getRequiredSignatures(): Promise<number>;
  getValidatorStats(address: string): Promise<ValidatorStats>;

  // Admin Actions
  addValidator(address: string): Promise<Transaction>;
  removeValidator(address: string): Promise<Transaction>;
  updateSignatureThreshold(threshold: number): Promise<Transaction>;
}

// UI Component
<ValidatorPanel>
  <ValidatorList>
    {validators.map(validator => (
      <ValidatorCard
        key={validator.address}
        validator={validator}
        stats={validatorStats[validator.address]}
        onRemove={() => handleRemoveValidator(validator.address)}
      />
    ))}
  </ValidatorList>

  <AddValidator>
    <Input
      placeholder="Validator address"
      value={newValidatorAddress}
      onChange={setNewValidatorAddress}
    />
    <Button onClick={handleAddValidator}>Add Validator</Button>
  </AddValidator>

  <ThresholdSettings>
    <Label>Required Signatures: {requiredSignatures} of {validators.length}</Label>
    <Slider
      min={1}
      max={validators.length}
      value={requiredSignatures}
      onChange={handleUpdateThreshold}
    />
  </ThresholdSettings>
</ValidatorPanel>
```

### 5. Contract Upgrade Management

```typescript
interface UpgradeManagement {
  // UUPS Upgrade Functions
  proposeUpgrade(contractAddress: string, newImplementation: string): Promise<Transaction>;
  executeUpgrade(contractAddress: string): Promise<Transaction>;
  getImplementation(proxyAddress: string): Promise<string>;

  // Version Management
  getCurrentVersion(contractAddress: string): Promise<string>;
  getUpgradeHistory(contractAddress: string): Promise<Upgrade[]>;
}

// UI Component
<UpgradePanel>
  <ContractVersions>
    <VersionCard
      title="RDAT Token"
      proxy="0x2c1CB448cAf3579B2374EFe20068Ea97F72A996E"
      implementation={rdatImplementation}
      version={rdatVersion}
    />
    <VersionCard
      title="Treasury Wallet"
      proxy="0x77D2713972af12F1E3EF39b5395bfD65C862367C"
      implementation={treasuryImplementation}
      version={treasuryVersion}
    />
  </ContractVersions>

  <UpgradeProposal>
    <Select options={upgradableContracts} onChange={setSelectedContract} />
    <Input
      placeholder="New implementation address"
      value={newImplementation}
      onChange={setNewImplementation}
    />
    <Button onClick={handleProposeUpgrade}>Propose Upgrade</Button>
  </UpgradeProposal>
</UpgradePanel>
```

### 6. DLP Management

```typescript
interface DLPManagement {
  // DLP Configuration
  getDLPId(): Promise<number>;
  getDLPRegistry(): Promise<string>;
  isDLPRegistered(): Promise<boolean>;

  // Admin Actions
  updateDLPRegistration(dlpId: number): Promise<Transaction>;
  setDLPRegistry(registryAddress: string): Promise<Transaction>;
  updateDLPMetadata(metadata: DLPMetadata): Promise<Transaction>;
}

// Current Mainnet Configuration
const DLP_CONFIG = {
  dlpId: 40,
  registry: '0x4D59880a924526d1dD33260552Ff4328b1E18a43',
  dataDAO: '0xBbB0B59163b850dDC5139e98118774557c5d9F92',
  name: 'r/datadao',
  website: 'https://rdatadao.org'
};

// UI Component
<DLPManagementPanel>
  <DLPStatus
    registered={isDLPRegistered}
    dlpId={dlpId}
    registry={dlpRegistry}
  />

  <DLPConfiguration>
    <Input
      label="DLP ID"
      value={dlpId}
      onChange={setDlpId}
    />
    <Input
      label="Registry Address"
      value={registryAddress}
      onChange={setRegistryAddress}
    />
    <Button onClick={handleUpdateDLP}>Update DLP Registration</Button>
  </DLPConfiguration>
</DLPManagementPanel>
```

### 7. Migration Bridge Administration

```typescript
interface BridgeAdministration {
  // Statistics
  getTotalMigrated(): Promise<BigNumber>;
  getRemainingAllocation(): Promise<BigNumber>;
  getMigrationQueue(): Promise<Migration[]>;

  // Admin Actions
  pauseMigration(): Promise<Transaction>;
  resumeMigration(): Promise<Transaction>;
  processPendingMigrations(migrationIds: string[]): Promise<Transaction>;
  refundFailedMigration(migrationId: string): Promise<Transaction>;
}

// UI Component
<BridgeAdminPanel>
  <MigrationStats>
    <StatCard label="Total Migrated" value={totalMigrated} />
    <StatCard label="Remaining Pool" value={remainingAllocation} />
    <StatCard label="Pending Migrations" value={pendingCount} />
  </MigrationStats>

  <PendingMigrations>
    {pendingMigrations.map(migration => (
      <MigrationCard
        key={migration.id}
        migration={migration}
        onProcess={() => handleProcessMigration(migration.id)}
        onRefund={() => handleRefundMigration(migration.id)}
      />
    ))}
  </PendingMigrations>

  <BridgeControls>
    <Button
      onClick={handlePauseBridge}
      disabled={isPaused}
    >
      Pause Bridge
    </Button>
    <Button
      onClick={handleResumeBridge}
      disabled={!isPaused}
    >
      Resume Bridge
    </Button>
  </BridgeControls>
</BridgeAdminPanel>
```

## Security Implementation

### 1. Role-Based Access Control

```typescript
// Middleware to protect admin routes
function requireAdmin(Component: React.FC) {
  return function AdminProtectedComponent(props: any) {
    const { address } = useAccount();
    const [isAdmin, setIsAdmin] = useState(false);

    useEffect(() => {
      checkAdminAccess(address).then(access => {
        setIsAdmin(access.hasAdminAccess);
      });
    }, [address]);

    if (!isAdmin) {
      return <UnauthorizedMessage />;
    }

    return <Component {...props} />;
  };
}

// Usage
const AdminPanel = requireAdmin(AdminPanelComponent);
```

### 2. Transaction Validation

```typescript
// Always validate admin transactions
async function validateAdminTransaction(
  action: string,
  params: any,
  signerAddress: string
): Promise<ValidationResult> {
  // Check role permissions
  const hasPermission = await checkPermission(action, signerAddress);
  if (!hasPermission) {
    return { valid: false, error: 'Insufficient permissions' };
  }

  // Validate parameters
  const validation = validateParams(action, params);
  if (!validation.valid) {
    return validation;
  }

  // Check contract state
  const isPaused = await checkPausedState();
  if (isPaused && action !== 'unpause') {
    return { valid: false, error: 'Contract is paused' };
  }

  return { valid: true };
}
```

### 3. Audit Logging

```typescript
// Log all admin actions
interface AdminActionLog {
  timestamp: number;
  action: string;
  params: any;
  signer: string;
  txHash: string;
  status: 'pending' | 'success' | 'failed';
}

async function logAdminAction(
  action: string,
  params: any,
  txHash: string
): Promise<void> {
  const log: AdminActionLog = {
    timestamp: Date.now(),
    action,
    params,
    signer: await signer.getAddress(),
    txHash,
    status: 'pending'
  };

  // Store in backend
  await api.post('/admin/logs', log);

  // Monitor transaction
  const receipt = await provider.waitForTransaction(txHash);
  log.status = receipt.status === 1 ? 'success' : 'failed';

  await api.put(`/admin/logs/${txHash}`, log);
}
```

## Testing Admin Features

### 1. Testnet Configuration
```typescript
// Use testnet multisigs for testing
const TESTNET_MULTISIGS = {
  vana: '0x29CeA936835D189BD5BEBA80Fe091f1Da29aA319',
  base: '0xdc096Bc0e5d7aB53C7Bd3cbb72B092d1054E393e'
};

// Test with mock signer
const mockMultisigSigner = new ethers.Wallet(
  TEST_PRIVATE_KEY,
  provider
);
```

### 2. Admin Feature Tests
```typescript
describe('Admin Features', () => {
  it('should only show admin panel to multisig', async () => {
    // Connect as multisig
    await connectWallet(VANA_MULTISIG);
    expect(screen.getByTestId('admin-panel')).toBeInTheDocument();

    // Connect as regular user
    await connectWallet(USER_ADDRESS);
    expect(screen.queryByTestId('admin-panel')).toBeNull();
  });

  it('should execute treasury proposal', async () => {
    await connectWallet(VANA_MULTISIG);

    const proposal = {
      to: '0x...',
      amount: parseUnits('1000', 18),
      reason: 'Development fund'
    };

    const tx = await executeProposal(proposal);
    expect(tx.hash).toBeDefined();
  });

  it('should pause contract in emergency', async () => {
    await connectWallet(VANA_MULTISIG);

    const tx = await pauseContract(RDAT_TOKEN_ADDRESS);
    await tx.wait();

    const isPaused = await checkPausedState(RDAT_TOKEN_ADDRESS);
    expect(isPaused).toBe(true);
  });
});
```

## Admin Dashboard Layout

```typescript
// Main admin dashboard structure
<AdminDashboard>
  <Header>
    <Title>r/DataDAO Admin Panel</Title>
    <ConnectedWallet address={address} role={role} />
  </Header>

  <Navigation>
    <Tab>Treasury</Tab>
    <Tab>Validators</Tab>
    <Tab>Bridge</Tab>
    <Tab>Emergency</Tab>
    <Tab>Upgrades</Tab>
    <Tab>DLP</Tab>
  </Navigation>

  <Content>
    <Route path="/admin/treasury" component={TreasuryPanel} />
    <Route path="/admin/validators" component={ValidatorPanel} />
    <Route path="/admin/bridge" component={BridgePanel} />
    <Route path="/admin/emergency" component={EmergencyPanel} />
    <Route path="/admin/upgrades" component={UpgradePanel} />
    <Route path="/admin/dlp" component={DLPPanel} />
  </Content>

  <ActivityLog>
    <RecentActions actions={recentAdminActions} />
  </ActivityLog>
</AdminDashboard>
```

## Implementation Checklist

### Phase 1: Basic Admin Features
- [ ] Role detection and authentication
- [ ] Treasury balance display
- [ ] Vesting schedule viewer
- [ ] Basic pause/unpause controls

### Phase 2: Advanced Management
- [ ] Treasury proposal execution
- [ ] Penalty withdrawal
- [ ] Validator management
- [ ] Migration bridge controls

### Phase 3: Protocol Governance
- [ ] Contract upgrade interface
- [ ] DLP configuration
- [ ] Advanced emergency controls
- [ ] Comprehensive audit logging

### Phase 4: Analytics & Monitoring
- [ ] Admin action history
- [ ] Protocol statistics dashboard
- [ ] Alert system for critical events
- [ ] Automated reports

## Important Notes

1. **Always verify multisig ownership** before showing admin features
2. **Log all admin actions** for audit trail
3. **Implement confirmation dialogs** for critical actions
4. **Show transaction status** clearly during execution
5. **Handle errors gracefully** with user-friendly messages
6. **Test thoroughly on testnet** before mainnet deployment

## Support

For technical questions about admin features:
- Review contract source code in `/src`
- Check role definitions in contracts
- Test on Vana Moksha testnet first
- Coordinate with multisig signers for testing

---

Last Updated: September 20, 2025
Status: Mainnet Deployed
Admin Features: Required for Protocol Management