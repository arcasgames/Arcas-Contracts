Arcas Assets Overview

1. 100mil ARCAS tokens on BNB, ETH & SONEIUM

BNB: 0x7ca058309053F90b39Bfc58dE1edA2a89e9c03a8
ETH: 0x570f09AC53b96929e3868f71864E36Ff6b1B67D7
SON: 0x570f09AC53b96929e3868f71864E36Ff6b1B67D7

2. 10k GAMESTER NFTS on BNB

BNB: 0x4bd2a30435e6624CcDee4C60229250A84a2E4cD6

3. 1500 BASTONIUM NFTs on SONEIUM

SON: 0x7683133aab29287b04d8a30caccc9e3fb5f7a68f

4. 90 BASTRONAUT NFTs on BNB

BNB:0x29013Cc12d6051246507FA1e46A510A1C0bc076D

5. 51 PRIME PROGRAM NFTs on SONEIUM

SON: 0x5E407c82D7eFa132fE84D2207F6109F89a1c500F

Arcas Badges Overview

1. 125,738 Welcome to the Jungle SBTs

SON: 0x52d44Bea684eCd8Cad6d02205e40FC3bD59Ad877

2. 7,763 BLACK MARKET TRADOOR SBTs

SON: 0x9a4cC369A91AE5e8cBd99163a2eAC5b7957879dB

3. TBD BATTLE HARDENED APE SBTs

SON: TBD

Partner Assets

1. ASTAR on Soneium:

SON: 0x2CAE934a1e84F693fbb78CA5ED3B0A6893259441

2. 307 Soneium Premium OG Badge ERC1155 TokenID 1:

SON: 0x2A21B17E366836e5FFB19bd47edB03b4b551C89d

3. 24,506 ACS OG Badge ErC1155 Token ID 3:

SON: 0x2A21B17E366836e5FFB19bd47edB03b4b551C89d




Soneium Contract System Design:

General Contracts:

1. SmartAccountAuthority.sol
Allows EOAs to connect a smart account which transacts on their behalf with ecosystem contracts.
It's called on initialisation whenever a smart account is created.

Arcas Hub:

1. Staking Module
This allows for Arcas & Partner assets to be staked

2. Arcas Badge ERC1155
This contract emits 3 tiers of badges which provide benefits across the Arcas ecosystem on Soneium.

3. Arcas Bridge
This CCIP contract handles the bridging of Arcas acros chains

4. Arcas Bridge Treasury
This handles the Arcas tokens stored in the bridge treasury

//Likely plan to relaunch the token using the Chainlink CCIP Token Manager, removing the need for the bridge.


Skillstaking:

1. PlayerManager.sol 
This stores player rank which is written directly from Arcas Champions.

2. Skillstaking.sol
Handles staking, unstaking and positions for users.

3. Treasury.sol
Uses Chainlink functions to calculate and award yield for users. Reads the Arcas Badge ERC1155 to award additional yield for stakers if they are eligible.
