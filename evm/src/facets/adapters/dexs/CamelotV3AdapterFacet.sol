// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ALMVault, WithdrawProceeds, Range} from "@/BTRTypes.sol";
import {BTRErrors as Errors, BTREvents as Events} from "@libraries/BTREvents.sol";
import {BTRUtils} from "@libraries/BTRUtils.sol";
import {ICamelotV3Pool} from "@interfaces/ICamelotV3Pool.sol";
import {DEXAdapter} from "@facets/abstract/DEXAdapter.sol";
import {LibDEXMaths} from "@libraries/LibDEXMaths.sol";

/**
 * @title CamelotV3AdapterFacet
 * @notice Facet for interacting with Camelot V3 pools
 * @dev Implements V3-specific functionality for Camelot (Algebra-based) pools
 */
abstract contract CamelotV3AdapterFacet is DEXAdapter {
    using SafeERC20 for IERC20;
    using BTRUtils for uint32;
    using BTRUtils for bytes32;
    
    /**
     * @notice Constructor that initializes valid tick spacings for Camelot pools
     * @dev Camelot pools use a dynamic tick spacing which we get from the pool directly
     */
    constructor() {
        // No static tick spacings for Camelot as they use dynamic tick spacing
    }

    /**
     * @inheritdoc DEXAdapter
     * @dev Implementation for Camelot V3
     */
    function _getPoolTickSpacing(address pool) internal pure override returns (int24) {
        return ICamelotV3Pool(pool).tickSpacing();
    }
    
    /**
     * @inheritdoc DEXAdapter
     * @dev Implementation for Camelot V3
     */
    function _getPoolSqrtPriceAndTick(address pool) internal view override returns (uint160 sqrtPriceX96, int24 tick) {
        (sqrtPriceX96, tick,,,,,) = ICamelotV3Pool(pool).globalState();
        return (sqrtPriceX96, tick);
    }
    
    /**
     * @inheritdoc DEXAdapter
     * @dev Implementation for Camelot V3
     */
    function _getPoolTokens(address pool) internal view override returns (address token0, address token1) {
        token0 = ICamelotV3Pool(pool).token0();
        token1 = ICamelotV3Pool(pool).token1();
        return (token0, token1);
    }

    /**
     * @inheritdoc DEXAdapter
     */
    function _getPositionInfo(
        address pool, 
        bytes32 positionId, 
        int24 tickLower, 
        int24 tickUpper
    ) internal view override returns (
        uint128 liquidity, 
        uint256 amount0, 
        uint256 amount1, 
        uint128 fees0, 
        uint128 fees1
    ) {
        (liquidity, , , , fees0, fees1) = ICamelotV3Pool(pool).positions(positionId);
        (,int24 currentTick) = _getPoolSqrtPriceAndTick(pool);
        (amount0, amount1) = LibDEXMaths.getAmountsForLiquidity(
            currentTick,
            tickLower,
            tickUpper,
            liquidity
        );
    }

    /**
     * @inheritdoc DEXAdapter
     * @dev Adapted for internal use with standardized parameters
     */
    function _mintPosition(
        bytes32 rangeId,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min
    ) internal override returns (uint128 liquidity, uint256 amount0, uint256 amount1) {
        Range storage range = rangeId.getRange();
        address pool = range.poolId.toAddress();
        int24 tickLower = range.lowerTick;
        int24 tickUpper = range.upperTick;
        
        // Get tokens from pool
        (address token0, address token1) = _getPoolTokens(pool);
        
        // Approve tokens to the pool
        IERC20(token0).approve(pool, amount0Desired);
        IERC20(token1).approve(pool, amount1Desired);
        
        // Camelot calculates liquidity internally, set to 0
        uint128 liquidityAmount = 0;
        
        // Mint position - Camelot has a different mint signature
        (amount0, amount1, liquidity) = ICamelotV3Pool(pool).mint(
            address(this),
            address(this),
            tickLower,
            tickUpper,
            liquidityAmount,
            abi.encode(amount0Desired, amount1Desired, amount0Min, amount1Min)
        );
        
        // Revoke approvals
        IERC20(token0).approve(pool, 0);
        IERC20(token1).approve(pool, 0);
        
        // Emit position creation event
        emit Events.PositionMinted(rangeId, tickLower, tickUpper, liquidity, amount0, amount1);
        
        return (liquidity, amount0, amount1);
    }

    /**
     * @inheritdoc DEXAdapter
     * @dev Implementation for Camelot V3 (Algebra-based)
     */
    function _observe(
        address pool,
        uint32[] memory secondsAgos
    ) internal view override returns (
        int56[] memory tickCumulatives,
        uint160[] memory secondsPerLiquidityCumulativeX128s
    ) {
        // Camelot's getTimepoints returns 4 arrays but we only need the first 2
        (tickCumulatives, secondsPerLiquidityCumulativeX128s, , ) = 
            ICamelotV3Pool(pool).getTimepoints(secondsAgos);
        return (tickCumulatives, secondsPerLiquidityCumulativeX128s);
    }

    function _burnPosition(
        bytes32 rangeId
    ) internal override returns (WithdrawProceeds memory withdrawProceeds) {
        Range storage range = rangeId.getRange();
        address pool = range.poolId.toAddress();
        int24 tickLower = range.lowerTick;
        int24 tickUpper = range.upperTick;
        uint128 liquidity = range.liquidity;
        
        // Get tokens from pool
        (address token0, address token1) = _getPoolTokens(pool);
        
        // Burn position to get tokens
        (uint256 amount0, uint256 amount1) = ICamelotV3Pool(pool).burn(
            tickLower,
            tickUpper,
            liquidity
        );
        
        // Collect tokens and fees
        (uint256 collected0, uint256 collected1) = ICamelotV3Pool(pool).collect(
            address(this),
            tickLower,
            tickUpper,
            type(uint128).max,
            type(uint128).max
        );
        
        // Calculate LP fee amounts
        uint256 fees0 = collected0 > amount0 ? collected0 - amount0 : 0;
        uint256 fees1 = collected1 > amount1 ? collected1 - amount1 : 0;
        
        // Transfer tokens back to caller
        if (collected0 > 0) {
            IERC20(token0).safeTransfer(msg.sender, collected0);
        }
        if (collected1 > 0) {
            IERC20(token1).safeTransfer(msg.sender, collected1);
        }
        
        // Emit position withdrawal event
        emit Events.PositionBurnt(rangeId, tickLower, tickUpper, liquidity, amount0, amount1, fees0, fees1);
        
        // Return withdrawn amounts
        withdrawProceeds.burn0 = amount0;
        withdrawProceeds.burn1 = amount1;
        withdrawProceeds.fee0 = fees0;
        withdrawProceeds.fee1 = fees1;
        
        return withdrawProceeds;
    }

    /**
     * @inheritdoc DEXAdapter
     */
    function _collectPositionFees(
        address pool,
        int24 tickLower,
        int24 tickUpper
    ) internal virtual override returns (uint256 collected0, uint256 collected1) {
        return ICamelotV3Pool(pool).collect(
            address(this),
            tickLower,
            tickUpper,
            type(uint128).max,
            type(uint128).max
        );
    }
}
