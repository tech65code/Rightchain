// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Rightchain
 * @dev A decentralized intellectual property and digital rights management system
 * @author Rightchain Team
 */
contract Rightchain {
    
    struct IntellectualProperty {
        uint256 id;
        address owner;
        string title;
        string description;
        string ipfsHash; // Hash of the content stored on IPFS
        uint256 timestamp;
        bool isActive;
        uint256 licensePrice;
    }
    
    struct License {
        uint256 ipId;
        address licensee;
        uint256 expiryTime;
        bool isActive;
        uint256 pricePaid;
    }
    
    // State variables
    uint256 private nextIPId;
    uint256 private nextLicenseId;
    
    mapping(uint256 => IntellectualProperty) public intellectualProperties;
    mapping(uint256 => License) public licenses;
    mapping(address => uint256[]) public ownerToIPs;
    mapping(address => uint256[]) public licenseeToLicenses;
    
    // Events
    event IPRegistered(uint256 indexed ipId, address indexed owner, string title);
    event LicensePurchased(uint256 indexed licenseId, uint256 indexed ipId, address indexed licensee);
    event IPTransferred(uint256 indexed ipId, address indexed from, address indexed to);
    
    // Modifiers
    modifier onlyIPOwner(uint256 _ipId) {
        require(intellectualProperties[_ipId].owner == msg.sender, "Not the IP owner");
        _;
    }
    
    modifier ipExists(uint256 _ipId) {
        require(_ipId < nextIPId && intellectualProperties[_ipId].isActive, "IP does not exist or inactive");
        _;
    }
    
    /**
     * @dev Register a new intellectual property
     * @param _title Title of the intellectual property
     * @param _description Description of the intellectual property
     * @param _ipfsHash IPFS hash of the content
     * @param _licensePrice Price for licensing (in wei)
     */
    function registerIP(
        string memory _title,
        string memory _description,
        string memory _ipfsHash,
        uint256 _licensePrice
    ) external returns (uint256) {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_ipfsHash).length > 0, "IPFS hash cannot be empty");
        
        uint256 ipId = nextIPId++;
        
        intellectualProperties[ipId] = IntellectualProperty({
            id: ipId,
            owner: msg.sender,
            title: _title,
            description: _description,
            ipfsHash: _ipfsHash,
            timestamp: block.timestamp,
            isActive: true,
            licensePrice: _licensePrice
        });
        
        ownerToIPs[msg.sender].push(ipId);
        
        emit IPRegistered(ipId, msg.sender, _title);
        return ipId;
    }
    
    /**
     * @dev Purchase a license for an intellectual property
     * @param _ipId ID of the intellectual property
     * @param _duration Duration of the license in seconds
     */
    function purchaseLicense(uint256 _ipId, uint256 _duration) external payable ipExists(_ipId) {
        IntellectualProperty memory ip = intellectualProperties[_ipId];
        require(ip.owner != msg.sender, "Cannot license your own IP");
        require(msg.value >= ip.licensePrice, "Insufficient payment");
        require(_duration > 0, "Duration must be greater than 0");
        
        uint256 licenseId = nextLicenseId++;
        uint256 expiryTime = block.timestamp + _duration;
        
        licenses[licenseId] = License({
            ipId: _ipId,
            licensee: msg.sender,
            expiryTime: expiryTime,
            isActive: true,
            pricePaid: msg.value
        });
        
        licenseeToLicenses[msg.sender].push(licenseId);
        
        // Transfer payment to IP owner
        payable(ip.owner).transfer(msg.value);
        
        emit LicensePurchased(licenseId, _ipId, msg.sender);
    }
    
    /**
     * @dev Transfer ownership of an intellectual property
     * @param _ipId ID of the intellectual property
     * @param _newOwner Address of the new owner
     */
    function transferIP(uint256 _ipId, address _newOwner) external onlyIPOwner(_ipId) ipExists(_ipId) {
        require(_newOwner != address(0), "Invalid new owner address");
        require(_newOwner != msg.sender, "Cannot transfer to yourself");
        
        address oldOwner = intellectualProperties[_ipId].owner;
        intellectualProperties[_ipId].owner = _newOwner;
        
        // Update owner mappings
        ownerToIPs[_newOwner].push(_ipId);
        
        emit IPTransferred(_ipId, oldOwner, _newOwner);
    }
    
    // View functions
    function getIPDetails(uint256 _ipId) external view ipExists(_ipId) returns (
        address owner,
        string memory title,
        string memory description,
        string memory ipfsHash,
        uint256 timestamp,
        uint256 licensePrice
    ) {
        IntellectualProperty memory ip = intellectualProperties[_ipId];
        return (
            ip.owner,
            ip.title,
            ip.description,
            ip.ipfsHash,
            ip.timestamp,
            ip.licensePrice
        );
    }
    
    function getLicenseDetails(uint256 _licenseId) external view returns (
        uint256 ipId,
        address licensee,
        uint256 expiryTime,
        bool isActive,
        uint256 pricePaid
    ) {
        require(_licenseId < nextLicenseId, "License does not exist");
        License memory license = licenses[_licenseId];
        return (
            license.ipId,
            license.licensee,
            license.expiryTime,
            license.isActive && block.timestamp <= license.expiryTime,
            license.pricePaid
        );
    }
    
    function getOwnerIPs(address _owner) external view returns (uint256[] memory) {
        return ownerToIPs[_owner];
    }
    
    function getLicenseesLicenses(address _licensee) external view returns (uint256[] memory) {
        return licenseeToLicenses[_licensee];
    }
    
    function getTotalIPs() external view returns (uint256) {
        return nextIPId;
    }
    
    function getTotalLicenses() external view returns (uint256) {
        return nextLicenseId;
    }
}
