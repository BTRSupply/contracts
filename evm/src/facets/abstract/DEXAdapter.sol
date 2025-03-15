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
 * @title DEXAdapter
 * @notice Abstract contract defining interfaces and common functionality for DEX adapters
 * @dev This contract defines virtual methods and implements common functionality for V3-style DEXes
 */
abstract contract DEXAdapter is PermissionedFacet, NonReentrantFacet, PausableFacet {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    using M for uint256;
    using BTRUtils for uint32;
    using BTRUtils for bytes32;
    using LibDEXMaths for int24;
    using LibDEXMaths for uint160;

    /**
     * @notice Helper function to get token pair from a pool
     * @param pool The DEX pool address
     * @return token0 Address of token0
     * @return token1 Address of token1
     */
    function _getPoolTokens(address pool) internal view virtual returns (address token0, address token1);

    /**
     * @notice Public function to get token pair from a pool
     * @param pool The DEX pool address
     * @return token0 Address of token0
     * @return token1 Address of token1
     */
    function getPoolTokens(address pool) external view returns (address token0, address token1) {
        return _getPoolTokens(pool);
    }

    /**
     * @notice Helper function to validate pool token configuration against vault configuration
     * @param vaultId The vault ID
     * @param pool The DEX pool address
     */
    function _validatePoolTokens(uint32 vaultId, address pool) internal view {
        ALMVault storage vault = vaultId.getVault();
        (address token0, address token1) = _getPoolTokens(pool);

        // Ensure tokens match vault configuration
        if (token0 != vault.token0 || token1 != vault.token1) {
            revert Errors.Unauthorized(ErrorType.TOKEN);
        }
    }

    /**
     * @notice Get the tick spacing for a pool
     * @param pool The DEX pool address
     * @return The tick spacing for the pool
     */
    function _getPoolTickSpacing(address pool) internal view virtual returns (int24);

    /**
     * @notice Get the current sqrt price and tick from a pool
     * @param pool The DEX pool address
     * @return sqrtPriceX96 The current sqrt price
     * @return tick The current tick
     */
    function _getPoolSqrtPriceAndTick(address pool) internal view virtual returns (uint160 sqrtPriceX96, int24 tick);

    /**
     * @notice Get position details for a specific position
     * @param pool The pool address
     * @param positionId The position ID
     * @param tickLower The lower tick of the position
     * @param tickUpper The upper tick of the position
     * @return liquidity The position's liquidity
     * @return amount0 Amount of token0 in the position
     * @return amount1 Amount of token1 in the position
     * @return fees0 Accumulated fees for token0
     * @return fees1 Accumulated fees for token1
     */
    function _getPositionInfo(
        address pool, 
        bytes32 positionId, 
        int24 tickLower, 
        int24 tickUpper
    ) internal view virtual returns (
        uint128 liquidity, 
        uint256 amount0, 
        uint256 amount1, 
        uint128 fees0, 
        uint128 fees1
    );

    /**
     * @notice Get position details for a specific range ID
     * @param rangeId The range ID
     * @return liquidity The position's liquidity
     * @return amount0 Amount of token0 in the position
     * @return amount1 Amount of token1 in the position
     * @return fees0 Accumulated fees for token0
     * @return fees1 Accumulated fees for token1
     */
    function _getPositionInfo(
        bytes32 rangeId
    ) internal view virtual returns (
        uint128 liquidity, 
        uint256 amount0, 
        uint256 amount1, 
        uint128 fees0, 
        uint128 fees1
    ) {
        Range storage range = rangeId.getRange();
        address pool = range.poolId.toAddress();
        // Convert uint256 positionId to bytes32 for the underlying implementation
        bytes32 positionIdBytes = bytes32(range.positionId);
        int24 tickLower = range.lowerTick;
        int24 tickUpper = range.upperTick;
        
        // Call the overloaded function from child implementation
        return _getPositionInfoHelper(pool, positionIdBytes, tickLower, tickUpper);
    }
    
    /**
     * @notice Helper method to call child implementation of position info
     * @dev Avoids overloaded function lookup issues
     */
    function _getPositionInfoHelper(
        address pool,
        bytes32 positionId,
        int24 tickLower,
        int24 tickUpper
    ) internal view virtual returns (
        uint128 liquidity, 
        uint256 amount0, 
        uint256 amount1, 
        uint128 fees0, 
        uint128 fees1
    ) {
        return _getPositionInfo(pool, positionId, tickLower, tickUpper);
    }

    /**
     * @notice Get position details for a specific vault
     * @param vaultId The vault ID
     * @return liquidity The position's liquidity
     * @return amount0 Amount of token0 in the position
     * @return amount1 Amount of token1 in the position
     * @return fees0 Accumulated fees for token0
     * @return fees1 Accumulated fees for token1
     */
    function getPositionInfo(uint32 vaultId) external view virtual returns (uint128 liquidity, uint256 amount0, uint256 amount1, uint128 fees0, uint128 fees1);

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
    ) internal view returns (uint256 amount0, uint256 amount1) {
        Range storage range = rangeId.getRange();
        
        // Get current tick directly from the pool along with sqrtPrice
        (,int24 currentTick) = _getPoolSqrtPriceAndTick(range.poolId.toAddress());

        // Calculate token amounts using DEX math library
        (amount0, amount1) = currentTick.getAmountsForLiquidity(
            range.lowerTick,
            range.upperTick,
            uint128(liquidity) // Cast to uint128 for the math library function
        );
        return (amount0, amount1);
    }

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

    /**
     * @notice Helper function to compute liquidity from desired amounts
     * @param pool The DEX pool address
     * @param tickLower The lower tick of the position
     * @param tickUpper The upper tick of the position
     * @param amount0Desired Desired amount of token0
     * @param amount1Desired Desired amount of token1
     * @return liquidity The computed liquidity amount
     */
    function _getLiquidityForAmounts(
        address pool,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0Desired,
        uint256 amount1Desired
    ) internal view returns (uint128 liquidity) {
        (uint160 sqrtPriceX96,) = _getPoolSqrtPriceAndTick(pool);
        return sqrtPriceX96.getLiquidityForAmounts(
            tickLower.getSqrtPriceAtTick(),
            tickUpper.getSqrtPriceAtTick(),
            amount0Desired,
            amount1Desired
        );
    }

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
     * @notice Validate tick spacing for a range
     * @param pool The pool address
     * @param range The range to validate
     * @return Whether the range is valid according to the pool's tick spacing
     */
    function validateTickSpacing(address pool, Range memory range) public view returns (bool) {
        return _getPoolTickSpacing(pool).validateTickSpacing(
            range.lowerTick,
            range.upperTick
        );
    }

    /**
     * @notice Burns a position and collects all tokens and fees
     * @param rangeId The range ID to burn
     * @return withdrawProceeds Struct containing withdrawn amounts and fees
     */
    function _burnPosition(
        bytes32 rangeId
    ) internal virtual returns (WithdrawProceeds memory withdrawProceeds);

    /**
     * @notice Withdraw liquidity from a position using rangeId
     * @param rangeId The range ID
     * @return amount0 Amount of token0 withdrawn
     * @return amount1 Amount of token1 withdrawn
     * @return fees0 Fees collected for token0
     * @return fees1 Fees collected for token1
     */
    function withdraw(
        bytes32 rangeId
    ) external virtual returns (uint256 amount0, uint256 amount1, uint256 fees0, uint256 fees1) {
        WithdrawProceeds memory proceeds = _burnPosition(rangeId);
        return (proceeds.burn0, proceeds.burn1, proceeds.fee0, proceeds.fee1);
    }

    /**
     * @notice Pool-specific implementation for burning a position
     * @dev Must be implemented by each adapter to handle pool-specific burn logic
     */
    function _burnPosition(
        address pool,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) internal virtual returns (uint256 amount0, uint256 amount1);

    /**
     * @notice Pool-specific implementation for collecting tokens and fees
     * @dev Must be implemented by each adapter to handle pool-specific collect logic
     */
    function _collectPositionFees(
        address pool,
        int24 tickLower,
        int24 tickUpper
    ) internal virtual returns (uint256 collected0, uint256 collected1);

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
     * @notice Common implementation for minting liquidity in a V3-style pool
     * @dev This handles the common logic while delegating pool-specific operations to virtual functions
     * @param rangeId The range ID
     * @param amount0Desired Desired amount of token0 to use
     * @param amount1Desired Desired amount of token1 to use
     * @param amount0Min Minimum amount of token0 to use (slippage protection)
     * @param amount1Min Minimum amount of token1 to use (slippage protection)
     * @return liquidity Liquidity amount minted
     * @return amount0 Actual amount of token0 used
     * @return amount1 Actual amount of token1 used
     */
    function _mintPosition(
        bytes32 rangeId,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min
    ) internal virtual returns (uint128 liquidity, uint256 amount0, uint256 amount1);

    /**
     * @notice Mint liquidity to a position using rangeId
     * @param rangeId The range ID
     * @param amount0Desired Desired amount of token0 to use
     * @param amount1Desired Desired amount of token1 to use
     * @param amount0Min Minimum amount of token0 to use (slippage protection)
     * @param amount1Min Minimum amount of token1 to use (slippage protection)
     * @return liquidity Liquidity amount minted
     * @return amount0 Actual amount of token0 used
     * @return amount1 Actual amount of token1 used
     */
    function mintPosition(
        bytes32 rangeId,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min
    ) external virtual returns (uint128 liquidity, uint256 amount0, uint256 amount1) {
        return _mintPosition(rangeId, amount0Desired, amount1Desired, amount0Min, amount1Min);
    }

    function _observe(
        address pool,
        uint32[] memory secondsAgos
    ) internal view virtual returns (
        int56[] memory tickCumulatives,
        uint160[] memory secondsPerLiquidityCumulativeX128s
    );

    /**
     * @notice Calculate time-weighted average price from the pool
     * @param pool The pool address
     * @param lookback Time interval in seconds for the TWAP calculation
     * @return arithmeticMeanTick The mean tick over the specified period
     * @return harmonicMeanLiquidity The harmonic mean liquidity over the specified period
     */
    function consult(
        address pool,
        uint32 lookback
    ) public view returns (int24 arithmeticMeanTick, uint128 harmonicMeanLiquidity) {
        if (lookback == 0) revert Errors.ZeroValue();
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = lookback;
        secondsAgos[1] = 0;

        (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s) = 
            _observe(pool, secondsAgos);

        int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];
        uint160 secondsPerLiquidityCumulativesDelta = secondsPerLiquidityCumulativeX128s[1] - secondsPerLiquidityCumulativeX128s[0];

        arithmeticMeanTick = int24(tickCumulativesDelta / int56(uint56(lookback)));

        // Calculate harmonic mean liquidity
        if (secondsPerLiquidityCumulativesDelta > 0) {
            harmonicMeanLiquidity = uint128(
                (uint256(lookback) << 128) / (uint256(secondsPerLiquidityCumulativesDelta) + 1)
            );
        }
        return (arithmeticMeanTick, harmonicMeanLiquidity);
    }

    /**
     * @notice Validate current price against time-weighted average price to detect manipulation
     * @param pool The DEX pool address
     * @param lookback Time interval in seconds for the TWAP calculation
     * @param maxDeviation Maximum allowed deviation between current price and TWAP in basis points (100 = 1%)
     * @return isStale True if price is stale, false if price is valid
     * @return deviation Deviation between current price and TWAP in basis points
     */
    function getPriceDeviation(
        address pool,
        uint32 lookback,
        uint256 maxDeviation
    ) internal view returns (bool isStale, uint256 deviation) {
        (uint160 currentSqrtPriceX96, ) = _getPoolSqrtPriceAndTick(pool);
        (int24 arithmeticMeanTick, ) = consult(pool, lookback);
        (isStale, deviation) = currentSqrtPriceX96.getPriceDeviation(
            arithmeticMeanTick.getSqrtPriceAtTick(),
            maxDeviation
        );
    }

    function checkStalePrice(
        address pool,
        uint32 lookback,
        uint256 maxDeviation
    ) internal view {
        (bool isStale, ) = getPriceDeviation(pool, lookback, maxDeviation);
        if (isStale) {
            revert Errors.StalePrice();
        }
    }
}
