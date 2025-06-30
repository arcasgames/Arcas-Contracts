// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title BastoniumNFT
 * @dev Simplified ERC721 contract for Bastonium NFTs with the same tokenURI logic
 */
contract BastoniumNFT is ERC721, Ownable {
    using Strings for uint256;
    
    // Total supply of Bastonium NFTs
    uint256 public constant TOTAL_SUPPLY = 500;
    
    // Base URI for token metadata
    string private baseURIString;
    
    // Events
    event BaseURIUpdated(string oldBaseURI, string newBaseURI);
    
    constructor() ERC721("Bastonium", "BASTONIUM") Ownable(msg.sender) {
        // Mint all 1500 NFTs to the deployer
        _mintBatch(msg.sender, TOTAL_SUPPLY);
    }
    
    /**
     * @dev Mint multiple tokens to an address
     * @param to The address to mint to
     * @param quantity The number of tokens to mint
     */
    function _mintBatch(address to, uint256 quantity) internal {
        for (uint256 i = 1; i <= quantity; i++) {
            _mint(to, i);
        }
    }
    
    /**
     * @dev Override tokenURI to match the original Bastonium logic
     * Returns just the base URI if it is implied to not be a directory
     * @param tokenId The token ID
     * @return The token URI
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) revert("URI query for nonexistent token");

        string memory baseURI = _baseURI();

        // Exit early if the baseURI is empty.
        if (bytes(baseURI).length == 0) {
            return "";
        }

        // Check if the last character in baseURI is a slash.
        if (bytes(baseURI)[bytes(baseURI).length - 1] != bytes("/")[0]) {
            return baseURI;
        }

        return string(abi.encodePacked(baseURI, tokenId.toString()));
    }
    
    /**
     * @dev Set the base URI for token metadata
     * @param newBaseURI The new base URI
     */
    function setBaseURI(string memory newBaseURI) external onlyOwner {
        string memory oldBaseURI = baseURIString;
        baseURIString = newBaseURI;
        emit BaseURIUpdated(oldBaseURI, newBaseURI);
    }
    
    /**
     * @dev Override _baseURI to return the stored base URI
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURIString;
    }
    
    /**
     * @dev Check if a token exists
     * @param tokenId The token ID to check
     * @return True if the token exists
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }
    
    /**
     * @dev Get the number of tokens minted by an address
     * @param owner The address to check
     * @return The number of tokens minted by the address
     */
    function numberMinted(address owner) external view returns (uint256) {
        return balanceOf(owner);
    }
} 