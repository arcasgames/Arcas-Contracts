// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "solady/src/auth/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPlayerManager {
    function accrueBurntTokens(uint256 playerId, uint256 amount) external;
    function playerExists(uint256 playerId) external view returns (bool);
    function getTotalStaked(uint256 playerId) external view returns (uint256);
}

interface ITreasury {
    function claimYield(address user, uint256 playerId, uint256 amount, bytes calldata proof) external returns (bytes32);
}

contract SkillStaking is Ownable {
    // =========================
    //   STATE VARIABLES
    // =========================
    address public playerManager;
    address public treasury;
    uint256 public yieldPerBlock;
    uint256 public maxStakePerPlayer;
    uint256 public maxEntryFee;
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    IERC20 public immutable stakingToken;

    struct Position {
        uint256 amountStaked;
        uint256 lastStakeBlock;
        uint256 lastUnstakeBlock;
        uint256 lastClaimBlock;
    }
    // user => playerId => Position
    mapping(address => mapping(uint256 => Position)) public positions;

    // =========================
    //   EVENTS
    // =========================
    event ParamsUpdated(uint256 yieldPerBlock, uint256 maxStakePerPlayer, uint256 maxEntryFee);
    event TreasurySet(address indexed treasury);
    event PlayerManagerSet(address indexed playerManager);
    event Staked(address indexed user, uint256 indexed playerId, uint256 amount);
    event Unstaked(address indexed user, uint256 indexed playerId, uint256 amount);
    event YieldClaimInitiated(address indexed user, uint256 indexed playerId, uint256 amount, bytes proof);
    event YieldClaimed(address indexed user, uint256 indexed playerId, uint256 amount);

    // =========================
    //   MODIFIERS
    // =========================
    modifier onlyTreasury() {
        require(msg.sender == treasury, "Not treasury");
        _;
    }

    // =========================
    //   CONSTRUCTOR
    // =========================
    constructor(IERC20 _stakingToken) {
        _initializeOwner(msg.sender);
        stakingToken = _stakingToken;
    }

    // =========================
    //   ADMIN FUNCTIONS
    // =========================
    function setParams(uint256 _yieldPerBlock, uint256 _maxStakePerPlayer, uint256 _maxEntryFee) external onlyOwner {
        yieldPerBlock = _yieldPerBlock;
        maxStakePerPlayer = _maxStakePerPlayer;
        maxEntryFee = _maxEntryFee;
        emit ParamsUpdated(_yieldPerBlock, _maxStakePerPlayer, _maxEntryFee);
    }
    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
        emit TreasurySet(_treasury);
    }
    function setPlayerManager(address _playerManager) external onlyOwner {
        playerManager = _playerManager;
        emit PlayerManagerSet(_playerManager);
    }

    // =========================
    //   PUBLIC FUNCTIONS
    // =========================
    function stake(uint256 playerId, uint256 amount) external {
        require(playerManager != address(0), "PlayerManager not set");
        require(amount > 0, "Zero stake");

        // Check player exists
        require(IPlayerManager(playerManager).playerExists(playerId), "Player does not exist");

        // Check sender has enough tokens and allowance
        require(stakingToken.balanceOf(msg.sender) >= amount, "Insufficient balance");
        require(stakingToken.allowance(msg.sender, address(this)) >= amount, "Insufficient allowance");

        // Get current staked under player
        uint256 currentlyStaked = IPlayerManager(playerManager).getTotalStaked(playerId);

        // Calculate entry fee
        uint256 entryFee = ((amount + currentlyStaked) * maxEntryFee) / maxStakePerPlayer;

        // Check max stake constraint
        require(amount + currentlyStaked - entryFee <= maxStakePerPlayer, "Exceeds max stake");

        // Transfer tokens from user to contract
        require(stakingToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        // Burn entry fee
        if (entryFee > 0) {
            require(stakingToken.transfer(BURN_ADDRESS, entryFee), "Burn failed");
            IPlayerManager(playerManager).accrueBurntTokens(playerId, entryFee);
        }

        // Update position
        positions[msg.sender][playerId].amountStaked += (amount - entryFee);
        positions[msg.sender][playerId].lastStakeBlock = block.number;

        emit Staked(msg.sender, playerId, amount);
    }
    function unstake(uint256 playerId, uint256 amount) external {
        require(playerManager != address(0), "PlayerManager not set");
        require(amount > 0, "Zero unstake");
        require(positions[msg.sender][playerId].amountStaked >= amount, "Not enough staked");
        // Transfer tokens out (not implemented)
        positions[msg.sender][playerId].amountStaked -= amount;
        positions[msg.sender][playerId].lastUnstakeBlock = block.number;
        emit Unstaked(msg.sender, playerId, amount);
    }

    /// @notice Initiate a yield claim (calls Treasury)
    function claimYield(uint256 playerId, uint256 amount, bytes calldata proof) external {
        require(treasury != address(0), "Treasury not set");
        ITreasury(treasury).claimYield(msg.sender, playerId, amount, proof);
        emit YieldClaimInitiated(msg.sender, playerId, amount, proof);
    }

    // =========================
    //   TREASURY CALLBACK
    // =========================
    /// @notice Called by Treasury after successful yield payout
    function onYieldClaimed(address user, uint256 playerId, uint256 amount) external onlyTreasury {
        positions[user][playerId].lastClaimBlock = block.number;
        emit YieldClaimed(user, playerId, amount);
    }
}
