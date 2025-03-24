// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockERC1155
 * @notice A simple ERC1155 token for testing
 */
contract MockERC1155 is ERC1155, Ownable {
    constructor(string memory uri) ERC1155(uri) Ownable(msg.sender) {}

    /**
     * @notice Mint a new token
     * @param to The address to mint the token to
     * @param id The ID of the token to mint
     * @param amount The amount of tokens to mint
     * @param data Additional data with no specified format
     */
    function mint(address to, uint256 id, uint256 amount, bytes memory data) public {
        _mint(to, id, amount, data);
    }

    /**
     * @notice Mint multiple tokens
     * @param to The address to mint the tokens to
     * @param ids Array of token IDs to mint
     * @param amounts Array of amounts to mint
     * @param data Additional data with no specified format
     */
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public {
        _mintBatch(to, ids, amounts, data);
    }
} 