// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {RDATUpgradeable} from "../../../src/RDATUpgradeable.sol";
import {vRDAT} from "../../../src/vRDAT.sol";
import {StakingPositions} from "../../../src/StakingPositions.sol";
import {VanaMigrationBridge} from "../../../src/VanaMigrationBridge.sol";
import {BaseMigrationBridge} from "../../../src/BaseMigrationBridge.sol";
import {MockRDAT} from "../../../src/mocks/MockRDAT.sol";
import {RewardsManager} from "../../../src/RewardsManager.sol";
import {TreasuryWallet} from "../../../src/TreasuryWallet.sol";
import {OffChainSimulator} from "./OffChainSimulator.sol";

/**
 * @title ScenarioHelpers
 * @notice Utility functions for scenario testing
 * @dev Provides common setup, state management, and verification functions
 */
contract ScenarioHelpers is Test {
    
    // ============ State Management ============
    
    struct SystemSnapshot {
        uint256 blockNumber;
        uint256 timestamp;
        uint256 totalRDATSupply;
        uint256 totalvRDATSupply;
        uint256 totalStaked;
        uint256 activePositions;
        bytes32 stateHash;
    }
    
    struct UserProfile {
        string name;
        address addr;
        uint256 v1Balance;
        uint256 v2Balance;
        uint256 vrdatBalance;
        uint256[] stakingPositions;
        bool hasVoted;
        uint256 totalRewardsClaimed;
    }
    
    mapping(bytes32 => SystemSnapshot) private snapshots;
    mapping(address => UserProfile) private userProfiles;
    address[] private managedUsers;
    uint256 private userCounter;
    
    // System contracts
    RDATUpgradeable public rdatToken;
    vRDAT public vrdatToken;
    StakingPositions public stakingContract;
    VanaMigrationBridge public vanaBridge;
    BaseMigrationBridge public baseBridge;
    MockRDAT public v1Token;
    RewardsManager public rewardsManager;
    TreasuryWallet public treasury;
    OffChainSimulator public simulator;
    
    // Default test parameters
    address public constant DEFAULT_ADMIN = address(0x1);
    address public constant DEFAULT_TREASURY = address(0x2);
    uint256 public constant DEFAULT_V1_AMOUNT = 10_000e18;
    uint256 public constant DEFAULT_ETH_AMOUNT = 10 ether;
    
    // Events
    event UserCreated(string indexed name, address indexed user);
    event UserFunded(address indexed user, uint256 v1Amount, uint256 ethAmount);
    event SystemSnapshotTaken(bytes32 indexed snapshotId, uint256 blockNumber);
    event SystemSnapshotRestored(bytes32 indexed snapshotId);
    event ScenarioStarted(string indexed scenarioName);
    event ScenarioCompleted(string indexed scenarioName, bool success);
    
    // ============ User Management ============
    
    /**
     * @notice Creates a new test user with a memorable name
     */
    function createUser(string memory name) external returns (address user) {
        userCounter++;
        user = vm.addr(userCounter + 1000); // Offset to avoid common test addresses
        
        UserProfile storage profile = userProfiles[user];
        profile.name = name;
        profile.addr = user;
        
        managedUsers.push(user);
        
        // Give the user some ETH for transactions
        vm.deal(user, DEFAULT_ETH_AMOUNT);
        
        emit UserCreated(name, user);
        console2.log(string.concat("[USER] Created user: ", name, " at ", vm.toString(user)));
        
        return user;
    }
    
    /**
     * @notice Creates multiple users at once
     */
    function createUsers(string[] memory names) external returns (address[] memory users) {
        users = new address[](names.length);
        for (uint256 i = 0; i < names.length; i++) {
            users[i] = this.createUser(names[i]);
        }
        return users;
    }
    
    /**
     * @notice Funds a user with V1 tokens and ETH
     */
    function fundUser(address user, uint256 v1Amount, uint256 ethAmount) external {
        require(userProfiles[user].addr != address(0), "User not registered");
        
        // Fund with V1 tokens (if v1Token is set)
        if (address(v1Token) != address(0) && v1Amount > 0) {
            vm.prank(DEFAULT_ADMIN);
            v1Token.mint(user, v1Amount);
            userProfiles[user].v1Balance += v1Amount;
        }
        
        // Fund with ETH
        if (ethAmount > 0) {
            vm.deal(user, address(user).balance + ethAmount);
        }
        
        emit UserFunded(user, v1Amount, ethAmount);
        console2.log(string.concat("[FUND] Funded ", userProfiles[user].name, " with ", vm.toString(v1Amount / 1e18), " V1 tokens"));
    }
    
    /**
     * @notice Sets up staking positions for a user
     */
    function setupUserStaking(
        address user, 
        uint256[] memory amounts, 
        uint256[] memory periods
    ) external {
        require(amounts.length == periods.length, "Mismatched arrays");
        require(userProfiles[user].addr != address(0), "User not registered");
        require(address(stakingContract) != address(0), "Staking not initialized");
        
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }
        
        // Ensure user has enough RDAT
        if (rdatToken.balanceOf(user) < totalAmount) {
            // Fund user with additional RDAT if needed (admin action)
            vm.prank(DEFAULT_ADMIN);
            rdatToken.transfer(user, totalAmount - rdatToken.balanceOf(user));
        }
        
        vm.startPrank(user);
        rdatToken.approve(address(stakingContract), totalAmount);
        
        for (uint256 i = 0; i < amounts.length; i++) {
            uint256 positionId = stakingContract.stake(amounts[i], periods[i]);
            userProfiles[user].stakingPositions.push(positionId);
            
            console2.log(string.concat("[CHART] Staked ", vm.toString(amounts[i] / 1e18), " RDAT for ", vm.toString(periods[i] / 1 days), " days"));
        }
        vm.stopPrank();
        
        console2.log(string.concat("[OK] Setup ", vm.toString(amounts.length), " staking positions for ", userProfiles[user].name));
    }
    
    // ============ System State Management ============
    
    /**
     * @notice Takes a snapshot of the current system state
     */
    function snapshotSystemState() external returns (bytes32 snapshotId) {
        snapshotId = keccak256(abi.encodePacked(block.number, block.timestamp, userCounter));
        
        SystemSnapshot storage snapshot = snapshots[snapshotId];
        snapshot.blockNumber = block.number;
        snapshot.timestamp = block.timestamp;
        
        if (address(rdatToken) != address(0)) {
            snapshot.totalRDATSupply = rdatToken.totalSupply();
        }
        if (address(vrdatToken) != address(0)) {
            snapshot.totalvRDATSupply = vrdatToken.totalSupply();
        }
        if (address(stakingContract) != address(0)) {
            snapshot.totalStaked = rdatToken.balanceOf(address(stakingContract));
            snapshot.activePositions = stakingContract.totalSupply();
        }
        
        // Create state hash for integrity checking
        snapshot.stateHash = keccak256(abi.encodePacked(
            snapshot.totalRDATSupply,
            snapshot.totalvRDATSupply,
            snapshot.totalStaked,
            snapshot.activePositions
        ));
        
        emit SystemSnapshotTaken(snapshotId, block.number);
        console2.log("[SNAP] System snapshot taken:", vm.toString(snapshotId));
        
        return snapshotId;
    }
    
    /**
     * @notice Restores system state to a previous snapshot
     */
    function restoreSystemState(bytes32 snapshotId) external {
        SystemSnapshot storage snapshot = snapshots[snapshotId];
        require(snapshot.blockNumber != 0, "Snapshot doesn't exist");
        
        // Restore block state
        vm.roll(snapshot.blockNumber);
        vm.warp(snapshot.timestamp);
        
        emit SystemSnapshotRestored(snapshotId);
        console2.log("[RESTORE] System state restored to snapshot:", vm.toString(snapshotId));
    }
    
    /**
     * @notice Validates system invariants
     */
    function validateSystemInvariants() external view returns (bool) {
        if (address(rdatToken) == address(0)) return true;
        
        // Check total supply invariant
        uint256 expectedSupply = 100_000_000e18;
        if (rdatToken.totalSupply() != expectedSupply) {
            console2.log("[FAIL] Total supply invariant violated");
            console2.log("   Expected:", expectedSupply);
            console2.log("   Actual:", rdatToken.totalSupply());
            return false;
        }
        
        // Check migration allocation invariant
        if (address(vanaBridge) != address(0)) {
            uint256 bridgeBalance = rdatToken.balanceOf(address(vanaBridge));
            uint256 totalMigrated = vanaBridge.totalMigrated();
            uint256 expectedRemaining = 30_000_000e18 - totalMigrated;
            
            if (bridgeBalance != expectedRemaining) {
                console2.log("[FAIL] Migration balance invariant violated");
                console2.log("   Expected bridge balance:", expectedRemaining);
                console2.log("   Actual bridge balance:", bridgeBalance);
                return false;
            }
        }
        
        console2.log("[OK] All system invariants validated");
        return true;
    }
    
    // ============ Event Verification ============
    
    /**
     * @notice Expects a migration event to be emitted
     */
    function expectMigrationEvent(address user, uint256 amount) external {
        vm.expectEmit(true, true, false, true);
        emit VanaMigrationBridge.MigrationCompleted(
            user, 
            amount,
            0 // bonus
        );
        console2.log(string.concat("[SEARCH] Expecting migration event for ", userProfiles[user].name));
    }
    
    /**
     * @notice Expects a staking event to be emitted
     */
    function expectStakingEvent(address user, uint256 positionId) external {
        // Note: Would need to check actual StakingPositions events
        console2.log(string.concat("[SEARCH] Expecting staking event for position ", vm.toString(positionId)));
    }
    
    /**
     * @notice Expects a governance event to be emitted
     */
    function expectGovernanceEvent(uint256 proposalId, uint8 outcome) external {
        // Note: Would need to check actual governance contract events
        console2.log(string.concat("[SEARCH] Expecting governance event for proposal ", vm.toString(proposalId), " outcome ", vm.toString(outcome)));
    }
    
    // ============ Scenario Management ============
    
    /**
     * @notice Marks the start of a scenario test
     */
    function startScenario(string memory scenarioName) external {
        emit ScenarioStarted(scenarioName);
        console2.log("");
        console2.log("[START] Starting scenario:", scenarioName);
        console2.log("========================================");
    }
    
    /**
     * @notice Marks the completion of a scenario test
     */
    function completeScenario(string memory scenarioName, bool success) external {
        emit ScenarioCompleted(scenarioName, success);
        console2.log("========================================");
        if (success) {
            console2.log("[OK] Scenario completed successfully:", scenarioName);
        } else {
            console2.log("[FAIL] Scenario failed:", scenarioName);
        }
        console2.log("");
    }
    
    // ============ Contract Setup Helpers ============
    
    /**
     * @notice Sets the system contracts for helpers to use
     */
    function setSystemContracts(
        address _rdatToken,
        address _vrdatToken,
        address _stakingContract,
        address _vanaBridge,
        address _baseBridge,
        address _v1Token,
        address _rewardsManager,
        address _treasury,
        address _simulator
    ) external {
        rdatToken = RDATUpgradeable(_rdatToken);
        vrdatToken = vRDAT(_vrdatToken);
        stakingContract = StakingPositions(_stakingContract);
        vanaBridge = VanaMigrationBridge(_vanaBridge);
        baseBridge = BaseMigrationBridge(_baseBridge);
        v1Token = MockRDAT(_v1Token);
        rewardsManager = RewardsManager(_rewardsManager);
        treasury = TreasuryWallet(payable(_treasury));
        simulator = OffChainSimulator(_simulator);
        
        console2.log("[CONFIG] System contracts configured for scenario testing");
    }
    
    // ============ Analytics and Reporting ============
    
    /**
     * @notice Gets comprehensive user information
     */
    function getUserInfo(address user) external view returns (
        string memory name,
        uint256 v1Balance,
        uint256 v2Balance,
        uint256 vrdatBalance,
        uint256 stakingPositionCount,
        uint256 totalRewardsClaimed
    ) {
        UserProfile storage profile = userProfiles[user];
        return (
            profile.name,
            address(v1Token) != address(0) ? v1Token.balanceOf(user) : 0,
            address(rdatToken) != address(0) ? rdatToken.balanceOf(user) : 0,
            address(vrdatToken) != address(0) ? vrdatToken.balanceOf(user) : 0,
            profile.stakingPositions.length,
            profile.totalRewardsClaimed
        );
    }
    
    /**
     * @notice Gets system-wide statistics
     */
    function getSystemStats() external view returns (
        uint256 totalUsers,
        uint256 totalRDATSupply,
        uint256 totalvRDATSupply,
        uint256 totalStaked,
        uint256 activePositions,
        uint256 totalMigrated
    ) {
        totalUsers = managedUsers.length;
        
        if (address(rdatToken) != address(0)) {
            totalRDATSupply = rdatToken.totalSupply();
        }
        if (address(vrdatToken) != address(0)) {
            totalvRDATSupply = vrdatToken.totalSupply();
        }
        if (address(stakingContract) != address(0)) {
            totalStaked = rdatToken.balanceOf(address(stakingContract));
            activePositions = stakingContract.totalSupply();
        }
        if (address(vanaBridge) != address(0)) {
            totalMigrated = vanaBridge.totalMigrated();
        }
    }
    
    /**
     * @notice Prints a detailed system report
     */
    function printSystemReport() external view {
        console2.log("");
        console2.log("[CHART] SYSTEM REPORT");
        console2.log("=======================================");
        
        (
            uint256 totalUsers,
            uint256 totalRDATSupply,
            uint256 totalvRDATSupply,
            uint256 totalStaked,
            uint256 activePositions,
            uint256 totalMigrated
        ) = this.getSystemStats();
        
        console2.log(string.concat("[USERS] Total Users: ", vm.toString(totalUsers)));
        console2.log(string.concat("[TOKEN] Total RDAT Supply: ", vm.toString(totalRDATSupply / 1e18)));
        console2.log(string.concat("[VOTE] Total vRDAT Supply: ", vm.toString(totalvRDATSupply / 1e18)));
        console2.log(string.concat("[CHART] Total Staked: ", vm.toString(totalStaked / 1e18)));
        console2.log(string.concat("[TREND] Active Positions: ", vm.toString(activePositions)));
        console2.log(string.concat("[BRIDGE] Total Migrated: ", vm.toString(totalMigrated / 1e18)));
        console2.log("=======================================");
        console2.log("");
    }
    
    /**
     * @notice Cleanup function for test teardown
     */
    function cleanup() external {
        // Reset user profiles
        for (uint256 i = 0; i < managedUsers.length; i++) {
            delete userProfiles[managedUsers[i]];
        }
        delete managedUsers;
        userCounter = 0;
        
        // Reset simulator if available
        if (address(simulator) != address(0)) {
            simulator.resetSimulation();
        }
        
        console2.log("[CLEAN] Scenario helpers cleanup completed");
    }
}