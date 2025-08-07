// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {vRDAT} from "../../src/vRDAT.sol";
import {IvRDAT} from "../../src/interfaces/IvRDAT.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract vRDATTest is Test {
    vRDAT public vrdat;
    
    address public admin;
    address public minter;
    address public burner;
    address public user1;
    address public user2;
    address public user3;
    
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    
    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    
    function setUp() public {
        admin = makeAddr("admin");
        minter = makeAddr("minter");
        burner = makeAddr("burner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        
        vm.prank(admin);
        vrdat = new vRDAT(admin);
        
        // Grant roles
        vm.startPrank(admin);
        vrdat.grantRole(MINTER_ROLE, minter);
        vrdat.grantRole(BURNER_ROLE, burner);
        vm.stopPrank();
    }
    
    function test_InitialState() public view {
        assertEq(vrdat.name(), "r/datadao Voting");
        assertEq(vrdat.symbol(), "vRDAT");
        assertEq(vrdat.decimals(), 18);
        assertEq(vrdat.totalSupply(), 0);
        
        assertTrue(vrdat.hasRole(DEFAULT_ADMIN_ROLE, admin));
        assertTrue(vrdat.hasRole(MINTER_ROLE, admin));
        assertTrue(vrdat.hasRole(MINTER_ROLE, minter));
        assertTrue(vrdat.hasRole(BURNER_ROLE, admin));
        assertTrue(vrdat.hasRole(BURNER_ROLE, burner));
    }
    
    function test_MintingWithRole() public {
        uint256 amount = 1000 * 10**18;
        
        vm.prank(minter);
        vm.expectEmit(true, false, false, true);
        emit Mint(user1, amount);
        vrdat.mint(user1, amount);
        
        assertEq(vrdat.balanceOf(user1), amount);
        assertEq(vrdat.totalSupply(), amount);
        assertEq(vrdat.totalMinted(user1), amount);
    }
    
    function test_MintingWithoutRole() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user1,
                MINTER_ROLE
            )
        );
        vrdat.mint(user2, 1000);
    }
    
    function test_MultipleMints() public {
        uint256 amount = 1000 * 10**18;
        
        // First mint
        vm.prank(minter);
        vrdat.mint(user1, amount);
        
        // Should be able to mint again immediately (no delay for soul-bound tokens)
        vm.prank(minter);
        vrdat.mint(user1, amount);
        
        assertEq(vrdat.balanceOf(user1), amount * 2);
        assertEq(vrdat.totalMinted(user1), amount * 2);
    }
    
    function test_MaxBalanceLimit() public {
        uint256 maxBalance = vrdat.MAX_PER_ADDRESS();
        
        // Mint up to max
        vm.prank(minter);
        vrdat.mint(user1, maxBalance);
        
        // Try to mint more (should exceed max balance)
        vm.prank(minter);
        vm.expectRevert(IvRDAT.ExceedsMaxBalance.selector);
        vrdat.mint(user1, 1);
    }
    
    function test_BurningWithRole() public {
        uint256 amount = 1000 * 10**18;
        
        // Mint first
        vm.prank(minter);
        vrdat.mint(user1, amount);
        
        // Burn half
        uint256 burnAmount = amount / 2;
        vm.prank(burner);
        vm.expectEmit(true, false, false, true);
        emit Burn(user1, burnAmount);
        vrdat.burn(user1, burnAmount);
        
        assertEq(vrdat.balanceOf(user1), amount - burnAmount);
        assertEq(vrdat.totalSupply(), amount - burnAmount);
        assertEq(vrdat.totalBurned(user1), burnAmount);
    }
    
    function test_BurningWithoutRole() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user1,
                BURNER_ROLE
            )
        );
        vrdat.burn(user2, 1000);
    }
    
    function test_NonTransferableTransfer() public {
        uint256 amount = 1000 * 10**18;
        
        // Mint tokens
        vm.prank(minter);
        vrdat.mint(user1, amount);
        
        // Try to transfer
        vm.prank(user1);
        vm.expectRevert(IvRDAT.NonTransferableToken.selector);
        vrdat.transfer(user2, amount);
    }
    
    function test_NonTransferableTransferFrom() public {
        uint256 amount = 1000 * 10**18;
        
        // Mint tokens
        vm.prank(minter);
        vrdat.mint(user1, amount);
        
        // Try to transfer from
        vm.prank(user2);
        vm.expectRevert(IvRDAT.NonTransferableToken.selector);
        vrdat.transferFrom(user1, user2, amount);
    }
    
    function test_NonTransferableApprove() public {
        // Try to approve
        vm.prank(user1);
        vm.expectRevert(IvRDAT.NonTransferableToken.selector);
        vrdat.approve(user2, 1000);
    }
    
    function test_Delegation() public {
        uint256 amount = 1000 * 10**18;
        
        // Mint tokens to multiple users
        vm.startPrank(minter);
        vrdat.mint(user1, amount);
        vrdat.mint(user2, amount * 2);
        vm.stopPrank();
        
        // Check initial voting power
        assertEq(vrdat.getVotes(user1), 0); // Not delegated yet
        assertEq(vrdat.getVotes(user2), 0);
        
        // User1 delegates to themselves
        vm.prank(user1);
        vrdat.delegate(user1);
        assertEq(vrdat.getVotes(user1), amount);
        
        // User2 delegates to user1
        vm.prank(user2);
        vm.expectEmit(true, true, true, false);
        emit DelegateChanged(user2, address(0), user1);
        vrdat.delegate(user1);
        
        // User1 now has voting power from both
        assertEq(vrdat.getVotes(user1), amount * 3);
        assertEq(vrdat.getVotes(user2), 0);
        
        // User2 changes delegation to themselves
        vm.prank(user2);
        vrdat.delegate(user2);
        
        assertEq(vrdat.getVotes(user1), amount);
        assertEq(vrdat.getVotes(user2), amount * 2);
    }
    
    function test_QuadraticVotingMath() public view {
        // Test quadratic cost calculation
        assertEq(vrdat.calculateQuadraticCost(0), 0);
        assertEq(vrdat.calculateQuadraticCost(1), 1);
        assertEq(vrdat.calculateQuadraticCost(2), 4);
        assertEq(vrdat.calculateQuadraticCost(3), 9);
        assertEq(vrdat.calculateQuadraticCost(10), 100);
        assertEq(vrdat.calculateQuadraticCost(100), 10000);
        
        // Test quadratic votes calculation (square root)
        assertEq(vrdat.calculateQuadraticVotes(0), 0);
        assertEq(vrdat.calculateQuadraticVotes(1), 1);
        assertEq(vrdat.calculateQuadraticVotes(4), 2);
        assertEq(vrdat.calculateQuadraticVotes(9), 3);
        assertEq(vrdat.calculateQuadraticVotes(100), 10);
        assertEq(vrdat.calculateQuadraticVotes(10000), 100);
        
        // Test non-perfect squares
        assertEq(vrdat.calculateQuadraticVotes(5), 2); // Floor of sqrt(5)
        assertEq(vrdat.calculateQuadraticVotes(99), 9); // Floor of sqrt(99)
    }
    
    function test_GetUserStats() public {
        uint256 amount1 = 1000 * 10**18;
        uint256 amount2 = 500 * 10**18;
        uint256 burnAmount = 200 * 10**18;
        
        // Mint tokens
        vm.startPrank(minter);
        vrdat.mint(user1, amount1);
        vrdat.mint(user1, amount2); // No delay needed for soul-bound tokens
        vm.stopPrank();
        
        // Burn some tokens
        vm.prank(burner);
        vrdat.burn(user1, burnAmount);
        
        // Delegate to self
        vm.prank(user1);
        vrdat.delegate(user1);
        
        // Check stats
        (uint256 balance, uint256 minted, uint256 burned, uint256 votingPower) = vrdat.getUserStats(user1);
        
        assertEq(balance, amount1 + amount2 - burnAmount);
        assertEq(minted, amount1 + amount2);
        assertEq(burned, burnAmount);
        assertEq(votingPower, balance);
    }
    
    function test_CanMint() public {
        // Check initial state
        (bool canMint, uint256 remainingCapacity) = vrdat.canMint(user1);
        assertTrue(canMint);
        assertEq(remainingCapacity, vrdat.MAX_PER_ADDRESS());
        
        // Mint some tokens
        uint256 mintAmount = 1000 * 10**18;
        vm.prank(minter);
        vrdat.mint(user1, mintAmount);
        
        // Should still be able to mint (no delay)
        (canMint, remainingCapacity) = vrdat.canMint(user1);
        assertTrue(canMint);
        assertEq(remainingCapacity, vrdat.MAX_PER_ADDRESS() - mintAmount);
        
        // Mint up to max
        uint256 maxPerAddress = vrdat.MAX_PER_ADDRESS();
        vm.prank(minter);
        vrdat.mint(user1, maxPerAddress - mintAmount);
        
        // Now should not be able to mint
        (canMint, remainingCapacity) = vrdat.canMint(user1);
        assertFalse(canMint);
        assertEq(remainingCapacity, 0);
    }
    
    function test_VotingPowerAfterBurn() public {
        uint256 amount = 1000 * 10**18;
        
        // Mint and delegate
        vm.prank(minter);
        vrdat.mint(user1, amount);
        
        vm.prank(user1);
        vrdat.delegate(user1);
        
        assertEq(vrdat.getVotes(user1), amount);
        
        // Burn half
        vm.prank(burner);
        vrdat.burn(user1, amount / 2);
        
        // Voting power should decrease
        assertEq(vrdat.getVotes(user1), amount / 2);
    }
    
    function test_ConsecutiveMints() public {
        uint256 amount = 1000 * 10**18;
        uint256 mintCount = 5;
        
        // Should be able to mint multiple times without delay
        for (uint256 i = 0; i < mintCount; i++) {
            vm.prank(minter);
            vrdat.mint(user1, amount);
        }
        
        assertEq(vrdat.balanceOf(user1), amount * mintCount);
        assertEq(vrdat.totalMinted(user1), amount * mintCount);
    }
    
    function testFuzz_MintBurn(uint256 mintAmount, uint256 burnAmount) public {
        mintAmount = bound(mintAmount, 1, vrdat.MAX_PER_ADDRESS());
        burnAmount = bound(burnAmount, 0, mintAmount);
        
        // Mint
        vm.prank(minter);
        vrdat.mint(user1, mintAmount);
        
        assertEq(vrdat.balanceOf(user1), mintAmount);
        
        // Burn
        if (burnAmount > 0) {
            vm.prank(burner);
            vrdat.burn(user1, burnAmount);
            
            assertEq(vrdat.balanceOf(user1), mintAmount - burnAmount);
            assertEq(vrdat.totalBurned(user1), burnAmount);
        }
    }
    
    function testFuzz_QuadraticMath(uint256 votes) public view {
        votes = bound(votes, 0, 1000000); // Reasonable bounds
        
        uint256 cost = vrdat.calculateQuadraticCost(votes);
        assertEq(cost, votes * votes);
        
        // Verify inverse relationship (with rounding)
        uint256 calculatedVotes = vrdat.calculateQuadraticVotes(cost);
        assertLe(calculatedVotes, votes);
        assertGe(calculatedVotes, votes > 0 ? votes - 1 : 0);
    }
}