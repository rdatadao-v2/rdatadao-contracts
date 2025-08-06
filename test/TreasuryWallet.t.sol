// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../src/TreasuryWallet.sol";
import "../src/interfaces/ITreasuryWallet.sol";
import "../src/RDATUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract TreasuryWalletTest is Test {
    TreasuryWallet public implementation;
    TreasuryWallet public treasury;
    RDATUpgradeable public rdatImpl;
    RDATUpgradeable public rdat;
    
    address public admin = makeAddr("admin");
    address public distributor = makeAddr("distributor");
    address public dao = makeAddr("dao");
    address public recipient = makeAddr("recipient");
    address public migrationBridge = makeAddr("migrationBridge");
    
    // Events
    event VestingScheduleCreated(bytes32 indexed allocation, uint256 total, uint256 tgeUnlock);
    event TokensReleased(bytes32 indexed allocation, uint256 amount);
    event TokensDistributed(address indexed recipient, uint256 amount, string reason);
    event Phase3Activated(uint256 timestamp);
    event DAOProposalExecuted(uint256 indexed proposalId);
    
    function setUp() public {
        // Deploy implementations
        implementation = new TreasuryWallet();
        rdatImpl = new RDATUpgradeable();
        
        // Calculate deterministic treasury address
        bytes32 salt = keccak256("TREASURY_V2");
        bytes memory treasuryBytecode = abi.encodePacked(
            type(ERC1967Proxy).creationCode,
            abi.encode(address(implementation), "")
        );
        address predictedTreasury = address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            address(this),
            salt,
            keccak256(treasuryBytecode)
        )))));
        
        // Deploy RDAT proxy with predicted treasury address
        bytes memory rdatInitData = abi.encodeCall(
            RDATUpgradeable.initialize,
            (predictedTreasury, admin, migrationBridge)
        );
        rdat = RDATUpgradeable(address(new ERC1967Proxy(address(rdatImpl), rdatInitData)));
        
        // Deploy treasury proxy using CREATE2
        treasury = TreasuryWallet(payable(address(new ERC1967Proxy{salt: salt}(address(implementation), ""))));
        
        // Initialize treasury with RDAT address
        bytes memory treasuryInitData = abi.encodeCall(
            TreasuryWallet.initialize,
            (admin, address(rdat))
        );
        (bool success,) = address(treasury).call(treasuryInitData);
        require(success, "Treasury init failed");
        
        // Grant additional roles
        vm.startPrank(admin);
        treasury.grantRole(treasury.DISTRIBUTOR_ROLE(), distributor);
        treasury.grantRole(treasury.DAO_ROLE(), dao);
        vm.stopPrank();
        
        // Verify treasury received tokens
        assertEq(rdat.balanceOf(address(treasury)), 70_000_000e18);
    }
    
    function test_Initialization() public view {
        // Check roles
        assertTrue(treasury.hasRole(treasury.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(treasury.hasRole(treasury.UPGRADER_ROLE(), admin));
        assertTrue(treasury.hasRole(treasury.DISTRIBUTOR_ROLE(), admin));
        assertTrue(treasury.hasRole(treasury.DISTRIBUTOR_ROLE(), distributor));
        assertTrue(treasury.hasRole(treasury.DAO_ROLE(), dao));
        
        // Check RDAT
        assertEq(address(treasury.rdat()), address(rdat));
        
        // Check vesting schedules are created
        (uint256 total, uint256 released,,) = treasury.getVestingInfo(treasury.FUTURE_REWARDS());
        assertEq(total, 30_000_000e18);
        assertEq(released, 0);
        
        (total, released,,) = treasury.getVestingInfo(treasury.TREASURY_ECOSYSTEM());
        assertEq(total, 25_000_000e18);
        assertEq(released, 0);
        
        (total, released,,) = treasury.getVestingInfo(treasury.LIQUIDITY_STAKING());
        assertEq(total, 15_000_000e18);
        assertEq(released, 0);
    }
    
    function test_TGEUnlocks() public {
        // Check available amounts at TGE
        (,, uint256 available, bool isActive) = treasury.getVestingInfo(treasury.FUTURE_REWARDS());
        assertEq(available, 0); // Phase 3 gated
        assertFalse(isActive);
        
        (,, available, isActive) = treasury.getVestingInfo(treasury.TREASURY_ECOSYSTEM());
        assertEq(available, 2_500_000e18); // 10% TGE unlock
        assertTrue(isActive);
        
        (,, available, isActive) = treasury.getVestingInfo(treasury.LIQUIDITY_STAKING());
        assertEq(available, 4_950_000e18); // 33% TGE unlock
        assertTrue(isActive);
    }
    
    function test_CheckAndRelease_TGE() public {
        // Release TGE amounts
        vm.expectEmit(true, false, false, true);
        emit TokensReleased(treasury.TREASURY_ECOSYSTEM(), 2_500_000e18);
        
        vm.expectEmit(true, false, false, true);
        emit TokensReleased(treasury.LIQUIDITY_STAKING(), 4_950_000e18);
        
        treasury.checkAndRelease();
        
        // Check released amounts
        (uint256 total, uint256 released,,) = treasury.getVestingInfo(treasury.TREASURY_ECOSYSTEM());
        assertEq(released, 2_500_000e18);
        
        (total, released,,) = treasury.getVestingInfo(treasury.LIQUIDITY_STAKING());
        assertEq(released, 4_950_000e18);
        
        // Future rewards should still be 0
        (total, released,,) = treasury.getVestingInfo(treasury.FUTURE_REWARDS());
        assertEq(released, 0);
    }
    
    function test_Distribute() public {
        // First release TGE funds
        treasury.checkAndRelease();
        
        // Distribute some tokens
        vm.startPrank(distributor);
        
        uint256 distributionAmount = 1_000_000e18;
        vm.expectEmit(true, false, false, true);
        emit TokensDistributed(recipient, distributionAmount, "Test distribution");
        
        treasury.distribute(recipient, distributionAmount, "Test distribution");
        
        // Check balances
        assertEq(rdat.balanceOf(recipient), distributionAmount);
        assertEq(treasury.distributionHistory(recipient), distributionAmount);
        assertEq(treasury.totalDistributed(), distributionAmount);
        
        vm.stopPrank();
    }
    
    function test_Distribute_RevertConditions() public {
        vm.startPrank(distributor);
        
        // Invalid recipient
        vm.expectRevert("Invalid recipient");
        treasury.distribute(address(0), 1e18, "test");
        
        // Invalid amount
        vm.expectRevert("Invalid amount");
        treasury.distribute(recipient, 0, "test");
        
        // Empty reason
        vm.expectRevert("Reason required");
        treasury.distribute(recipient, 1e18, "");
        
        // Insufficient balance
        vm.expectRevert("Insufficient balance");
        treasury.distribute(recipient, 100_000_000e18, "test");
        
        vm.stopPrank();
        
        // Unauthorized
        vm.expectRevert();
        treasury.distribute(recipient, 1e18, "test");
    }
    
    function test_Phase3Activation() public {
        // Check initial state
        assertFalse(treasury.phase3Active());
        
        // Activate Phase 3
        vm.startPrank(admin);
        
        vm.expectEmit(false, false, false, true);
        emit Phase3Activated(block.timestamp);
        
        treasury.setPhase3Active();
        
        assertTrue(treasury.phase3Active());
        
        // Try to activate again
        vm.expectRevert("Already active");
        treasury.setPhase3Active();
        
        vm.stopPrank();
        
        // Check Future Rewards now available
        (,, uint256 available, bool isActive) = treasury.getVestingInfo(treasury.FUTURE_REWARDS());
        assertEq(available, 30_000_000e18);
        assertTrue(isActive);
    }
    
    function test_Phase3_CheckAndRelease() public {
        // Activate Phase 3
        vm.prank(admin);
        treasury.setPhase3Active();
        
        // Release Future Rewards
        vm.expectEmit(true, false, false, true);
        emit TokensReleased(treasury.FUTURE_REWARDS(), 30_000_000e18);
        
        treasury.checkAndRelease();
        
        // Check released
        (, uint256 released,,) = treasury.getVestingInfo(treasury.FUTURE_REWARDS());
        assertEq(released, 30_000_000e18);
    }
    
    function test_TreasuryVesting() public {
        // Release TGE first
        treasury.checkAndRelease();
        
        // Before cliff - no more available
        (,, uint256 available,) = treasury.getVestingInfo(treasury.TREASURY_ECOSYSTEM());
        assertEq(available, 0);
        
        // Fast forward past cliff (6 months)
        skip(180 days + 1);
        
        // Some should be available
        (,, available,) = treasury.getVestingInfo(treasury.TREASURY_ECOSYSTEM());
        assertGt(available, 0);
        
        // Release vested amount
        treasury.checkAndRelease();
        
        (, uint256 released,,) = treasury.getVestingInfo(treasury.TREASURY_ECOSYSTEM());
        assertGt(released, 2_500_000e18); // More than just TGE
        
        // Fast forward to end of vesting
        skip(540 days);
        
        // All should be available
        (,, available,) = treasury.getVestingInfo(treasury.TREASURY_ECOSYSTEM());
        treasury.checkAndRelease();
        
        (, released,,) = treasury.getVestingInfo(treasury.TREASURY_ECOSYSTEM());
        assertEq(released, 25_000_000e18); // Full amount
    }
    
    function test_DAOProposalExecution() public {
        // Create a simple proposal to transfer tokens
        address[] memory targets = new address[](1);
        targets[0] = address(rdat);
        
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeCall(IERC20.transfer, (recipient, 1_000_000e18));
        
        // First need to release and distribute tokens to have them available
        treasury.checkAndRelease();
        vm.prank(distributor);
        treasury.distribute(address(treasury), 1_000_000e18, "For DAO proposal");
        
        // Execute proposal
        vm.startPrank(dao);
        
        vm.expectEmit(true, false, false, false);
        emit DAOProposalExecuted(123);
        
        treasury.executeDAOProposal(123, targets, values, calldatas);
        
        // Check recipient received tokens
        assertEq(rdat.balanceOf(recipient), 1_000_000e18);
        
        vm.stopPrank();
    }
    
    function test_GetAllVestingSchedules() public view {
        // Check Future Rewards
        (uint256 total, uint256 released,, bool isActive) = treasury.getVestingInfo(treasury.FUTURE_REWARDS());
        assertEq(total, 30_000_000e18);
        assertEq(released, 0);
        assertFalse(isActive); // Phase 3 gated
        
        // Check Treasury Ecosystem
        (total, released,, isActive) = treasury.getVestingInfo(treasury.TREASURY_ECOSYSTEM());
        assertEq(total, 25_000_000e18);
        assertEq(released, 0);
        assertTrue(isActive);
        
        // Check Liquidity Staking
        (total, released,, isActive) = treasury.getVestingInfo(treasury.LIQUIDITY_STAKING());
        assertEq(total, 15_000_000e18);
        assertEq(released, 0);
        assertTrue(isActive);
    }
    
    function test_ReceiveETH() public {
        // Send ETH to treasury
        uint256 amount = 1 ether;
        (bool success,) = payable(address(treasury)).call{value: amount}("");
        assertTrue(success);
        
        assertEq(address(treasury).balance, amount);
    }
    
    function test_LinearVestingCalculations() public {
        // Release TGE
        treasury.checkAndRelease();
        
        // Treasury has 25M total, 2.5M released at TGE
        // Remaining 22.5M vests over 18 months after 6 month cliff
        
        // Fast forward to middle of vesting (6 months cliff + 9 months vesting)
        skip(180 days + 270 days);
        
        (uint256 total,, uint256 available,) = treasury.getVestingInfo(treasury.TREASURY_ECOSYSTEM());
        
        // Should have ~50% of remaining available
        // After TGE claimed, only the additional vested amount is available
        // 50% of 22.5M = 11.25M
        uint256 expectedAvailable = 22_500_000e18 / 2;
        
        // Allow for small rounding differences
        assertApproxEqAbs(available, expectedAvailable, 1e18);
    }
    
    function test_MultipleClaims() public {
        // Test that we can claim multiple times as vesting progresses
        treasury.checkAndRelease();
        
        (, uint256 released1,,) = treasury.getVestingInfo(treasury.TREASURY_ECOSYSTEM());
        
        // Fast forward 1 year
        skip(365 days);
        treasury.checkAndRelease();
        
        (, uint256 released2,,) = treasury.getVestingInfo(treasury.TREASURY_ECOSYSTEM());
        assertGt(released2, released1);
        
        // Fast forward to end of vesting (total 24 months: 6 cliff + 18 vesting)
        skip(365 days); // Another year to reach 2 years total
        treasury.checkAndRelease();
        
        (, uint256 released3,,) = treasury.getVestingInfo(treasury.TREASURY_ECOSYSTEM());
        assertEq(released3, 25_000_000e18); // Should be fully vested
    }
    
    function testFuzz_Distribution(uint256 amount, string memory reason) public {
        vm.assume(amount > 0 && amount <= 50_000_000e18);
        vm.assume(bytes(reason).length > 0);
        
        // Release some funds
        treasury.checkAndRelease();
        
        vm.prank(distributor);
        treasury.distribute(recipient, amount, reason);
        
        assertEq(rdat.balanceOf(recipient), amount);
        assertEq(treasury.distributionHistory(recipient), amount);
        assertEq(treasury.totalDistributed(), amount);
    }
}