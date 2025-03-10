// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import {VaultStorage} from "../../BTRTypes.sol";
import {BTRStorage as S} from "../../libraries/BTRStorage.sol";
import {BTRErrors as Errors, BTREvents as Events} from "../../libraries/BTREvents.sol";

/// @title ERC20 Facet
/// @dev Implements ERC20 functionality for the BTR Diamond
abstract contract ERC20Facet is IERC20, IERC20Metadata {
    /// @notice Returns the name of the token
    function name() external view override returns (string memory) {
        return S.vault().name;
    }

    /// @notice Returns the symbol of the token
    function symbol() external view override returns (string memory) {
        return S.vault().symbol;
    }

    /// @notice Returns the decimals places of the token
    function decimals() external view override returns (uint8) {
        return S.vault().decimals;
    }
    
    /// @notice Returns the amount of tokens in existence
    function totalSupply() external view override returns (uint256) {
        return S.vault().totalSupply;
    }
    
    /// @notice Returns the amount of tokens owned by `account`
    function balanceOf(address account) external view override returns (uint256) {
        return S.vault().balances[account];
    }
    
    /// @notice Moves `amount` tokens from the caller's account to `to`
    function transfer(address to, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }
    
    /// @notice Returns the remaining number of tokens that `spender` will be allowed to spend on behalf of `owner`
    function allowance(address owner, address spender) external view override returns (uint256) {
        return S.vault().allowances[owner][spender];
    }
    
    /// @notice Sets `amount` as the allowance of `spender` over the caller's tokens
    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }
    
    /// @notice Moves `amount` tokens from `from` to `to` using the allowance mechanism
    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    // Make internal functions public to allow other facets to call them
    function _transfer(address from, address to, uint256 amount) internal virtual {
        if (from == address(0)) revert Errors.ZeroAddress();
        if (to == address(0)) revert Errors.ZeroAddress();

        _update(from, to, amount);
    }

    // Add centralized update function similar to OZ implementation
    function _update(address from, address to, uint256 amount) internal virtual {
        VaultStorage storage vs = S.vault();
        
        if (from == address(0)) {
            // Mint case
            vs.totalSupply += amount;
        } else {
            // Transfer case
            uint256 fromBalance = vs.balances[from];
            if (fromBalance < amount) revert Errors.TransferExceedsBalance();
            
            unchecked {
                vs.balances[from] = fromBalance - amount;
            }
        }

        if (to == address(0)) {
            // Burn case
            vs.totalSupply -= amount;
        } else {
            vs.balances[to] += amount;
        }

        emit Events.Transfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        if (account == address(0)) revert Errors.ZeroAddress();
        _update(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        if (account == address(0)) revert Errors.ZeroAddress();
        _update(account, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        _approve(owner, spender, amount, true);
    }

    function _approve(address owner, address spender, uint256 amount, bool emitEvent) internal virtual {
        if (owner == address(0)) revert Errors.ZeroAddress();
        if (spender == address(0)) revert Errors.ZeroAddress();

        VaultStorage storage vs = S.vault();
        vs.allowances[owner][spender] = amount;
        
        if (emitEvent) {
            emit Events.Approval(owner, spender, amount);
        }
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = S.vault().allowances[owner][spender];
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < amount) revert Errors.InsufficientAllowance();
            unchecked {
                _approve(owner, spender, currentAllowance - amount, false);
            }
        }
    }
} 