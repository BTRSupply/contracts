// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {BTRStorage as S} from "../libraries/BTRStorage.sol";
import {VaultStorage} from "../BTRTypes.sol";
import {LibVaultMath} from "../libraries/LibVaultMath.sol";
import {Maths} from "../libraries/Maths.sol";
import {BTRErrors as Errors, BTREvents as Events} from "../libraries/BTREvents.sol";
import {ERC4626Facet as AbstractERC4626Facet} from "./abstract/ERC4626Facet.sol";

/// @dev ERC4626 vault implementation inheriting from abstract ERC4626Facet
contract ERC4626Facet is AbstractERC4626Facet {
    using SafeERC20 for IERC20;
    
    function deposit(uint256 assets, address receiver) external override whenNotPaused nonReentrant returns (uint256) {
        // Check max deposit limit
        uint256 maxAssets = this.maxDeposit(receiver);
        if (assets > maxAssets) {
            revert Errors.Exceeds(assets, maxAssets);
        }

        // Calculate shares to mint
        uint256 shares = convertToShares(assets);
        
        VaultStorage storage vs = S.vault();

        // Handle deposit of second token if vault has been initialized
        if (vs.totalSupply > 0) {
            // Calculate required amount of token1 based on proportional deposit
            uint256 token1Amount = (LibVaultMath.calculateTotalToken1() * assets) / totalAssets();
            
            // Transfer token1 from user
            IERC20(address(vs.tokens[1])).safeTransferFrom(msg.sender, address(this), token1Amount);
        } else {
            // First deposit uses initial amounts
            if (assets != vs.initialTokenAmounts[0]) revert Errors.InvalidParameter();
            
            // Transfer token1 using initial amount
            IERC20(address(vs.tokens[1])).safeTransferFrom(msg.sender, address(this), vs.initialTokenAmounts[1]);
        }
        
        // Transfer assets from caller to vault
        IERC20(asset()).safeTransferFrom(msg.sender, address(this), assets);
        
        // Mint shares to receiver using ERC20Facet functionality
        _mint(receiver, shares);

        emit Events.Deposit(msg.sender, receiver, assets, shares);
        return shares;
    }
    
    function mint(uint256 shares, address receiver) external override whenNotPaused nonReentrant returns (uint256) {
        // Check max mint limit
        uint256 maxShares = this.maxMint(receiver);
        if (shares > maxShares) {
            revert Errors.Exceeds(shares, maxShares);
        }

        // Calculate assets needed
        uint256 assets = LibVaultMath.convertToAssets(shares, Maths.Rounding.UP);
        
        VaultStorage storage vs = S.vault();
        
        // Handle deposit of second token if vault has been initialized
        if (vs.totalSupply > 0) {
            // Calculate required amount of token1 based on proportional deposit
            uint256 token1Amount = (LibVaultMath.calculateTotalToken1() * assets) / totalAssets();
            
            // Transfer token1 from user
            IERC20(address(vs.tokens[1])).safeTransferFrom(msg.sender, address(this), token1Amount);
        } else {
            // First deposit uses initial amounts with converted shares
            uint256 expectedAssets = vs.initialTokenAmounts[0];
            if (assets != expectedAssets) revert Errors.InvalidParameter();
            
            // Transfer token1 using initial amount
            IERC20(address(vs.tokens[1])).safeTransferFrom(msg.sender, address(this), vs.initialTokenAmounts[1]);
        }
        
        // Transfer assets from caller to vault
        IERC20(asset()).safeTransferFrom(msg.sender, address(this), assets);
        
        // Mint shares to receiver using ERC20Facet functionality
        _mint(receiver, shares);

        emit Events.Deposit(msg.sender, receiver, assets, shares);
        return assets;
    }
    
    function withdraw(uint256 assets, address receiver, address owner) external override whenNotPaused nonReentrant returns (uint256) {
        // Check max withdraw limit
        uint256 maxAssets = this.maxWithdraw(owner);
        if (assets > maxAssets) {
            revert Errors.Exceeds(assets, maxAssets);
        }

        // Calculate shares to burn
        uint256 shares = LibVaultMath.convertToShares(assets, Maths.Rounding.UP);
        
        // Handle allowances if caller is not owner
        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }
        
        VaultStorage storage vs = S.vault();
        
        // Calculate token1 amount proportionally
        uint256 token1Amount = (LibVaultMath.calculateTotalToken1() * assets) / totalAssets();
        
        // Burn shares from owner using ERC20Facet functionality
        _burn(owner, shares);
        
        // Transfer assets from vault to receiver
        IERC20(asset()).safeTransfer(receiver, assets);
        
        // Transfer token1 from vault to receiver
        IERC20(address(vs.tokens[1])).safeTransfer(receiver, token1Amount);

        emit Events.Withdraw(msg.sender, receiver, owner, assets, shares);
        return shares;
    }

    function redeem(uint256 shares, address receiver, address owner) external override whenNotPaused nonReentrant returns (uint256) {
        // Check max redeem limit
        uint256 maxShares = this.maxRedeem(owner);
        if (shares > maxShares) {
            revert Errors.Exceeds(shares, maxShares);
        }

        // Calculate assets to withdraw
        uint256 assets = LibVaultMath.convertToAssets(shares, Maths.Rounding.DOWN);
        
        // Handle allowances if caller is not owner
        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }
        
        VaultStorage storage vs = S.vault();
        
        // Calculate token1 amount proportionally
        uint256 token1Amount = (LibVaultMath.calculateTotalToken1() * assets) / totalAssets();
        
        // Burn shares from owner using ERC20Facet functionality
        _burn(owner, shares);
        
        // Transfer assets from vault to receiver
        IERC20(asset()).safeTransfer(receiver, assets);
        
        // Transfer token1 from vault to receiver
        IERC20(address(vs.tokens[1])).safeTransfer(receiver, token1Amount);

        emit Events.Withdraw(msg.sender, receiver, owner, assets, shares);
        return assets;
    }

    function _depositFirstTime(uint256 assets, address receiver) internal returns (uint256) {
        VaultStorage storage vs = S.vault();
        
        // For the first deposit, we need exact amounts to establish the initial rate
        if (assets != vs.initialTokenAmounts[0]) revert Errors.InvalidParameter();
        
        // Mint initial shares to the first depositor
        _mint(receiver, vs.initialShareAmount);
        
        _after_deposit(assets, vs.initialShareAmount, receiver);
        
        return vs.initialShareAmount;
    }

    function _validateFirstDeposit(uint256 assets, uint256 _shares) internal view {
        VaultStorage storage vs = S.vault();
        uint256 expectedAssets = vs.initialTokenAmounts[0];
        if (assets != expectedAssets) revert Errors.InvalidParameter();
    }
}
