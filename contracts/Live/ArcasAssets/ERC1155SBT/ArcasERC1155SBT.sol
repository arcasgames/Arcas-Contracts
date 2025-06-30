// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title ArcasERC1155SBT
 * @dev ERC1155 Soulbound Token contract for Arcas badges
 * Badges are non-transferrable and can only be minted/burned by the RewardStaking contract
 */
contract ArcasERC1155SBT is ERC1155, Ownable, ReentrancyGuard {
    
    // Badge tier constants
    uint256 public constant BRONZE_BADGE = 1;
    uint256 public constant SILVER_BADGE = 2;
    uint256 public constant GOLD_BADGE = 3;
    
    // Badge tier names
    string public constant BRONZE_NAME = "Arcas Bronze Badge";
    string public constant SILVER_NAME = "Arcas Silver Badge";
    string public constant GOLD_NAME = "Arcas Gold Badge";
    
    // Metadata URIs for each badge tier
    string public constant BRONZE_METADATA_URI = "ipfs://bafkreieucjg5wmnpcjd2ml76skffs5nwjiromzwva3tdpwjcjsa5o3g3wy";
    string public constant SILVER_METADATA_URI = "ipfs://bafkreicpkbh7uaiacklnxxsy6kqiiqeoay32qsoytfayefh465zz4gz7ey";
    string public constant GOLD_METADATA_URI = "ipfs://bafkreiebrdcba6aa5lpurixrnmgni7nyw32k7vhzfbcnjnujp7vkm36wl4";
    
    // Mapping to track if a token ID is a valid badge
    mapping(uint256 => bool) public isValidBadge;
    
    // Contract name and symbol
    string public name;
    string public symbol;
    
    // Events
    event BadgeMinted(address indexed to, uint256 indexed tokenId, uint256 amount);
    event BadgeBurned(address indexed from, uint256 indexed tokenId, uint256 amount);
    
    constructor() ERC1155("") Ownable(msg.sender) {
        // Initialize contract name and symbol
        name = "Arcas Ecosystem Badge Collection";
        symbol = "ARCASECOBADGES";
        
        // Initialize the 3 badge tiers
        isValidBadge[BRONZE_BADGE] = true;
        isValidBadge[SILVER_BADGE] = true;
        isValidBadge[GOLD_BADGE] = true;
    }
    

    //SBT FUNCTIONS
    //////////////////////////////////////////////////////////////

    /**
     * @dev Override _update to make badges non-transferrable (SBT)
     */
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal virtual override {
        // Only allow minting (from zero address), prevent transfers
        for (uint256 i = 0; i < ids.length; i++) {
            if (isValidBadge[ids[i]] && from != address(0)) {
                revert("Soulbound: Badges are non-transferable");
            }
        }
        
        super._update(from, to, ids, values);
    }

    //MINTING FUNCTIONS
    //////////////////////////////////////////////////////////////

    /**
     * @dev Mint badges - only callable by owner (RewardStaking contract)
     * @param to The address to mint to
     * @param tokenId The badge token ID (1=Bronze, 2=Silver, 3=Gold)
     * @param amount The amount to mint (should be 1 for badges)
     * @param data Additional data
     */
    function mint(address to, uint256 tokenId, uint256 amount, bytes memory data) external onlyOwner {
        require(isValidBadge[tokenId], "Invalid badge token ID");
        require(amount > 0, "Amount must be greater than 0");
        
        _mint(to, tokenId, amount, data);
        emit BadgeMinted(to, tokenId, amount);
    }
    
    /**
     * @dev Burn badges - only callable by owner (RewardStaking contract)
     * @param from The address to burn from
     * @param tokenId The badge token ID (1=Bronze, 2=Silver, 3=Gold)
     * @param amount The amount to burn (should be 1 for badges)
     */
    function burn(address from, uint256 tokenId, uint256 amount) external onlyOwner {
        require(isValidBadge[tokenId], "Invalid badge token ID");
        require(amount > 0, "Amount must be greater than 0");
        require(balanceOf(from, tokenId) >= amount, "Insufficient balance");
        
        _burn(from, tokenId, amount);
        emit BadgeBurned(from, tokenId, amount);
    }
    

    //VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////

    /**
     * @dev Get badge name by token ID
     * @param tokenId The badge token ID
     * @return The badge name
     */
    function getBadgeName(uint256 tokenId) external pure returns (string memory) {
        if (tokenId == BRONZE_BADGE) return BRONZE_NAME;
        if (tokenId == SILVER_BADGE) return SILVER_NAME;
        if (tokenId == GOLD_BADGE) return GOLD_NAME;
        return "Invalid Badge";
    }
    
    /**
     * @dev Check if address has a specific badge
     * @param account The address to check
     * @param tokenId The badge token ID
     * @return True if the address has the badge
     */
    function hasBadge(address account, uint256 tokenId) external view returns (bool) {
        return isValidBadge[tokenId] && balanceOf(account, tokenId) > 0;
    }
    
    /**
     * @dev Get all badges owned by an address
     * @param account The address to check
     * @return Array of token IDs that the address owns
     */
    function getBadgesByAddress(address account) external view returns (uint256[] memory) {
        uint256[] memory badges = new uint256[](3);
        uint256 count = 0;
        
        for (uint256 i = 1; i <= 3; i++) {
            if (balanceOf(account, i) > 0) {
                badges[count] = i;
                count++;
            }
        }
        
        // Resize array to actual count
        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = badges[i];
        }
        
        return result;
    }
    
    /**
     * @dev Override supportsInterface to include ERC1155 interface
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
    
    /**
     * @dev Returns the URI for a given token ID
     * This is the standard ERC1155 metadata function that marketplaces like OpenSea call
     * @param id The token ID
     * @return The metadata URI for the token
     */
    function uri(uint256 id) public view virtual override returns (string memory) {
        require(isValidBadge[id], "ArcasERC1155SBT: URI query for nonexistent badge");
        
        if (id == BRONZE_BADGE) return BRONZE_METADATA_URI;
        if (id == SILVER_BADGE) return SILVER_METADATA_URI;
        if (id == GOLD_BADGE) return GOLD_METADATA_URI;
        
        return "";
    }
    
    //ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////

    /**
     * @dev Transfer ownership to RewardStaking contract
     * This should be called after deployment to ensure only the staking contract can mint/burn
     * @param newOwner The RewardStaking contract address
     */
    function transferOwnershipToStaking(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        _transferOwnership(newOwner);
    }
}
