// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {MigrationBonusVesting} from "../src/MigrationBonusVesting.sol";
import {VanaMigrationBridge} from "../src/VanaMigrationBridge.sol";
import {RDATUpgradeable} from "../src/RDATUpgradeable.sol";
import {TreasuryWallet} from "../src/TreasuryWallet.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MigrationBonusVestingTest is Test {
    MigrationBonusVesting public vesting;
    VanaMigrationBridge public bridge;
    RDATUpgradeable public rdat;
    TreasuryWallet public treasury;
    
    address public admin = address(0x1);
    address public treasuryAdmin = address(0x2);
    address public migrationContract = address(0x3);
    address public validator1 = address(0x11);
    address public validator2 = address(0x12);
    address public validator3 = address(0x13);
    address public user1 = address(0x21);
    address public user2 = address(0x22);
    
    uint256 public constant TREASURY_ALLOCATION = 70_000_000e18;
    uint256 public constant MIGRATION_ALLOCATION = 30_000_000e18;
    uint256 public constant BONUS_ALLOCATION = 2_000_000e18;
    
    function setUp() public {
        // Deploy RDAT
        RDATUpgradeable rdatImpl = new RDATUpgradeable();
        
        // First deploy treasury implementation
        TreasuryWallet treasuryImpl = new TreasuryWallet();
        
        // Calculate future RDAT proxy address
        address expectedRdatAddress = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 2);
        
        // Deploy treasury proxy with expected RDAT address
        bytes memory treasuryInitData = abi.encodeWithSelector(
            TreasuryWallet.initialize.selector,
            treasuryAdmin,
            expectedRdatAddress
        );
        ERC1967Proxy treasuryProxy = new ERC1967Proxy(address(treasuryImpl), treasuryInitData);
        treasury = TreasuryWallet(payable(address(treasuryProxy)));
        
        // Deploy RDAT proxy
        bytes memory rdatInitData = abi.encodeWithSelector(
            RDATUpgradeable.initialize.selector,
            address(treasury),
            admin,
            migrationContract
        );
        ERC1967Proxy rdatProxy = new ERC1967Proxy(address(rdatImpl), rdatInitData);
        rdat = RDATUpgradeable(address(rdatProxy));
        
        // Verify RDAT address matches expected
        require(address(rdat) == expectedRdatAddress, "RDAT address mismatch");
        
        // Deploy migration bridge
        address[] memory validators = new address[](3);
        validators[0] = validator1;
        validators[1] = validator2;
        validators[2] = validator3;
        
        bridge = new VanaMigrationBridge(address(rdat), admin, validators);
        
        // Deploy bonus vesting
        vesting = new MigrationBonusVesting(address(rdat), admin);
        
        // Configure contracts
        vm.startPrank(admin);
        vesting.setMigrationBridge(address(bridge));
        bridge.setBonusVesting(address(vesting));
        vm.stopPrank();
        
        // Fund contracts from treasury
        vm.startPrank(treasuryAdmin);
        // Fund migration bridge with 30M for 1:1 exchange
        treasury.distribute(address(bridge), MIGRATION_ALLOCATION, "Migration allocation");
        // Fund vesting contract with 2M for bonuses
        treasury.distribute(address(vesting), BONUS_ALLOCATION, "Migration bonus incentives");
        vm.stopPrank();
    }
    
    function test_InitialState() public view {
        assertEq(address(vesting.rdatToken()), address(rdat));
        assertEq(vesting.VESTING_DURATION(), 365 days);
        assertEq(vesting.CLIFF_DURATION(), 0);
        assertTrue(vesting.hasRole(vesting.MIGRATION_BRIDGE_ROLE(), address(bridge)));
        assertEq(rdat.balanceOf(address(vesting)), BONUS_ALLOCATION);
    }
    
    function test_MigrationWithBonusVesting() public {
        uint256 migrationAmount = 100_000e18;
        bytes32 burnTxHash = keccak256("burn1");
        
        // Submit validations
        vm.prank(validator1);
        bridge.submitValidation(user1, migrationAmount, burnTxHash, 12345);
        
        vm.prank(validator2);
        bridge.submitValidation(user1, migrationAmount, burnTxHash, 12345);
        
        // Warp past challenge period
        vm.warp(block.timestamp + 7 hours);
        
        // Execute migration
        bytes32 requestId = keccak256(abi.encodePacked(user1, migrationAmount, burnTxHash));
        uint256 expectedBonus = bridge.calculateBonus(migrationAmount); // 5% = 5000 RDAT
        
        bridge.executeMigration(requestId);
        
        // Check user received base amount immediately
        assertEq(rdat.balanceOf(user1), migrationAmount);
        
        // Check bonus was granted in vesting
        assertEq(vesting.allocations(user1), expectedBonus);
        assertEq(vesting.beneficiaryEligibilityDates(user1), block.timestamp);
        
        // Check no bonus tokens vested yet (just started)
        assertEq(vesting.calculateVestedAmount(user1), 0);
        assertEq(vesting.getClaimableAmount(user1), 0);
        
        // Warp 6 months - should have 50% vested
        vm.warp(block.timestamp + 182.5 days);
        uint256 halfBonus = expectedBonus / 2;
        assertApproxEqAbs(vesting.calculateVestedAmount(user1), halfBonus, 1e15); // Allow small rounding
        
        // Claim half the bonus
        vm.prank(user1);
        vesting.claim();
        assertApproxEqAbs(rdat.balanceOf(user1), migrationAmount + halfBonus, 1e15);
        
        // Warp to 12 months - should have 100% vested
        vm.warp(block.timestamp + 182.5 days);
        assertEq(vesting.calculateVestedAmount(user1), expectedBonus);
        
        // Claim remaining bonus
        vm.prank(user1);
        vesting.claim();
        assertEq(rdat.balanceOf(user1), migrationAmount + expectedBonus);
    }
    
    function test_MultipleMigrationsWithDecayingBonus() public {
        uint256 amount = 100_000e18;
        address[3] memory users = [user1, user2, address(0x23)];
        uint256[3] memory expectedBonuses;
        expectedBonuses[0] = 5_000e18;  // 5% for week 1
        expectedBonuses[1] = 3_000e18;  // 3% for week 3
        expectedBonuses[2] = 1_000e18;  // 1% for week 5
        
        // Process migrations at different times
        for (uint i = 0; i < users.length; i++) {
            // Warp to appropriate week
            if (i == 1) vm.warp(bridge.deploymentTime() + 3 weeks);
            if (i == 2) vm.warp(bridge.deploymentTime() + 5 weeks);
            
            bytes32 burnTxHash = keccak256(abi.encodePacked("burn", i));
            
            // Submit validations
            vm.prank(validator1);
            bridge.submitValidation(users[i], amount, burnTxHash, 12345 + i);
            
            vm.prank(validator2);
            bridge.submitValidation(users[i], amount, burnTxHash, 12345 + i);
            
            // Wait and execute
            vm.warp(block.timestamp + 7 hours);
            bytes32 requestId = keccak256(abi.encodePacked(users[i], amount, burnTxHash));
            bridge.executeMigration(requestId);
            
            // Verify bonus allocation
            assertEq(vesting.allocations(users[i]), expectedBonuses[i]);
        }
        
        // Verify total allocations don't exceed funding
        assertEq(vesting.getTotalAllocated(), 9_000e18); // 5k + 3k + 1k
        assertTrue(vesting.getTotalAllocated() <= BONUS_ALLOCATION);
    }
    
    function test_RevertManualBeneficiaryAddition() public {
        vm.prank(admin);
        vm.expectRevert("Use grantMigrationBonus instead");
        vesting.addBeneficiary(user1, 1000e18);
    }
    
    function test_RevertManualEligibilityDate() public {
        vm.prank(admin);
        vm.expectRevert("Eligibility date is automatic for migration bonuses");
        vesting.setEligibilityDate(block.timestamp + 30 days);
    }
    
    function test_RevertInsufficientFunds() public {
        // Try to grant more than available
        uint256 hugeAmount = 50_000_000e18; // 50M RDAT
        bytes32 burnTxHash = keccak256("huge");
        
        vm.prank(validator1);
        bridge.submitValidation(user1, hugeAmount, burnTxHash, 12345);
        
        vm.prank(validator2);
        bridge.submitValidation(user1, hugeAmount, burnTxHash, 12345);
        
        vm.warp(block.timestamp + 7 hours);
        
        // This should fail because bonus (2.5M) exceeds vesting contract balance (2M)
        bytes32 requestId = keccak256(abi.encodePacked(user1, hugeAmount, burnTxHash));
        vm.expectRevert(); // Will revert in vesting contract
        bridge.executeMigration(requestId);
    }
    
    function test_MigrationWithoutBonusContract() public {
        // Deploy new bridge without bonus vesting
        address[] memory validators = new address[](3);
        validators[0] = validator1;
        validators[1] = validator2;
        validators[2] = validator3;
        
        VanaMigrationBridge bridgeNoBonus = new VanaMigrationBridge(
            address(rdat),
            admin,
            validators
        );
        
        // Fund it
        vm.prank(treasuryAdmin);
        treasury.distribute(address(bridgeNoBonus), 1_000_000e18, "Test allocation");
        
        // Process migration
        uint256 amount = 100_000e18;
        bytes32 burnTxHash = keccak256("nobonus");
        
        vm.prank(validator1);
        bridgeNoBonus.submitValidation(user1, amount, burnTxHash, 12345);
        
        vm.prank(validator2);
        bridgeNoBonus.submitValidation(user1, amount, burnTxHash, 12345);
        
        vm.warp(block.timestamp + 7 hours);
        
        bytes32 requestId = keccak256(abi.encodePacked(user1, amount, burnTxHash));
        uint256 balanceBefore = rdat.balanceOf(user1);
        
        // Should work but user only gets base amount (no bonus)
        bridgeNoBonus.executeMigration(requestId);
        
        assertEq(rdat.balanceOf(user1), balanceBefore + amount);
        // No bonus vesting contract means no bonus, just 1:1 exchange
    }
}