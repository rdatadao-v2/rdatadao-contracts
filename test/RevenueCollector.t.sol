// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../src/RevenueCollector.sol";
import "../src/StakingPositions.sol";
import "../src/RDATUpgradeable.sol";
import "../src/vRDAT.sol";
import "../src/mocks/MockERC20.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title RevenueCollectorTest
 * @author r/datadao
 * @notice Comprehensive tests for RevenueCollector contract
 */
contract RevenueCollectorTest is Test {
    RevenueCollector public revenueCollector;
    StakingPositions public stakingPositions;
    RDATUpgradeable public rdat;
    vRDAT public vrdat;
    MockERC20 public mockToken;
    MockERC20 public secondToken;
    
    address public admin = address(0x1);
    address public treasury = address(0x2);
    address public contributorPool = address(0x3);
    address public revenueSource = address(0x4);
    address public user = address(0x5);
    
    uint256 constant REVENUE_AMOUNT = 10000e18; // 10,000 tokens
    uint256 constant THRESHOLD = 1000e18; // 1,000 tokens
    
    function setUp() public {
        vm.startPrank(admin);
        
        // Deploy RDAT
        RDATUpgradeable rdatImpl = new RDATUpgradeable();
        bytes memory rdatInitData = abi.encodeCall(
            rdatImpl.initialize,
            (treasury, admin, address(0x100)) // migration contract address
        );
        ERC1967Proxy rdatProxy = new ERC1967Proxy(address(rdatImpl), rdatInitData);
        rdat = RDATUpgradeable(address(rdatProxy));
        
        // Deploy vRDAT
        vrdat = new vRDAT(admin);
        // No mint delay needed for soul-bound tokens
        
        // Deploy StakingPositions
        StakingPositions stakingImpl = new StakingPositions();
        bytes memory stakingInitData = abi.encodeCall(
            stakingImpl.initialize,
            (address(rdat), address(vrdat), admin)
        );
        ERC1967Proxy stakingProxy = new ERC1967Proxy(address(stakingImpl), stakingInitData);
        stakingPositions = StakingPositions(address(stakingProxy));
        
        // Deploy RevenueCollector
        RevenueCollector revenueImpl = new RevenueCollector();
        bytes memory revenueInitData = abi.encodeCall(
            revenueImpl.initialize,
            (address(stakingPositions), treasury, contributorPool, admin)
        );
        ERC1967Proxy revenueProxy = new ERC1967Proxy(address(revenueImpl), revenueInitData);
        revenueCollector = RevenueCollector(address(revenueProxy));
        
        // Deploy mock tokens for testing
        mockToken = new MockERC20("Mock Token", "MOCK", 18);
        secondToken = new MockERC20("Second Token", "SECOND", 18);
        
        // Setup roles and permissions
        // RDAT no longer has MINTER_ROLE - all tokens minted at deployment
        vrdat.grantRole(vrdat.MINTER_ROLE(), address(stakingPositions));
        revenueCollector.grantRole(revenueCollector.REVENUE_REPORTER_ROLE(), revenueSource);
        
        // Grant ADMIN_ROLE to RevenueCollector so it can call notifyRewardAmount
        stakingPositions.grantRole(stakingPositions.ADMIN_ROLE(), address(revenueCollector));
        
        // Mint test tokens
        mockToken.mint(revenueSource, REVENUE_AMOUNT * 10);
        secondToken.mint(revenueSource, REVENUE_AMOUNT * 5);
        
        // Transfer RDAT from treasury to user (no minting)
        vm.startPrank(treasury);
        rdat.transfer(user, 1000e18);
        vm.stopPrank();
        
        vm.startPrank(admin);
        
        vm.stopPrank();
    }
    
    // ============ Initialization Tests ============
    
    function test_InitializationValues() public {
        assertEq(address(revenueCollector.stakingPositions()), address(stakingPositions));
        assertEq(revenueCollector.treasury(), treasury);
        assertEq(revenueCollector.contributorPool(), contributorPool);
        
        // Check distribution ratios
        assertEq(revenueCollector.STAKING_SHARE(), 5000); // 50%
        assertEq(revenueCollector.TREASURY_SHARE(), 3000); // 30%
        assertEq(revenueCollector.CONTRIBUTOR_SHARE(), 2000); // 20%
        assertEq(revenueCollector.PRECISION(), 10000); // 100%
    }
    
    function test_CannotInitializeWithZeroAddresses() public {
        RevenueCollector newImpl = new RevenueCollector();
        
        // Test invalid staking positions
        vm.expectRevert("Invalid staking positions");
        new ERC1967Proxy(
            address(newImpl),
            abi.encodeCall(newImpl.initialize, (address(0), treasury, contributorPool, admin))
        );
        
        // Test invalid treasury
        vm.expectRevert("Invalid treasury");
        new ERC1967Proxy(
            address(newImpl),
            abi.encodeCall(newImpl.initialize, (address(stakingPositions), address(0), contributorPool, admin))
        );
        
        // Test invalid contributor pool
        vm.expectRevert("Invalid contributor pool");
        new ERC1967Proxy(
            address(newImpl),
            abi.encodeCall(newImpl.initialize, (address(stakingPositions), treasury, address(0), admin))
        );
        
        // Test invalid admin
        vm.expectRevert("Invalid admin");
        new ERC1967Proxy(
            address(newImpl),
            abi.encodeCall(newImpl.initialize, (address(stakingPositions), treasury, contributorPool, address(0)))
        );
    }
    
    // ============ Revenue Reporting Tests ============
    
    function test_NotifyRevenue() public {
        // Set high threshold to prevent automatic distribution
        vm.prank(admin);
        revenueCollector.addSupportedToken(address(mockToken), REVENUE_AMOUNT * 2);
        
        vm.startPrank(revenueSource);
        
        // Approve tokens for transfer
        mockToken.approve(address(revenueCollector), REVENUE_AMOUNT);
        
        // Notify revenue
        vm.expectEmit(true, true, false, true);
        emit IRevenueCollector.RevenueReported(address(mockToken), REVENUE_AMOUNT, revenueSource);
        
        revenueCollector.notifyRevenue(address(mockToken), REVENUE_AMOUNT);
        
        // Verify state changes (no automatic distribution)
        assertEq(revenueCollector.pendingRevenue(address(mockToken)), REVENUE_AMOUNT);
        assertEq(revenueCollector.totalRevenueCollected(address(mockToken)), REVENUE_AMOUNT);
        assertEq(mockToken.balanceOf(address(revenueCollector)), REVENUE_AMOUNT);
        assertTrue(revenueCollector.isSupportedToken(address(mockToken)));
        
        vm.stopPrank();
    }
    
    function test_NotifyRevenueRequiresRole() public {
        vm.startPrank(user);
        
        mockToken.approve(address(revenueCollector), REVENUE_AMOUNT);
        
        // Should fail without REVENUE_REPORTER_ROLE
        vm.expectRevert();
        revenueCollector.notifyRevenue(address(mockToken), REVENUE_AMOUNT);
        
        vm.stopPrank();
    }
    
    function test_NotifyRevenueValidation() public {
        vm.startPrank(revenueSource);
        
        // Test zero address
        vm.expectRevert("Invalid token");
        revenueCollector.notifyRevenue(address(0), REVENUE_AMOUNT);
        
        // Test zero amount
        vm.expectRevert("Zero amount");
        revenueCollector.notifyRevenue(address(mockToken), 0);
        
        vm.stopPrank();
    }
    
    function test_AutomaticDistribution() public {
        // Add token with low threshold for testing
        vm.prank(admin);
        revenueCollector.addSupportedToken(address(mockToken), 100e18);
        
        vm.startPrank(revenueSource);
        mockToken.approve(address(revenueCollector), REVENUE_AMOUNT);
        
        // Revenue above threshold should trigger automatic distribution
        vm.expectEmit(true, false, false, true);
        emit IRevenueCollector.RevenueDistributed(
            address(mockToken), 
            REVENUE_AMOUNT, 
            5000e18, // 50% to stakers
            3000e18, // 30% to treasury
            2000e18  // 20% to contributors
        );
        
        revenueCollector.notifyRevenue(address(mockToken), REVENUE_AMOUNT);
        
        // Verify distribution happened
        assertEq(revenueCollector.pendingRevenue(address(mockToken)), 0);
        assertEq(revenueCollector.totalDistributed(address(mockToken)), REVENUE_AMOUNT);
        
        vm.stopPrank();
    }
    
    // ============ Distribution Tests ============
    
    function test_ManualDistribution() public {
        // Set high threshold to prevent automatic distribution
        vm.prank(admin);
        revenueCollector.addSupportedToken(address(mockToken), REVENUE_AMOUNT * 2);
        
        // Setup revenue
        vm.startPrank(revenueSource);
        mockToken.approve(address(revenueCollector), REVENUE_AMOUNT);
        revenueCollector.notifyRevenue(address(mockToken), REVENUE_AMOUNT);
        vm.stopPrank();
        
        // Record balances before distribution
        uint256 treasuryBefore = mockToken.balanceOf(treasury);
        uint256 contributorsBefore = mockToken.balanceOf(contributorPool);
        
        // Manual distribution
        (uint256 stakingAmount, uint256 treasuryAmount, uint256 contributorAmount) = 
            revenueCollector.distribute(address(mockToken));
        
        // Verify amounts
        assertEq(stakingAmount, 5000e18); // 50%
        assertEq(treasuryAmount, 3000e18); // 30%
        assertEq(contributorAmount, 2000e18); // 20%
        
        // Verify actual transfers
        assertEq(mockToken.balanceOf(treasury), treasuryBefore + treasuryAmount);
        assertEq(mockToken.balanceOf(contributorPool), contributorsBefore + contributorAmount);
        
        // Verify state cleanup
        assertEq(revenueCollector.pendingRevenue(address(mockToken)), 0);
    }
    
    function test_DistributeAll() public {
        // Setup revenue for multiple tokens
        vm.startPrank(revenueSource);
        
        // First token
        mockToken.approve(address(revenueCollector), REVENUE_AMOUNT);
        revenueCollector.notifyRevenue(address(mockToken), REVENUE_AMOUNT);
        
        // Second token
        secondToken.approve(address(revenueCollector), REVENUE_AMOUNT / 2);
        revenueCollector.notifyRevenue(address(secondToken), REVENUE_AMOUNT / 2);
        
        vm.stopPrank();
        
        // Distribute all
        (
            address[] memory tokens,
            uint256[] memory stakingAmounts,
            uint256[] memory treasuryAmounts,
            uint256[] memory contributorAmounts
        ) = revenueCollector.distributeAll();
        
        // Verify results
        assertEq(tokens.length, 2);
        assertEq(stakingAmounts.length, 2);
        assertEq(treasuryAmounts.length, 2);
        assertEq(contributorAmounts.length, 2);
        
        // First token (10,000)
        assertTrue(tokens[0] == address(mockToken) || tokens[1] == address(mockToken));
        // Second token (5,000)
        assertTrue(tokens[0] == address(secondToken) || tokens[1] == address(secondToken));
    }
    
    function test_DistributionRounding() public {
        // Test with odd number to check rounding handling
        uint256 oddAmount = 10001e18; // Results in fractional shares
        
        vm.startPrank(revenueSource);
        mockToken.approve(address(revenueCollector), oddAmount);
        revenueCollector.notifyRevenue(address(mockToken), oddAmount);
        vm.stopPrank();
        
        (uint256 stakingAmount, uint256 treasuryAmount, uint256 contributorAmount) = 
            revenueCollector.distribute(address(mockToken));
        
        // Verify all tokens are distributed (no loss due to rounding)
        assertEq(stakingAmount + treasuryAmount + contributorAmount, oddAmount);
        
        // Treasury should get any rounding remainder
        assertEq(stakingAmount, 5000.5e18); // 50% = 5000.5
        assertEq(contributorAmount, 2000.2e18); // 20% = 2000.2
        // Treasury gets 30% + remainder = 3000.3 + 0 = 3000.3
        assertGe(treasuryAmount, 3000.3e18);
    }
    
    // ============ Admin Functions Tests ============
    
    function test_SetDistributionThreshold() public {
        // First add a supported token
        vm.prank(admin);
        revenueCollector.addSupportedToken(address(mockToken), THRESHOLD);
        
        uint256 newThreshold = 2000e18;
        
        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit IRevenueCollector.ThresholdUpdated(address(mockToken), THRESHOLD, newThreshold);
        
        revenueCollector.setDistributionThreshold(address(mockToken), newThreshold);
        
        assertEq(revenueCollector.distributionThreshold(address(mockToken)), newThreshold);
    }
    
    function test_SetTreasury() public {
        address newTreasury = address(0x999);
        
        vm.prank(admin);
        vm.expectEmit(true, true, false, false);
        emit IRevenueCollector.TreasuryUpdated(treasury, newTreasury);
        
        revenueCollector.setTreasury(newTreasury);
        
        assertEq(revenueCollector.treasury(), newTreasury);
    }
    
    function test_SetContributorPool() public {
        address newPool = address(0x888);
        
        vm.prank(admin);
        vm.expectEmit(true, true, false, false);
        emit IRevenueCollector.ContributorPoolUpdated(contributorPool, newPool);
        
        revenueCollector.setContributorPool(newPool);
        
        assertEq(revenueCollector.contributorPool(), newPool);
    }
    
    function test_AddSupportedToken() public {
        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit IRevenueCollector.TokenSupported(address(mockToken), THRESHOLD);
        
        revenueCollector.addSupportedToken(address(mockToken), THRESHOLD);
        
        assertTrue(revenueCollector.isSupportedToken(address(mockToken)));
        assertEq(revenueCollector.distributionThreshold(address(mockToken)), THRESHOLD);
        
        address[] memory supportedTokens = revenueCollector.getSupportedTokens();
        assertEq(supportedTokens.length, 1);
        assertEq(supportedTokens[0], address(mockToken));
    }
    
    function test_RemoveSupportedToken() public {
        // Add token first
        vm.prank(admin);
        revenueCollector.addSupportedToken(address(mockToken), THRESHOLD);
        
        // Remove it
        vm.prank(admin);
        vm.expectEmit(true, false, false, false);
        emit IRevenueCollector.TokenRemoved(address(mockToken));
        
        revenueCollector.removeSupportedToken(address(mockToken));
        
        assertFalse(revenueCollector.isSupportedToken(address(mockToken)));
        assertEq(revenueCollector.distributionThreshold(address(mockToken)), 0);
        
        address[] memory supportedTokens = revenueCollector.getSupportedTokens();
        assertEq(supportedTokens.length, 0);
    }
    
    // ============ View Functions Tests ============
    
    function test_GetPendingRevenue() public {
        // Add multiple tokens with revenue
        vm.startPrank(revenueSource);
        
        mockToken.approve(address(revenueCollector), REVENUE_AMOUNT);
        revenueCollector.notifyRevenue(address(mockToken), REVENUE_AMOUNT);
        
        secondToken.approve(address(revenueCollector), REVENUE_AMOUNT / 2);
        revenueCollector.notifyRevenue(address(secondToken), REVENUE_AMOUNT / 2);
        
        vm.stopPrank();
        
        (address[] memory tokens, uint256[] memory amounts) = revenueCollector.getPendingRevenue();
        
        assertEq(tokens.length, 2);
        assertEq(amounts.length, 2);
        
        // Check amounts are correct (order may vary)
        uint256 total = amounts[0] + amounts[1];
        assertEq(total, REVENUE_AMOUNT + REVENUE_AMOUNT / 2);
    }
    
    function test_IsDistributionNeeded() public {
        // Add token with specific threshold
        vm.prank(admin);
        revenueCollector.addSupportedToken(address(mockToken), 1000e18);
        
        // Initially no distribution needed
        (bool needed,) = revenueCollector.isDistributionNeeded();
        assertFalse(needed);
        
        // Add revenue below threshold
        vm.startPrank(revenueSource);
        mockToken.approve(address(revenueCollector), 500e18);
        revenueCollector.notifyRevenue(address(mockToken), 500e18);
        vm.stopPrank();
        
        (needed,) = revenueCollector.isDistributionNeeded();
        assertFalse(needed);
        
        // Add more revenue above threshold
        vm.startPrank(revenueSource);
        mockToken.approve(address(revenueCollector), 600e18);
        revenueCollector.notifyRevenue(address(mockToken), 600e18);
        vm.stopPrank();
        
        address[] memory tokensReady;
        (needed, tokensReady) = revenueCollector.isDistributionNeeded();
        assertTrue(needed);
        assertEq(tokensReady.length, 1);
        assertEq(tokensReady[0], address(mockToken));
    }
    
    function test_GetStats() public {
        (uint256 totalDistributions, uint256 lastDistributionTime, uint256 supportedTokenCount) = 
            revenueCollector.getStats();
        
        assertEq(totalDistributions, 0);
        assertGt(lastDistributionTime, 0); // Should be set to block.timestamp in constructor
        assertEq(supportedTokenCount, 0);
        
        // Add a token and distribute
        vm.startPrank(revenueSource);
        mockToken.approve(address(revenueCollector), REVENUE_AMOUNT);
        revenueCollector.notifyRevenue(address(mockToken), REVENUE_AMOUNT);
        vm.stopPrank();
        
        revenueCollector.distribute(address(mockToken));
        
        (totalDistributions, lastDistributionTime, supportedTokenCount) = revenueCollector.getStats();
        assertEq(totalDistributions, 1);
        assertEq(lastDistributionTime, block.timestamp);
        assertEq(supportedTokenCount, 1); // Auto-added during notifyRevenue
    }
    
    // ============ Error Cases ============
    
    function test_DistributeInvalidToken() public {
        vm.expectRevert("Token not supported");
        revenueCollector.distribute(address(mockToken));
    }
    
    function test_DistributeNoRevenue() public {
        // Add token but no revenue
        vm.prank(admin);
        revenueCollector.addSupportedToken(address(mockToken), THRESHOLD);
        
        vm.expectRevert("No revenue to distribute");
        revenueCollector.distribute(address(mockToken));
    }
    
    function test_DistributeAllNoRevenue() public {
        vm.expectRevert("No revenue to distribute");
        revenueCollector.distributeAll();
    }
    
    // ============ Access Control Tests ============
    
    function test_OnlyAdminCanSetThreshold() public {
        vm.prank(admin);
        revenueCollector.addSupportedToken(address(mockToken), THRESHOLD);
        
        vm.prank(user);
        vm.expectRevert();
        revenueCollector.setDistributionThreshold(address(mockToken), 2000e18);
    }
    
    function test_OnlyAdminCanSetAddresses() public {
        vm.startPrank(user);
        
        vm.expectRevert();
        revenueCollector.setTreasury(address(0x999));
        
        vm.expectRevert();
        revenueCollector.setContributorPool(address(0x888));
        
        vm.stopPrank();
    }
    
    function test_OnlyAdminCanManageTokens() public {
        vm.startPrank(user);
        
        vm.expectRevert();
        revenueCollector.addSupportedToken(address(mockToken), THRESHOLD);
        
        vm.stopPrank();
    }
}