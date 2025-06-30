// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "solady/src/auth/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./SmartAccountAuthority.sol";

contract RewardStaking is Ownable, ReentrancyGuard {
    SmartAccountAuthority public immutable smartAccountAuthority;
    
    // Bastonium tiers contract for rarity checking
    address public immutable bastoniumTiersContract;
    
    // Bastonium NFT Collection Address
    address public immutable bastoniumNFTCollection;
    
    // BATTLE HARDENED APE SBT Address
    address public immutable battleHardenedApeSBT;
    
    // ArcasERC1155Badge contract for minting/burning badges
    address public immutable arcasERC1155Badge;
    
    // Arcas token address for staking
    address public immutable arcasTokenAddress;
    
    // Arcas Bronze base amount
    uint256 public immutable arcasBronzeBaseAmount;
    
    
    // User staking position structure
    struct UserBadgeStakingPosition {
        uint256 badgeTier; // 1 = Bronze, 2 = Silver, 3 = Gold
        address tokenStaked;
        uint256 tokenAmount;
        uint256 timestamp; // When the position was created
    }
    
    // Mapping to track user staking positions
    mapping(address => UserBadgeStakingPosition) public userStakingPositions;
    
    // Gold and Silver configuration
    struct GoldSilverConfig {
        address[] eligibleTokens; // ERC20 tokens (ARCAS, LP tokens)
        uint256[] baseAmounts; // Base amounts for Gold tier per token
    }
    GoldSilverConfig private goldConfig;
    
    // Bronze configuration
    struct BronzeConfig {
        address[] eligibleERC721SBTs; // ERC721 SBT addresses
        address[] eligibleERC1155SBTs; // ERC1155 SBT addresses
        uint256[] eligibleERC1155TokenIds; // Token IDs for ERC1155 SBTs
    }
    BronzeConfig private bronzeConfig;
    
    // Users who have staked Bastonium UNCOMMON NFTs (provides 25% reduction)
    mapping(address => bool) public hasStakedBastoniumUncommon;
    
    // Token ID of staked Bastonium UNCOMMON NFT per user
    mapping(address => uint256) public stakedBastoniumTokenId;
    
    // Events
    event BastoniumUncommonStaked(address indexed user, uint256 tokenId);
    event BastoniumUncommonUnstaked(address indexed user, uint256 tokenId);
    
    constructor(
        address _smartAccountAuthority, 
        address _bastoniumTiersContract,
        address _bastoniumNFTCollection,
        address _battleHardenedApeSBT,
        address _arcasERC1155Badge,
        address _arcasTokenAddress,
        uint256 _arcasGoldBaseAmount,
        uint256 _arcasBronzeBaseAmount
    ) {
        smartAccountAuthority = SmartAccountAuthority(_smartAccountAuthority);
        bastoniumTiersContract = _bastoniumTiersContract;
        bastoniumNFTCollection = _bastoniumNFTCollection;
        battleHardenedApeSBT = _battleHardenedApeSBT;
        arcasERC1155Badge = _arcasERC1155Badge;
        arcasTokenAddress = _arcasTokenAddress;
        arcasBronzeBaseAmount = _arcasBronzeBaseAmount;
        _initializeOwner(msg.sender);
        
        // Initialize GoldSilverConfig with Arcas token as first entry
        goldConfig.eligibleTokens.push(_arcasTokenAddress);
        goldConfig.baseAmounts.push(_arcasGoldBaseAmount);
    }
    
    //INTERNAL FUNCTIONS
    //////////////////////////////
    /**
     * @dev Calculate discounted amount based on user's SBT and staked Bastonium NFT
     * @param user The user address
     * @param baseAmount The base amount to calculate discount from
     * @return The discounted amount
     */
    function _calculateDiscountedAmount(address user, uint256 baseAmount) internal view returns (uint256) {
        uint256 totalDiscount = 0;
        
        // Check for BATTLE HARDENED APE SBT discount (50%)
        try IERC721(battleHardenedApeSBT).balanceOf(user) returns (uint256 balance) {
            if (balance > 0) {
                totalDiscount += baseAmount * 50 / 100; // 50% discount
            }
        } catch {
            // If call fails, no discount
        }
        
        // Check for staked Bastonium UNCOMMON NFT discount (25%)
        if (hasStakedBastoniumUncommon[user]) {
            totalDiscount += baseAmount * 25 / 100; // 25% discount
        }
        
        // Return base amount minus total discount
        return baseAmount - totalDiscount;
    }    
    
    //BASTONIUM STAKING FUNCTIONS
    //////////////////////////////
    /**
     * @dev Stake a Bastonium UNCOMMON NFT for 25% system-wide reduction
     */
    function stakeBastonium(uint256 tokenId) external nonReentrant {
        address eoaOwner = smartAccountAuthority.getEOAOwner(msg.sender);
        require(eoaOwner != address(0), "Not authorized");
        require(!hasStakedBastoniumUncommon[eoaOwner], "Already staked Bastonium UNCOMMON");
        require(userStakingPositions[eoaOwner].badgeTier == 0, "Cannot stake Bastonium while badge is active");
        
        // Check that the token is UNCOMMON rarity
        (bool success, bytes memory data) = bastoniumTiersContract.staticcall(
            abi.encodeWithSignature("getRarity(uint256)", tokenId)
        );
        
        require(success && data.length >= 32, "Failed to get rarity");
        uint8 rarity = abi.decode(data, (uint8));
        require(rarity == 2, "Token is not UNCOMMON rarity"); // UNCOMMON = 2
        
        // Transfer the NFT from EOA to contract
        IERC721(bastoniumNFTCollection).transferFrom(eoaOwner, address(this), tokenId);
        
        // Mark user as having staked Bastonium UNCOMMON
        hasStakedBastoniumUncommon[eoaOwner] = true;
        
        // Store the token ID
        stakedBastoniumTokenId[eoaOwner] = tokenId;
        
        emit BastoniumUncommonStaked(eoaOwner, tokenId);
    }
    
    /**
     * @dev Unstake Bastonium UNCOMMON NFT
     */
    function unstakeBastonium() external nonReentrant {
        address eoaOwner = smartAccountAuthority.getEOAOwner(msg.sender);
        require(eoaOwner != address(0), "Not authorized");
        require(hasStakedBastoniumUncommon[eoaOwner], "No Bastonium UNCOMMON staked");
        require(userStakingPositions[eoaOwner].badgeTier == 0, "Cannot unstake while badge is active");
        
        // Get the stored token ID
        uint256 tokenId = stakedBastoniumTokenId[eoaOwner];
        require(tokenId > 0, "No Bastonium UNCOMMON NFT staked");
        
        // Transfer the NFT from contract to EOA
        IERC721(bastoniumNFTCollection).transferFrom(address(this), eoaOwner, tokenId);
        
        // Remove Bastonium UNCOMMON staking status
        hasStakedBastoniumUncommon[eoaOwner] = false;
        
        // Clear the stored token ID
        delete stakedBastoniumTokenId[eoaOwner];
        
        emit BastoniumUncommonUnstaked(eoaOwner, tokenId);
    }
    
    //TOKEN STAKING FUNCTIONS
    //////////////////////////////
    /**
     * @dev Stake Arcas tokens for Bronze tier badge
     */
    function stakeBronze() external nonReentrant {
        address eoaOwner = smartAccountAuthority.getEOAOwner(msg.sender);
        require(eoaOwner != address(0), "Not authorized");
        require(userStakingPositions[eoaOwner].badgeTier == 0, "User already has a staking position");
        
        // Check if user has valid Bronze SBT (ERC721 or ERC1155)
        bool hasValidBronzeSBT = false;
        
        // Check ERC721 SBTs
        for (uint256 i = 0; i < bronzeConfig.eligibleERC721SBTs.length; i++) {
            try IERC721(bronzeConfig.eligibleERC721SBTs[i]).balanceOf(eoaOwner) returns (uint256 balance) {
                if (balance > 0) {
                    hasValidBronzeSBT = true;
                    break;
                }
            } catch {
                // Continue to next SBT if this one fails
            }
        }
        
        // Check ERC1155 SBTs if no ERC721 found
        if (!hasValidBronzeSBT) {
            for (uint256 i = 0; i < bronzeConfig.eligibleERC1155SBTs.length; i++) {
                try IERC1155(bronzeConfig.eligibleERC1155SBTs[i]).balanceOf(eoaOwner, bronzeConfig.eligibleERC1155TokenIds[i]) returns (uint256 balance) {
                    if (balance > 0) {
                        hasValidBronzeSBT = true;
                        break;
                    }
                } catch {
                    // Continue to next SBT if this one fails
                }
            }
        }
        
        require(hasValidBronzeSBT, "No valid Bronze SBT found");
        
        // Transfer Arcas tokens from user to contract (full bronze amount)
        require(IERC20(arcasTokenAddress).transferFrom(eoaOwner, address(this), arcasBronzeBaseAmount), "Token transfer failed");
        
        // Create staking position
        userStakingPositions[eoaOwner] = UserBadgeStakingPosition({
            badgeTier: 1, // Bronze
            tokenStaked: arcasTokenAddress,
            tokenAmount: arcasBronzeBaseAmount,
            timestamp: block.timestamp
        });
        
        // Mint Bronze badge (token ID 1) to user
        (bool success, ) = arcasERC1155Badge.call(
            abi.encodeWithSignature("mint(address,uint256,uint256,bytes)", eoaOwner, 1, 1, "")
        );
        require(success, "Failed to mint Bronze badge");
    }
    
    /**
     * @dev Stake tokens for Silver tier badge
     * @param tokenAddress The address of the token to stake
     */
    function stakeSilver(address tokenAddress) external nonReentrant {
        address eoaOwner = smartAccountAuthority.getEOAOwner(msg.sender);
        require(eoaOwner != address(0), "Not authorized");
        require(userStakingPositions[eoaOwner].badgeTier == 0, "User already has a staking position");
        
        // Verify token is eligible for Silver tier
        bool isEligible = false;
        uint256 baseAmount = 0;
        for (uint256 i = 0; i < goldConfig.eligibleTokens.length; i++) {
            if (goldConfig.eligibleTokens[i] == tokenAddress) {
                isEligible = true;
                baseAmount = goldConfig.baseAmounts[i];
                break;
            }
        }
        require(isEligible, "Token not eligible for Silver tier");
        
        // Calculate Silver amount (25% of Gold base amount)
        uint256 silverBaseAmount = baseAmount * 25 / 100;
        
        // Calculate discounted amount
        uint256 discountedAmount = _calculateDiscountedAmount(eoaOwner, silverBaseAmount);
        
        // Transfer tokens from user to contract
        require(IERC20(tokenAddress).transferFrom(eoaOwner, address(this), discountedAmount), "Token transfer failed");
        
        // Create staking position
        userStakingPositions[eoaOwner] = UserBadgeStakingPosition({
            badgeTier: 2, // Silver
            tokenStaked: tokenAddress,
            tokenAmount: discountedAmount,
            timestamp: block.timestamp
        });
        
        // Mint Silver badge (token ID 2) to user
        (bool success, ) = arcasERC1155Badge.call(
            abi.encodeWithSignature("mint(address,uint256,uint256,bytes)", eoaOwner, 2, 1, "")
        );
        require(success, "Failed to mint Silver badge");
    }
    
    /**
     * @dev Stake tokens for Gold tier badge
     * @param tokenAddress The address of the token to stake
     */
    function stakeGold(address tokenAddress) external nonReentrant {
        address eoaOwner = smartAccountAuthority.getEOAOwner(msg.sender);
        require(eoaOwner != address(0), "Not authorized");
        require(userStakingPositions[eoaOwner].badgeTier == 0, "User already has a staking position");
        
        // Verify token is eligible for Gold tier
        bool isEligible = false;
        uint256 baseAmount = 0;
        for (uint256 i = 0; i < goldConfig.eligibleTokens.length; i++) {
            if (goldConfig.eligibleTokens[i] == tokenAddress) {
                isEligible = true;
                baseAmount = goldConfig.baseAmounts[i];
                break;
            }
        }
        require(isEligible, "Token not eligible for Gold tier");
        
        // Calculate discounted amount using full Gold base amount
        uint256 discountedAmount = _calculateDiscountedAmount(eoaOwner, baseAmount);
        
        // Transfer tokens from user to contract
        require(IERC20(tokenAddress).transferFrom(eoaOwner, address(this), discountedAmount), "Token transfer failed");
        
        // Create staking position
        userStakingPositions[eoaOwner] = UserBadgeStakingPosition({
            badgeTier: 3, // Gold
            tokenStaked: tokenAddress,
            tokenAmount: discountedAmount,
            timestamp: block.timestamp
        });
        
        // Mint Gold badge (token ID 3) to user
        (bool success, ) = arcasERC1155Badge.call(
            abi.encodeWithSignature("mint(address,uint256,uint256,bytes)", eoaOwner, 3, 1, "")
        );
        require(success, "Failed to mint Gold badge");
    }
    
    /**
     * @dev Unstake tokens and revoke badge
     */
    function unstake() external nonReentrant {
        address eoaOwner = smartAccountAuthority.getEOAOwner(msg.sender);
        require(eoaOwner != address(0), "Not authorized");
        
        UserBadgeStakingPosition memory position = userStakingPositions[eoaOwner];
        require(position.badgeTier > 0, "No staking position found");
        
        // Return tokens to user
        require(IERC20(position.tokenStaked).transfer(eoaOwner, position.tokenAmount), "Token return failed");
        
        // Burn the badge (token ID corresponds to tier: 1=Bronze, 2=Silver, 3=Gold)
        (bool success, ) = arcasERC1155Badge.call(
            abi.encodeWithSignature("burn(address,uint256,uint256)", eoaOwner, position.badgeTier, 1)
        );
        require(success, "Failed to burn badge");
        
        // Clear the staking position
        delete userStakingPositions[eoaOwner];
    }
    
    //VIEW FUNCTIONS
    //////////////////////////////
    /**
     * @dev Check if user has staked a Bastonium UNCOMMON NFT and return the token ID
     * @return hasStaked True if user has staked Bastonium NFT
     * @return tokenId The token ID of the staked NFT (0 if not staked)
     */
    function hasStakedBastoniumNFT(address user) external view returns (bool hasStaked, uint256 tokenId) {
        hasStaked = hasStakedBastoniumUncommon[user];
        tokenId = hasStaked ? stakedBastoniumTokenId[user] : 0;
    }
    
    /**
     * @dev Get user's staking position
     * @param user The user address
     * @return The UserBadgeStakingPosition struct
     */
    function getUserStakingPosition(address user) external view returns (UserBadgeStakingPosition memory) {
        return userStakingPositions[user];
    }

    //ADMIN FUNCTIONS
    //////////////////////////////
    /**
     * @dev Add a token and its base amount to Gold/Silver configuration
     * @param token The ERC20 token address
     * @param baseAmount The base amount required for Gold tier
     */
    function addGoldSilverConfig(address token, uint256 baseAmount) external onlyOwner {
        require(token != address(0), "Invalid token address");
        require(baseAmount > 0, "Base amount must be greater than 0");
        
        // Verify it's an ERC20 token by calling supportsInterface(0x36372b07)
        try IERC20(token).supportsInterface(0x36372b07) returns (bool supported) {
            require(supported, "Address does not support ERC20 interface");
        } catch {
            revert("Address is not a valid ERC20 token");
        }
        
        goldConfig.eligibleTokens.push(token);
        goldConfig.baseAmounts.push(baseAmount);
    }
    
    /**
     * @dev Add an ERC721 SBT to Bronze configuration
     * @param sbtAddress The ERC721 SBT contract address
     */
    function addBronzeConfigERC721SBT(address sbtAddress) external onlyOwner {
        require(sbtAddress != address(0), "Invalid SBT address");
        
        // Verify it's an ERC721 token by calling supportsInterface(0x80ac58cd)
        try IERC721(sbtAddress).supportsInterface(0x80ac58cd) returns (bool supported) {
            require(supported, "Address does not support ERC721 interface");
        } catch {
            revert("Address is not a valid ERC721 token");
        }
        
        bronzeConfig.eligibleERC721SBTs.push(sbtAddress);
    }
    
    /**
     * @dev Add an ERC1155 SBT and its token ID to Bronze configuration
     * @param sbtAddress The ERC1155 SBT contract address
     * @param tokenId The specific token ID for the ERC1155 SBT
     */
    function addBronzeConfigERC1155SBT(address sbtAddress, uint256 tokenId) external onlyOwner {
        require(sbtAddress != address(0), "Invalid SBT address");
        
        // Verify it's an ERC1155 token by calling supportsInterface(0xd9b67a26)
        try IERC1155(sbtAddress).supportsInterface(0xd9b67a26) returns (bool supported) {
            require(supported, "Address does not support ERC1155 interface");
        } catch {
            revert("Address is not a valid ERC1155 token");
        }
        
        bronzeConfig.eligibleERC1155SBTs.push(sbtAddress);
        bronzeConfig.eligibleERC1155TokenIds.push(tokenId);
    }
}