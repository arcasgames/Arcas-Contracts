// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./PrimeNFT.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PrimeMinter is Ownable {
    PrimeProgramNFT private nftContract;

    constructor(PrimeProgramNFT _nftContract) Ownable(msg.sender) {
        nftContract = _nftContract;
    }

    function batchMint(address[] calldata recipients) external onlyOwner {
        for (uint256 i = 0; i < recipients.length; i++) {
            nftContract.mint(recipients[i]);
        }
    }
}