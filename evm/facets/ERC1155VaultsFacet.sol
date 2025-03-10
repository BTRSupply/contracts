// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {VaultStorage, ProtocolStorage, ErrorType} from "../BTRTypes.sol";
import {BTRStorage as S} from "../libraries/BTRStorage.sol";
import {BTRErrors as Errors, BTREvents as Events} from "../libraries/BTREvents.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {PausableFacet} from "./abstract/PausableFacet.sol";
import {NonReentrantFacet} from "./abstract/NonReentrantFacet.sol";

/**
 * @title ERC1155-like Facet for Multiple Vault Tokens
 * @notice Handles token operations for multiple vault tokens in a single contract
 * @dev Implements ERC1155-like functionality where tokenId is the vaultId
 */
contract ERC1155VaultsFacet is PausableFacet, NonReentrantFacet {
    using SafeERC20 for IERC20;

    // Modifier to ensure the vault exists
    modifier vaultExists(uint32 vaultId) {
        if (vaultId >= S.protocol().vaultCount) revert Errors.NotFound(ErrorType.VAULT);
        _;
    }
    
    // Modifier to check if a vault is not paused
    modifier whenVaultNotPaused(uint32 vaultId) {
        if (S.protocol().vaults[vaultId].paused) revert Errors.Paused();
        _;
    }

    /**
     * @notice Get the balance of vault tokens for an account
     * @param vaultId ID of the vault
     * @param account Address to query balance for
     * @return Token balance for the account
     */
    function balanceOf(uint32 vaultId, address account) external view vaultExists(vaultId) returns (uint256) {
        return S.protocol().vaults[vaultId].balances[account];
    }

    /**
     * @notice Get the total supply of vault tokens
     * @param vaultId ID of the vault
     * @return Total supply of tokens
     */
    function totalSupply(uint32 vaultId) external view vaultExists(vaultId) returns (uint256) {
        return S.protocol().vaults[vaultId].totalSupply;
    }

    /**
     * @notice Approve spender to spend vault tokens
     * @param vaultId ID of the vault
     * @param spender Address to approve
     * @param amount Amount to approve
     * @return True if the operation succeeded
     */
    function approve(uint32 vaultId, address spender, uint256 amount) external vaultExists(vaultId) returns (bool) {
        if (spender == address(0)) revert Errors.ZeroAddress();
        
        VaultStorage storage vs = S.protocol().vaults[vaultId];
        vs.allowances[msg.sender][spender] = amount;
        
        emit Events.Approval(msg.sender, spender, amount);
        return true;
    }

    /**
     * @notice Get the allowance for spender from owner
     * @param vaultId ID of the vault
     * @param owner Address that owns the tokens
     * @param spender Address that can spend the tokens
     * @return Amount spender is allowed to spend
     */
    function allowance(uint32 vaultId, address owner, address spender) external view vaultExists(vaultId) returns (uint256) {
        return S.protocol().vaults[vaultId].allowances[owner][spender];
    }

    /**
     * @notice Transfer vault tokens to recipient
     * @param vaultId ID of the vault
     * @param recipient Address to transfer tokens to
     * @param amount Amount of tokens to transfer
     * @return True if the operation succeeded
     */
    function transfer(uint32 vaultId, address recipient, uint256 amount) external vaultExists(vaultId) returns (bool) {
        _transfer(vaultId, msg.sender, recipient, amount);
        return true;
    }

    /**
     * @notice Transfer vault tokens from sender to recipient
     * @param vaultId ID of the vault
     * @param sender Address to transfer tokens from
     * @param recipient Address to transfer tokens to
     * @param amount Amount of tokens to transfer
     * @return True if the operation succeeded
     */
    function transferFrom(uint32 vaultId, address sender, address recipient, uint256 amount) external vaultExists(vaultId) returns (bool) {
        VaultStorage storage vs = S.protocol().vaults[vaultId];
        
        // Check allowances
        if (sender != msg.sender) {
            uint256 currentAllowance = vs.allowances[sender][msg.sender];
            if (currentAllowance < amount) {
                revert Errors.Insufficient(currentAllowance, amount);
            }
            vs.allowances[sender][msg.sender] = currentAllowance - amount;
        }
        
        _transfer(vaultId, sender, recipient, amount);
        return true;
    }

    /**
     * @notice Internal transfer implementation
     * @param vaultId ID of the vault
     * @param sender Address sending tokens
     * @param recipient Address receiving tokens
     * @param amount Amount of tokens to transfer
     */
    function _transfer(uint32 vaultId, address sender, address recipient, uint256 amount) internal whenVaultNotPaused(vaultId) {
        if (sender == address(0) || recipient == address(0)) revert Errors.ZeroAddress();
        if (amount == 0) revert Errors.ZeroValue();
        
        VaultStorage storage vs = S.protocol().vaults[vaultId];
        
        // Check if sender has enough balance
        if (vs.balances[sender] < amount) {
            revert Errors.Insufficient(vs.balances[sender], amount);
        }
        
        // Transfer balance
        vs.balances[sender] -= amount;
        vs.balances[recipient] += amount;
        
        emit Events.Transfer(sender, recipient, amount);
    }

    /**
     * @notice Internal method to mint vault tokens
     * @param vaultId ID of the vault
     * @param account Address to receive the tokens
     * @param amount Amount of tokens to mint
     */
    function _mint(uint32 vaultId, address account, uint256 amount) internal {
        if (account == address(0)) revert Errors.ZeroAddress();
        
        VaultStorage storage vs = S.protocol().vaults[vaultId];
        
        // Check max supply
        if (vs.maxSupply > 0 && vs.totalSupply + amount > vs.maxSupply) {
            revert Errors.Exceeds(vs.totalSupply + amount, vs.maxSupply);
        }
        
        // Increase total supply and account balance
        vs.totalSupply += amount;
        vs.balances[account] += amount;
        
        emit Events.Transfer(address(0), account, amount);
    }

    /**
     * @notice Internal method to burn vault tokens
     * @param vaultId ID of the vault
     * @param account Address to burn tokens from
     * @param amount Amount of tokens to burn
     */
    function _burn(uint32 vaultId, address account, uint256 amount) internal {
        if (account == address(0)) revert Errors.ZeroAddress();
        
        VaultStorage storage vs = S.protocol().vaults[vaultId];
        
        // Check if account has enough balance
        if (vs.balances[account] < amount) {
            revert Errors.Insufficient(vs.balances[account], amount);
        }
        
        // Decrease total supply and account balance
        vs.totalSupply -= amount;
        vs.balances[account] -= amount;
        
        emit Events.Transfer(account, address(0), amount);
    }
} 