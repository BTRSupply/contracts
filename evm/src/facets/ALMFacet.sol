// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ALMVault, Range, Rebalance, VaultInitParams, DEX, ErrorType, VaultInfo} from "@/BTRTypes.sol";
import {BTRStorage as S} from "@libraries/BTRStorage.sol";
import {BTRErrors as Errors, BTREvents as Events} from "@libraries/BTREvents.sol";
import {ERC1155Facet} from "@facets/ERC1155VaultsFacet.sol";
import {LibALM as ALM} from "@libraries/LibALM.sol";
import {LibAccessControl} from "@libraries/LibAccessControl.sol";
import {BTRUtils} from "@libraries/BTRUtils.sol";

contract ALMFacet is ERC1155Facet {
    using BTRUtils for uint32;
    using BTRUtils for bytes32;

    // Only keep this custom modifier that isn't defined in parent classes
    modifier vaultExists(uint32 vaultId) {
        if (vaultId >= S.registry().vaultCount) revert Errors.NotFound(ErrorType.VAULT);
        _;
    }

    function createVault(
        VaultInitParams calldata params
    ) external onlyManager returns (uint32 vaultId) {
        return ALM.createVault(params);
    }

    function getDexAdapter(DEX dex) external view returns (address) {
        return ALM.getDexAdapter(dex);
    }

    function getDexAdapter(bytes32 poolId) external view returns (address) {
        return ALM.getDexAdapter(poolId);
    }

    function deposit(
        uint32 vaultId,
        uint256 mintAmount,
        address receiver
    ) external whenVaultNotPaused(vaultId) nonReentrant returns (uint256 amount0, uint256 amount1) {
        return ALM.deposit(vaultId, mintAmount, receiver);
    }

    function withdraw(
        uint32 vaultId,
        uint256 burnAmount,
        address receiver
    ) external whenVaultNotPaused(vaultId) nonReentrant returns (uint256 amount0, uint256 amount1) {
        return ALM.withdraw(vaultId, burnAmount, receiver);
    }

    /**
     * @notice Rebalance a vault by burning ranges, swapping tokens, and adding new ranges
     * @dev This function processes burns, swaps and mints in sequence
     * @param vaultId The vault ID to rebalance
     * @param rebalance The rebalance data containing burns, swaps and mints
     * @return protocolFees0 The amount of protocol fees collected (token0)
     * @return protocolFees1 The amount of protocol fees collected (token1)
     */
    function rebalance(
        uint32 vaultId,
        Rebalance calldata rebalance
    ) external whenVaultNotPaused(vaultId) onlyKeeper nonReentrant returns (uint256 protocolFees0, uint256 protocolFees1) {
        return ALM.rebalance(vaultId, rebalance);
    }

    function getVaultTotalBalances(uint32 vaultId) external view vaultExists(vaultId) returns (uint256 balance0, uint256 balance1) {
        return ALM.getVaultTotalBalances(vaultId);
    }

    /**
     * @notice Get information about a vault
     * @param vaultId The ID of the vault to get information for
     * @return The vault information
     */
    function getVaultInfo(uint32 vaultId) external view vaultExists(vaultId) returns (VaultInfo memory) {
        return ALM.getVaultInfo(vaultId);
    }

    function collectFees(uint32 vaultId) external onlyTreasury nonReentrant returns (uint256 amount0, uint256 amount1) {
        return ALM.collectFees(vaultId);
    }

    /**
     * @notice Preview the token amounts required for minting a specific amount of shares
     * @param vaultId The vault ID
     * @param mintAmount The amount of shares to mint
     * @return amount0 The amount of token0 required
     * @return amount1 The amount of token1 required
     * @return fee0 The amount of token0 that will be taken as fee
     * @return fee1 The amount of token1 that will be taken as fee
     */
    function previewDeposit(
        uint32 vaultId, 
        uint256 mintAmount
    ) external view vaultExists(vaultId) returns (uint256 amount0, uint256 amount1, uint256 fee0, uint256 fee1) {
        return ALM.previewDeposit(vaultId, mintAmount);
    }
    
    /**
     * @notice Preview how much token1 is needed when depositing a specific amount of token0
     * @param vaultId The vault ID
     * @param amount0 The amount of token0 to deposit
     * @return amount1 The amount of token1 needed
     */
    function previewDeposit1For0(
        uint32 vaultId,
        uint256 amount0
    ) external view vaultExists(vaultId) returns (uint256 amount1) {
        return ALM.previewDeposit1For0(vaultId, amount0);
    }
    
    /**
     * @notice Preview how much token0 is needed when depositing a specific amount of token1
     * @param vaultId The vault ID
     * @param amount1 The amount of token1 to deposit
     * @return amount0 The amount of token0 needed
     */
    function previewDeposit0For1(
        uint32 vaultId,
        uint256 amount1
    ) external view vaultExists(vaultId) returns (uint256 amount0) {
        return ALM.previewDeposit0For1(vaultId, amount1);
    }
    
    /**
     * @notice Preview the token amounts to be received for burning a specific amount of shares
     * @param vaultId The vault ID
     * @param burnAmount The amount of shares to burn
     * @return amount0 The amount of token0 to be received
     * @return amount1 The amount of token1 to be received
     * @return fee0 The fee amount for token0
     * @return fee1 The fee amount for token1
     */
    function previewWithdraw(
        uint32 vaultId,
        uint256 burnAmount
    ) external view vaultExists(vaultId) returns (uint256 amount0, uint256 amount1, uint256 fee0, uint256 fee1) {
        return ALM.previewWithdraw(vaultId, burnAmount);
    }
    
    /**
     * @notice Preview how much token1 would be withdrawn for a given amount of token0
     * @param vaultId The vault ID
     * @param amount0 The amount of token0 to withdraw
     * @return amount1 The amount of token1 to be received
     * @return shareAmount The amount of shares that would be burned
     * @return fee0 The fee amount for token0
     * @return fee1 The fee amount for token1
     */
    function previewWithdraw0For1(
        uint32 vaultId,
        uint256 amount0
    ) external view vaultExists(vaultId) returns (uint256 amount1, uint256 shareAmount, uint256 fee0, uint256 fee1) {
        return ALM.previewWithdraw0For1(vaultId, amount0);
    }
    
    /**
     * @notice Preview how much token0 would be withdrawn for a given amount of token1
     * @param vaultId The vault ID
     * @param amount1 The amount of token1 to withdraw
     * @return amount0 The amount of token0 to be received
     * @return shareAmount The amount of shares that would be burned
     * @return fee0 The fee amount for token0
     * @return fee1 The fee amount for token1
     */
    function previewWithdraw1For0(
        uint32 vaultId,
        uint256 amount1
    ) external view vaultExists(vaultId) returns (uint256 amount0, uint256 shareAmount, uint256 fee0, uint256 fee1) {
        return ALM.previewWithdraw1For0(vaultId, amount1);
    }
    
    /**
     * @notice Get the total token values in the vault (sum of all positions and free tokens)
     * @param vaultId The vault ID
     * @return total0 The total amount of token0
     * @return total1 The total amount of token1
     */
    function getTotalTokenValue(
        uint32 vaultId
    ) external view vaultExists(vaultId) returns (uint256 total0, uint256 total1) {
        return ALM.getVaultTotalBalances(vaultId);
    }
}
