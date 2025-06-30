// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BlackMarketTradoorSBT is ERC721, Ownable {
    bool public mintingLocked;
    string private _baseTokenURI;
    uint256 private _nextTokenId = 1;

    constructor(address initialOwner, string memory baseURI) 
        ERC721("Black Market Tradoor SBT", "BLACKMARKETSBT") 
        Ownable(initialOwner) 
    {
        _baseTokenURI = baseURI;
    }

    function batchMint(address[] calldata recipients) external onlyOwner {
        require(!mintingLocked, "Minting is locked");

        for (uint256 i = 0; i < recipients.length; i++) {
            require(balanceOf(recipients[i]) == 0, "Address already owns a token");
            _safeMint(recipients[i], _nextTokenId++);
        }
    }

    function lockMinting() external onlyOwner {
        mintingLocked = true;
    }

    function setBaseURI(string memory baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    function tokenURI(uint256) public view override returns (string memory) {
        return string(abi.encodePacked("ipfs://", _baseTokenURI));
    }

    function _update(address to, uint256 tokenId, address auth) internal virtual override returns (address) {
        require(_ownerOf(tokenId) == address(0), "Soulbound token: transfers disabled");
        return super._update(to, tokenId, auth);
    }
}
