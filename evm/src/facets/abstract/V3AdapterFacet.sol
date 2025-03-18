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
import {DEXAdapterFacet} from "@facets/abstract/DEXAdapterFacet.sol";
import {IUniV3Pool} from "@interfaces/dexs/IUniV3Pool.sol";

/**
 * @title DEXAdapterFacet
 * @notice Abstract contract defining interfaces and common functionality for DEX adapters
 * @dev This contract defines virtual methods and implements common functionality for V3-style DEXes
 */
abstract contract V3AdapterFacet is DEXAdapterFacet {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    using M for uint256;
    using BTRUtils for uint32;
    using BTRUtils for bytes32;
    using LibDEXMaths for int24;
    using LibDEXMaths for uint160;

    // NB: also works with v3 forks algebra deployments
    function _getPoolTokens(
        IUniV3Pool pool
    ) internal view virtual returns (IERC20 token0, IERC20 token1) {
        return (IERC20(pool.token0()), IERC20(pool.token1()));
    }

    /**
     * @notice Helper function to get token pair from a pool
     * @param poolId The DEX pool ID
     * @return token0 Address of token0
     * @return token1 Address of token1
     */
    function _getPoolTokens(
        bytes32 poolId
    ) internal view override returns (IERC20 token0, IERC20 token1) {
        return _getPoolTokens(IUniV3Pool(poolId.toAddress()));
    }

    // NB: also works with v3 forks algebra deployments
    function _getPoolTickSpacing(
        bytes32 poolId
    ) internal view override returns (int24) {
        return IUniV3Pool(poolId.toAddress()).tickSpacing();
    }

    function _validateTickSpacing(
        Range memory range
    ) internal view override returns (bool) {
        return
            _getPoolTickSpacing(range.poolId).validateTickSpacing(
                range.lowerTick,
                range.upperTick
            );
    }

    function _getPoolSqrtPriceAndTick(
        address pool
    ) internal view virtual returns (uint160 sqrtPriceX96, int24 tick) {
        (sqrtPriceX96, tick, , , , , ) = IUniV3Pool(pool).slot0();
    }

    function _getPoolSqrtPriceAndTick(
        bytes32 poolId
    ) internal view override returns (uint160 sqrtPriceX96, int24 tick) {
        return _getPoolSqrtPriceAndTick(poolId.toAddress());
    }

    function _getPosition(
        address pool,
        bytes32 positionId
    )
        internal
        view
        virtual
        returns (uint128 liquidity, uint128 fees0, uint128 fees1)
    {
        (liquidity, , , fees0, fees1) = IUniV3Pool(pool).positions(
            keccak256(abi.encodePacked(address(this), positionId))
        );
    }

    /**
     * @notice Get position details for a given pool, position ID, and tick range
     * @param pool The pool address
     * @param positionId The position ID
     * @param tickLower The lower tick
     * @param tickUpper The upper tick
     * @return liquidity The position's liquidity
     * @return amount0 Amount of token0 in the position
     * @return amount1 Amount of token1 in the position
     * @return fees0 Accumulated fees for token0
     * @return fees1 Accumulated fees for token1
     */
    function _getPositionWithAmounts(
        address pool,
        bytes32 positionId,
        int24 tickLower,
        int24 tickUpper
    )
        internal
        view
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1,
            uint128 fees0,
            uint128 fees1
        )
    {
        (liquidity, fees0, fees1) = _getPosition(pool, positionId);
        (, int24 currentTick) = _getPoolSqrtPriceAndTick(pool);
        (amount0, amount1) = currentTick.getAmountsForLiquidity(
            tickLower,
            tickUpper,
            liquidity
        );
    }

    /**
     * @notice Get position details for a specific range ID
     * @param rangeId The range ID
     * @return liquidity The position's liquidity
     * @return amount0 Amount of token0 in the position
     * @return amount1 Amount of token1 in the position
     * @return fees0 Accumulated fees for token0
     * @return fees1 Accumulated fees for token1
     */
    function _getPositionWithAmounts(
        bytes32 rangeId
    )
        internal
        view
        override
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1,
            uint128 fees0,
            uint128 fees1
        )
    {
        Range storage range = rangeId.getRange();
        return
            _getPositionWithAmounts(
                range.poolId.toAddress(),
                range.positionId,
                range.lowerTick,
                range.upperTick
            );
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
    ) internal view override returns (uint256 amount0, uint256 amount1) {
        Range storage range = rangeId.getRange();

        // Get current tick directly from the pool along with sqrtPrice
        (, int24 currentTick) = _getPoolSqrtPriceAndTick(range.poolId);

        // Calculate token amounts using DEX math library
        (amount0, amount1) = currentTick.getAmountsForLiquidity(
            range.lowerTick,
            range.upperTick,
            uint128(liquidity) // Cast to uint128 for the math library function
        );
        return (amount0, amount1);
    }

    function _getLiquidityForAmounts(
        bytes32 rangeId,
        uint256 amount0Desired,
        uint256 amount1Desired
    ) internal view override returns (uint128 liquidity) {
        Range storage range = rangeId.getRange();
        return
            _getLiquidityForAmounts(
                range.poolId.toAddress(),
                range.lowerTick,
                range.upperTick,
                amount0Desired,
                amount1Desired
            );
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
        (uint160 sqrtPriceX96, ) = _getPoolSqrtPriceAndTick(pool);
        return
            sqrtPriceX96.getLiquidityForAmounts(
                tickLower.getSqrtPriceAtTick(),
                tickUpper.getSqrtPriceAtTick(),
                amount0Desired,
                amount1Desired
            );
    }

    function _mintPosition(
        address pool,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) internal virtual returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = IUniV3Pool(pool).mint(
            address(this),
            tickLower,
            tickUpper,
            liquidity,
            abi.encode(pool)
        );
    }

    /**
     * @inheritdoc DEXAdapterFacet
     * @dev Implementation for Uniswap V3 using rangeId
     */
    function _mintRange(
        bytes32 rangeId
    ) internal override returns (uint128 liquidity, uint256 amount0, uint256 amount1) {
        Range storage range = rangeId.getRange();
        address pool = range.poolId.toAddress();

        if (range.positionId == bytes32(0)) {
            range.positionId = bytes32(_getPositionId(range.lowerTick, range.upperTick));
        }

        // Get liquidity from position
        (uint128 currentLiquidity, , ) = _getPosition(pool, range.positionId);

        // increase only
        if (currentLiquidity >= range.liquidity) {
            revert Errors.Exceeds(currentLiquidity, range.liquidity);
        }

        (IERC20 token0, IERC20 token1) = _getPoolTokens(pool);

        // Approve tokens vault->pool
        token0.approve(pool, type(uint256).max);
        token1.approve(pool, type(uint256).max);
        (amount0, amount1) = _mintPosition(
            pool,
            range.lowerTick,
            range.upperTick,
            range.liquidity - currentLiquidity
        );

        // Revoke approvals pool->vault (after mint callback)
        token0.approve(pool, 0);
        token1.approve(pool, 0);
        liquidity = range.liquidity;
        emit Events.RangeMinted(rangeId, liquidity, amount0, amount1);
    }

    function _mintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) internal {
        address pool = abi.decode(data, (address));
        if (msg.sender != pool) {
            revert Errors.Unauthorized(ErrorType.CONTRACT);
        }

        // Ensure minimum amounts are satisfied
        // if (amount0Owed < amount0Min || amount1Owed < amount1Min)
        //     revert Errors.SlippageTooHigh();

        (IERC20 token0, IERC20 token1) = _getPoolTokens(IUniV3Pool(pool));

        // Transfer owed tokens to the pool
        if (amount0Owed > 0) {
            token0.safeTransfer(msg.sender, amount0Owed);
        }
        if (amount1Owed > 0) {
            token1.safeTransfer(msg.sender, amount1Owed);
        }
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
    ) internal virtual returns (uint256 amount0, uint256 amount1) {
        // Burn position to release tokens
        (amount0, amount1) = IUniV3Pool(pool).burn(
            tickLower,
            tickUpper,
            liquidity
        );
    }

    /**
     * @inheritdoc DEXAdapterFacet
     * @dev Implementation for Uniswap V3 using rangeId
     */
    function _burnRange(
        bytes32 rangeId
    )
        internal
        override
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 lpFees0,
            uint256 lpFees1
        )
    {
        Range storage range = rangeId.getRange();
        address pool = range.poolId.toAddress();

        if (range.positionId == bytes32(0)) {
            range.positionId = bytes32(_getPositionId(range.lowerTick, range.upperTick));
        }

        // Get liquidity from position
        (uint128 liquidity, , ) = _getPosition(pool, range.positionId);

        // decrease only
        if (liquidity <= range.liquidity) {
            revert Errors.Exceeds(range.liquidity, liquidity);
        }

        // burn position
        (amount0, amount1) = _burnPosition(
            pool,
            range.lowerTick,
            range.upperTick,
            range.liquidity - liquidity
        );


        // Collect tokens from burnt liquidity and fees
        (uint256 collected0, uint256 collected1) = _collectPositionFees(
            pool,
            range.lowerTick,
            range.upperTick
        );

        // Calculate LP fee amounts
        lpFees0 = collected0 > amount0 ? collected0 - amount0 : 0;
        lpFees1 = collected1 > amount1 ? collected1 - amount1 : 0;

        // update range liquidity
        range.liquidity = liquidity;
        emit Events.RangeBurnt(
            rangeId,
            liquidity,
            amount0,
            amount1,
            lpFees0,
            lpFees1
        );
    }

    /**
     * @notice Pool-specific implementation for collecting tokens and fees
     * @dev Must be implemented by each adapter to handle pool-specific collect logic
     */
    function _collectPositionFees(
        address pool,
        int24 tickLower,
        int24 tickUpper
    )
        internal
        virtual
        returns (uint256 collected0, uint256 collected1)
    {
        return
            IUniV3Pool(pool).collect(
                address(this),
                tickLower,
                tickUpper,
                type(uint128).max,
                type(uint128).max
            );
    }

    function _collectRangeFees(
        bytes32 rangeId
    ) internal override returns (uint256 collected0, uint256 collected1) {
        Range storage range = rangeId.getRange();
        return
            _collectPositionFees(
                range.poolId.toAddress(),
                range.lowerTick,
                range.upperTick
            );
    }

    function _observe(
        address pool,
        uint32[] memory secondsAgos
    )
        internal
        view
        virtual
        returns (
            int56[] memory tickCumulatives,
            uint160[] memory intervalSecondsX128
        )
    {
        return IUniV3Pool(pool).observe(secondsAgos);
    }

    /**
     * @notice Calculate time-weighted average price from the pool
     * @param pool The pool address
     * @param lookback Time interval in seconds for the TWAP calculation
     * @return arithmeticMeanTick The mean tick over the specified period
     * @return harmonicMeanLiquidity The harmonic mean liquidity over the specified period
     */
    function _consult(
        address pool,
        uint32 lookback
    ) internal view virtual returns (int24 arithmeticMeanTick, uint128 harmonicMeanLiquidity) {
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = lookback;
        secondsAgos[1] = 0;

        (
            int56[] memory tickCumulatives,
            uint160[] memory intervalSecondsX128
        ) = _observe(pool, secondsAgos);

        // Calculate arithmetic mean tick
        int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];
        arithmeticMeanTick = int24(tickCumulativesDelta / int56(uint56(lookback)));

        // Calculate harmonic mean liquidity
        uint160 secondsPerLiquidityDelta = intervalSecondsX128[1] - intervalSecondsX128[0];
        if (secondsPerLiquidityDelta > 0) {
            harmonicMeanLiquidity = uint128(
                (uint256(lookback) << 128) / (uint256(secondsPerLiquidityDelta) + 1)
            );
        }
    }

    /**
     * @notice Validate current price against time-weighted average price to detect manipulation
     * @param pool The DEX pool address
     * @param lookback Time interval in seconds for the TWAP calculation
     * @param maxDeviation Maximum allowed deviation between current price and TWAP in basis points (100 = 1%)
     * @return isStale True if price is stale, false if price is valid
     * @return deviation Deviation between current price and TWAP in basis points
     */
    function _getPriceDeviation(
        address pool,
        uint32 lookback,
        uint256 maxDeviation
    ) internal view returns (bool isStale, uint256 deviation) {
        // Get current price from pool
        (uint160 currentSqrtPriceX96, ) = _getPoolSqrtPriceAndTick(pool);
        
        // Get time-weighted average price
        (int24 arithmeticMeanTick, ) = _consult(pool, lookback);
        
        // Calculate price deviation
        uint160 twapSqrtPriceX96 = arithmeticMeanTick.getSqrtPriceAtTick();
        return currentSqrtPriceX96.getPriceDeviation(twapSqrtPriceX96, maxDeviation);
    }

    function _checkStalePrice(
        address pool,
        uint32 lookback,
        uint256 maxDeviation
    ) internal view {
        (bool isStale, ) = _getPriceDeviation(pool, lookback, maxDeviation);
        if (isStale) {
            revert Errors.StalePrice();
        }
    }

    function _getPoolTokens(
        address pool
    ) internal view virtual returns (IERC20 token0, IERC20 token1) {
        return (IERC20(IUniV3Pool(pool).token0()), IERC20(IUniV3Pool(pool).token1()));
    }
}
