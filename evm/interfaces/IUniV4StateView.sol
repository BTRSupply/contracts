// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IUniV4PoolManager} from "@interfaces/IUniV4PoolManager.sol";

// Uniswap V4 lens contract, aka. StateView
interface IUniV4StateView {
    function poolManager() external view returns (IUniV4PoolManager);
    function getFeeGrowthGlobals(bytes32 poolId) external view returns (uint256 feeGrowthGlobal0, uint256 feeGrowthGlobal1);
    function getFeeGrowthInside(bytes32 poolId, int24 tickLower, int24 tickUpper) external view returns (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128);
    function getLiquidity(bytes32 poolId) external view returns (uint128 liquidity);
    function getPositionInfo(bytes32 poolId, bytes32 positionId) external view returns (uint128 liquidity, uint256 innerFeeGrowth0X128, uint256 innerFeeGrowth1X128);
    function getPositionInfo(bytes32 poolId, address owner, int24 tickLower, int24 tickUpper, bytes32 salt) external view returns (uint128 liquidity, uint256 innerFeeGrowth0X128, uint256 innerFeeGrowth1X128);
    function getPositionLiquidity(bytes32 poolId, bytes32 positionId) external view returns (uint128 liquidity);
    function getSlot0(bytes32 poolId) external view returns (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee);
    function getTickBitmap(bytes32 poolId, int16 tick) external view returns (uint256 tickBitmap);
    function getTickFeeGrowthOutside(bytes32 poolId, int24 tick) external view returns (uint256 feeGrowthOutside0X128, uint256 feeGrowthOutside1X128);
    function getTickInfo(bytes32 poolId, int24 tick) external view returns (uint128 liquidityGross, int128 liquidityNet, uint256 feeGrowthOutside0X128, uint256 feeGrowthOutside1X128);
    function getTickLiquidity(bytes32 poolId, int24 tick) external view returns (uint128 liquidityGross, int128 liquidityNet);
}
