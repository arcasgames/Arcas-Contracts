// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract WelcomeToTheJungleSBT is ERC721, Ownable {
    bool public mintingLocked;
    string private _baseTokenURI;
    mapping(address => bool) private _hasMinted;
    uint256 private _nextTokenId = 1;

    constructor(address initialOwner, string memory baseURI) ERC721("Welcome to the Jungle SBT", "WELCOMESBT") Ownable(initialOwner) {
        _baseTokenURI = baseURI;
    }

    function mint() external {
        require(!mintingLocked, "Minting is locked");
        require(!_hasMinted[msg.sender], "Wallet has already minted");
        uint256 tokenId = _nextTokenId;
        _safeMint(msg.sender, tokenId);
        _hasMinted[msg.sender] = true;
        _nextTokenId++;
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