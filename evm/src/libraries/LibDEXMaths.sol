// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {FixedPoint96} from "@libraries/FixedPoint96.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {LibMaths as M} from "@libraries/LibMaths.sol"; // contains mulDiv

/**
 * @title LibDEXMaths
 * @notice Library containing all DEX-specific math functions
 * @dev Used by various DEX adapters to calculate position values, ticks, and prices
 */
library LibDEXMaths {
    using SafeCast for uint256;
    using SafeCast for int256;
    using M for uint256;
    using M for uint160;
    
    /// @dev The minimum tick that may be passed to #getSqrtPriceAtTick computed from log base 1.0001 of 2**-128
    int24 internal constant MIN_TICK = -887272;
    /// @dev The maximum tick that may be passed to #getSqrtPriceAtTick computed from log base 1.0001 of 2**128
    int24 internal constant MAX_TICK = -MIN_TICK;

    /// @dev The minimum value that can be returned from #getSqrtPriceAtTick. Equivalent to getSqrtPriceAtTick(MIN_TICK)
    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    /// @dev The maximum value that can be returned from #getSqrtPriceAtTick. Equivalent to getSqrtPriceAtTick(MAX_TICK)
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;
    
    /**
     * @notice Calculate token0 amount for given liquidity
     * @param sqrtPriceAX96 Lower sqrt price
     * @param sqrtPriceBX96 Upper sqrt price
     * @param liquidity Liquidity amount
     * @return amount0 Amount of token0
     */
    function getAmount0ForLiquidity(
        uint160 sqrtPriceAX96,
        uint160 sqrtPriceBX96,
        uint128 liquidity
    ) internal pure returns (uint256 amount0) {
        if (sqrtPriceAX96 > sqrtPriceBX96) {
            (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);
        }

        return uint256(liquidity) * FixedPoint96.Q96 * (sqrtPriceBX96 - sqrtPriceAX96) / (sqrtPriceAX96 * sqrtPriceBX96);
    }
    
    /**
     * @notice Calculate token1 amount for given liquidity
     * @param sqrtPriceAX96 Lower sqrt price
     * @param sqrtPriceBX96 Upper sqrt price
     * @param liquidity Liquidity amount
     * @return amount1 Amount of token1
     */
    function getAmount1ForLiquidity(
        uint160 sqrtPriceAX96,
        uint160 sqrtPriceBX96,
        uint128 liquidity
    ) internal pure returns (uint256 amount1) {
        if (sqrtPriceAX96 > sqrtPriceBX96) {
            (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);
        }

        return uint256(liquidity) * (sqrtPriceBX96 - sqrtPriceAX96) / FixedPoint96.Q96;
    }
    
    /**
     * @notice Calculate liquidity for given token amounts
     * @param sqrtPriceX96 Current sqrt price
     * @param sqrtPriceAX96 Lower sqrt price
     * @param sqrtPriceBX96 Upper sqrt price
     * @param amount0Desired Desired amount of token0
     * @param amount1Desired Desired amount of token1
     * @return liquidity The calculated liquidity amount
     */
    function getLiquidityForAmounts(
        uint160 sqrtPriceX96,
        uint160 sqrtPriceAX96,
        uint160 sqrtPriceBX96,
        uint256 amount0Desired,
        uint256 amount1Desired
    ) internal pure returns (uint128 liquidity) {
        if (sqrtPriceAX96 > sqrtPriceBX96) {
            (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);
        }

        if (sqrtPriceX96 <= sqrtPriceAX96) {
            liquidity = getLiquidityForAmount0(sqrtPriceAX96, sqrtPriceBX96, amount0Desired);
        } else if (sqrtPriceX96 < sqrtPriceBX96) {
            uint128 liquidity0 = getLiquidityForAmount0(sqrtPriceX96, sqrtPriceBX96, amount0Desired);
            uint128 liquidity1 = getLiquidityForAmount1(sqrtPriceAX96, sqrtPriceX96, amount1Desired);
            liquidity = liquidity0 < liquidity1 ? liquidity0 : liquidity1;
        } else {
            liquidity = getLiquidityForAmount1(sqrtPriceAX96, sqrtPriceBX96, amount1Desired);
        }
    }

    /**
     * @notice Calculate liquidity for amount0
     * @param sqrtPriceAX96 Lower sqrt price
     * @param sqrtPriceBX96 Upper sqrt price
     * @param amount0 Amount of token0
     * @return liquidity The calculated liquidity amount
     */
    function getLiquidityForAmount0(
        uint160 sqrtPriceAX96, 
        uint160 sqrtPriceBX96, 
        uint256 amount0
    ) internal pure returns (uint128 liquidity) {
        if (sqrtPriceAX96 > sqrtPriceBX96) {
            (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);
        }
        uint256 intermediate = sqrtPriceAX96.mulDivDown(sqrtPriceBX96, FixedPoint96.Q96);
        return uint128(amount0.mulDivDown(intermediate, sqrtPriceBX96 - sqrtPriceAX96));
    }

    /**
     * @notice Calculate liquidity for amount1
     * @param sqrtPriceAX96 Lower sqrt price
     * @param sqrtPriceBX96 Upper sqrt price
     * @param amount1 Amount of token1
     * @return liquidity The calculated liquidity amount
     */
    function getLiquidityForAmount1(
        uint160 sqrtPriceAX96, 
        uint160 sqrtPriceBX96, 
        uint256 amount1
    ) internal pure returns (uint128 liquidity) {
        if (sqrtPriceAX96 > sqrtPriceBX96) {
            (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);
        }
        return uint128(amount1.mulDivDown(FixedPoint96.Q96, sqrtPriceBX96 - sqrtPriceAX96));
    }

    /**
     * @notice Calculate fee growth
     * @param feeGrowthGlobal Global fee growth
     * @param feeGrowthInside Inside fee growth
     * @param liquidity Liquidity amount
     * @return fee Amount of fees
     */
    function calculateFeeGrowth(
        uint256 feeGrowthGlobal,
        uint256 feeGrowthInside,
        uint128 liquidity
    ) internal pure returns (uint256 fee) {
        uint256 feeGrowthDelta = feeGrowthGlobal - feeGrowthInside;
        return uint256(liquidity) * feeGrowthDelta / (1 << 128);
    }

    /**
     * @notice Calculates sqrt(1.0001^tick) * 2^96
     * @dev Throws if |tick| > max tick
     * @param tick The input tick for the above formula
     * @return sqrtPriceX96 A Fixed point Q64.96 number representing the sqrt of the ratio of the two assets (token1/token0)
     * at the given tick
     */
    function getSqrtPriceAtTick(int24 tick) internal pure returns (uint160 sqrtPriceX96) {
        unchecked {
            int256 absTick = tick < 0 ? -int256(tick) : int256(tick);
            require(absTick <= int256(MAX_TICK));

            uint256 absTickUint = SafeCast.toUint256(absTick);
            uint256 ratio = absTickUint & 0x1 != 0 ? 0xfffcb933bd6fad37aa2d162d1a594001 : 0x100000000000000000000000000000000;
            if (absTickUint & 0x2 != 0) ratio = (ratio * 0xfff97272373d413259a46990580e213a) >> 128;
            if (absTickUint & 0x4 != 0) ratio = (ratio * 0xfff2e50f5f656932ef12357cf3c7fdcc) >> 128;
            if (absTickUint & 0x8 != 0) ratio = (ratio * 0xffe5caca7e10e4e61c3624eaa0941cd0) >> 128;
            if (absTickUint & 0x10 != 0) ratio = (ratio * 0xffcb9843d60f6159c9db58835c926644) >> 128;
            if (absTickUint & 0x20 != 0) ratio = (ratio * 0xff973b41fa98c081472e6896dfb254c0) >> 128;
            if (absTickUint & 0x40 != 0) ratio = (ratio * 0xff2ea16466c96a3843ec78b326b52861) >> 128;
            if (absTickUint & 0x80 != 0) ratio = (ratio * 0xfe5dee046a99a2a811c461f1969c3053) >> 128;
            if (absTickUint & 0x100 != 0) ratio = (ratio * 0xfcbe86c7900a88aedcffc83b479aa3a4) >> 128;
            if (absTickUint & 0x200 != 0) ratio = (ratio * 0xf987a7253ac413176f2b074cf7815e54) >> 128;
            if (absTickUint & 0x400 != 0) ratio = (ratio * 0xf3392b0822b70005940c7a398e4b70f3) >> 128;
            if (absTickUint & 0x800 != 0) ratio = (ratio * 0xe7159475a2c29b7443b29c7fa6e889d9) >> 128;
            if (absTickUint & 0x1000 != 0) ratio = (ratio * 0xd097f3bdfd2022b8845ad8f792aa5825) >> 128;
            if (absTickUint & 0x2000 != 0) ratio = (ratio * 0xa9f746462d870fdf8a65dc1f90e061e5) >> 128;
            if (absTickUint & 0x4000 != 0) ratio = (ratio * 0x70d869a156d2a1b890bb3df62baf32f7) >> 128;
            if (absTickUint & 0x8000 != 0) ratio = (ratio * 0x31be135f97d08fd981231505542fcfa6) >> 128;
            if (absTickUint & 0x10000 != 0) ratio = (ratio * 0x9aa508b5b7a84e1c677de54f3e99bc9) >> 128;
            if (absTickUint & 0x20000 != 0) ratio = (ratio * 0x5d6af8dedb81196699c329225ee604) >> 128;
            if (absTickUint & 0x40000 != 0) ratio = (ratio * 0x2216e584f5fa1ea926041bedfe98) >> 128;
            if (absTickUint & 0x80000 != 0) ratio = (ratio * 0x48a170391f7dc42444e8fa2) >> 128;

            if (tick > 0) ratio = type(uint256).max / ratio;

            // this divides by 1<<32 rounding up to go from a Q128.128 to a Q128.96.
            // we then downcast because we know the result always fits within 160 bits due to our tick input constraint
            // we round up in the division so getTickAtSqrtPrice of the output price is always consistent
            sqrtPriceX96 = uint160((ratio >> 32) + (ratio % (1 << 32) == 0 ? 0 : 1));
        }
    }

    /**
     * @notice Calculates the greatest tick value such that getRatioAtTick(tick) <= ratio
     * @dev Throws in case sqrtPriceX96 < MIN_SQRT_RATIO, as MIN_SQRT_RATIO is the lowest value getRatioAtTick may
     * ever return.
     * @param sqrtPriceX96 The sqrt ratio for which to compute the tick as a Q64.96
     * @return tick The greatest tick for which the ratio is less than or equal to the input ratio
     */
    function getTickAtSqrtPrice(uint160 sqrtPriceX96) internal pure returns (int24 tick) {
        // second inequality must be < because the price can never reach the price at the max tick
        require(sqrtPriceX96 >= MIN_SQRT_RATIO && sqrtPriceX96 < MAX_SQRT_RATIO, 'R');
        uint256 ratio = uint256(sqrtPriceX96) << 32;

        uint256 r = ratio;
        uint256 msb = 0;

        assembly {
            let f := shl(7, gt(r, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))
            msb := or(msb, f)
            r := shr(f, r)
        }
        assembly {
            let f := shl(6, gt(r, 0xFFFFFFFFFFFFFFFF))
            msb := or(msb, f)
            r := shr(f, r)
        }
        assembly {
            let f := shl(5, gt(r, 0xFFFFFFFF))
            msb := or(msb, f)
            r := shr(f, r)
        }
        assembly {
            let f := shl(4, gt(r, 0xFFFF))
            msb := or(msb, f)
            r := shr(f, r)
        }
        assembly {
            let f := shl(3, gt(r, 0xFF))
            msb := or(msb, f)
            r := shr(f, r)
        }
        assembly {
            let f := shl(2, gt(r, 0xF))
            msb := or(msb, f)
            r := shr(f, r)
        }
        assembly {
            let f := shl(1, gt(r, 0x3))
            msb := or(msb, f)
            r := shr(f, r)
        }
        assembly {
            let f := gt(r, 0x1)
            msb := or(msb, f)
        }

        if (msb >= 128) r = ratio >> (msb - 127);
        else r = ratio << (127 - msb);

        int256 log_2 = (int256(msb) - 128) << 64;

        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(63, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(62, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(61, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(60, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(59, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(58, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(57, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(56, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(55, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(54, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(53, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(52, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(51, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(50, f))
        }

        int256 log_sqrt10001 = log_2 * 255738958999603826347141; // 128.128 number

        int24 tickLow = int24((log_sqrt10001 - 3402992956809132418596140100660247210) >> 128);
        int24 tickHi = int24((log_sqrt10001 + 291339464771989622907027621153398088495) >> 128);

        tick = tickLow == tickHi ? tickLow : getSqrtPriceAtTick(tickHi) <= sqrtPriceX96 ? tickHi : tickLow;
    }
    
    /**
     * @notice Calculates total asset value across multiple positions
     * @param currentTick Current tick in the pool
     * @param positions Array of position data: lowerTick, upperTick, liquidity
     * @return amount0 Total amount of token0
     * @return amount1 Total amount of token1
     */
    function getTotalPositionValues(
        int24 currentTick, 
        Position[] memory positions
    ) internal pure returns (uint256 amount0, uint256 amount1) {
        for (uint256 i = 0; i < positions.length; i++) {
            Position memory pos = positions[i];
            if (pos.liquidity == 0) continue;

            (uint256 posAmount0, uint256 posAmount1) = getAmountsForLiquidity(
                currentTick,
                pos.lowerTick,
                pos.upperTick,
                pos.liquidity
            );
            
            amount0 += posAmount0;
            amount1 += posAmount1;
        }
    }
    
    /**
     * @notice Calculate amounts in a single position
     * @param currentTick Current tick in the pool
     * @param lowerTick Lower tick of position
     * @param upperTick Upper tick of position
     * @param liquidity Liquidity in the position
     * @return amount0 Amount of token0
     * @return amount1 Amount of token1
     */
    function getAmountsForLiquidity(
        int24 currentTick,
        int24 lowerTick,
        int24 upperTick,
        uint128 liquidity
    ) internal pure returns (uint256 amount0, uint256 amount1) {
        // Calculate token amounts based on liquidity
        if (currentTick < lowerTick) {
            // All token0, no token1
            amount0 = getAmount0ForLiquidity(
                getSqrtPriceAtTick(lowerTick),
                getSqrtPriceAtTick(upperTick),
                liquidity
            );
        } else if (currentTick >= upperTick) {
            // All token1, no token0
            amount1 = getAmount1ForLiquidity(
                getSqrtPriceAtTick(lowerTick),
                getSqrtPriceAtTick(upperTick),
                liquidity
            );
        } else {
            // Mix of token0 and token1
            amount0 = getAmount0ForLiquidity(
                getSqrtPriceAtTick(currentTick),
                getSqrtPriceAtTick(upperTick),
                liquidity
            );
            amount1 = getAmount1ForLiquidity(
                getSqrtPriceAtTick(lowerTick),
                getSqrtPriceAtTick(currentTick),
                liquidity
            );
        }
    }
    
    // Helper struct for position operations
    struct Position {
        int24 lowerTick;
        int24 upperTick;
        uint128 liquidity;
    }

    /**
     * @notice Calculate liquidity from desired amounts using ticks
     * @param sqrtPriceX96 Current sqrt price
     * @param tickLower The lower tick of the position
     * @param tickUpper The upper tick of the position
     * @param amount0Desired Desired amount of token0
     * @param amount1Desired Desired amount of token1
     * @return liquidity The computed liquidity amount
     */
    function calculateLiquidityForAmounts(
        uint160 sqrtPriceX96,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0Desired,
        uint256 amount1Desired
    ) internal pure returns (uint128 liquidity) {
        uint160 sqrtPriceAX96 = getSqrtPriceAtTick(tickLower);
        uint160 sqrtPriceBX96 = getSqrtPriceAtTick(tickUpper);
        
        return getLiquidityForAmounts(
            sqrtPriceX96,
            sqrtPriceAX96,
            sqrtPriceBX96,
            amount0Desired,
            amount1Desired
        );
    }
    
    /**
     * @notice Validate tick spacing for a range
     * @param spacing The tick spacing for the pool
     * @param tickLower The lower tick of the position
     * @param tickUpper The upper tick of the position
     * @return Whether the range is valid according to the pool's tick spacing
     */
    function validateTickSpacing(
        int24 spacing,
        int24 tickLower,
        int24 tickUpper
    ) internal pure returns (bool) {
        return
            tickLower < tickUpper &&
            tickLower % spacing == 0 &&
            tickUpper % spacing == 0;
    }

    /**
     * @notice Calculate the amount of quote token for a given amount of base token at a specific tick
     * @param tick The tick from which to get the quote
     * @param baseAmount Amount of base token
     * @param baseToken Base token address
     * @param quoteToken Quote token address
     * @return quoteAmount Amount of quote token
     */
    function getQuoteAtTick(
        int24 tick,
        uint128 baseAmount,
        address baseToken,
        address quoteToken
    ) internal pure returns (uint256 quoteAmount) {
        uint160 sqrtRatioX96 = getSqrtPriceAtTick(tick);

        if (sqrtRatioX96 <= type(uint128).max) {
            uint256 ratioX192 = uint256(sqrtRatioX96) * sqrtRatioX96;
            quoteAmount = baseToken < quoteToken
                ? ratioX192.mulDivDown(baseAmount, 1 << 192)
                : uint256(1 << 192).mulDivDown(baseAmount, ratioX192);
        } else {
            uint256 ratioX128 = sqrtRatioX96.mulDivDown(sqrtRatioX96, 1 << 64);
            quoteAmount = baseToken < quoteToken
                ? ratioX128.mulDivDown(baseAmount, 1 << 128)
                : uint256(1 << 128).mulDivDown(baseAmount, ratioX128);
        }
    }


    /**
     * @notice Validate current price against time-weighted average price to detect manipulation
     * @param currentSqrtPriceX96 Current sqrt price
     * @param meanSqrtPriceX96 Mean sqrt price
     * @param maxDeviation Maximum allowed deviation between current price and TWAP in basis points (100 = 1%)
     * @return isStale True if price is stale, false if price is valid
     * @return deviation Deviation between current price and TWAP in basis points
     */
    function getPriceDeviation(
        uint160 currentSqrtPriceX96,
        uint160 meanSqrtPriceX96,
        uint256 maxDeviation
    ) internal pure returns (bool isStale, uint256 deviation) {
        if (currentSqrtPriceX96 > meanSqrtPriceX96) {
            deviation = uint256(currentSqrtPriceX96 - meanSqrtPriceX96) * M.BP_BASIS / uint256(meanSqrtPriceX96);
        } else {
            deviation = uint256(meanSqrtPriceX96 - currentSqrtPriceX96) * M.BP_BASIS / uint256(currentSqrtPriceX96);
        }
        isStale = deviation > maxDeviation;
        return (isStale, deviation);
    }
}
