// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockERC721
 * @notice A simple ERC721 token for testing
 */
contract MockERC721 is ERC721Burnable, Ownable {
    constructor(string memory name, string memory symbol) ERC721(name, symbol) Ownable(msg.sender) {}

    /**
     * @notice Mint a new token
     * @param to The address to mint the token to
     * @param tokenId The ID of the token to mint
     */
    function mint(address to, uint256 tokenId) public {
        _safeMint(to, tokenId);
    }
} 