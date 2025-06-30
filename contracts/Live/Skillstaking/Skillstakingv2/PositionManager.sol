// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./SkillStaking.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PositionManager {
    SkillStaking public skillStaking;
    IERC20 public stakingToken;

    struct Position {
        uint256 amountStaked;
        uint256 userIndex;
        uint256 accruedYield;
    }
    // user => playerId => Position
    mapping(address => mapping(uint256 => Position)) public positions;

    constructor(address _skillStaking, address _stakingToken) {
        skillStaking = SkillStaking(_skillStaking);
        stakingToken = IERC20(_stakingToken);
    }

    function stake(uint256 playerId, uint256 amount) external {
        require(amount > 0, "Zero stake");
        skillStaking.updatePlayerIndex(playerId);

        Position storage pos = positions[msg.sender][playerId];
        // Accrue yield up to now
        pos.accruedYield += (pos.amountStaked * (skillStaking.playerData(playerId).globalIndex - pos.userIndex)) / 1e18;
        pos.amountStaked += amount;
        pos.userIndex = skillStaking.playerData(playerId).globalIndex;

        // Transfer tokens in
        require(stakingToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        // Update system stats
        skillStaking.updateSystemStats(playerId, int256(amount), 0);
    }

    function unstake(uint256 playerId, uint256 amount) external {
        Position storage pos = positions[msg.sender][playerId];
        require(pos.amountStaked >= amount, "Not enough staked");
        skillStaking.updatePlayerIndex(playerId);

        // Accrue yield up to now
        pos.accruedYield += (pos.amountStaked * (skillStaking.playerData(playerId).globalIndex - pos.userIndex)) / 1e18;
        pos.amountStaked -= amount;
        pos.userIndex = skillStaking.playerData(playerId).globalIndex;

        // Transfer tokens out
        require(stakingToken.transfer(msg.sender, amount), "Transfer failed");

        // Update system stats
        skillStaking.updateSystemStats(playerId, -int256(amount), 0);
    }

    function collectYield(uint256 playerId) external {
        skillStaking.updatePlayerIndex(playerId);
        Position storage pos = positions[msg.sender][playerId];
        uint256 pending = (pos.amountStaked * (skillStaking.playerData(playerId).globalIndex - pos.userIndex)) / 1e18;
        uint256 totalYield = pos.accruedYield + pending;
        require(totalYield > 0, "No yield");
        pos.accruedYield = 0;
        pos.userIndex = skillStaking.playerData(playerId).globalIndex;

        // Payout logic here (e.g., transfer from treasury)
        // Example: require(treasury.transfer(msg.sender, totalYield), "Payout failed");
    }
}