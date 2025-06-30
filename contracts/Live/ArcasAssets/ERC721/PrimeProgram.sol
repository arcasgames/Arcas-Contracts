// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PrimeProgramNFT is ERC721Enumerable, Ownable {
    string private _baseTokenURI;
    mapping(address => bool) private _whitelist;
    uint256 private _nextTokenId;

    constructor(string memory baseURI, address initialOwner) ERC721("Prime Program", "PRIME") Ownable(initialOwner) {
        _baseTokenURI = baseURI;
        _whitelist[initialOwner] = true;
        _nextTokenId = 1;
    }

    function tokenURI(uint256) public view override returns (string memory) {
        return string(abi.encodePacked("ipfs://", _baseTokenURI));
    }

    function setBaseURI(string memory baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    function addToWhitelist(address user) external onlyOwner {
        _whitelist[user] = true;
    }

    function removeFromWhitelist(address user) external onlyOwner {
        _whitelist[user] = false;
    }

    function isWhitelisted(address user) external view returns (bool) {
        return _whitelist[user];
    }

    function mint(address to) external {
        require(_whitelist[msg.sender], "Not whitelisted");
        _safeMint(to, _nextTokenId);
        _nextTokenId++;
    }
}