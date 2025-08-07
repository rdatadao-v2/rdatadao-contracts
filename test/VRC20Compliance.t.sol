// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../src/RDATUpgradeable.sol";
import "../src/TreasuryWallet.sol";
import "../src/VanaMigrationBridge.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract VRC20ComplianceTest is Test {
    RDATUpgradeable public rdat;
    TreasuryWallet public treasury;
    VanaMigrationBridge public migrationBridge;
    
    address public admin = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public blacklistedUser = address(0x4);
    address public dlpRegistryAddress = address(0x5);
    
    uint256 constant TOTAL_SUPPLY = 100_000_000 * 10**18;
    uint256 constant TREASURY_ALLOCATION = 70_000_000 * 10**18;
    uint256 constant MIGRATION_ALLOCATION = 30_000_000 * 10**18;
    
    function setUp() public {
        vm.startPrank(admin);
        
        // Deploy implementation
        RDATUpgradeable implementation = new RDATUpgradeable();
        
        // Deploy treasury implementation and proxy
        TreasuryWallet treasuryImpl = new TreasuryWallet();
        bytes memory treasuryInitData = abi.encodeWithSelector(
            TreasuryWallet.initialize.selector,
            admin,
            address(0x100) // Temp RDAT address
        );
        ERC1967Proxy treasuryProxy = new ERC1967Proxy(
            address(treasuryImpl),
            treasuryInitData
        );
        treasury = TreasuryWallet(payable(address(treasuryProxy)));
        
        // Deploy migration bridge
        address[] memory validators = new address[](3);
        validators[0] = address(0x10);
        validators[1] = address(0x11);
        validators[2] = address(0x12);
        
        migrationBridge = new VanaMigrationBridge(
            address(0x100), // Temp RDAT address
            admin,
            validators
        );
        
        // Deploy proxy with initialization
        bytes memory initData = abi.encodeWithSelector(
            RDATUpgradeable.initialize.selector,
            address(treasury),
            admin,
            address(migrationBridge)
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );
        
        rdat = RDATUpgradeable(address(proxy));
        
        vm.stopPrank();
        
        // Give user1 some tokens directly for testing
        vm.prank(address(treasury));
        rdat.transfer(user1, 10000 * 10**18);
    }
    
    // ============ Blocklist Tests ============
    
    function test_Blacklist_AddAddress() public {
        vm.startPrank(admin);
        
        assertFalse(rdat.isBlacklisted(blacklistedUser));
        assertEq(rdat.blacklistCount(), 0);
        
        rdat.blacklist(blacklistedUser);
        
        assertTrue(rdat.isBlacklisted(blacklistedUser));
        assertEq(rdat.blacklistCount(), 1);
        
        vm.stopPrank();
    }
    
    function test_Blacklist_RemoveAddress() public {
        vm.startPrank(admin);
        
        rdat.blacklist(blacklistedUser);
        assertTrue(rdat.isBlacklisted(blacklistedUser));
        
        rdat.unBlacklist(blacklistedUser);
        assertFalse(rdat.isBlacklisted(blacklistedUser));
        assertEq(rdat.blacklistCount(), 0);
        
        vm.stopPrank();
    }
    
    function test_Blacklist_CannotBlacklistZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert("Cannot blacklist zero address");
        rdat.blacklist(address(0));
    }
    
    function test_Blacklist_CannotBlacklistTokenContract() public {
        vm.prank(admin);
        vm.expectRevert("Cannot blacklist token contract");
        rdat.blacklist(address(rdat));
    }
    
    function test_Blacklist_CannotDoubleBlacklist() public {
        vm.startPrank(admin);
        
        rdat.blacklist(blacklistedUser);
        
        vm.expectRevert("Already blacklisted");
        rdat.blacklist(blacklistedUser);
        
        vm.stopPrank();
    }
    
    function test_Blacklist_BlocksTransferFrom() public {
        vm.prank(admin);
        rdat.blacklist(user1);
        
        vm.prank(user1);
        vm.expectRevert("Sender is blacklisted");
        rdat.transfer(user2, 100 * 10**18);
    }
    
    function test_Blacklist_BlocksTransferTo() public {
        vm.prank(admin);
        rdat.blacklist(blacklistedUser);
        
        vm.prank(user1);
        vm.expectRevert("Recipient is blacklisted");
        rdat.transfer(blacklistedUser, 100 * 10**18);
    }
    
    function test_Blacklist_OnlyAdminCanBlacklist() public {
        vm.prank(user1);
        vm.expectRevert();
        rdat.blacklist(user2);
    }
    
    // ============ DLP Registry Tests ============
    
    function test_DLPRegistry_SetRegistry() public {
        vm.startPrank(admin);
        
        // Initially no registry
        (address registry,,,) = rdat.getDLPInfo();
        assertEq(registry, address(0));
        
        // Set registry
        rdat.setDLPRegistry(dlpRegistryAddress);
        
        (registry,,,) = rdat.getDLPInfo();
        assertEq(registry, dlpRegistryAddress);
        
        vm.stopPrank();
    }
    
    function test_DLPRegistry_UpdateRegistry() public {
        vm.startPrank(admin);
        
        rdat.setDLPRegistry(dlpRegistryAddress);
        
        address newRegistry = address(0x999);
        rdat.setDLPRegistry(newRegistry);
        
        (address registry,,,) = rdat.getDLPInfo();
        assertEq(registry, newRegistry);
        
        vm.stopPrank();
    }
    
    function test_DLPRegistry_CannotSetZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert("Invalid registry address");
        rdat.setDLPRegistry(address(0));
    }
    
    function test_DLPRegistry_Registration() public {
        vm.startPrank(admin);
        
        // Set registry first
        rdat.setDLPRegistry(dlpRegistryAddress);
        
        // Register with DLP
        uint256 dlpId = 42;
        rdat.updateDLPRegistration(dlpId);
        
        (address registry, bool registered, uint256 id, uint256 blockNum) = rdat.getDLPInfo();
        assertEq(registry, dlpRegistryAddress);
        assertTrue(registered);
        assertEq(id, dlpId);
        assertEq(blockNum, block.number);
        
        vm.stopPrank();
    }
    
    function test_DLPRegistry_CannotRegisterWithoutRegistry() public {
        vm.prank(admin);
        vm.expectRevert("DLP Registry not set");
        rdat.updateDLPRegistration(1);
    }
    
    function test_DLPRegistry_OnlyAdminCanSetRegistry() public {
        vm.prank(user1);
        vm.expectRevert();
        rdat.setDLPRegistry(dlpRegistryAddress);
    }
    
    // ============ Timelock Tests ============
    
    function test_Timelock_ScheduleAction() public {
        vm.startPrank(admin);
        
        string memory description = "Upgrade contract to V2";
        bytes32 actionId = rdat.scheduleTimelock(description);
        
        uint256 expiry = rdat.getTimelockExpiry(actionId);
        assertEq(expiry, block.timestamp + 48 hours);
        
        vm.stopPrank();
    }
    
    function test_Timelock_ExecuteAfterDelay() public {
        vm.startPrank(admin);
        
        bytes32 actionId = rdat.scheduleTimelock("Test action");
        
        // Cannot execute immediately
        vm.expectRevert("Timelock not expired");
        rdat.executeTimelock(actionId);
        
        // Fast forward 48 hours
        vm.warp(block.timestamp + 48 hours);
        
        // Now can execute
        rdat.executeTimelock(actionId);
        
        // Check marked as executed (value = 1)
        assertEq(rdat.getTimelockExpiry(actionId), 1);
        
        vm.stopPrank();
    }
    
    function test_Timelock_CancelAction() public {
        vm.startPrank(admin);
        
        bytes32 actionId = rdat.scheduleTimelock("Test action");
        uint256 expiry = rdat.getTimelockExpiry(actionId);
        assertTrue(expiry > 0);
        
        rdat.cancelTimelock(actionId);
        
        // Check deleted
        assertEq(rdat.getTimelockExpiry(actionId), 0);
        
        vm.stopPrank();
    }
    
    function test_Timelock_CannotExecuteNonExistent() public {
        vm.prank(admin);
        vm.expectRevert("Timelock not found");
        rdat.executeTimelock(bytes32(0));
    }
    
    function test_Timelock_CannotExecuteTwice() public {
        vm.startPrank(admin);
        
        bytes32 actionId = rdat.scheduleTimelock("Test");
        vm.warp(block.timestamp + 48 hours);
        rdat.executeTimelock(actionId);
        
        vm.expectRevert("Already executed");
        rdat.executeTimelock(actionId);
        
        vm.stopPrank();
    }
    
    function test_Timelock_OnlyAdminCanSchedule() public {
        vm.prank(user1);
        vm.expectRevert();
        rdat.scheduleTimelock("Unauthorized");
    }
    
    // ============ VRC-20 Compliance Check ============
    
    function test_VRC20_ComplianceStatus() public view {
        // Check VRC-20 compliance
        assertTrue(rdat.isVRC20Compliant());
        
        // Check individual components
        assertTrue(rdat.isVRC20());
        assertEq(rdat.TIMELOCK_DURATION(), 48 hours);
    }
    
    // ============ Integration Tests ============
    
    function test_Integration_FullVRC20Flow() public {
        vm.startPrank(admin);
        
        // 1. Set DLP Registry
        rdat.setDLPRegistry(dlpRegistryAddress);
        
        // 2. Register with DLP
        rdat.updateDLPRegistration(1);
        
        // 3. Blacklist bad actor
        rdat.blacklist(blacklistedUser);
        
        // 4. Schedule critical operation
        bytes32 upgradeId = rdat.scheduleTimelock("Upgrade to V3");
        
        vm.stopPrank();
        
        // 5. Verify compliance
        assertTrue(rdat.isVRC20Compliant());
        
        // 6. Verify DLP registration
        (, bool registered,,) = rdat.getDLPInfo();
        assertTrue(registered);
        
        // 7. Verify blacklist works
        assertTrue(rdat.isBlacklisted(blacklistedUser));
        
        // 8. Verify timelock is enforced
        uint256 expiry = rdat.getTimelockExpiry(upgradeId);
        assertGt(expiry, block.timestamp);
        
        // 9. Test blacklisted transfer fails
        vm.prank(user1);
        vm.expectRevert("Recipient is blacklisted");
        rdat.transfer(blacklistedUser, 100 * 10**18);
    }
    
    function test_Integration_PostDeploymentConfiguration() public {
        // Simulate post-deployment scenario
        
        // Initially no DLP registry
        (address registry,,,) = rdat.getDLPInfo();
        assertEq(registry, address(0));
        
        // Token is still VRC-20 compliant
        assertTrue(rdat.isVRC20Compliant());
        
        // Later, admin sets DLP registry
        vm.prank(admin);
        rdat.setDLPRegistry(dlpRegistryAddress);
        
        // And registers with DLP
        vm.prank(admin);
        rdat.updateDLPRegistration(123);
        
        // Verify registration
        (, bool registered, uint256 id,) = rdat.getDLPInfo();
        assertTrue(registered);
        assertEq(id, 123);
    }
}