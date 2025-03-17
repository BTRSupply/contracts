// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ALMVault, Range, Rebalance, VaultInitParams, DEX, ErrorType, FeeType} from "@/BTRTypes.sol";
import {BTRStorage as S} from "@libraries/BTRStorage.sol";
import {BTRErrors as Errors, BTREvents as Events} from "@libraries/BTREvents.sol";
import {ERC1155Facet} from "@facets/ERC1155VaultsFacet.sol";
import {LibALM as ALM} from "@libraries/LibALM.sol";
import {LibAccessControl} from "@libraries/LibAccessControl.sol";
import {BTRUtils} from "@libraries/BTRUtils.sol";
import {DEXAdapterFacet} from "@facets/abstract/V3AdapterFacet.sol";

// NB: vault existence is handled in the .getVault() function in all ALM functions
// noo need for a ifVaultExists modifier
contract ALMFacet is ERC1155Facet {
    using BTRUtils for uint32;
    using BTRUtils for bytes32;

    function createVault(
        VaultInitParams calldata params
    ) external onlyManager returns (uint32 vaultId) {
        return ALM.createVault(params);
    }

    function updateDexAdapter(DEX dex, address adapter) external onlyAdmin {
        ALM.updateDexAdapter(dex, adapter);
    }

    function getDexAdapter(DEX dex) external view returns (address) {
        return ALM.getDexAdapter(dex);
    }

    function getPoolDexAdapter(bytes32 poolId) external view returns (address) {
        return ALM.getPoolDexAdapter(poolId);
    }

    function getRangeDexAdapter(bytes32 rangeId) external view returns (address) {
        return ALM.getRangeDexAdapter(rangeId);
    }

    function deposit(
        uint32 vaultId,
        uint256 sharesMinted,
        address receiver
    ) external whenVaultNotPaused(vaultId) nonReentrant returns (uint256 amount0, uint256 amount1, uint256 fee0, uint256 fee1) {
        return ALM.deposit(vaultId, sharesMinted, receiver);
    }

    function withdraw(
        uint32 vaultId,
        uint256 sharesBurnt,
        address receiver
    ) external whenVaultNotPaused(vaultId) nonReentrant returns (uint256 amount0, uint256 amount1, uint256 fee0, uint256 fee1) {
        return ALM.withdraw(vaultId, sharesBurnt, receiver);
    }

    /**
     * @notice Rebalance a vault by burning ranges, swapping tokens, and adding new ranges
     * @dev This function processes burns, swaps and mints in sequence
     * @param vaultId The vault ID to rebalance
     * @param rebalanceData The rebalance data containing burns, swaps and mints
     * @return protocolFees0 The amount of protocol fees collected (token0)
     * @return protocolFees1 The amount of protocol fees collected (token1)
     */
    function rebalance(
        uint32 vaultId,
        Rebalance calldata rebalanceData
    ) external whenVaultNotPaused(vaultId) onlyKeeper nonReentrant returns (uint256 protocolFees0, uint256 protocolFees1) {
        return ALM.rebalance(vaultId, rebalanceData);
    }

    function getTotalBalances(uint32 vaultId) external returns (uint256 balance0, uint256 balance1) {
        return ALM.getTotalBalances(vaultId);
    }

    function getWeights(uint32 vaultId) external view returns (uint256[] memory weights0) {
        return ALM.getWeights(vaultId);
    }

    function getRatios0(uint32 vaultId) external returns (uint256[] memory ratios0) {
        return ALM.getRatios0(vaultId);
    }

    function targetRatio0(uint32 vaultId) external returns (uint256 targetPBp0) {
        return ALM.targetRatio0(vaultId);
    }

    function targetRatio1(uint32 vaultId) external returns (uint256 targetPBp1) {
        return ALM.targetRatio1(vaultId);
    }

    function collectFees(uint32 vaultId) external onlyTreasury nonReentrant returns (uint256 amount0, uint256 amount1) {
        return ALM.collectFees(vaultId);
    }

    /**
     * @notice Preview the token amounts required for minting a specific amount of shares
     * @param vaultId The vault ID
     * @param sharesMinted The amount of shares to mint
     * @return amount0 The amount of token0 required
     * @return amount1 The amount of token1 required
     * @return fee0 The amount of token0 that will be taken as fee
     * @return fee1 The amount of token1 that will be taken as fee
     */
    function previewDeposit(
        uint32 vaultId, 
        uint256 sharesMinted
    ) external returns (uint256 amount0, uint256 amount1, uint256 fee0, uint256 fee1) {
        return ALM.previewDeposit(vaultId, sharesMinted);
    }

    /**
     * @notice Preview the share amount for given token amounts
     * @param vaultId The vault ID
     * @param amount0 The amount of token0
     * @param amount1 The amount of token1
     * @return sharesAmount The equivalent share amount
     * @return fee0 The fee amount for token0
     * @return fee1 The fee amount for token1
     */
    function previewDeposit(
        uint32 vaultId,
        uint256 amount0,
        uint256 amount1
    ) external returns (uint256 sharesAmount, uint256 fee0, uint256 fee1) {
        return ALM.previewDeposit(vaultId, amount0, amount1);
    }

    /**
     * @notice Preview how much token0 is needed when depositing a specific amount of token1
     * @param vaultId The vault ID
     * @param amount1 The amount of token1 to deposit
     * @return amount0 The amount of token0 needed
     * @return mintShares The amount of shares that would be minted
     * @return fee0 The fee amount for token0
     * @return fee1 The fee amount for token1
     */
    function previewDeposit0For1(
        uint32 vaultId,
        uint256 amount1
    ) external returns (uint256 amount0, uint256 mintShares, uint256 fee0, uint256 fee1) {
        return ALM.previewDeposit0For1(vaultId, amount1);
    }

    /**
     * @notice Preview how much token1 is needed when depositing a specific amount of token0
     * @param vaultId The vault ID
     * @param amount0 The amount of token0 to deposit
     * @return amount1 The amount of token1 needed
     * @return mintShares The amount of shares that would be minted
     * @return fee0 The fee amount for token0
     * @return fee1 The fee amount for token1
     */
    function previewDeposit1For0(
        uint32 vaultId,
        uint256 amount0
    ) external returns (uint256 amount1, uint256 mintShares, uint256 fee0, uint256 fee1) {
        return ALM.previewDeposit1For0(vaultId, amount0);
    }

    /**
     * @notice Preview the token amounts to be received for burning a specific amount of shares
     * @param vaultId The vault ID
     * @param sharesBurnt The amount of shares to burn
     * @return amount0 The amount of token0 to be received
     * @return amount1 The amount of token1 to be received
     * @return fee0 The fee amount for token0
     * @return fee1 The fee amount for token1
     */
    function previewWithdraw(
        uint32 vaultId,
        uint256 sharesBurnt
    ) external returns (uint256 amount0, uint256 amount1, uint256 fee0, uint256 fee1) {
        return ALM.previewWithdraw(vaultId, sharesBurnt);
    }

    function previewWithdraw(
        uint32 vaultId,
        uint256 amount0,
        uint256 amount1
    ) external returns (uint256 sharesAmount, uint256 fee0, uint256 fee1) {
        return ALM.previewWithdraw(vaultId, amount0, amount1);
    }

    /**
     * @notice Preview how much token0 would be withdrawn for a given amount of token1
     * @param vaultId The vault ID
     * @param amount1 The amount of token1 to withdraw
     * @return amount0 The amount of token0 to be received
     * @return sharesBurnt The amount of shares that would be burned
     * @return fee0 The fee amount for token0
     * @return fee1 The fee amount for token1
     */
    function previewWithdraw0For1(
        uint32 vaultId,
        uint256 amount1
    ) external returns (uint256 amount0, uint256 sharesBurnt, uint256 fee0, uint256 fee1) {
        return ALM.previewWithdraw0For1(vaultId, amount1);
    }

    /**
     * @notice Preview how much token1 would be withdrawn for a given amount of token0
     * @param vaultId The vault ID
     * @param amount0 The amount of token0 to withdraw
     * @return amount1 The amount of token1 to be received
     * @return sharesBurnt The amount of shares that would be burned
     * @return fee0 The fee amount for token0
     * @return fee1 The fee amount for token1
     */
    function previewWithdraw1For0(
        uint32 vaultId,
        uint256 amount0
    ) external returns (uint256 amount1, uint256 sharesBurnt, uint256 fee0, uint256 fee1) {
        return ALM.previewWithdraw1For0(vaultId, amount0);
    }

    /**
     * @notice Deposit tokens by specifying token amounts rather than share amount
     * @param vaultId The vault ID to deposit into
     * @param amount0 The amount of token0 to deposit
     * @param amount1 The amount of token1 to deposit
     * @param receiver The address to receive the minted shares
     * @return mintedShares The amount of shares minted
     * @return fee0 The amount of token0 taken as fee
     * @return fee1 The amount of token1 taken as fee
     */
    function deposit(
        uint32 vaultId,
        uint256 amount0, 
        uint256 amount1,
        address receiver
    ) external whenVaultNotPaused(vaultId) nonReentrant returns (uint256 mintedShares, uint256 fee0, uint256 fee1) {
        return ALM.deposit(vaultId, amount0, amount1, receiver);
    }

    /**
     * @notice Withdraw tokens by specifying token amounts rather than share amount
     * @param vaultId The vault ID to withdraw from
     * @param amount0 The amount of token0 to withdraw
     * @param amount1 The amount of token1 to withdraw
     * @param receiver The address to receive the withdrawn tokens
     * @return sharesBurnt The amount of shares burnt
     * @return fee0 The amount of token0 taken as fee
     * @return fee1 The amount of token1 taken as fee
     */
    function withdraw(
        uint32 vaultId,
        uint256 amount0,
        uint256 amount1,
        address receiver
    ) external whenVaultNotPaused(vaultId) nonReentrant returns (uint256 sharesBurnt, uint256 fee0, uint256 fee1) {
        return ALM.withdraw(vaultId, amount0, amount1, receiver);
    }
}
