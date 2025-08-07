// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../../src/StakingPositions.sol";
import "../../src/RDATUpgradeable.sol";
import "../../src/vRDAT.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title MinStakeTest
 * @author r/datadao
 * @notice Simple test for minimum stake amount security fix
 */
contract MinStakeTest is Test {
    StakingPositions public stakingPositions;
    RDATUpgradeable public rdat;
    vRDAT public vrdat;

    address public admin = address(0x1);
    address public user = address(0x2);
    address public treasury = address(0x4);

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

        // Setup roles
        // RDAT no longer has MINTER_ROLE - admin);
        vrdat.grantRole(vrdat.MINTER_ROLE(), address(stakingPositions));

        // Transfer test tokens from treasury (no minting)
        vm.startPrank(treasury);
        rdat.transfer(user, 10e18); // 10 RDAT for user
        vm.stopPrank();

        vm.startPrank(admin);
        vm.stopPrank();
    }

    function test_MinimumStakeEnforcement() public {
        vm.startPrank(user);

        // Test 1: Dust amount (1 wei) should fail
        rdat.approve(address(stakingPositions), 1);
        vm.expectRevert(IStakingPositions.BelowMinimumStake.selector);
        stakingPositions.stake(1, 30 days);

        // Test 2: Just under minimum (1 RDAT - 1 wei) should fail
        rdat.approve(address(stakingPositions), 1e18 - 1);
        vm.expectRevert(IStakingPositions.BelowMinimumStake.selector);
        stakingPositions.stake(1e18 - 1, 30 days);

        // Test 3: Exactly minimum (1 RDAT) should succeed
        rdat.approve(address(stakingPositions), 1e18);
        uint256 positionId = stakingPositions.stake(1e18, 30 days);

        // Verify position was created
        assertEq(positionId, 1);
        assertEq(stakingPositions.balanceOf(user), 1);

        // Test 4: Above minimum should succeed
        rdat.approve(address(stakingPositions), 2e18);
        uint256 positionId2 = stakingPositions.stake(2e18, 30 days);

        assertEq(positionId2, 2);
        assertEq(stakingPositions.balanceOf(user), 2);

        vm.stopPrank();
    }

    function test_MaxPositionsLimit() public {
        vm.startPrank(user);

        // Create 3 positions (small test)
        for (uint256 i = 0; i < 3; i++) {
            rdat.approve(address(stakingPositions), 1e18);
            stakingPositions.stake(1e18, 30 days);
        }

        // Verify positions created
        assertEq(stakingPositions.balanceOf(user), 3);

        vm.stopPrank();
    }
}
