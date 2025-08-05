// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRDAT is IERC20 {
    // Events
    event VRCContractSet(string contractType, address indexed contractAddress);
    event RevenueCollectorSet(address indexed collector);
    
    // Functions
    function mint(address to, uint256 amount) external;
    function pause() external;
    function unpause() external;
    function setPoCContract(address _poc) external;
    function setDataRefiner(address _refiner) external;
    function setRevenueCollector(address _collector) external;
    
    // Constants
    function TOTAL_SUPPLY() external view returns (uint256);
    function MIGRATION_ALLOCATION() external view returns (uint256);
    function isVRC20() external view returns (bool);
    function pocContract() external view returns (address);
    function dataRefiner() external view returns (address);
    function revenueCollector() external view returns (address);
}