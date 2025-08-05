// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title VanaDataContract
 * @notice This contract is designed for Vana blockchain's data-centric features
 */
contract VanaDataContract {
    uint256 public constant VANA_CHAIN_ID = 1480; // Vana Mainnet
    uint256 public constant VANA_MOKSHA_CHAIN_ID = 14800; // Vana Moksha Testnet
    
    struct DataRecord {
        string dataHash;
        address owner;
        uint256 timestamp;
        bool verified;
    }
    
    mapping(uint256 => DataRecord) public dataRecords;
    mapping(address => uint256[]) public userDataIds;
    uint256 public nextDataId = 1;
    
    event DataStored(uint256 indexed dataId, address indexed owner, string dataHash);
    event DataVerified(uint256 indexed dataId, address indexed verifier);
    
    modifier onlyVana() {
        require(
            block.chainid == VANA_CHAIN_ID || block.chainid == VANA_MOKSHA_CHAIN_ID,
            "This contract can only be deployed on Vana"
        );
        _;
    }
    
    constructor() onlyVana {
        // Contract can only be deployed on Vana
    }
    
    function storeData(string memory _dataHash) external returns (uint256) {
        uint256 dataId = nextDataId++;
        
        dataRecords[dataId] = DataRecord({
            dataHash: _dataHash,
            owner: msg.sender,
            timestamp: block.timestamp,
            verified: false
        });
        
        userDataIds[msg.sender].push(dataId);
        
        emit DataStored(dataId, msg.sender, _dataHash);
        return dataId;
    }
    
    function verifyData(uint256 _dataId) external {
        require(dataRecords[_dataId].timestamp > 0, "Data record does not exist");
        require(!dataRecords[_dataId].verified, "Data already verified");
        
        dataRecords[_dataId].verified = true;
        emit DataVerified(_dataId, msg.sender);
    }
    
    function getUserDataCount(address _user) external view returns (uint256) {
        return userDataIds[_user].length;
    }
}