// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IAlgebraV3Pool {
    function activeIncentive() external view returns (address);
    function burn(int24 bottomTick, int24 topTick, uint128 amount) external returns (uint256 amount0, uint256 amount1);
    function collect(address recipient, int24 bottomTick, int24 topTick, uint128 amount0Requested, uint128 amount1Requested) external returns (uint128 amount0, uint128 amount1);
    function dataStorageOperator() external view returns (address);
    function factory() external view returns (address);
    function flash(address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external;
    function getInnerCumulatives(int24 bottomTick, int24 topTick) external view returns (int56 innerTickCumulative, uint160 innerSecondsSpentPerLiquidity, uint32 innerSecondsSpent);
    function getTimepoints(uint32[] calldata secondsAgos) external view returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulatives, uint112[] memory volatilityCumulatives, uint256[] memory volumePerAvgLiquiditys);
    // function globalState() external view returns (uint160 price, int24 tick, uint16 fee, uint16 timepointIndex, uint16 communityFeeToken0, uint16 communityFeeToken1, bool unlocked);
    function initialize(uint160 initialPrice) external;
    function liquidity() external view returns (uint128);
    function liquidityCooldown() external view returns (uint32);
    function maxLiquidityPerTick() external pure returns (uint128);
    function mint(address sender, address recipient, int24 bottomTick, int24 topTick, uint128 liquidityDesired, bytes calldata data) external returns (uint256 amount0, uint256 amount1, uint128 liquidityActual);
    function positions(bytes32) external view returns (uint128 liquidity, uint32 lastLiquidityAddTimestamp, uint256 innerFeeGrowth0X128, uint256 innerFeeGrowth1X128, uint128 fees0, uint128 fees1);
    function setCommunityFee(uint16 communityFee0, uint16 communityFee1) external;
    function setIncentive(address virtualPoolAddress) external;
    function setLiquidityCooldown(uint32 newLiquidityCooldown) external;
    function swap(address recipient, bool zeroToOne, int256 amountRequired, uint160 limitSqrtPrice, bytes calldata data) external returns (int256 amount0, int256 amount1);
    function swapSupportingFeeOnInputTokens(address sender, address recipient, bool zeroToOne, int256 amountRequired, uint160 limitSqrtPrice, bytes calldata data) external returns (int256 amount0, int256 amount1);
    function tickSpacing() external pure returns (int24);
    function tickTable(int16) external view returns (uint256);
    function ticks(int24) external view returns (uint128 liquidityTotal, int128 liquidityDelta, uint256 outerFeeGrowth0Token, uint256 outerFeeGrowth1Token, int56 outerTickCumulative, uint160 outerSecondsPerLiquidity, uint32 outerSecondsSpent, bool initialized);
    function timepoints(uint256 index) external view returns (bool initialized, uint32 blockTimestamp, int56 tickCumulative, uint160 secondsPerLiquidityCumulative, uint88 volatilityCumulative, int24 averageTick, uint144 volumePerLiquidityCumulative);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function totalFeeGrowth0Token() external view returns (uint256);
    function totalFeeGrowth1Token() external view returns (uint256);
}
