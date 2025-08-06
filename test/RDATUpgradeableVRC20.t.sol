// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../src/RDATUpgradeable.sol";
import "../src/ProofOfContribution.sol";
import "../src/EmergencyPause.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract RDATUpgradeableVRC20Test is Test {
    RDATUpgradeable public implementation;
    RDATUpgradeable public rdat;
    ProofOfContribution public poc;
    EmergencyPause public emergencyPause;
    
    address public admin = address(0x1);
    address public treasury = address(0x2);
    address public user1 = address(0x3);
    address public user2 = address(0x4);
    address public validator1 = address(0x5);
    address public validator2 = address(0x6);
    address public dlpAddress = address(0x7);
    
    // Events
    event DataPoolCreated(bytes32 indexed poolId, address indexed creator, string metadata);
    event DataAdded(bytes32 indexed poolId, bytes32 indexed dataHash, address indexed contributor);
    event DLPRegistered(address indexed dlpAddress, uint256 timestamp);
    event EpochRewardsSet(uint256 indexed epoch, uint256 rewards);
    event EpochRewardsClaimed(address indexed user, uint256 indexed epoch, uint256 amount);

    function setUp() public {
        vm.startPrank(admin);
        
        // Deploy implementation
        implementation = new RDATUpgradeable();
        
        // Deploy proxy
        bytes memory initData = abi.encodeCall(
            RDATUpgradeable.initialize,
            (treasury, admin, address(0x100)) // migration contract address
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        rdat = RDATUpgradeable(address(proxy));
        
        // Deploy ProofOfContribution
        emergencyPause = new EmergencyPause(admin);
        address[] memory validators = new address[](2);
        validators[0] = validator1;
        validators[1] = validator2;
        poc = new ProofOfContribution(dlpAddress, address(emergencyPause), validators);
        
        // Set PoC contract
        rdat.setPoCContract(address(poc));
        
        vm.stopPrank();
    }

    // ========== VRC-20 VERSION TESTS ==========

    function test_VRCVersion() public view {
        assertEq(rdat.vrcVersion(), "VRC-20-1.0");
        assertTrue(rdat.isVRC20());
    }

    // ========== DATA POOL TESTS ==========

    function test_CreateDataPool() public {
        bytes32 poolId = keccak256("pool1");
        string memory metadata = "ipfs://QmXxx";
        address[] memory contributors = new address[](2);
        contributors[0] = user1;
        contributors[1] = user2;
        
        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit DataPoolCreated(poolId, user1, metadata);
        
        bool success = rdat.createDataPool(poolId, metadata, contributors);
        assertTrue(success);
        
        // Check pool data
        (
            address creator,
            string memory poolMetadata,
            uint256 contributorCount,
            uint256 totalDataPoints,
            bool active
        ) = rdat.getDataPool(poolId);
        
        assertEq(creator, user1);
        assertEq(poolMetadata, metadata);
        assertEq(contributorCount, 2);
        assertEq(totalDataPoints, 0);
        assertTrue(active);
    }

    function test_CreateDataPool_AlreadyExists() public {
        bytes32 poolId = keccak256("pool1");
        address[] memory contributors = new address[](0);
        
        vm.prank(user1);
        rdat.createDataPool(poolId, "metadata1", contributors);
        
        vm.prank(user2);
        vm.expectRevert("Pool already exists");
        rdat.createDataPool(poolId, "metadata2", contributors);
    }

    function test_AddDataToPool() public {
        // Create pool first
        bytes32 poolId = keccak256("pool1");
        address[] memory contributors = new address[](0);
        
        vm.prank(user1);
        rdat.createDataPool(poolId, "metadata", contributors);
        
        // Add data
        bytes32 dataHash = keccak256("data1");
        uint256 quality = 80;
        
        vm.prank(user1);
        vm.expectEmit(true, true, true, false);
        emit DataAdded(poolId, dataHash, user1);
        
        bool success = rdat.addDataToPool(poolId, dataHash, quality);
        assertTrue(success);
        
        // Check data point
        (
            address contributor,
            uint256 timestamp,
            uint256 dataQuality,
            bool verified
        ) = rdat.getDataPoint(poolId, dataHash);
        
        assertEq(contributor, user1);
        assertEq(timestamp, block.timestamp);
        assertEq(dataQuality, quality);
        assertFalse(verified);
        
        // Check pool updated
        (,, uint256 contributorCount, uint256 totalDataPoints,) = rdat.getDataPool(poolId);
        assertEq(contributorCount, 1);
        assertEq(totalDataPoints, 1);
    }

    function test_AddDataToPool_InvalidPool() public {
        bytes32 poolId = keccak256("nonexistent");
        bytes32 dataHash = keccak256("data1");
        
        vm.prank(user1);
        vm.expectRevert("Pool not active");
        rdat.addDataToPool(poolId, dataHash, 50);
    }

    function test_DataOwnership() public {
        // Create pool and add data
        bytes32 poolId = keccak256("pool1");
        bytes32 dataHash = keccak256("data1");
        address[] memory contributors = new address[](0);
        
        vm.startPrank(user1);
        rdat.createDataPool(poolId, "metadata", contributors);
        rdat.addDataToPool(poolId, dataHash, 75);
        vm.stopPrank();
        
        // Check ownership
        assertTrue(rdat.verifyDataOwnership(dataHash, user1));
        assertFalse(rdat.verifyDataOwnership(dataHash, user2));
    }

    // ========== DLP REGISTRATION TESTS ==========

    function test_RegisterDLP() public {
        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit DLPRegistered(dlpAddress, block.timestamp);
        
        bool success = rdat.registerDLP(dlpAddress);
        assertTrue(success);
        assertTrue(rdat.isDLPRegistered());
        assertEq(rdat.getDLPAddress(), dlpAddress);
    }

    function test_RegisterDLP_AlreadyRegistered() public {
        vm.startPrank(admin);
        rdat.registerDLP(dlpAddress);
        
        vm.expectRevert("DLP already registered");
        rdat.registerDLP(address(0x8));
        vm.stopPrank();
    }

    function test_RegisterDLP_NotAdmin() public {
        vm.prank(user1);
        vm.expectRevert();
        rdat.registerDLP(dlpAddress);
    }

    // ========== EPOCH REWARDS TESTS ==========

    function test_SetEpochRewards() public {
        uint256 epoch = 1;
        uint256 amount = 1000 ether;
        
        // First fund the contract with rewards from admin
        // Give admin some tokens to fund with
        vm.prank(treasury);
        rdat.transfer(admin, amount);
        
        vm.startPrank(admin);
        rdat.fundEpochRewards(amount);
        
        vm.expectEmit(true, false, false, true);
        emit EpochRewardsSet(epoch, amount);
        
        rdat.setEpochRewards(epoch, amount);
        vm.stopPrank();
        
        assertEq(rdat.epochRewards(epoch), amount);
    }

    function test_SetEpochRewards_ExceedsSupply() public {
        uint256 epoch = 1;
        uint256 tooMuch = 1000 ether;
        
        // Fund with less than what we'll try to set
        vm.prank(treasury);
        rdat.transfer(admin, 500 ether);
        
        vm.startPrank(admin);
        rdat.fundEpochRewards(500 ether);
        
        vm.expectRevert("Insufficient contract balance for rewards");
        rdat.setEpochRewards(epoch, tooMuch);
        vm.stopPrank();
    }

    function test_ClaimEpochRewards_NoRewards() public {
        // Try to claim from epoch with no rewards
        vm.prank(user1);
        vm.expectRevert("No rewards for epoch");
        rdat.claimEpochRewards(1);
    }

    function test_ClaimEpochRewards_Integration() public {
        // This test would require full integration with ProofOfContribution
        // For now, it will revert with "No rewards to claim" because
        // _calculateEpochReward returns 0
        
        // Fund the contract first
        vm.prank(treasury);
        rdat.transfer(admin, 1000 ether);
        
        vm.startPrank(admin);
        rdat.fundEpochRewards(1000 ether);
        rdat.setEpochRewards(1, 1000 ether);
        vm.stopPrank();
        
        vm.prank(user1);
        vm.expectRevert("No rewards to claim");
        rdat.claimEpochRewards(1);
    }

    // ========== INTEGRATION TESTS ==========

    function test_DataPoolWithPoC() public {
        // Set up PoC to accept contributions
        vm.prank(admin);
        poc.setRewardsManager(admin); // Just for testing
        
        // Create pool and add data
        bytes32 poolId = keccak256("pool1");
        bytes32 dataHash = keccak256("data1");
        address[] memory contributors = new address[](0);
        
        vm.startPrank(user1);
        rdat.createDataPool(poolId, "metadata", contributors);
        
        // This should trigger PoC recording
        rdat.addDataToPool(poolId, dataHash, 90);
        vm.stopPrank();
        
        // Check that PoC received the contribution
        assertEq(poc.contributionCount(user1), 1);
        ProofOfContribution.Contribution memory contrib = poc.contributions(user1, 0);
        assertEq(contrib.score, 90);
        assertEq(contrib.dataHash, dataHash);
    }

    // ========== VIEW FUNCTION TESTS ==========

    function test_GetDataPool_NonExistent() public view {
        bytes32 poolId = keccak256("nonexistent");
        
        (
            address creator,
            string memory metadata,
            uint256 contributorCount,
            uint256 totalDataPoints,
            bool active
        ) = rdat.getDataPool(poolId);
        
        assertEq(creator, address(0));
        assertEq(metadata, "");
        assertEq(contributorCount, 0);
        assertEq(totalDataPoints, 0);
        assertFalse(active);
    }

    function test_GetDataPoint_NonExistent() public view {
        bytes32 poolId = keccak256("pool1");
        bytes32 dataHash = keccak256("data1");
        
        (
            address contributor,
            uint256 timestamp,
            uint256 quality,
            bool verified
        ) = rdat.getDataPoint(poolId, dataHash);
        
        assertEq(contributor, address(0));
        assertEq(timestamp, 0);
        assertEq(quality, 0);
        assertFalse(verified);
    }
}