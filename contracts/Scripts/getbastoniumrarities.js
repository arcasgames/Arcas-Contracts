const { ethers } = require('ethers');

// Configuration
const CONTRACT_ADDRESS = "0xD4ef3289542f76eF5aADfEeA94d5Ac59d539A0A3";

// Contract ABI for getRarity function
const CONTRACT_ABI = [
    "function getRarity(uint256 nftId) view returns (uint8)"
];

// Rarity mapping
const RARITY_MAP = {
    0: "UNASSIGNED",
    1: "COMMON",
    2: "UNCOMMON",
    3: "RARE"
};

async function main() {
    const provider = new ethers.JsonRpcProvider("https://soneium.rpc.scs.startale.com?apikey=xYkJP5odlf3KVpfq7bdh2D2fkzf5TJDE");
    const contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, provider);

    console.log("Starting rarity retrieval for NFTs 1-500...");

    const results = [];
    let processedCount = 0;
    const totalNfts = 500;

    // Process NFTs in batches to avoid rate limiting
    const batchSize = 50;
    for (let i = 1; i <= totalNfts; i += batchSize) {
        const end = Math.min(i + batchSize - 1, totalNfts);
        console.log(`Processing NFTs ${i} to ${end}...`);

        const batchPromises = [];
        for (let nftId = i; nftId <= end; nftId++) {
            batchPromises.push(
                contract.getRarity(nftId)
                    .then(rarity => ({
                        nftId,
                        rarity: Number(rarity) // Convert BigInt to number
                    }))
                    .catch(error => {
                        console.error(`Error fetching rarity for NFT ${nftId}:`, error);
                        return {
                            nftId,
                            rarity: 0 // UNASSIGNED
                        };
                    })
            );
        }

        const batchResults = await Promise.all(batchPromises);
        results.push(...batchResults);
        processedCount += batchResults.length;

        // Print progress
        if (processedCount % 100 === 0) {
            console.log(`Progress: ${processedCount}/${totalNfts} NFTs processed`);
        }
    }

    // Filter out UNASSIGNED rarities and prepare arrays for setRarityBatch
    const validResults = results.filter(result => result.rarity !== 0);
    
    const nftIds = validResults.map(result => Number(result.nftId)); // Convert BigInt to number
    const rarities = validResults.map(result => Number(result.rarity)); // Convert BigInt to number

    console.log("\n=== ARRAYS FOR setRarityBatch ===");
    console.log("NFT IDs array:");
    console.log(JSON.stringify(nftIds));
    console.log("\nRarities array:");
    console.log(JSON.stringify(rarities));
    
    console.log("\n=== COPY-PASTE FOR CONTRACT CALL ===");
    console.log(`nftIds: [${nftIds.join(', ')}]`);
    console.log(`rarities: [${rarities.join(', ')}]`);

    // Calculate rarity distribution
    const rarityCounts = results.reduce((acc, nft) => {
        const rarityName = RARITY_MAP[nft.rarity] || "UNKNOWN";
        acc[rarityName] = (acc[rarityName] || 0) + 1;
        return acc;
    }, {});

    console.log("\n=== RARITY DISTRIBUTION ===");
    console.log(`Total NFTs processed: ${processedCount}`);
    console.log(`Valid NFTs for setRarityBatch: ${validResults.length}`);
    Object.entries(rarityCounts).forEach(([rarity, count]) => {
        console.log(`${rarity}: ${count} NFTs (${((count/totalNfts)*100).toFixed(2)}%)`);
    });
    
    console.log("\n=== USAGE INSTRUCTIONS ===");
    console.log("1. Copy the nftIds and rarities arrays above");
    console.log("2. Call setRarityBatch(nftIds, rarities) on your BastoniumTiersTestnet contract");
    console.log("3. Rarity values: 1=COMMON, 2=UNCOMMON, 3=RARE");
}

main().catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
});
