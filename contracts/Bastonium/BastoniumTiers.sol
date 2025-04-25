// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol";
import "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTTierDistributor is VRFV2PlusWrapperConsumerBase, Ownable {
    // Chainlink VRF Configuration for Soneium Mainnet
    uint32 private constant CALLBACK_GAS_LIMIT = 100000;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    
    // Soneium Mainnet VRF Wrapper Address
    address private constant VRF_WRAPPER = 0xb89BB0aB64b219Ba7702f862020d879786a2BC49;
    
    // Bastonium NFT Collection Address on Soneium Mainnet
    address public constant NFT_COLLECTION = 0x7683133AaB29287b04d8A30caccC9E3Fb5f7A68f;

    // Rarity mapping using an enum
    enum Rarity { UNASSIGNED, COMMON, UNCOMMON, RARE }
    mapping(uint256 => Rarity) public nftRarity;

    // Rarity counts
    uint256 public totalAssigned;
    uint256 public constant TOTAL_RARE = 100;
    uint256 public constant TOTAL_UNCOMMON = 400;
    uint256 public constant TOTAL_SUPPLY = 1500;
    uint256 private remainingRare = TOTAL_RARE;
    uint256 private remainingUncommon = TOTAL_UNCOMMON;
    uint256 private lastRandomNumber; // VRF provided random number

    event RarityAssigned(uint256 indexed nftId, Rarity rarity);
    event RandomNumberRequested(uint256 requestId);
    event RandomNumberReceived(uint256 randomNumber);
    event NativeTokensReceived(uint256 amount);
    event RequestPrice(uint256 price);
    event DistributionComplete();

    /**
     * @notice Constructor initializes the contract with hardcoded addresses.
     */
    constructor() VRFV2PlusWrapperConsumerBase(VRF_WRAPPER) Ownable(msg.sender) {}

    /// @notice Step 1: Request a random number from Chainlink VRF using direct funding with native ETH.
    function requestRandomNumber() external onlyOwner {
        require(lastRandomNumber == 0, "Random number already requested");
        
        // Create extra args for native payment
        bytes memory extraArgs = abi.encode(VRFV2PlusClient.ExtraArgsV1({nativePayment: true}));
        
        // Request randomness with native payment enabled
        (uint256 requestId, uint256 price) = requestRandomnessPayInNative(
            CALLBACK_GAS_LIMIT,
            REQUEST_CONFIRMATIONS,
            NUM_WORDS,
            extraArgs
        );
        
        emit RandomNumberRequested(requestId);
        emit RequestPrice(price);
    }

    /// @notice Step 2: Chainlink VRF callback – store the random number.
    function fulfillRandomWords(uint256, uint256[] memory randomWords) internal override {
        require(lastRandomNumber == 0, "Random number already set");
        lastRandomNumber = randomWords[0];
        emit RandomNumberReceived(lastRandomNumber);
    }

    /**
     * @notice Step 3: Compute rarities in batches to save on gas.
     * @param batchSize Number of NFTs to process in this call.
     */
    function computeRarities(uint256 batchSize) external onlyOwner {
        require(lastRandomNumber != 0, "Random number not set yet");
        require(totalAssigned < TOTAL_SUPPLY, "All NFTs have assigned rarities");

        uint256 remainingSupply = TOTAL_SUPPLY - totalAssigned;
        uint256 randomNumber = lastRandomNumber;
        uint256 count = 0;

        while (count < batchSize && totalAssigned < TOTAL_SUPPLY) {
            uint256 index = randomNumber % remainingSupply;
            uint256 nftId = totalAssigned + 1; // Start from ID 1

            // Calculate the probability ranges based on remaining counts
            uint256 rareRange = remainingRare;
            uint256 uncommonRange = rareRange + remainingUncommon;

            if (index < rareRange && remainingRare > 0) {
                nftRarity[nftId] = Rarity.RARE;
                remainingRare--;
            } else if (index < uncommonRange && remainingUncommon > 0) {
                nftRarity[nftId] = Rarity.UNCOMMON;
                remainingUncommon--;
            } else {
                nftRarity[nftId] = Rarity.COMMON;
            }

            emit RarityAssigned(nftId, nftRarity[nftId]);

            remainingSupply--;
            totalAssigned++;
            count++;

            // Generate a new random seed for the next iteration
            randomNumber = uint256(keccak256(abi.encode(randomNumber, totalAssigned)));
        }

        // Check if distribution is complete
        if (totalAssigned == TOTAL_SUPPLY) {
            require(remainingRare == 0, "Incorrect number of RARE NFTs");
            require(remainingUncommon == 0, "Incorrect number of UNCOMMON NFTs");
            emit DistributionComplete();
        }
    }

    /// @notice Returns the rarity tier of a given NFT by its ID.
    function getRarity(uint256 nftId) external view returns (Rarity) {
        require(nftId > 0 && nftId <= TOTAL_SUPPLY, "NFT ID out of range");
        return nftRarity[nftId];
    }

    /// @notice Returns the current counts of each rarity tier
    function getRarityCounts() external view returns (uint256 rare, uint256 uncommon, uint256 common) {
        rare = TOTAL_RARE - remainingRare;
        uncommon = TOTAL_UNCOMMON - remainingUncommon;
        common = totalAssigned - rare - uncommon;
    }

    /// @notice Allows the contract to receive native tokens for VRF requests
    receive() external payable {
        emit NativeTokensReceived(msg.value);
    }

    /// @notice Allows the owner to withdraw any excess native tokens
    function withdrawNative() external onlyOwner {
        (bool success, ) = payable(owner()).call{value: address(this).balance}("");
        require(success, "Withdrawal failed");
    }
}
