// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {RDATUpgradeable} from "../src/RDATUpgradeable.sol";
import {Create2Factory} from "../src/Create2Factory.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract RDATUpgradeableTest is Test {
    RDATUpgradeable public implementation;
    RDATUpgradeable public rdat;
    Create2Factory public factory;

    address public admin;
    address public treasury;
    address public minter;
    address public pauser;
    address public user1;
    address public user2;
    address public migrationBridge;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    // MINTER_ROLE no longer exists in RDAT
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    uint256 public constant TOTAL_SUPPLY = 100_000_000 * 10 ** 18;
    uint256 public constant MIGRATION_ALLOCATION = 30_000_000 * 10 ** 18;

    event Upgraded(address indexed implementation);

    function setUp() public {
        admin = makeAddr("admin");
        treasury = makeAddr("treasury");
        minter = makeAddr("minter");
        pauser = makeAddr("pauser");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        migrationBridge = makeAddr("migrationBridge");

        // Deploy CREATE2 factory
        factory = new Create2Factory();

        // Deploy implementation
        implementation = new RDATUpgradeable();

        // Deploy proxy and initialize
        bytes memory initData =
            abi.encodeWithSelector(RDATUpgradeable.initialize.selector, treasury, admin, migrationBridge);

        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);

        rdat = RDATUpgradeable(address(proxy));

        // Grant roles
        vm.startPrank(admin);
        // RDAT no longer has MINTER_ROLE - all tokens minted at deployment
        rdat.grantRole(PAUSER_ROLE, pauser);
        vm.stopPrank();
    }

    function test_Initialization() public view {
        assertEq(rdat.name(), "r/datadao");
        assertEq(rdat.symbol(), "RDAT");
        assertEq(rdat.decimals(), 18);
        assertEq(rdat.totalSupply(), TOTAL_SUPPLY); // Full supply minted
        assertEq(rdat.balanceOf(treasury), TOTAL_SUPPLY - MIGRATION_ALLOCATION); // 70M to treasury
        assertEq(rdat.balanceOf(migrationBridge), MIGRATION_ALLOCATION); // 30M to migration
        assertEq(rdat.totalMinted(), TOTAL_SUPPLY); // All 100M minted

        assertTrue(rdat.hasRole(DEFAULT_ADMIN_ROLE, admin));
        assertTrue(rdat.hasRole(PAUSER_ROLE, admin));
        assertTrue(rdat.hasRole(UPGRADER_ROLE, admin));
    }

    function test_CannotReinitialize() public {
        vm.expectRevert();
        rdat.initialize(user1, user2, address(0x100));
    }

    function test_UpgradeAuthorization() public {
        // Deploy new implementation
        RDATUpgradeableV2 newImpl = new RDATUpgradeableV2();

        // Non-upgrader cannot upgrade
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user1, UPGRADER_ROLE)
        );
        rdat.upgradeToAndCall(address(newImpl), "");

        // Admin (with UPGRADER_ROLE) can upgrade
        vm.prank(admin);
        rdat.upgradeToAndCall(address(newImpl), "");

        // Verify upgrade
        RDATUpgradeableV2 upgradedRdat = RDATUpgradeableV2(address(rdat));
        assertEq(upgradedRdat.version(), "V2");
    }

    function test_StatePreservationAfterUpgrade() public {
        // Setup some state (transfer from treasury, no minting)
        vm.prank(treasury);
        rdat.transfer(user1, 1000 * 10 ** 18);

        vm.prank(user1);
        rdat.transfer(user2, 500 * 10 ** 18);

        uint256 user1BalanceBefore = rdat.balanceOf(user1);
        uint256 user2BalanceBefore = rdat.balanceOf(user2);
        uint256 totalMintedBefore = rdat.totalMinted();

        // Upgrade
        RDATUpgradeableV2 newImpl = new RDATUpgradeableV2();
        vm.prank(admin);
        rdat.upgradeToAndCall(address(newImpl), "");

        // Verify state is preserved
        assertEq(rdat.balanceOf(user1), user1BalanceBefore);
        assertEq(rdat.balanceOf(user2), user2BalanceBefore);
        assertEq(rdat.totalMinted(), totalMintedBefore);
        assertEq(rdat.totalSupply(), TOTAL_SUPPLY); // Fixed supply, no minting

        // Verify roles are preserved
        assertTrue(rdat.hasRole(DEFAULT_ADMIN_ROLE, admin));
        // MINTER_ROLE no longer exists
        assertTrue(rdat.hasRole(PAUSER_ROLE, pauser));
    }

    function test_CREATE2Deployment() public {
        // Deploy implementation via CREATE2
        bytes memory bytecode = type(RDATUpgradeable).creationCode;
        bytes32 salt = keccak256("RDAT_V2_IMPLEMENTATION");

        // Predict address
        address predictedAddr = factory.computeAddress(bytecode, salt);

        // Deploy
        address deployed = factory.deploy(bytecode, salt);
        assertEq(deployed, predictedAddr);

        // Deploy proxy via CREATE2
        bytes memory proxyBytecode = abi.encodePacked(
            type(ERC1967Proxy).creationCode,
            abi.encode(
                deployed, abi.encodeWithSelector(RDATUpgradeable.initialize.selector, treasury, admin, migrationBridge)
            )
        );

        bytes32 proxySalt = keccak256("RDAT_V2_PROXY");
        address predictedProxyAddr = factory.computeAddress(proxyBytecode, proxySalt);

        address deployedProxy = factory.deploy(proxyBytecode, proxySalt);
        assertEq(deployedProxy, predictedProxyAddr);

        // Verify the proxy works
        RDATUpgradeable rdatFromCreate2 = RDATUpgradeable(deployedProxy);
        assertEq(rdatFromCreate2.name(), "r/datadao");
        assertEq(rdatFromCreate2.totalSupply(), TOTAL_SUPPLY); // Full supply minted
    }

    function test_UpgradeWithReinitialize() public {
        // Deploy V2 with reinitialize function
        RDATUpgradeableV2WithReinit newImpl = new RDATUpgradeableV2WithReinit();

        // Upgrade and reinitialize in one transaction
        bytes memory reinitData = abi.encodeWithSelector(RDATUpgradeableV2WithReinit.reinitialize.selector, user1);

        vm.prank(admin);
        rdat.upgradeToAndCall(address(newImpl), reinitData);

        // Verify reinitialization worked
        RDATUpgradeableV2WithReinit upgradedRdat = RDATUpgradeableV2WithReinit(address(rdat));
        assertEq(upgradedRdat.newFeature(), user1);
    }

    function test_PauseAndUpgrade() public {
        // Pause the contract
        vm.prank(pauser);
        rdat.pause();

        // Verify transfers are paused
        vm.prank(treasury);
        vm.expectRevert();
        rdat.transfer(user1, 1000 * 10 ** 18);

        // Upgrade while paused
        RDATUpgradeableV2 newImpl = new RDATUpgradeableV2();
        vm.prank(admin);
        rdat.upgradeToAndCall(address(newImpl), "");

        // Verify still paused after upgrade
        vm.prank(treasury);
        vm.expectRevert();
        rdat.transfer(user1, 1000 * 10 ** 18);

        // Unpause
        vm.prank(pauser);
        rdat.unpause();

        // Now transfers work
        vm.prank(treasury);
        rdat.transfer(user1, 1000 * 10 ** 18);
        assertEq(rdat.balanceOf(user1), 1000 * 10 ** 18);
    }

    function test_FailedUpgradeRollback() public {
        // Deploy a bad implementation that will fail during upgrade
        BadImplementation badImpl = new BadImplementation();

        // Attempt upgrade (should fail)
        vm.prank(admin);
        vm.expectRevert();
        rdat.upgradeToAndCall(address(badImpl), "");

        // Verify contract still works with original implementation
        assertEq(rdat.name(), "r/datadao");
        vm.prank(treasury);
        rdat.transfer(user1, 1000 * 10 ** 18);
        assertEq(rdat.balanceOf(user1), 1000 * 10 ** 18);
    }
}

// Mock V2 implementation for testing
contract RDATUpgradeableV2 is RDATUpgradeable {
    function version() public pure returns (string memory) {
        return "V2";
    }
}

// Mock V2 with reinitialize function
contract RDATUpgradeableV2WithReinit is RDATUpgradeable {
    address public newFeature;

    function reinitialize(address _newFeature) public reinitializer(2) {
        newFeature = _newFeature;
    }
}

// Bad implementation for testing failed upgrades
contract BadImplementation {
    // Intentionally incompatible storage layout
    uint256 public badStorageSlot;
}
