// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract SkillStaking is Ownable {
    struct Player {
        uint256 playerId;
        uint256 rank;
        bool exists;
        uint256 totalStaked;
        uint256 playerRankIndex;    // Cumulative rank multiplier index
        uint256 lastRankUpdateBlock;
    }
    mapping(uint256 => Player) public players;
    uint256 public playerCount;
    uint256 public totalRank;
    uint256 public totalStaked;

    // Global yield index
    uint256 public globalIndex;
    uint256 public lastGlobalUpdateBlock;

    // System parameters
    uint256 public Y;   // Yield per block

    // User position
    struct Position {
        uint256 amountStaked;
        uint256 userGlobalIndex;
        uint256 userPlayerRankIndex;
        uint256 accruedYield;
    }
    // user => playerId => Position
    mapping(address => mapping(uint256 => Position)) public positions;

    // --- Index Update Functions ---

    // Update the global index up to the current block
    function updateGlobalIndex() public {
        uint256 blocksElapsed = block.number - lastGlobalUpdateBlock;
        if (blocksElapsed > 0 && totalStaked > 0) {
            uint256 yieldThisPeriod = Y * blocksElapsed;
            globalIndex += (yieldThisPeriod * 1e18) / totalStaked;
        }
        lastGlobalUpdateBlock = block.number;
    }

    // Update the player's rank index up to the current block
    function updatePlayerRankIndex(uint256 playerId) public {
        Player storage p = players[playerId];
        uint256 blocksElapsed = block.number - p.lastRankUpdateBlock;
        if (blocksElapsed > 0) {
            uint256 AR = getAverageRank();
            uint256 rankSkew = (1e18 + ((p.rank - AR) * 1e18) / AR); // 1e18 scaling
            // Compound the rank multiplier over time
            p.playerRankIndex += (rankSkew * blocksElapsed);
        }
        p.lastRankUpdateBlock = block.number;
    }

    // --- User Actions ---

    function stake(uint256 playerId, uint256 amount) external {
        require(amount > 0, "Zero stake");
        updateGlobalIndex();
        updatePlayerRankIndex(playerId);

        Position storage pos = positions[msg.sender][playerId];
        // Accrue yield up to now
        uint256 pending = (pos.amountStaked * (globalIndex - pos.userGlobalIndex) * (players[playerId].playerRankIndex - pos.userPlayerRankIndex)) / 1e36;
        pos.accruedYield += pending;
        pos.amountStaked += amount;
        pos.userGlobalIndex = globalIndex;
        pos.userPlayerRankIndex = players[playerId].playerRankIndex;

        // Update system stats
        totalStaked += amount;
        players[playerId].totalStaked += amount;
        // Transfer tokens in, etc.
    }

    function unstake(uint256 playerId, uint256 amount) external {
        Position storage pos = positions[msg.sender][playerId];
        require(pos.amountStaked >= amount, "Not enough staked");
        updateGlobalIndex();
        updatePlayerRankIndex(playerId);

        // Accrue yield up to now
        uint256 pending = (pos.amountStaked * (globalIndex - pos.userGlobalIndex) * (players[playerId].playerRankIndex - pos.userPlayerRankIndex)) / 1e36;
        pos.accruedYield += pending;
        pos.amountStaked -= amount;
        pos.userGlobalIndex = globalIndex;
        pos.userPlayerRankIndex = players[playerId].playerRankIndex;

        // Update system stats
        totalStaked -= amount;
        players[playerId].totalStaked -= amount;
        // Transfer tokens out, etc.
    }

    function collectYield(uint256 playerId) external {
        updateGlobalIndex();
        updatePlayerRankIndex(playerId);

        Position storage pos = positions[msg.sender][playerId];
        uint256 pending = (pos.amountStaked * (globalIndex - pos.userGlobalIndex) * (players[playerId].playerRankIndex - pos.userPlayerRankIndex)) / 1e36;
        uint256 totalYield = pos.accruedYield + pending;
        require(totalYield > 0, "No yield");
        pos.accruedYield = 0;
        pos.userGlobalIndex = globalIndex;
        pos.userPlayerRankIndex = players[playerId].playerRankIndex;

        // Payout logic here
    }

    // --- Admin/Server Functions ---

    function registerPlayer(uint256 playerId, uint256 initialRank) external onlyOwner {
        require(!players[playerId].exists, "Player exists");
        players[playerId] = Player(playerId, initialRank, true, 0, 0, block.number);
        playerCount++;
        totalRank += initialRank;
    }

    function batchUpdateRanks(uint256[] calldata playerIds, uint256[] calldata newRanks) external onlyOwner {
        require(playerIds.length == newRanks.length, "Array length mismatch");
        for (uint256 i = 0; i < playerIds.length; i++) {
            uint256 playerId = playerIds[i];
            uint256 newRank = newRanks[i];
            require(players[playerId].exists, "Player does not exist");
            updatePlayerRankIndex(playerId); // Accrue up to now at old rank
            uint256 oldRank = players[playerId].rank;
            players[playerId].rank = newRank;
            totalRank = totalRank + newRank - oldRank;
        }
    }

    // --- Read Functions ---

    function getAverageRank() public view returns (uint256) {
        return playerCount == 0 ? 1 : totalRank / playerCount;
    }
}