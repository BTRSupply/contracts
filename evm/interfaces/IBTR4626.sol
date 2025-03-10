// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC4626} from "@openzeppelin/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

/**
 * @dev Extension of the ERC4626 standard for BTR's dual-asset vaults
 */
interface IBTR4626 is IERC4626 {
    /**
     * @dev Returns the addresses of both underlying tokens used for the Vault.
     */
    function assets() external view returns (address asset0, address asset1);

    /**
     * @dev Returns the total amounts of both underlying assets managed by this vault.
     */
    function totalAssetsDual() external view returns (uint256 totalAssets0, uint256 totalAssets1);

    /**
     * @dev Converts a specified amount of assets (both tokens) to vault shares.
     */
    function convertToSharesDual(uint256 assets0, uint256 assets1) external view returns (uint256 shares);

    /**
     * @dev Converts a specified amount of shares to amounts of both underlying assets.
     */
    function convertToAssetsDual(uint256 shares) external view returns (uint256 assets0, uint256 assets1);

    /**
     * @dev Returns the maximum amounts of both assets that can be deposited for the receiver.
     */
    function maxDepositDual(address receiver) external view returns (uint256 maxAssets0, uint256 maxAssets1);

    /**
     * @dev Returns the maximum amounts of both assets that can be withdrawn by the owner.
     */
    function maxWithdrawDual(address owner) external view returns (uint256 maxAssets0, uint256 maxAssets1);

    /**
     * @dev Previews the amount of shares that would be minted for the given amounts of assets.
     */
    function previewDepositDual(uint256 assets0, uint256 assets1) external view returns (uint256 shares);

    /**
     * @dev Previews the amounts of assets that would be withdrawn for the given amount of shares.
     */
    function previewRedeemDual(uint256 shares) external view returns (uint256 assets0, uint256 assets1);

    /**
     * @dev Deposits specified amounts of both assets and mints shares to the receiver.
     */
    function depositDual(uint256 assets0, uint256 assets1, address receiver) external returns (uint256 shares);

    /**
     * @dev Redeems the specified amount of shares and sends both assets to the receiver.
     */
    function redeemDual(uint256 shares, address receiver, address owner) 
        external returns (uint256 assets0, uint256 assets1);
} 