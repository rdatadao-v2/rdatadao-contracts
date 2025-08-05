// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../src/StakingPositions.sol";
import "../src/examples/StakingPositionsV2Example.sol";
import "../src/RDATUpgradeable.sol";
import "../src/vRDAT.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract StakingPositionsUpgradeTest is Test {
    StakingPositions public stakingV1;
    StakingPositionsV2Example public stakingV2;
    RDATUpgradeable public rdat;
    vRDAT public vrdat;
    ERC1967Proxy public stakingProxy;
    
    address public admin = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);
    address public charlie = address(0x4);
    address public treasury = address(0x5);
    
    uint256 constant INITIAL_BALANCE = 1_000_000 * 10**18;
    uint256 constant STAKE_AMOUNT = 1000 * 10**18;
    
    // Track positions created in V1
    uint256 position1;
    uint256 position2;
    uint256 position3;
    
    function setUp() public {
        vm.startPrank(admin);
        
        // Deploy RDAT
        RDATUpgradeable rdatImpl = new RDATUpgradeable();
        bytes memory rdatInitData = abi.encodeCall(
            rdatImpl.initialize,
            (treasury, admin)
        );
        rdat = RDATUpgradeable(address(new ERC1967Proxy(address(rdatImpl), rdatInitData)));
        
        // Deploy vRDAT
        vrdat = new vRDAT(admin);
        vm.warp(block.timestamp + vrdat.MINT_DELAY() + 1);
        
        // Deploy StakingPositions V1 with proxy
        StakingPositions stakingImpl = new StakingPositions();
        bytes memory stakingInitData = abi.encodeCall(
            stakingImpl.initialize,
            (address(rdat), address(vrdat), admin)
        );
        stakingProxy = new ERC1967Proxy(address(stakingImpl), stakingInitData);
        stakingV1 = StakingPositions(address(stakingProxy));
        
        // Setup roles
        vrdat.grantRole(vrdat.MINTER_ROLE(), address(stakingProxy));
        vrdat.grantRole(vrdat.BURNER_ROLE(), address(stakingProxy));
        rdat.grantRole(rdat.MINTER_ROLE(), address(stakingProxy));
        rdat.grantRole(rdat.MINTER_ROLE(), admin);
        
        // Mint tokens
        rdat.mint(alice, INITIAL_BALANCE);
        rdat.mint(bob, INITIAL_BALANCE);
        rdat.mint(charlie, INITIAL_BALANCE);
        
        vm.stopPrank();
        
        // Approve staking
        vm.prank(alice);
        rdat.approve(address(stakingProxy), type(uint256).max);
        vm.prank(bob);
        rdat.approve(address(stakingProxy), type(uint256).max);
        vm.prank(charlie);
        rdat.approve(address(stakingProxy), type(uint256).max);
    }
    
    function testUpgradePreservesAllNFTPositions() public {
        // Step 1: Create positions in V1
        vm.startPrank(alice);
        position1 = stakingV1.stake(STAKE_AMOUNT, stakingV1.MONTH_1());
        vm.warp(block.timestamp + vrdat.MINT_DELAY() + 1);
        position2 = stakingV1.stake(STAKE_AMOUNT * 2, stakingV1.MONTH_6());
        vm.stopPrank();
        
        vm.startPrank(bob);
        position3 = stakingV1.stake(STAKE_AMOUNT * 3, stakingV1.MONTH_12());
        vm.stopPrank();
        
        // Record V1 state
        address owner1 = stakingV1.ownerOf(position1);
        address owner2 = stakingV1.ownerOf(position2);
        address owner3 = stakingV1.ownerOf(position3);
        
        IStakingPositions.Position memory pos1Before = stakingV1.getPosition(position1);
        IStakingPositions.Position memory pos2Before = stakingV1.getPosition(position2);
        IStakingPositions.Position memory pos3Before = stakingV1.getPosition(position3);
        
        uint256 totalStakedBefore = stakingV1.totalStaked();
        uint256 aliceBalanceBefore = stakingV1.balanceOf(alice);
        uint256 bobBalanceBefore = stakingV1.balanceOf(bob);
        
        // Step 2: Upgrade to V2
        vm.startPrank(admin);
        
        // Deploy V2 implementation
        StakingPositionsV2Example stakingV2Impl = new StakingPositionsV2Example();
        
        // Upgrade proxy to V2
        stakingV1.upgradeToAndCall(
            address(stakingV2Impl),
            abi.encodeCall(StakingPositionsV2Example.initializeV2, ())
        );
        
        // Cast proxy to V2 interface
        stakingV2 = StakingPositionsV2Example(address(stakingProxy));
        
        vm.stopPrank();
        
        // Step 3: Verify all NFTs are preserved
        assertEq(stakingV2.ownerOf(position1), owner1, "Position 1 owner changed");
        assertEq(stakingV2.ownerOf(position2), owner2, "Position 2 owner changed");
        assertEq(stakingV2.ownerOf(position3), owner3, "Position 3 owner changed");
        
        // Verify position data preserved
        IStakingPositions.Position memory pos1After = stakingV2.getPosition(position1);
        IStakingPositions.Position memory pos2After = stakingV2.getPosition(position2);
        IStakingPositions.Position memory pos3After = stakingV2.getPosition(position3);
        
        assertEq(pos1After.amount, pos1Before.amount, "Position 1 amount changed");
        assertEq(pos1After.lockPeriod, pos1Before.lockPeriod, "Position 1 lock changed");
        assertEq(pos1After.startTime, pos1Before.startTime, "Position 1 start changed");
        
        assertEq(pos2After.amount, pos2Before.amount, "Position 2 amount changed");
        assertEq(pos3After.amount, pos3Before.amount, "Position 3 amount changed");
        
        // Verify balances preserved
        assertEq(stakingV2.balanceOf(alice), aliceBalanceBefore, "Alice balance changed");
        assertEq(stakingV2.balanceOf(bob), bobBalanceBefore, "Bob balance changed");
        assertEq(stakingV2.totalStaked(), totalStakedBefore, "Total staked changed");
        
        // Step 4: Verify V2 features work
        assertEq(stakingV2.version(), 2, "Version not updated");
        assertEq(stakingV2.globalBoostEnabled(), 1, "Boost not enabled");
        assertEq(stakingV2.referralBonusRate(), 500, "Referral rate not set");
    }
    
    function testCanCreateNewPositionsAfterUpgrade() public {
        // Create initial position
        vm.prank(alice);
        position1 = stakingV1.stake(STAKE_AMOUNT, stakingV1.MONTH_1());
        
        // Upgrade to V2
        vm.startPrank(admin);
        StakingPositionsV2Example stakingV2Impl = new StakingPositionsV2Example();
        stakingV1.upgradeToAndCall(
            address(stakingV2Impl),
            abi.encodeCall(StakingPositionsV2Example.initializeV2, ())
        );
        stakingV2 = StakingPositionsV2Example(address(stakingProxy));
        vm.stopPrank();
        
        // Create new position in V2
        vm.startPrank(charlie);
        uint256 newPosition = stakingV2.stake(STAKE_AMOUNT, stakingV2.MONTH_3());
        
        // Verify position ID continues from V1
        assertEq(newPosition, position1 + 1, "Position ID didn't continue");
        assertEq(stakingV2.ownerOf(newPosition), charlie, "Wrong owner");
        
        // Create position with referral
        vm.warp(block.timestamp + vrdat.MINT_DELAY() + 1);
        uint256 referralPosition = stakingV2.stakeWithReferral(
            STAKE_AMOUNT,
            stakingV2.MONTH_6(),
            alice
        );
        
        assertEq(stakingV2.referrers(charlie), alice, "Referrer not set");
        assertGt(stakingV2.loyaltyPoints(charlie), 0, "No loyalty points");
        vm.stopPrank();
    }
    
    function testExistingPositionsCanClaimRewardsAfterUpgrade() public {
        // Setup reward rate and create position
        vm.prank(admin);
        stakingV1.setRewardRate(100);
        
        vm.prank(alice);
        position1 = stakingV1.stake(STAKE_AMOUNT, stakingV1.MONTH_1());
        
        // Fast forward to accumulate rewards
        vm.warp(block.timestamp + 1 days);
        
        // Upgrade
        vm.startPrank(admin);
        StakingPositionsV2Example stakingV2Impl = new StakingPositionsV2Example();
        stakingV1.upgradeToAndCall(
            address(stakingV2Impl),
            abi.encodeCall(StakingPositionsV2Example.initializeV2, ())
        );
        stakingV2 = StakingPositionsV2Example(address(stakingProxy));
        vm.stopPrank();
        
        // Claim rewards using V2 contract
        uint256 balanceBefore = rdat.balanceOf(alice);
        
        vm.prank(alice);
        stakingV2.claimRewards(position1);
        
        uint256 balanceAfter = rdat.balanceOf(alice);
        assertGt(balanceAfter, balanceBefore, "No rewards claimed");
    }
    
    function testExistingPositionsCanBeUnstakedAfterUpgrade() public {
        // Create locked position
        vm.prank(alice);
        position1 = stakingV1.stake(STAKE_AMOUNT, stakingV1.MONTH_1());
        
        // Upgrade
        vm.startPrank(admin);
        StakingPositionsV2Example stakingV2Impl = new StakingPositionsV2Example();
        stakingV1.upgradeToAndCall(
            address(stakingV2Impl),
            abi.encodeCall(StakingPositionsV2Example.initializeV2, ())
        );
        stakingV2 = StakingPositionsV2Example(address(stakingProxy));
        vm.stopPrank();
        
        // Fast forward past lock
        vm.warp(block.timestamp + stakingV2.MONTH_1() + 1);
        
        // Unstake using V2
        uint256 balanceBefore = rdat.balanceOf(alice);
        
        vm.prank(alice);
        stakingV2.unstake(position1);
        
        uint256 balanceAfter = rdat.balanceOf(alice);
        assertEq(balanceAfter, balanceBefore + STAKE_AMOUNT, "Wrong unstake amount");
        
        // Verify NFT burned
        vm.expectRevert();
        stakingV2.ownerOf(position1);
    }
    
    function testV2FeaturesWorkWithBoosts() public {
        // Upgrade first
        vm.startPrank(admin);
        StakingPositionsV2Example stakingV2Impl = new StakingPositionsV2Example();
        stakingV1.upgradeToAndCall(
            address(stakingV2Impl),
            abi.encodeCall(StakingPositionsV2Example.initializeV2, ())
        );
        stakingV2 = StakingPositionsV2Example(address(stakingProxy));
        vm.stopPrank();
        
        // Create multiple positions to earn loyalty
        vm.startPrank(alice);
        
        // First stake with referral
        position1 = stakingV2.stakeWithReferral(
            STAKE_AMOUNT,
            stakingV2.MONTH_12(),
            bob
        );
        
        // Check loyalty points earned
        uint256 loyaltyPoints = stakingV2.loyaltyPoints(alice);
        assertEq(loyaltyPoints, 4000, "Wrong loyalty points"); // 1000 * 4
        
        // Second stake should have boost
        vm.warp(block.timestamp + vrdat.MINT_DELAY() + 1);
        position2 = stakingV2.stakeWithReferral(
            STAKE_AMOUNT,
            stakingV2.MONTH_6(),
            address(0)
        );
        
        uint256 boost = stakingV2.positionBoosts(position2);
        assertEq(boost, 1000, "Wrong boost"); // 10% boost for 1000+ loyalty
        
        vm.stopPrank();
        
        // Check referral rewards for Bob
        uint256 bobReferralRewards = stakingV2.referralRewards(bob);
        assertEq(bobReferralRewards, STAKE_AMOUNT * 500 / 10000, "Wrong referral rewards");
    }
    
    function testStorageCollisionPrevention() public {
        // Create position with specific data
        vm.prank(alice);
        position1 = stakingV1.stake(12345 * 10**18, stakingV1.MONTH_3());
        
        // Get raw storage slot for position data
        bytes32 positionSlot = keccak256(abi.encode(position1, uint256(62))); // slot 62 is _positions mapping
        uint256 storedAmount = uint256(vm.load(address(stakingProxy), positionSlot));
        
        // Upgrade
        vm.startPrank(admin);
        StakingPositionsV2Example stakingV2Impl = new StakingPositionsV2Example();
        stakingV1.upgradeToAndCall(
            address(stakingV2Impl),
            abi.encodeCall(StakingPositionsV2Example.initializeV2, ())
        );
        stakingV2 = StakingPositionsV2Example(address(stakingProxy));
        vm.stopPrank();
        
        // Verify storage unchanged
        uint256 storedAmountAfter = uint256(vm.load(address(stakingProxy), positionSlot));
        assertEq(storedAmountAfter, storedAmount, "Storage corrupted");
        
        // Verify through getter
        IStakingPositions.Position memory pos = stakingV2.getPosition(position1);
        assertEq(pos.amount, 12345 * 10**18, "Position data corrupted");
    }
}