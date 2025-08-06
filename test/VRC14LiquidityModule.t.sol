// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../src/rewards/VRC14LiquidityModule.sol";
import "../src/mocks/MockRDAT.sol";
import "../src/mocks/MockUniswapV3.sol";
import "../src/mocks/MockRewardsManager.sol";
import "../src/StakingManager.sol";
import "../src/EmergencyPause.sol";

contract VRC14LiquidityModuleTest is Test {
    VRC14LiquidityModule public module;
    MockRDAT public rdatToken;
    MockRDAT public vanaToken; // Using MockRDAT as VANA for testing
    StakingManager public stakingManager;
    EmergencyPause public emergencyPause;
    MockRewardsManager public mockRewardsManager;
    
    MockSwapRouter public swapRouter;
    MockNonfungiblePositionManager public positionManager;
    MockUniswapV3Factory public uniswapFactory;
    
    address public admin = address(0x1);
    address public executor = address(0x2);
    address public rewardsManager;
    address public user1 = address(0x4);
    address public user2 = address(0x5);
    address public treasury = address(0x6);
    
    uint256 public constant TOTAL_VANA = 90000 ether; // 1000 per day
    uint256 public constant VANA_PER_TRANCHE = 1000 ether;
    
    // Events
    event ProgramInitialized(uint256 totalVana, uint256 perTranche, uint256 startTime);
    event TrancheExecuted(uint256 indexed tranche, uint256 positionId, uint256 liquidity);
    event LPSharesClaimed(address indexed user, uint256 indexed tranche, uint256 shares);

    function setUp() public {
        vm.startPrank(admin);
        
        // Deploy tokens
        rdatToken = new MockRDAT(admin);
        vanaToken = new MockRDAT(admin); // Using MockRDAT as VANA
        
        // Deploy Uniswap mocks
        swapRouter = new MockSwapRouter();
        positionManager = new MockNonfungiblePositionManager();
        uniswapFactory = new MockUniswapV3Factory();
        
        // Deploy mock rewards manager
        mockRewardsManager = new MockRewardsManager();
        rewardsManager = address(mockRewardsManager);
        
        // Deploy staking infrastructure
        emergencyPause = new EmergencyPause(admin);
        stakingManager = new StakingManager(
            address(rdatToken),
            rewardsManager
        );
        
        // Deploy VRC14 module
        module = new VRC14LiquidityModule(
            address(rdatToken),
            address(stakingManager),
            admin
        );
        
        // Configure module
        module.configureUniswap(
            address(vanaToken),
            address(swapRouter),
            address(positionManager),
            address(uniswapFactory)
        );
        
        // Create pool
        module.createOrSetPool(3000);
        
        // Grant roles
        module.grantRole(module.EXECUTOR_ROLE(), executor);
        module.setRewardsManager(rewardsManager);
        
        // Setup staking
        stakingManager.setRewardsManager(rewardsManager);
        
        // Mint tokens for testing
        rdatToken.mint(treasury, 100000 ether);
        vanaToken.mint(admin, TOTAL_VANA);
        vanaToken.mint(address(swapRouter), 100000 ether); // For swaps
        rdatToken.mint(address(swapRouter), 100000 ether); // For swaps
        
        // Mint RDAT to users for staking
        rdatToken.mint(user1, 10000 ether);
        rdatToken.mint(user2, 20000 ether);
        
        vm.stopPrank();
    }

    // ========== CONFIGURATION TESTS ==========

    function test_ConfigureUniswap() public {
        // Deploy new module
        vm.prank(admin);
        VRC14LiquidityModule newModule = new VRC14LiquidityModule(
            address(rdatToken),
            address(stakingManager),
            admin
        );
        
        vm.prank(admin);
        newModule.configureUniswap(
            address(vanaToken),
            address(swapRouter),
            address(positionManager),
            address(uniswapFactory)
        );
        
        assertEq(address(newModule.vanaToken()), address(vanaToken));
        assertEq(address(newModule.swapRouter()), address(swapRouter));
        assertEq(address(newModule.positionManager()), address(positionManager));
        assertEq(address(newModule.uniswapFactory()), address(uniswapFactory));
    }

    function test_ConfigureUniswap_NotAdmin() public {
        vm.prank(user1);
        vm.expectRevert();
        module.configureUniswap(
            address(vanaToken),
            address(swapRouter),
            address(positionManager),
            address(uniswapFactory)
        );
    }

    // ========== INITIALIZATION TESTS ==========

    function test_InitializeProgram() public {
        vm.startPrank(admin);
        vanaToken.approve(address(module), TOTAL_VANA);
        
        vm.expectEmit(true, false, false, true);
        emit ProgramInitialized(TOTAL_VANA, VANA_PER_TRANCHE, block.timestamp);
        
        module.initializeProgram(TOTAL_VANA);
        vm.stopPrank();
        
        assertEq(module.totalVanaAllocated(), TOTAL_VANA);
        assertEq(module.vanaPerTranche(), VANA_PER_TRANCHE);
        assertTrue(module.initialized());
        assertEq(vanaToken.balanceOf(address(module)), TOTAL_VANA);
    }

    function test_InitializeProgram_AlreadyInitialized() public {
        vm.startPrank(admin);
        vanaToken.approve(address(module), TOTAL_VANA);
        module.initializeProgram(TOTAL_VANA);
        
        vm.expectRevert(VRC14LiquidityModule.ProgramAlreadyInitialized.selector);
        module.initializeProgram(TOTAL_VANA);
        vm.stopPrank();
    }

    // ========== TRANCHE EXECUTION TESTS ==========

    function test_ExecuteDailyTranche() public {
        // Warp to a reasonable time
        vm.warp(2 days);
        
        // Initialize program
        vm.startPrank(admin);
        vanaToken.approve(address(module), TOTAL_VANA);
        module.initializeProgram(TOTAL_VANA);
        vm.stopPrank();
        
        // Setup stakes
        vm.startPrank(user1);
        rdatToken.approve(address(stakingManager), 1000 ether);
        stakingManager.stake(1000 ether, 30 days);
        vm.stopPrank();
        
        // Execute tranche
        vm.prank(executor);
        vm.expectEmit(true, false, false, false);
        emit TrancheExecuted(1, 1, 0); // We don't know exact liquidity
        
        module.executeDailyTranche();
        
        assertEq(module.currentTranche(), 1);
        assertEq(module.tranchePositionIds(0), 1);
        assertTrue(module.positionLiquidity(1) > 0);
    }

    function test_ExecuteDailyTranche_TooEarly() public {
        // Warp to a time where we can properly test the delay
        vm.warp(2 days);
        
        // Initialize program
        vm.startPrank(admin);
        vanaToken.approve(address(module), TOTAL_VANA);
        module.initializeProgram(TOTAL_VANA);
        vm.stopPrank();
        
        // Execute first tranche
        vm.prank(executor);
        module.executeDailyTranche();
        
        // Try to execute again immediately
        vm.prank(executor);
        vm.expectRevert(VRC14LiquidityModule.TooEarlyForTranche.selector);
        module.executeDailyTranche();
    }

    function test_ExecuteDailyTranche_NotInitialized() public {
        vm.prank(executor);
        vm.expectRevert(VRC14LiquidityModule.ProgramNotInitialized.selector);
        module.executeDailyTranche();
    }

    function test_ExecuteAllTranches() public {
        // Warp to a reasonable time
        vm.warp(2 days);
        
        // Initialize program
        vm.startPrank(admin);
        vanaToken.approve(address(module), TOTAL_VANA);
        module.initializeProgram(TOTAL_VANA);
        vm.stopPrank();
        
        // Setup stakes
        vm.startPrank(user1);
        rdatToken.approve(address(stakingManager), 1000 ether);
        stakingManager.stake(1000 ether, 30 days);
        vm.stopPrank();
        
        // Execute all 90 tranches
        for (uint256 i = 0; i < 90; i++) {
            vm.prank(executor);
            module.executeDailyTranche();
            
            // Advance time by 1 day
            vm.warp(block.timestamp + 1 days);
        }
        
        assertEq(module.currentTranche(), 90);
        
        // Try to execute one more
        vm.prank(executor);
        vm.expectRevert(VRC14LiquidityModule.ProgramComplete.selector);
        module.executeDailyTranche();
    }

    // ========== CLAIM TESTS ==========

    function test_ClaimRewards() public {
        // Initialize and execute some tranches
        _setupAndExecuteTranches(5);
        
        // Calculate expected shares
        uint256 expectedShares = module.calculateRewards(user1, 0);
        assertTrue(expectedShares > 0);
        
        // Claim rewards
        vm.prank(rewardsManager);
        uint256 claimed = module.claimRewards(user1, 0);
        
        assertEq(claimed, expectedShares);
        assertEq(module.userAccumulatedShares(user1), expectedShares);
        
        // Check that tranches are marked as claimed
        for (uint256 i = 0; i < 5; i++) {
            assertTrue(module.hasClaimedTranche(user1, i));
        }
    }

    function test_ClaimRewards_Multiple() public {
        // Initialize and execute tranches
        _setupAndExecuteTranches(3);
        
        // Both users claim
        vm.startPrank(rewardsManager);
        uint256 claimed1 = module.claimRewards(user1, 0);
        uint256 claimed2 = module.claimRewards(user2, 0);
        vm.stopPrank();
        
        // User2 should have 2x shares (staked 2x amount)
        assertEq(claimed2, claimed1 * 2);
    }

    function test_ClaimRewards_NothingToClaim() public {
        // Initialize but don't execute tranches
        vm.startPrank(admin);
        vanaToken.approve(address(module), TOTAL_VANA);
        module.initializeProgram(TOTAL_VANA);
        vm.stopPrank();
        
        // Try to claim
        vm.prank(rewardsManager);
        vm.expectRevert(VRC14LiquidityModule.NoSharesToClaim.selector);
        module.claimRewards(user1, 0);
    }

    function test_ClaimRewards_AlreadyClaimed() public {
        // Initialize and execute tranches
        _setupAndExecuteTranches(3);
        
        // Claim once
        vm.prank(rewardsManager);
        module.claimRewards(user1, 0);
        
        // Try to claim again
        vm.prank(rewardsManager);
        vm.expectRevert(VRC14LiquidityModule.NoSharesToClaim.selector);
        module.claimRewards(user1, 0);
    }

    // ========== VIEW FUNCTION TESTS ==========

    function test_CalculateRewards() public {
        _setupAndExecuteTranches(3);
        
        uint256 rewards1 = module.calculateRewards(user1, 0);
        uint256 rewards2 = module.calculateRewards(user2, 0);
        
        assertTrue(rewards1 > 0);
        assertTrue(rewards2 > 0);
        assertEq(rewards2, rewards1 * 2); // User2 staked 2x
    }

    function test_GetModuleInfo() public {
        vm.startPrank(admin);
        vanaToken.approve(address(module), TOTAL_VANA);
        module.initializeProgram(TOTAL_VANA);
        vm.stopPrank();
        
        IRewardModule.ModuleInfo memory info = module.getModuleInfo();
        
        assertEq(info.name, "VRC-14 Liquidity Incentives");
        assertEq(info.version, "1.0.0");
        assertEq(info.rewardToken, address(vanaToken));
        assertTrue(info.isActive);
        assertEq(info.totalAllocated, TOTAL_VANA);
        assertEq(info.totalDistributed, 0);
    }

    // ========== ADMIN FUNCTION TESTS ==========

    function test_SetActive() public {
        // Initialize first
        vm.startPrank(admin);
        vanaToken.approve(address(module), TOTAL_VANA);
        module.initializeProgram(TOTAL_VANA);
        
        // Now test setActive
        module.setActive(false);
        assertFalse(module.isActive());
        
        module.setActive(true);
        assertTrue(module.isActive());
        vm.stopPrank();
    }

    function test_EmergencyWithdraw() public {
        // Send some tokens to module
        vm.prank(treasury);
        rdatToken.transfer(address(module), 1000 ether);
        
        uint256 balanceBefore = rdatToken.balanceOf(admin);
        
        vm.prank(admin);
        module.emergencyWithdraw(address(rdatToken), 1000 ether);
        
        assertEq(rdatToken.balanceOf(admin), balanceBefore + 1000 ether);
    }

    // ========== HELPER FUNCTIONS ==========

    function _setupAndExecuteTranches(uint256 numTranches) private {
        // Warp to a reasonable time to avoid issues with low block.timestamp
        vm.warp(2 days);
        
        // Initialize program
        vm.startPrank(admin);
        vanaToken.approve(address(module), TOTAL_VANA);
        module.initializeProgram(TOTAL_VANA);
        vm.stopPrank();
        
        // Setup stakes
        vm.startPrank(user1);
        rdatToken.approve(address(stakingManager), 1000 ether);
        stakingManager.stake(1000 ether, 30 days);
        vm.stopPrank();
        
        vm.startPrank(user2);
        rdatToken.approve(address(stakingManager), 2000 ether);
        stakingManager.stake(2000 ether, 30 days);
        vm.stopPrank();
        
        // Execute tranches
        for (uint256 i = 0; i < numTranches; i++) {
            vm.prank(executor);
            module.executeDailyTranche();
            
            if (i < numTranches - 1) {
                vm.warp(block.timestamp + 1 days);
            }
        }
    }
}