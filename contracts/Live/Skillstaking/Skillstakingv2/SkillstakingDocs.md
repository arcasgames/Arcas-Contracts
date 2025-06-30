# SkillStakingV2 System Documentation

## Overview
SkillStakingV2 is a modular staking system for games, allowing users to stake tokens under players and earn yield based on player rank. The system is composed of three main contracts:

1. **PlayerManager**: Admin-only contract for adding players and updating their ranks.
2. **SkillStaking**: Stores system parameters, manages per-player yield indices, and provides math for yield calculation.
3. **PositionManager**: Public contract for staking, unstaking, and collecting yield, tracking user positions.

---

## 1. PlayerManager.sol
**Purpose:** Server-side contract to add new players and update their ranks.

### Functions
- `registerPlayer(uint256 playerId, uint256 initialRank)`
  - Adds a new player with a given ID and initial rank. Only callable by the owner (server).
- `updateRank(uint256 playerId, uint256 newRank)`
  - Updates the rank of an existing player. Only callable by the owner (server).
- `getRank(uint256 playerId) -> uint256`
  - Returns the current rank of a player.

### Events
- `PlayerRegistered(uint256 indexed playerId, uint256 rank)`
- `PlayerRankUpdated(uint256 indexed playerId, uint256 oldRank, uint256 newRank)`

---

## 2. SkillStaking.sol
**Purpose:** Stores system-wide and per-player parameters, manages yield indices, and provides math for yield calculation. Only the owner (server) can update parameters and call certain functions.

### Functions
- `setParams(uint256 _Y, uint256 _ME, uint256 _MS)`
  - Sets system parameters: yield per block (Y), max entry fee (ME), max staked per player (MS).
- `updatePlayerIndex(uint256 playerId)`
  - Updates the global yield index for a player up to the current block, using the current rank and system parameters. Should be called before any state-changing action affecting yield.
- `updateSystemStats(uint256 playerId, int256 stakeDelta, int256 rankDelta)`
  - Updates system-wide and per-player stats when stake/unstake occurs. Only callable by the owner (PositionManager).
- `getAverageRank() -> uint256`
  - Returns the average rank across all players.
- `updateRankAndIndex(uint256 playerId, uint256 newRank)`
  - Helper function: updates the player's global index (accruing yield up to now at the old rank) and then updates the player's rank in PlayerManager. Only callable by the owner (server).

### Events
- `ParamsUpdated(uint256 Y, uint256 ME, uint256 MS)`

### Data Structures
- `PlayerData` struct: stores per-player stats (totalStaked, globalIndex, lastUpdateBlock, rank)

---

## 3. PositionManager.sol
**Purpose:** Public contract for users to stake, unstake, and collect yield. Tracks user positions and interacts with SkillStaking for yield math and system updates.

### Functions
- `stake(uint256 playerId, uint256 amount)`
  - User stakes tokens under a player. Updates yield index, accrues yield, and updates system stats.
- `unstake(uint256 playerId, uint256 amount)`
  - User unstakes tokens from a player. Updates yield index, accrues yield, and updates system stats.
- `collectYield(uint256 playerId)`
  - User collects accrued yield from staking under a player. Updates yield index and pays out yield.

### Data Structures
- `Position` struct: stores user position per player (amountStaked, userIndex, accruedYield)

---

## How the Contracts Relate
- **PlayerManager** is the source of truth for player existence and rank. Only the server can add/update players.
- **SkillStaking** references PlayerManager for up-to-date ranks and manages all yield math and system parameters. Only the server or PositionManager can call certain functions.
- **PositionManager** is the only contract users interact with. It calls SkillStaking to update indices and stats, and calls the ERC20 token for transfers.

---

## Deployment Order
1. **Deploy PlayerManager**
   - Initialize with the server/admin as the owner.
2. **Deploy SkillStaking**
   - Pass the address of the deployed PlayerManager to the constructor.
   - Set initial system parameters (Y, ME, MS) using `setParams`.
3. **Deploy PositionManager**
   - Pass the addresses of the deployed SkillStaking and the ERC20 staking token to the constructor.

---

## Example Workflow
1. **Server** adds players and updates ranks via PlayerManager.
2. **Server** updates system parameters via SkillStaking as needed.
3. **Users** stake, unstake, and collect yield via PositionManager.
4. **PositionManager** calls SkillStaking to update indices and stats, ensuring yield is always up-to-date and fair.
5. **Server** uses `updateRankAndIndex` in SkillStaking to atomically update yield and player rank.

---

For further details, see the inline documentation in each contract. 