// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract SmartAccountAuthority {
    // Mapping from smart account to authorized EOA
    mapping(address => address) public smartAccountToEOA;
    
    // Mapping from EOA to authorized smart account
    mapping(address => address) public eoaToSmartAccount;
    
    // Events
    event SmartAccountAuthorized(address indexed eoa, address indexed smartAccount, bool authorized);
    
    /**
     * @dev Authorize or unauthorize a smart account for an EOA
     * @param smartAccount The smart account address to authorize
     * @param authorized Whether to authorize (true) or unauthorize (false)
     */
    function authorizeSmartAccount(address smartAccount, bool authorized) external {
        require(smartAccount != address(0), "Invalid smart account address");
        
        if (authorized) {
            // Authorize the smart account
            require(eoaToSmartAccount[msg.sender] == address(0), "EOA already has authorized smart account");
            require(smartAccountToEOA[smartAccount] == address(0), "Smart account already authorized");
            
            eoaToSmartAccount[msg.sender] = smartAccount;
            smartAccountToEOA[smartAccount] = msg.sender;
            
            emit SmartAccountAuthorized(msg.sender, smartAccount, true);
        } else {
            // Unauthorize the smart account
            require(eoaToSmartAccount[msg.sender] == smartAccount, "Smart account not authorized for this EOA");
            
            delete eoaToSmartAccount[msg.sender];
            delete smartAccountToEOA[smartAccount];
            
            emit SmartAccountAuthorized(msg.sender, smartAccount, false);
        }
    }
    
    /**
     * @dev Get the EOA that authorized a smart account
     * @param smartAccount The smart account address
     * @return The EOA address
     */
    function getAuthorizedEOA(address smartAccount) external view returns (address) {
        return smartAccountToEOA[smartAccount];
    }
    
    /**
     * @dev Get the authorized smart account for an EOA
     * @param eoa The EOA address
     * @return The smart account address
     */
    function getAuthorizedSmartAccount(address eoa) external view returns (address) {
        return eoaToSmartAccount[eoa];
    }
    
    /**
     * @dev Check if a smart account is authorized
     * @param smartAccount The smart account address
     * @return Whether the smart account is authorized
     */
    function isAuthorizedSmartAccount(address smartAccount) external view returns (bool) {
        return smartAccountToEOA[smartAccount] != address(0);
    }
    
    /**
     * @dev Get the EOA owner for a caller (EOA or smart account)
     * @param caller The address calling the function
     * @return The EOA owner address
     */
    function getEOAOwner(address caller) external view returns (address) {
        // If caller is an EOA, return the caller
        if (smartAccountToEOA[caller] == address(0)) {
            return caller;
        }
        
        // If caller is a smart account, return the authorized EOA
        return smartAccountToEOA[caller];
    }
    
    /**
     * @dev Allow smart account to dissociate itself from an EOA
     */
    function dissociateFromEOA() external {
        address eoa = smartAccountToEOA[msg.sender];
        require(eoa != address(0), "No EOA associated");
        
        delete eoaToSmartAccount[eoa];
        delete smartAccountToEOA[msg.sender];
        
        emit SmartAccountAuthorized(eoa, msg.sender, false);
    }
    
    /**
     * @dev Allow EOA to dissociate itself from its associated smart account
     */
    function dissociateFromSmartAccount() external {
        address smartAccount = eoaToSmartAccount[msg.sender];
        require(smartAccount != address(0), "No smart account associated");
        
        delete eoaToSmartAccount[msg.sender];
        delete smartAccountToEOA[smartAccount];
        
        emit SmartAccountAuthorized(msg.sender, smartAccount, false);
    }
} 