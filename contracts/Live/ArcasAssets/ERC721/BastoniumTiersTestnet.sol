// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title BastoniumTiersTestnet
 * @dev Simplified rarity management contract for Bastonium NFTs on testnet
 */
contract BastoniumTiersTestnet is Ownable {
    
    // Rarity mapping using an enum
    enum Rarity { UNASSIGNED, COMMON, UNCOMMON, RARE }
    
    // Mapping from token ID to rarity
    mapping(uint256 => Rarity) public nftRarity;
    
    // Total supply of Bastonium NFTs
    uint256 public constant TOTAL_SUPPLY = 500;
    
    // Events
    event RaritySet(uint256 indexed nftId, Rarity rarity);
    event RarityBatchSet(uint256[] nftIds, Rarity[] rarities);
    
    constructor() Ownable(msg.sender) {}
    
    /**
     * @dev Set rarity for a specific NFT
     * @param nftId The NFT token ID
     * @param rarity The rarity to assign
     */
    function setRarity(uint256 nftId, Rarity rarity) external onlyOwner {
        require(nftId > 0 && nftId <= TOTAL_SUPPLY, "NFT ID out of range");
        require(rarity != Rarity.UNASSIGNED, "Cannot set UNASSIGNED rarity");
        
        nftRarity[nftId] = rarity;
        emit RaritySet(nftId, rarity);
    }
    
    /**
     * @dev Set rarity for multiple NFTs in batch
     * @param nftIds Array of NFT token IDs
     * @param rarities Array of rarities to assign
     */
    function setRarityBatch(uint256[] calldata nftIds, Rarity[] calldata rarities) external onlyOwner {
        require(nftIds.length == rarities.length, "Arrays length mismatch");
        
        for (uint256 i = 0; i < nftIds.length; i++) {
            require(nftIds[i] > 0 && nftIds[i] <= TOTAL_SUPPLY, "NFT ID out of range");
            require(rarities[i] != Rarity.UNASSIGNED, "Cannot set UNASSIGNED rarity");
            
            nftRarity[nftIds[i]] = rarities[i];
        }
        
        emit RarityBatchSet(nftIds, rarities);
    }
    
    /**
     * @dev Get the rarity of a specific NFT
     * @param nftId The NFT token ID
     * @return The rarity of the NFT
     */
    function getRarity(uint256 nftId) external view returns (Rarity) {
        require(nftId > 0 && nftId <= TOTAL_SUPPLY, "NFT ID out of range");
        return nftRarity[nftId];
    }
    
    /**
     * @dev Get rarity for multiple NFTs
     * @param nftIds Array of NFT token IDs
     * @return Array of rarities
     */
    function getRarityBatch(uint256[] calldata nftIds) external view returns (Rarity[] memory) {
        Rarity[] memory rarities = new Rarity[](nftIds.length);
        
        for (uint256 i = 0; i < nftIds.length; i++) {
            require(nftIds[i] > 0 && nftIds[i] <= TOTAL_SUPPLY, "NFT ID out of range");
            rarities[i] = nftRarity[nftIds[i]];
        }
        
        return rarities;
    }
    
    /**
     * @dev Check if an NFT has been assigned a rarity
     * @param nftId The NFT token ID
     * @return True if rarity is assigned
     */
    function hasRarity(uint256 nftId) external view returns (bool) {
        require(nftId > 0 && nftId <= TOTAL_SUPPLY, "NFT ID out of range");
        return nftRarity[nftId] != Rarity.UNASSIGNED;
    }
    
    /**
     * @dev Get rarity counts
     * @return rare Count of rare NFTs
     * @return uncommon Count of uncommon NFTs
     * @return common Count of common NFTs
     * @return unassigned Count of unassigned NFTs
     */
    function getRarityCounts() external view returns (uint256 rare, uint256 uncommon, uint256 common, uint256 unassigned) {
        for (uint256 i = 1; i <= TOTAL_SUPPLY; i++) {
            Rarity rarity = nftRarity[i];
            if (rarity == Rarity.RARE) {
                rare++;
            } else if (rarity == Rarity.UNCOMMON) {
                uncommon++;
            } else if (rarity == Rarity.COMMON) {
                common++;
            } else {
                unassigned++;
            }
        }
    }
} 