// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title IERC7802 Interface
 * @dev Interface for the ERC7802 standard, which defines a cross-chain token bridge interface.
 * This standard allows tokens to be transferred between different blockchain networks.
 */
interface IERC7802 {
    /**
     * @dev Emitted when tokens are minted as part of a cross-chain operation
     * @param to The address receiving the tokens
     * @param amount The amount of tokens minted
     * @param bridge The address of the bridge contract that triggered the mint
     */
    event CrosschainMint(address indexed to, uint256 amount, address indexed bridge);
    
    /**
     * @dev Emitted when tokens are burned as part of a cross-chain operation
     * @param from The address whose tokens were burned
     * @param amount The amount of tokens burned
     * @param bridge The address of the bridge contract that triggered the burn
     */
    event CrosschainBurn(address indexed from, uint256 amount, address indexed bridge);
    
    /**
     * @dev Mint tokens as part of a cross-chain transfer
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint
     */
    function crosschainMint(address to, uint256 amount) external;
    
    /**
     * @dev Burn tokens as part of a cross-chain transfer
     * @param from The address to burn tokens from
     * @param amount The amount of tokens to burn
     */
    function crosschainBurn(address from, uint256 amount) external;
}
