// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {RDAT} from "../../src/RDAT.sol";
import {TestHelpers} from "../TestHelpers.sol";

/**
 * @title RDATGasBenchmark
 * @notice Gas benchmark tests for RDAT token operations
 * @dev Run with: forge test --match-contract RDATGasBenchmark --gas-report
 */
contract RDATGasBenchmark is TestHelpers {
    RDAT public rdat;
    address public minter;
    
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    function setUp() public {
        labelAddresses();
        
        // Deploy RDAT
        rdat = new RDAT(treasury);
        
        // Setup minter
        minter = makeAddr("minter");
        rdat.grantRole(MINTER_ROLE, minter);
        
        // Give some tokens to alice for transfer tests
        vm.prank(treasury);
        rdat.transfer(alice, 10_000_000e18);
    }
    
    function test_GasDeployment() public {
        // Measure deployment gas
        uint256 gasStart = gasleft();
        new RDAT(treasury);
        uint256 gasUsed = gasStart - gasleft();
        console2.log("Deployment gas:", gasUsed);
    }
    
    function test_GasTransfer() public {
        vm.prank(alice);
        rdat.transfer(bob, 1000e18);
    }
    
    function test_GasTransferFrom() public {
        vm.prank(alice);
        rdat.approve(bob, 1000e18);
        
        vm.prank(bob);
        rdat.transferFrom(alice, charlie, 1000e18);
    }
    
    function test_GasMint() public {
        vm.prank(minter);
        rdat.mint(alice, 1000e18);
    }
    
    function test_GasBurn() public {
        vm.prank(alice);
        rdat.burn(1000e18);
    }
    
    function test_GasPause() public {
        rdat.pause();
    }
    
    function test_GasUnpause() public {
        rdat.pause();
        rdat.unpause();
    }
    
    function test_GasSetPoCContract() public {
        rdat.setPoCContract(makeAddr("poc"));
    }
    
    function test_GasSetDataRefiner() public {
        rdat.setDataRefiner(makeAddr("refiner"));
    }
    
    function test_GasSetRevenueCollector() public {
        rdat.setRevenueCollector(makeAddr("collector"));
    }
    
    function test_GasPermit() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);
        
        // Give owner some tokens
        vm.prank(treasury);
        rdat.transfer(owner, 1000e18);
        
        uint256 nonce = rdat.nonces(owner);
        uint256 deadline = block.timestamp + 1 days;
        uint256 amount = 500e18;
        
        // Create permit signature
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                rdat.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        owner,
                        alice,
                        amount,
                        nonce,
                        deadline
                    )
                )
            )
        );
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        
        // Execute permit
        rdat.permit(owner, alice, amount, deadline, v, r, s);
    }
    
    // Batch operations to measure gas in different scenarios
    function test_GasBatchTransfers() public {
        // Measure gas for multiple transfers
        uint256 totalGas = 0;
        uint256 gasStart;
        
        for (uint i = 0; i < 10; i++) {
            address recipient = address(uint160(uint256(keccak256(abi.encode(i)))));
            
            gasStart = gasleft();
            vm.prank(alice);
            rdat.transfer(recipient, 100e18);
            totalGas += gasStart - gasleft();
        }
        
        console2.log("Average gas per transfer (10 transfers):", totalGas / 10);
    }
    
    function test_GasMultipleMints() public {
        uint256 totalGas = 0;
        uint256 gasStart;
        
        for (uint i = 0; i < 5; i++) {
            address recipient = address(uint160(uint256(keccak256(abi.encode(i)))));
            
            gasStart = gasleft();
            vm.prank(minter);
            rdat.mint(recipient, 1000e18);
            totalGas += gasStart - gasleft();
        }
        
        console2.log("Average gas per mint (5 mints):", totalGas / 5);
    }
}