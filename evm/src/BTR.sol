// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@abstract/ERC20Bridgeable.sol";

/**
 * @title BTR Token
 * @dev Cross-chain ERC20 token with a fixed maximum supply and genesis mint capability
 */
contract BTR is ERC20Bridgeable {
    // Custom Errors
    error InvalidMaxSupply();
    error GenesisAlreadyMinted();
    error NoTreasuryAddressFound();
    error InvalidAmount();

    // Custom Events
    event MaxSupplyUpdated(uint256 newMaxSupply);
    event GenesisMint(address indexed treasury, uint256 amount);

    // Supply limits
    uint256 public maxSupply;
    bool public genesisMinted;
    
    /**
     * @dev Constructor
     * @param name Token name
     * @param symbol Token symbol
     * @param _diamond Address of the diamond contract for access control
     * @param _maxSupply Maximum token supply that can be minted
     */
    constructor(
        string memory name,
        string memory symbol,
        address _diamond,
        uint256 _maxSupply
    ) ERC20Bridgeable(name, symbol, _diamond) {
        if (_maxSupply == 0) revert InvalidMaxSupply();
        
        maxSupply = _maxSupply;
        genesisMinted = false;
        
        // Emit event for initialization
        emit MaxSupplyUpdated(_maxSupply);
    }

    /**
     * @dev Update the maximum supply
     * @param _newMaxSupply The new maximum supply
     */
    function setMaxSupply(uint256 _newMaxSupply) external onlyAdmin {
        if (_newMaxSupply == 0) revert InvalidMaxSupply();
        if (_newMaxSupply < totalSupply()) revert InvalidMaxSupply();
        
        maxSupply = _newMaxSupply;
        emit MaxSupplyUpdated(_newMaxSupply);
    }

    /**
     * @dev Gets the treasury address with validation
     * @return The validated treasury address
     */
    function treasury() public view returns (address) {
        address treasuryAddr = super.treasury();
        if (treasuryAddr == address(0)) revert NoTreasuryAddressFound();
        return treasuryAddr;
    }

    /**
     * @dev Perform a one-time genesis mint to the treasury
     * @param amount The amount to mint in the genesis event
     */
    function mintGenesis(uint256 amount) external onlyAdmin {
        if (genesisMinted) revert GenesisAlreadyMinted();
        if (amount == 0) revert InvalidAmount();
        if (amount > maxSupply) revert MaxSupplyExceeded();
        
        address treasuryAddr = treasury(); // Will revert if no treasury found
        
        // Perform the genesis mint
        _mint(treasuryAddr, amount);
        
        // Mark genesis as completed
        genesisMinted = true;
        
        emit GenesisMint(treasuryAddr, amount);
    }

    /**
     * @dev Admin function to mint tokens directly to the treasury
     * @param amount The amount to mint
     */
    function mintToTreasury(uint256 amount) external onlyAdmin {
        if (amount == 0) revert InvalidAmount();
        
        // Use inherited function to check supply
        if (_wouldExceedMaxSupply(amount)) revert MaxSupplyExceeded();
        
        address treasuryAddr = treasury(); // Will revert if no treasury found
        _mint(treasuryAddr, amount);
    }

    /**
     * @dev Check if minting would exceed max supply
     * @param amount The amount to mint
     * @return True if minting would exceed max supply
     */
    function _wouldExceedMaxSupply(uint256 amount) internal view override returns (bool) {
        return totalSupply() + amount > maxSupply;
    }
}
