// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {ALMVault, Range, WithdrawProceeds, ErrorType, DEX} from "@/BTRTypes.sol";
import {BTRErrors as Errors, BTREvents as Events} from "@libraries/BTREvents.sol";
import {BTRUtils} from "@libraries/BTRUtils.sol";
import {LibMaths as M} from "@libraries/LibMaths.sol";
import {LibDEXMaths} from "@libraries/LibDEXMaths.sol";
import {NonReentrantFacet} from "@facets/abstract/NonReentrantFacet.sol";
import {PausableFacet} from "@facets/abstract/PausableFacet.sol";
import {PermissionedFacet} from "@facets/abstract/PermissionedFacet.sol";

/**
 * @title DEXAdapterFacet
 * @notice Abstract contract defining interfaces and common functionality for DEX adapters
 * @dev This contract defines virtual methods and implements common functionality for V3-style DEXes
 */
abstract contract DEXAdapterFacet is PermissionedFacet, NonReentrantFacet, PausableFacet {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    using M for uint256;
    using BTRUtils for uint32;
    using BTRUtils for bytes32;
    using LibDEXMaths for int24;
    using LibDEXMaths for uint160;


    function _getRangeId(uint32 vaultId, bytes32 poolId, int24 tickLower, int24 tickUpper) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(address(this), vaultId, poolId, tickLower, tickUpper));
    }

    function getRangeId(bytes32 rangeId) public view returns (bytes32) {
        Range storage range = rangeId.getRange();
        return _getRangeId(range.vaultId, range.poolId, range.lowerTick, range.upperTick);
    }

    function _getPositionId(int24 tickLower, int24 tickUpper) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(address(this), tickLower, tickUpper)));
    }

    function getPositionId(bytes32 rangeId) public view returns (uint256) {
        Range storage range = rangeId.getRange();
        return _getPositionId(range.lowerTick, range.upperTick);
    }

    /**
     * @notice Helper function to get token pair from a pool
     * @param poolId The DEX pool ID
     * @return token0 Address of token0
     * @return token1 Address of token1
     */
    function _getPoolTokens(bytes32 poolId) internal view virtual returns (IERC20 token0, IERC20 token1);

    /**
     * @notice Public function to get token pair from a pool
     * @param poolId The DEX pool ID
     * @return token0 Address of token0
     * @return token1 Address of token1
     */
    function getPoolTokens(bytes32 poolId) external view returns (IERC20 token0, IERC20 token1) {
        return _getPoolTokens(poolId);
    }

    /**
     * @notice Helper function to validate pool token configuration against vault configuration
     * @param vaultId The vault ID
     * @param pool The DEX pool address
     */
    function _validatePoolTokens(uint32 vaultId, address pool) internal view {
        ALMVault storage vault = vaultId.getVault();
        (IERC20 token0, IERC20 token1) = _getPoolTokens(bytes32(uint256(uint160(pool))));

        // Ensure tokens match vault configuration
        if (token0 != vault.token0 || token1 != vault.token1) {
            revert Errors.Unauthorized(ErrorType.TOKEN);
        }
    }

    function _getPoolTickSpacing(bytes32 poolId) internal view virtual returns (int24);

    function _validateTickSpacing(Range memory range) internal view virtual returns (bool);

    function validateTickSpacing(Range memory range) public view returns (bool) {
        return _validateTickSpacing(range);
    }

    function _getPoolSqrtPriceAndTick(bytes32 poolId) internal view virtual returns (uint160 sqrtPriceX96, int24 tick);

    function _getPositionWithAmounts(bytes32 rangeId) internal view virtual returns (uint128 liquidity, uint256 amount0, uint256 amount1, uint128 fees0, uint128 fees1);

    /**
     * @notice Get position details for a specific vault
     * @param rangeId The range ID
     * @return liquidity The position's liquidity
     * @return amount0 Amount of token0 in the position
     * @return amount1 Amount of token1 in the position
     * @return fees0 Accumulated fees for token0
     * @return fees1 Accumulated fees for token1
     */
    function getPositionInfo(bytes32 rangeId) external view returns (uint128 liquidity, uint256 amount0, uint256 amount1, uint128 fees0, uint128 fees1) {
        return _getPositionWithAmounts(rangeId);
    }

    /**
     * @notice Common implementation for getAmountsForLiquidity for V3-style DEXes
     * @param rangeId The range ID
     * @param liquidity The liquidity amount to calculate for
     * @return amount0 Amount of token0 in the position
     * @return amount1 Amount of token1 in the position
     */
    function _getAmountsForLiquidity(
        bytes32 rangeId,
        uint256 liquidity
    ) internal view virtual returns (uint256 amount0, uint256 amount1);

    function _getAmountsForLiquidity(
        bytes32 rangeId
    ) internal view returns (uint256 amount0, uint256 amount1) {
        Range storage range = rangeId.getRange();
        return _getAmountsForLiquidity(rangeId, range.liquidity);
    }

    /**
     * @notice Calculate token amounts for a specified liquidity amount
     * @param rangeId The range ID
     * @param liquidity The liquidity amount to calculate for
     * @return amount0 Amount of token0 for the specified liquidity
     * @return amount1 Amount of token1 for the specified liquidity 
     */
    function getAmountsForLiquidity(
        bytes32 rangeId,
        uint128 liquidity
    ) external view returns (uint256 amount0, uint256 amount1) {
        return _getAmountsForLiquidity(rangeId, liquidity);
    }

    function _getLiquidityForAmounts(
        bytes32 rangeId,
        uint256 amount0Desired,
        uint256 amount1Desired
    ) internal view virtual returns (uint128 liquidity);

    /**
     * @notice Calculate liquidity ratio for token0 compared to total liquidity
     * @param rangeId The range ID
     * @return ratio0 The ratio of token0 to total liquidity (in basis points)
     */
    function getLiquidityRatio0(bytes32 rangeId) external view returns (uint256) {
        return _getLiquidityRatio0(rangeId);
    }
    
    /**
     * @notice Internal implementation to calculate liquidity ratio for token0
     * @param rangeId The range ID
     * @return ratio0 The ratio of token0 to total liquidity (in basis points)
     */
    function _getLiquidityRatio0(
        bytes32 rangeId
    ) internal view returns (uint256 ratio0) {
        (uint256 amount0, uint256 amount1) = _getAmountsForLiquidity(rangeId, M.PRECISION_BP_BASIS);
        return amount0.divDown(amount1 + amount0);
    }

    /**
     * @notice Pool-specific implementation for collecting tokens and fees
     * @dev Must be implemented by each adapter to handle pool-specific collect logic
     */
    function _collectRangeFees(
        bytes32 rangeId
    ) internal virtual returns (uint256 collected0, uint256 collected1);

    function collectRangeFees(
        bytes32 rangeId
    ) external virtual returns (uint256 collected0, uint256 collected1) {
        return _collectRangeFees(rangeId);
    }

    function _mintRange(
        bytes32 rangeId
    ) internal virtual returns (uint128 liquidity, uint256 amount0, uint256 amount1);

    function mintRange(
        bytes32 rangeId
    ) external virtual returns (uint256 amount0, uint256 amount1) {
        uint128 liquidity;
        (liquidity, amount0, amount1) = _mintRange(rangeId);
    }

    function _burnRange(
        bytes32 rangeId
    ) internal virtual returns (uint256 amount0, uint256 amount1, uint256 lpFees0, uint256 lpFees1);

    /**
     * @notice Withdraw liquidity from a position using rangeId
     * @param rangeId The range ID
     * @return amount0 Amount of token0 withdrawn
     * @return amount1 Amount of token1 withdrawn
     * @return lpFees0 Fees collected for token0
     * @return lpFees1 Fees collected for token1
     */
    function burnRange(
        bytes32 rangeId
    ) external virtual returns (uint256 amount0, uint256 amount1, uint256 lpFees0, uint256 lpFees1) {
        return _burnRange(rangeId);
    }
}
