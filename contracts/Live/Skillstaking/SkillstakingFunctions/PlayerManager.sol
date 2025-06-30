// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "solady/src/auth/Ownable.sol";

contract PlayerManager is Ownable {
    // =========================
    //   STATE VARIABLES
    // =========================
    struct Player {
        uint256 rank;
        bool exists;
        uint256 accruedEntryFees;
    }
    mapping(uint256 => Player) public players;
    uint256 public playerCount;
    address public server;
    address public skillStaking;

    // =========================
    //   EVENTS
    // =========================
    event ServerSet(address indexed server);
    event SkillStakingSet(address indexed skillStaking);
    event RanksUpdated(uint256[] playerIds, uint256[] ranks);
    event BurntTokensAccrued(uint256 indexed playerId, uint256 amount);

    // =========================
    //   MODIFIERS
    // =========================
    modifier onlyServer() {
        require(msg.sender == server || msg.sender == owner(), "Not server");
        _;
    }
    modifier onlySkillStaking() {
        require(msg.sender == skillStaking, "Not SkillStaking");
        _;
    }

    // =========================
    //   CONSTRUCTOR
    // =========================
    constructor() {
        _initializeOwner(msg.sender);
    }

    // =========================
    //   ADMIN FUNCTIONS
    // =========================
    function setServer(address _server) external onlyOwner {
        require(_server != address(0), "Zero address");
        server = _server;
        emit ServerSet(_server);
    }
    function setSkillStaking(address _skillStaking) external onlyOwner {
        require(_skillStaking != address(0), "Zero address");
        skillStaking = _skillStaking;
        emit SkillStakingSet(_skillStaking);
    }

    // =========================
    //   SERVER FUNCTIONS
    // =========================
    /// @notice Batch update ranks for multiple players, registering new ones if they don't exist
    /// @param playerIds Array of player IDs to update
    /// @param ranks Array of corresponding new ranks
    function batchUpdateRanks(uint256[] calldata playerIds, uint256[] calldata ranks) external onlyServer {
        require(playerIds.length == ranks.length, "Array length mismatch");
        require(playerIds.length > 0, "Empty arrays");

        // Cache array length to avoid multiple SLOADs
        uint256 length = playerIds.length;
        
        // Cache playerCount to avoid multiple SLOADs
        uint256 _playerCount = playerCount;

        for (uint256 i = 0; i < length; i++) {
            uint256 playerId = playerIds[i];
            uint256 newRank = ranks[i];

            if (!players[playerId].exists) {
                // Register new player
                players[playerId] = Player(newRank, true, 0);
                _playerCount++;
            } else {
                // Update existing player
                players[playerId].rank = newRank;
            }
        }

        // Update playerCount once at the end
        playerCount = _playerCount;

        // Emit single event with all updates
        emit RanksUpdated(playerIds, ranks);
    }

    // =========================
    //   SKILLSTAKING FUNCTIONS
    // =========================
    /// @notice Called by SkillStaking to accrue burnt entry fees under a player
    function accrueBurntTokens(uint256 playerId, uint256 amount) external onlySkillStaking {
        require(players[playerId].exists, "Player does not exist");
        // Use unchecked for addition since we're not concerned about overflow
        unchecked {
            players[playerId].accruedEntryFees += amount;
        }
        emit BurntTokensAccrued(playerId, amount);
    }

    // Optional: helper functions
    function playerExists(uint256 playerId) external view returns (bool) {
        return players[playerId].exists;
    }
} 