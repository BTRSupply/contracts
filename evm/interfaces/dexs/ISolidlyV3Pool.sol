// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface ISolidlyV3PoolBase {
    function burn(int24 tickLower, int24 tickUpper, uint128 amount, uint256 amount0Min, uint256 amount1Min, uint256 deadline) external returns (uint256 amount0, uint256 amount1);
    function burn(int24 tickLower, int24 tickUpper, uint128 amount) external returns (uint256 amount0, uint256 amount1);
    function burnAndCollect(address recipient, int24 tickLower, int24 tickUpper, uint128 amountToBurn, uint128 amount0ToCollect, uint128 amount1ToCollect) external returns (uint256 amount0FromBurn, uint256 amount1FromBurn, uint128 amount0Collected, uint128 amount1Collected);
    function burnAndCollect(address recipient, int24 tickLower, int24 tickUpper, uint128 amountToBurn, uint256 amount0FromBurnMin, uint256 amount1FromBurnMin, uint128 amount0ToCollect, uint128 amount1ToCollect, uint256 deadline) external returns (uint256 amount0FromBurn, uint256 amount1FromBurn, uint128 amount0Collected, uint128 amount1Collected);
    function collect(address recipient, int24 tickLower, int24 tickUpper, uint128 amount0Requested, uint128 amount1Requested) external returns (uint128 amount0, uint128 amount1);
    function collectProtocol(address recipient, uint128 amount0Requested, uint128 amount1Requested) external returns (uint128 amount0, uint128 amount1);
    function factory() external view returns (address);
    function flash(address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external;
    function initialize(uint160 sqrtPriceX96) external;
    function liquidity() external view returns (uint128);
    function maxLiquidityPerTick() external view returns (uint128);
    function mint(address recipient, int24 tickLower, int24 tickUpper, uint128 amount, bytes calldata data) external returns (uint256 amount0, uint256 amount1);
    function mint(address recipient, int24 tickLower, int24 tickUpper, uint128 amount, uint256 amount0Min, uint256 amount1Min, uint256 deadline) external returns (uint256 amount0, uint256 amount1);
    function mint(address recipient, int24 tickLower, int24 tickUpper, uint128 amount, uint256 amount0Min, uint256 amount1Min, uint256 deadline, bytes calldata data) external returns (uint256 amount0, uint256 amount1);
    function mint(address recipient, int24 tickLower, int24 tickUpper, uint128 amount) external returns (uint256 amount0, uint256 amount1);
    function poolFees() external view returns (uint128 token0, uint128 token1);
    function positions(bytes32) external view returns (uint128 liquidity, uint128 tokensOwed0, uint128 tokensOwed1);
    function quoteSwap(bool zeroForOne, int256 amountSpecified, uint160 sqrtPriceLimitX96) external view returns (int256 amount0, int256 amount1, uint160 sqrtPriceX96After, int24 tickAfter, uint128 liquidityAfter);
    function setFee(uint24 fee) external;
    function swap(address recipient, bool zeroForOne, int256 amountSpecified, uint160 sqrtPriceLimitX96, uint256 amountLimit, uint256 deadline, bytes calldata data) external returns (int256 amount0, int256 amount1);
    function swap(address recipient, bool zeroForOne, int256 amountSpecified, uint160 sqrtPriceLimitX96, bytes calldata data) external returns (int256 amount0, int256 amount1);
    function swap(address recipient, bool zeroForOne, int256 amountSpecified, uint160 sqrtPriceLimitX96, uint256 amountLimit, uint256 deadline, bytes calldata data, uint256 trackingCode) external returns (int256 amount0, int256 amount1);
    function swap(address recipient, bool zeroForOne, int256 amountSpecified, uint160 sqrtPriceLimitX96, uint256 trackingCode) external returns (int256 amount0, int256 amount1);
    function swap(address recipient, bool zeroForOne, int256 amountSpecified, uint160 sqrtPriceLimitX96, uint256 amountLimit, uint256 deadline) external returns (int256 amount0, int256 amount1);
    function swap(address recipient, bool zeroForOne, int256 amountSpecified, uint160 sqrtPriceLimitX96, uint256 amountLimit, uint256 deadline, uint256 trackingCode) external returns (int256 amount0, int256 amount1);
    function swap(address recipient, bool zeroForOne, int256 amountSpecified, uint160 sqrtPriceLimitX96, bytes calldata data, uint256 trackingCode) external returns (int256 amount0, int256 amount1);
    function swap(address recipient, bool zeroForOne, int256 amountSpecified, uint160 sqrtPriceLimitX96) external returns (int256 amount0, int256 amount1);
    function tickBitmap(int16) external view returns (uint256);
    function tickSpacing() external view returns (int24);
    function ticks(int24) external view returns (uint128 liquidityGross, int128 liquidityNet, bool initialized);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface ISolidlyV3Pool is ISolidlyV3PoolBase {
    function slot0() external view returns (uint160 sqrtPriceX96, int24 tick, uint24 fee, bool unlocked);
}
