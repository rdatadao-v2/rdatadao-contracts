// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../src/RevenueCollector.sol";
import "../src/StakingPositions.sol";
import "../src/RDATUpgradeable.sol";
import "../src/vRDAT.sol";
import "../src/mocks/MockERC20.sol";
import "../src/mocks/MockRewardsManager.sol";
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
        bytes memory stakingInitData = abi.encodeCall(stakingImpl.initialize, (address(rdat), address(vrdat), admin));
        ERC1967Proxy stakingProxy = new ERC1967Proxy(address(stakingImpl), stakingInitData);
        stakingPositions = StakingPositions(address(stakingProxy));

        // Deploy RevenueCollector
        RevenueCollector revenueImpl = new RevenueCollector();
        bytes memory revenueInitData =
            abi.encodeCall(revenueImpl.initialize, (address(stakingPositions), treasury, contributorPool, admin));
        ERC1967Proxy revenueProxy = new ERC1967Proxy(address(revenueImpl), revenueInitData);
        revenueCollector = RevenueCollector(address(revenueProxy));

        // Deploy mock tokens for testing
        mockToken = new MockERC20("Mock Token", "MOCK", 18);
        secondToken = new MockERC20("Second Token", "SECOND", 18);

        // Setup roles and permissions
        // RDAT no longer has MINTER_ROLE - all tokens minted at deployment
        vrdat.grantRole(vrdat.MINTER_ROLE(), address(stakingPositions));
        revenueCollector.grantRole(revenueCollector.REVENUE_REPORTER_ROLE(), revenueSource);

        // Grant REVENUE_COLLECTOR_ROLE to RevenueCollector so it can call notifyRewardAmount
        stakingPositions.grantRole(stakingPositions.REVENUE_COLLECTOR_ROLE(), address(revenueCollector));

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

    function test_InitializationValues() public view {
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
            address(newImpl), abi.encodeCall(newImpl.initialize, (address(0), treasury, contributorPool, admin))
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

    function test_AutomaticDistributionNonRDAT() public {
        // Add token with low threshold for testing
        vm.prank(admin);
        revenueCollector.addSupportedToken(address(mockToken), 100e18);

        vm.startPrank(revenueSource);
        mockToken.approve(address(revenueCollector), REVENUE_AMOUNT);

        // For non-RDAT tokens, all revenue goes to treasury
        vm.expectEmit(true, false, false, true);
        emit IRevenueCollector.RevenueDistributed(
            address(mockToken),
            REVENUE_AMOUNT,
            0, // 0% to stakers (non-RDAT)
            REVENUE_AMOUNT, // 100% to treasury
            0 // 0% to contributors
        );

        revenueCollector.notifyRevenue(address(mockToken), REVENUE_AMOUNT);

        // Verify distribution happened
        assertEq(revenueCollector.pendingRevenue(address(mockToken)), 0);
        assertEq(revenueCollector.totalDistributed(address(mockToken)), REVENUE_AMOUNT);

        vm.stopPrank();
    }

    function test_AutomaticDistributionRDAT() public {
        // Mint RDAT to revenue source
        vm.prank(treasury);
        rdat.transfer(revenueSource, REVENUE_AMOUNT);

        // Add RDAT token with low threshold for testing
        vm.prank(admin);
        revenueCollector.addSupportedToken(address(rdat), 100e18);

        vm.startPrank(revenueSource);
        rdat.approve(address(revenueCollector), REVENUE_AMOUNT);

        // For RDAT tokens, normal distribution
        vm.expectEmit(true, false, false, true);
        emit IRevenueCollector.RevenueDistributed(
            address(rdat),
            REVENUE_AMOUNT,
            5000e18, // 50% to stakers
            3000e18, // 30% to treasury
            2000e18 // 20% to contributors
        );

        revenueCollector.notifyRevenue(address(rdat), REVENUE_AMOUNT);

        // Verify distribution happened
        assertEq(revenueCollector.pendingRevenue(address(rdat)), 0);
        assertEq(revenueCollector.totalDistributed(address(rdat)), REVENUE_AMOUNT);

        vm.stopPrank();
    }

    // ============ Distribution Tests ============

    function test_ManualDistributionNonRDAT() public {
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

        // Verify amounts (non-RDAT: all goes to treasury)
        assertEq(stakingAmount, 0); // 0% (non-RDAT)
        assertEq(treasuryAmount, REVENUE_AMOUNT); // 100% to treasury
        assertEq(contributorAmount, 0); // 0% to contributors

        // Verify actual transfers (all goes to treasury for non-RDAT)
        assertEq(mockToken.balanceOf(treasury), treasuryBefore + REVENUE_AMOUNT);
        assertEq(mockToken.balanceOf(contributorPool), contributorsBefore); // No change

        // Verify state cleanup
        assertEq(revenueCollector.pendingRevenue(address(mockToken)), 0);
    }

    function test_ManualDistributionRDAT() public {
        // Mint RDAT to revenue source and StakingPositions
        vm.startPrank(treasury);
        rdat.transfer(revenueSource, REVENUE_AMOUNT);
        rdat.transfer(address(stakingPositions), REVENUE_AMOUNT); // For rewards
        vm.stopPrank();

        // Set high threshold to prevent automatic distribution
        vm.prank(admin);
        revenueCollector.addSupportedToken(address(rdat), REVENUE_AMOUNT * 2);

        // Setup revenue
        vm.startPrank(revenueSource);
        rdat.approve(address(revenueCollector), REVENUE_AMOUNT);
        revenueCollector.notifyRevenue(address(rdat), REVENUE_AMOUNT);
        vm.stopPrank();

        // Record balances before distribution
        uint256 treasuryBefore = rdat.balanceOf(treasury);
        uint256 contributorsBefore = rdat.balanceOf(contributorPool);
        uint256 stakingBefore = rdat.balanceOf(address(stakingPositions));

        // Manual distribution
        (uint256 stakingAmount, uint256 treasuryAmount, uint256 contributorAmount) =
            revenueCollector.distribute(address(rdat));

        // Verify amounts (RDAT: normal distribution)
        assertEq(stakingAmount, 5000e18); // 50%
        assertEq(treasuryAmount, 3000e18); // 30%
        assertEq(contributorAmount, 2000e18); // 20%

        // Verify actual transfers
        assertEq(rdat.balanceOf(treasury), treasuryBefore + treasuryAmount);
        assertEq(rdat.balanceOf(contributorPool), contributorsBefore + contributorAmount);
        assertEq(rdat.balanceOf(address(stakingPositions)), stakingBefore + stakingAmount);

        // Verify state cleanup
        assertEq(revenueCollector.pendingRevenue(address(rdat)), 0);
    }

    function test_DistributeAll() public {
        // Add tokens with high thresholds to prevent automatic distribution
        vm.startPrank(admin);
        revenueCollector.addSupportedToken(address(mockToken), REVENUE_AMOUNT * 2);
        revenueCollector.addSupportedToken(address(secondToken), REVENUE_AMOUNT * 2);
        vm.stopPrank();

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
        // Add token with high threshold to prevent automatic distribution
        vm.prank(admin);
        revenueCollector.addSupportedToken(address(mockToken), REVENUE_AMOUNT * 2);

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

        // For non-RDAT tokens, all goes to treasury
        assertEq(stakingAmount, 0); // 0% (non-RDAT)
        assertEq(contributorAmount, 0); // 0% to contributors
        // Treasury gets 100%
        assertEq(treasuryAmount, oddAmount);
    }

    function test_NonRDATTokensGoToTreasury() public {
        // Test that USDC, USDT, and other non-RDAT tokens go entirely to treasury
        // This is the intended behavior until DAO governance decides on distribution

        // Add USDC-like token with high threshold
        vm.prank(admin);
        revenueCollector.addSupportedToken(address(mockToken), REVENUE_AMOUNT * 2);

        // Setup revenue
        vm.startPrank(revenueSource);
        mockToken.approve(address(revenueCollector), REVENUE_AMOUNT);
        revenueCollector.notifyRevenue(address(mockToken), REVENUE_AMOUNT);
        vm.stopPrank();

        // Record treasury balance
        uint256 treasuryBefore = mockToken.balanceOf(treasury);
        uint256 contributorsBefore = mockToken.balanceOf(contributorPool);

        // Distribute
        (uint256 stakingAmount, uint256 treasuryAmount, uint256 contributorAmount) =
            revenueCollector.distribute(address(mockToken));

        // Verify ALL revenue went to treasury
        assertEq(stakingAmount, 0, "No staking distribution for non-RDAT");
        assertEq(treasuryAmount, REVENUE_AMOUNT, "All revenue to treasury");
        assertEq(contributorAmount, 0, "No contributor distribution for non-RDAT");

        // Verify actual balances
        assertEq(mockToken.balanceOf(treasury), treasuryBefore + REVENUE_AMOUNT);
        assertEq(mockToken.balanceOf(contributorPool), contributorsBefore);
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
        // Add tokens with high thresholds to prevent automatic distribution
        vm.startPrank(admin);
        revenueCollector.addSupportedToken(address(mockToken), REVENUE_AMOUNT * 2);
        revenueCollector.addSupportedToken(address(secondToken), REVENUE_AMOUNT * 2);
        vm.stopPrank();

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
        revenueCollector.addSupportedToken(address(mockToken), 1300e18); // Higher threshold to prevent auto-distribution

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

        // Add more revenue to exceed threshold
        vm.startPrank(revenueSource);
        mockToken.approve(address(revenueCollector), 900e18); // 500 + 900 = 1400, exceeds threshold of 1300
        revenueCollector.notifyRevenue(address(mockToken), 900e18);
        vm.stopPrank();

        // Check that distribution is needed after manually checking
        address[] memory tokensReady;
        (needed, tokensReady) = revenueCollector.isDistributionNeeded();
        assertFalse(needed); // Should be false because auto-distribution happened
        assertEq(tokensReady.length, 0);

        // Verify that distribution already happened
        assertEq(revenueCollector.pendingRevenue(address(mockToken)), 0);
        assertEq(revenueCollector.totalDistributed(address(mockToken)), 1400e18);
    }

    function test_GetStats() public {
        (uint256 totalDistributions, uint256 lastDistributionTime, uint256 supportedTokenCount) =
            revenueCollector.getStats();

        assertEq(totalDistributions, 0);
        assertGt(lastDistributionTime, 0); // Should be set to block.timestamp in constructor
        assertEq(supportedTokenCount, 0);

        // Add token with high threshold to prevent automatic distribution
        vm.prank(admin);
        revenueCollector.addSupportedToken(address(mockToken), REVENUE_AMOUNT * 2);

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

    function test_RewardsManagerIntegration() public {
        // Deploy mock rewards manager
        MockRewardsManager mockRewardsManager = new MockRewardsManager();

        // Set rewards manager
        vm.prank(admin);
        revenueCollector.setRewardsManager(address(mockRewardsManager));

        // Test 1: Token supported by RewardsManager gets proper distribution
        MockERC20 supportedToken = new MockERC20("Supported Token", "SUP", 18);
        supportedToken.mint(revenueSource, REVENUE_AMOUNT);

        // Mark token as supported in RewardsManager
        mockRewardsManager.setTokenSupport(address(supportedToken), true);

        // Add token to revenue collector
        vm.prank(admin);
        revenueCollector.addSupportedToken(address(supportedToken), REVENUE_AMOUNT * 2);

        // Report revenue
        vm.startPrank(revenueSource);
        supportedToken.approve(address(revenueCollector), REVENUE_AMOUNT);
        revenueCollector.notifyRevenue(address(supportedToken), REVENUE_AMOUNT);
        vm.stopPrank();

        // Distribute and verify 50/30/20 split
        (uint256 stakingAmount, uint256 treasuryAmount, uint256 contributorAmount) =
            revenueCollector.distribute(address(supportedToken));

        assertEq(stakingAmount, 5000e18, "50% to stakers");
        assertEq(treasuryAmount, 3000e18, "30% to treasury");
        assertEq(contributorAmount, 2000e18, "20% to contributors");

        // Verify RewardsManager received the staking amount
        assertEq(mockRewardsManager.lastRevenueAmount(), 5000e18);

        // Test 2: Token NOT supported by RewardsManager goes entirely to treasury
        MockERC20 unsupportedToken = new MockERC20("Unsupported Token", "UNS", 18);
        unsupportedToken.mint(revenueSource, REVENUE_AMOUNT);

        // Add token but don't mark as supported in RewardsManager
        vm.prank(admin);
        revenueCollector.addSupportedToken(address(unsupportedToken), REVENUE_AMOUNT * 2);

        // Report revenue
        vm.startPrank(revenueSource);
        unsupportedToken.approve(address(revenueCollector), REVENUE_AMOUNT);
        revenueCollector.notifyRevenue(address(unsupportedToken), REVENUE_AMOUNT);
        vm.stopPrank();

        // Distribute and verify all goes to treasury
        (stakingAmount, treasuryAmount, contributorAmount) = revenueCollector.distribute(address(unsupportedToken));

        assertEq(stakingAmount, 0, "No staking distribution");
        assertEq(treasuryAmount, REVENUE_AMOUNT, "100% to treasury");
        assertEq(contributorAmount, 0, "No contributor distribution");
    }

    function test_SetRewardsManager() public {
        address newRewardsManager = address(0x123);

        vm.prank(admin);
        vm.expectEmit(true, false, false, false);
        emit IRevenueCollector.RewardsManagerUpdated(newRewardsManager);

        revenueCollector.setRewardsManager(newRewardsManager);

        assertEq(address(revenueCollector.rewardsManager()), newRewardsManager);
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
