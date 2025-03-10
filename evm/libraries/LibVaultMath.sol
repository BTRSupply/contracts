// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {SafeCast} from "@openzeppelin/utils/math/SafeCast.sol";
import {BTRStorage as S} from "./BTRStorage.sol";
import {VaultStorage} from "../BTRTypes.sol";
import {BTRErrors as Errors, BTREvents as Events} from "./BTREvents.sol";
import {Maths} from "./Maths.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

/// @title LibVaultMath
/// @dev Combined math functions for the BTR Vault
library LibVaultMath {
  using SafeCast for uint256;
  using Maths for uint256;

  struct UnderlyingPayload {
    address[] pools;
    address[] tokenAddresses;
  }

  struct Withdraw {
    uint256 burn0;
    uint256 burn1;
  }

  /// @notice Calculate token amounts for an existing vault with liquidity
  /// @param payload Underlying payload with pools and token addresses
  /// @param mintAmount Amount of vault shares to mint
  /// @param totalSupply Current total supply of vault shares
  /// @return amount0 Amount of token0 needed
  /// @return amount1 Amount of token1 needed
  function calculateExistingMintAmounts(
    UnderlyingPayload memory payload,
    uint256 mintAmount,
    uint256 totalSupply
  ) public view returns (uint256 amount0, uint256 amount1) {
    // This implementation would use the payload to calculate amounts
    // For now, we'll use a basic proportional calculation
    if (totalSupply == 0) {
      return (0, 0); // Should never happen in "existing" case
    }
    
    uint256 totalAssets = calculateTotalAssets();
    uint256 totalToken1 = calculateTotalToken1();
    
    amount0 = (totalAssets * mintAmount) / totalSupply;
    amount1 = (totalToken1 * mintAmount) / totalSupply;
    
    return (amount0, amount1);
  }

  /// @notice Calculate token amounts for initial mint
  /// @param mintAmount Amount of vault shares to mint
  /// @param initialToken0 Initial token0 ratio
  /// @param initialToken1 Initial token1 ratio
  /// @return amount0 Amount of token0 needed
  /// @return amount1 Amount of token1 needed
  function calculateInitialMintAmounts(
    uint256 mintAmount,
    uint256 initialToken0,
    uint256 initialToken1
  ) public pure returns (uint256 amount0, uint256 amount1) {
    uint256 denominator = 1 ether;

    // Use unchecked for overflow-safe math operations
    unchecked {
      amount0 = Maths.mulDivUp(
        mintAmount,
        initialToken0,
        denominator
      );
      amount1 = Maths.mulDivUp(
        mintAmount,
        initialToken1,
        denominator
      );
    }

    // Check ratio against small values that skew init ratio
    if (Maths.mulDiv(mintAmount, initialToken0, denominator) == 0) {
      amount0 = 0;
    }
    if (Maths.mulDiv(mintAmount, initialToken1, denominator) == 0) {
      amount1 = 0;
    }

    uint256 amount0Mint = initialToken0 != 0
      ? Maths.mulDiv(amount0, denominator, initialToken0)
      : type(uint256).max;
    uint256 amount1Mint = initialToken1 != 0
      ? Maths.mulDiv(amount1, denominator, initialToken1)
      : type(uint256).max;

    if ((amount0Mint < amount1Mint ? amount0Mint : amount1Mint) != mintAmount) {
      revert Errors.InvalidParameter();
    }
    
    return (amount0, amount1);
  }

  /// @notice Calculate token amounts to withdraw
  /// @param burnAmount Amount of vault shares to burn
  /// @param totalSupply Current total supply of vault shares
  /// @param total Aggregated withdrawal information
  /// @param balance0 Current token0 balance
  /// @param balance1 Current token1 balance
  /// @param managerBalance0 Manager's token0 balance
  /// @param managerBalance1 Manager's token1 balance
  /// @return amount0 Amount of token0 to withdraw
  /// @return amount1 Amount of token1 to withdraw
  function calculateWithdrawAmounts(
    uint256 burnAmount, 
    uint256 totalSupply, 
    Withdraw memory total,
    uint256 balance0,
    uint256 balance1,
    uint256 managerBalance0,
    uint256 managerBalance1
  ) public pure returns (uint256 amount0, uint256 amount1) {
    uint256 leftOver0 = balance0 - managerBalance0 - total.burn0;
    uint256 leftOver1 = balance1 - managerBalance1 - total.burn1;

    // Use unchecked for arithmetic where overflow isn't possible
    unchecked {
      amount0 = Maths.mulDiv(leftOver0, burnAmount, totalSupply) + total.burn0;
      amount1 = Maths.mulDiv(leftOver1, burnAmount, totalSupply) + total.burn1;
    }
    
    return (amount0, amount1);
  }

  /// @notice Convert assets to shares
  /// @param assets Amount of assets to convert
  /// @param rounding Rounding direction
  /// @return Amount of shares
  function convertToShares(uint256 assets, Maths.Rounding rounding) internal view returns (uint256) {
    return _convertToShares(assets, rounding);
  }

  /// @notice Convert shares to assets
  /// @param shares Amount of shares to convert
  /// @param rounding Rounding direction
  /// @return Amount of assets
  function convertToAssets(uint256 shares, Maths.Rounding rounding) internal view returns (uint256) {
    return _convertToAssets(shares, rounding);
  }

  /// @notice Internal conversion from assets to shares with rounding control
  /// @param assets Asset amount to convert
  /// @param rounding Rounding direction
  /// @return Share amount
  function _convertToShares(uint256 assets, Maths.Rounding rounding) internal view returns (uint256) {
    VaultStorage storage vs = S.vault();
    
    uint256 totalSupply = vs.totalSupply;
    
    // If vault is empty, use 1:1 ratio (first deposit)
    if (totalSupply == 0) {
      return assets;
    }
    
    uint256 totalAssets = calculateTotalAssets();
    
    if (rounding == Maths.Rounding.DOWN) {
      return Maths.mulDiv(assets, totalSupply, totalAssets);
    } else {
      return Maths.mulDivUp(assets, totalSupply, totalAssets);
    }
  }

  /// @notice Internal conversion from shares to assets with rounding control
  /// @param shares Share amount to convert
  /// @param rounding Rounding direction
  /// @return Asset amount
  function _convertToAssets(uint256 shares, Maths.Rounding rounding) internal view returns (uint256) {
    VaultStorage storage vs = S.vault();
    
    uint256 totalSupply = vs.totalSupply;
    
    // If vault is empty, use 1:1 ratio
    if (totalSupply == 0) {
      return shares;
    }
    
    uint256 totalAssets = calculateTotalAssets();
    
    if (rounding == Maths.Rounding.DOWN) {
      return Maths.mulDiv(shares, totalAssets, totalSupply);
    } else {
      return Maths.mulDivUp(shares, totalAssets, totalSupply);
    }
  }

  /// @notice Calculate total assets in the vault
  /// @return Total assets
  function calculateTotalAssets() internal view returns (uint256) {
    VaultStorage storage vs = S.vault();
    
    // This would include:
    // 1. Assets held directly in the vault
    // 2. Assets in Uniswap positions
    // For this implementation, we'll just return assets held directly
    return vs.asset.balanceOf(address(this));
  }

  /// @notice Calculate total token1 in the vault
  /// @return Total token1
  function calculateTotalToken1() internal view returns (uint256) {
    VaultStorage storage vs = S.vault();
    
    // This would include:
    // 1. Token1 held directly in the vault
    // 2. Token1 in Uniswap positions
    // For this implementation, we'll just return token1 held directly
    return vs.tokens[1].balanceOf(address(this));
  }

  /// @notice Calculate both token balances
  /// @return token0 Total balance of token0
  /// @return token1 Total balance of token1
  function calculateTotalBalances() internal view returns (uint256 token0, uint256 token1) {
    VaultStorage storage vs = S.vault();
    
    token0 = vs.tokens[0].balanceOf(address(this));
    token1 = vs.tokens[1].balanceOf(address(this));
    
    // For more complex vaults, would add position values for both tokens
  }
}
  