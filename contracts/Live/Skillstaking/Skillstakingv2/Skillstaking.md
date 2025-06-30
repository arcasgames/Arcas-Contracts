The goal of skillstaking is to allow people to stake ERC20 tokens under a particular player inside a
game and to earn variable yield based upon their in game rank value going up or down.

The system has the following components:

1. PlayerManager.sol -> This is used to add new players to the system, referenced by their playerID
as well as to update the Rank value parameters of players as they play (if they win a game, we increase
their rank score, if they lose we decrease it) Only the server admin can add players or update rank.


2. Skillstaking.sol -> The contract needs to contain the logic on how to calculate yield, with some
parameters which can be set by the admin to adjust how it is calculated and what the yield rate it.
Here we need to consider the following:

- The total amount of tokens staked accross all players (TS)
- The total rank value accross all players (TR)
- The average rank value accross all players (AR)
- The Maximum which can be staked under a single player (MS)
- The total yield being payed out per block (Y)
- The maximum entry fee charged when a player is staked (ME)

Now the formula to calculate yield is the following:


Rank Skew = (1 + ((Player Rank - AR) / AR)) 
This creates a multiplier on your yield based on your rank compared to the average rank of all players.

Stake Size = Amount staked / TS
This factors in your proportion of the total staking pool

Yield to collect = ((blocknumber.now - lastcollectblock) * Y) * Stake Size * Rank Skew

Now the key issue with this formula is that it doesn't factor in the changes to rank over time
between the current block number and the last block in which the user collected their yield.

This is what we need to work on.


3. PositionManager.sol -> This contract is the only one which is exposed to the public. It needs to
handle the logic which allows people to stake/unstake a specific player and collect yield from their
positions. Ideally this position manager also has functions which allow the user to collect yield on
all of their positions (although as we are using Account abstraction, we can also batch these on the 
frontend in the background). Also ideally the posiiton manager is able to let people stake / unstake 
variable amounts from players, and not in fixed amounts like on the v1 positionManager.

When a player is staked we need to do the following:

1. We ensure that the amount staked doesn't exceed the MS (Maximum Staked) for a player.
2. We create / update the staked position under that player for the staking wallet.
3. We calculate the entry fee which is burnt under the player, this is calculated based on:
((Amount being staked + Total staked under player) / MS) * ME
Basically if a player has 0 staked, your entry fee is v small. If a player is close to max staked, your entry fee is big.

When a player is unstaked:

1. We allow a variable amount to be unstaked, so you could e.g. withdraw 50% of what you staked under a player.
2. We update the staked position under that player for the staking wallet.
3. We update the TS and the amount staked under that player.
4. We calculate and withdraw the outstanding yield to the stakers wallet.

When the staker collects yield:

1. We need to calculaet how much yield the staker is owed based upon when he last collected yield. Here we need to factor in the fact that the players rank will have fluctuated.