// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {ALMVault, Range, WithdrawProceeds, ErrorType, DEX} from "@/BTRTypes.sol";
import {BTRErrors as Errors, BTREvents as Events} from "@libraries/BTREvents.sol";
import {BTRUtils} from "@libraries/BTRUtils.sol";
import {IUniV3Pool} from "@interfaces/IUniV3Pool.sol";
import {IUniV3NFPManager} from "@interfaces/IUniV3NFPManager.sol";
import {DEXAdapter} from "@facets/abstract/DEXAdapter.sol";
import {LibDEXMaths} from "@libraries/LibDEXMaths.sol";

/**
 * @title UniV3AdapterFacet
 * @notice Facet for interacting with Uniswap V3 pools
 * @dev Implements V3-specific functionality for Uniswap V3
 */
abstract contract UniV3AdapterFacet is DEXAdapter {
    using SafeERC20 for IERC20;
    using BTRUtils for uint32;
    using BTRUtils for bytes32;
    using LibDEXMaths for int24;
    using LibDEXMaths for uint160;

    /**
     * @inheritdoc DEXAdapter
     * @dev Implementation for Uniswap V3
     */
    function _getPoolTickSpacing(address pool) internal view override returns (int24) {
        return IUniV3Pool(pool).tickSpacing();
    }

    /**
     * @inheritdoc DEXAdapter
     * @dev Implementation for Uniswap V3
     */
    function _getPoolSqrtPriceAndTick(address pool) internal view virtual override returns (uint160 sqrtPriceX96, int24 tick) {
        (sqrtPriceX96, tick,,,,,) = IUniV3Pool(pool).slot0();
        return (sqrtPriceX96, tick);
    }

    /**
     * @inheritdoc DEXAdapter
     * @dev Implementation for Uniswap V3
     */
    function _getPoolTokens(address pool) internal view override returns (address token0, address token1) {
        token0 = IUniV3Pool(pool).token0();
        token1 = IUniV3Pool(pool).token1();
        return (token0, token1);
    }

    /**
     * @inheritdoc DEXAdapter
     * @dev Implementation for Uniswap V3 using rangeId
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
        
        if (range.positionId == 0) {
            // new range or missing id
            range.positionId = uint256(keccak256(abi.encodePacked(address(this), tickLower, tickUpper)));
        }

        // Calculate liquidity from desired amounts
        uint128 calculatedLiquidity = uint128(_getLiquidityForAmounts(
            pool,
            tickLower,
            tickUpper,
            amount0Desired,
            amount1Desired
        ));
        
        liquidity = calculatedLiquidity;

        // Approve tokens vault->pool
        IERC20(token0).approve(pool, amount0Desired);
        IERC20(token1).approve(pool, amount1Desired);

        // Call mint function
        (amount0, amount1) = IUniV3Pool(pool).mint(
            address(this),  // recipient
            tickLower,
            tickUpper,
            liquidity,
            abi.encode(pool, amount0Min, amount1Min) // callback checks
        );
        
        // Revoke approvals pool->vault
        IERC20(token0).approve(pool, 0);
        IERC20(token1).approve(pool, 0);
        range.liquidity += liquidity;

        // Emit position creation event
        emit Events.PositionMinted(rangeId, tickLower, tickUpper, liquidity, amount0, amount1);
    
        return (liquidity, amount0, amount1);
    }
    
    /**
     * @notice Callback function for Uniswap V3 minting
     * @param amount0Owed Amount of token0 to pay
     * @param amount1Owed Amount of token1 to pay
     * @param data Callback data containing pool and minimum amounts
     */
    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external {
        // Decode callback data
        (address pool, uint256 amount0Min, uint256 amount1Min) = abi.decode(data, (address, uint256, uint256));
        if (msg.sender != pool) {
            revert Errors.Unauthorized(ErrorType.CONTRACT);
        }

        // Ensure minimum amounts are satisfied
        if (amount0Owed < amount0Min || amount1Owed < amount1Min) {
            revert Errors.SlippageTooHigh();
        }

        // Get tokens from pool
        (address token0, address token1) = _getPoolTokens(pool);

        // Transfer tokens to the pool
        if (amount0Owed > 0) {
            IERC20(token0).safeTransfer(msg.sender, amount0Owed);
        }
        if (amount1Owed > 0) {
            IERC20(token1).safeTransfer(msg.sender, amount1Owed);
        }
    }

    /**
     * @inheritdoc DEXAdapter
     */
    function _burnPosition(
        bytes32 rangeId
    ) internal virtual override returns (WithdrawProceeds memory withdrawProceeds) {
        Range storage range = rangeId.getRange();
        address pool = range.poolId.toAddress();
        int24 tickLower = range.lowerTick;
        int24 tickUpper = range.upperTick;
        uint128 liquidity = range.liquidity;
        
        // Get tokens from pool
        (address token0, address token1) = _getPoolTokens(pool);
        
        // Burn position to get tokens
        (uint256 amount0, uint256 amount1) = IUniV3Pool(pool).burn(
            tickLower,
            tickUpper,
            liquidity
        );
        
        // Collect tokens and fees
        (uint256 collected0, uint256 collected1) = IUniV3Pool(pool).collect(
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
        return IUniV3Pool(pool).collect(
            address(this),
            tickLower,
            tickUpper,
            type(uint128).max,
            type(uint128).max
        );
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
        (liquidity, , , fees0, fees1) = IUniV3Pool(pool).positions(positionId);
        (,int24 currentTick) = _getPoolSqrtPriceAndTick(pool);
        (amount0, amount1) = currentTick.getAmountsForLiquidity(
            tickLower,
            tickUpper,
            liquidity
        );
    }

    /**
     * @inheritdoc DEXAdapter
     * @dev Implementation for Uniswap V3
     */
    function _observe(
        address pool,
        uint32[] memory secondsAgos
    ) internal view override returns (
        int56[] memory tickCumulatives,
        uint160[] memory secondsPerLiquidityCumulativeX128s
    ) {
        return IUniV3Pool(pool).observe(secondsAgos);
    }
}
