// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IUniV3PoolNoObs} from "@interfaces/dexs/IUniV3Pool.sol";

interface IRamsesObservable {
    function observations(uint256 index) external view returns (uint32 blockTimestamp, int56 tickCumulative, uint160 secondsPerLiquidityCumulativeX128, bool initialized, uint160 secondsPerBoostedLiquidityPeriodX128);
    function observe(uint32[] calldata secondsAgos) external view returns (int56[] memory tickCumulatives, uint160[] memory intervalSecondsX128, uint160[] memory secondsPerBoostedLiquidityPeriodX128s);
    function increaseObservationCardinalityNext(uint16 observationCardinalityNext) external;
    function snapshotCumulativesInside(int24 tickLower, int24 tickUpper) external view returns (int56 tickCumulativeInside, uint160 secondsPerLiquidityInsideX128, uint160 secondsPerBoostedLiquidityInsideX128, uint32 secondsInside);
    function positions(bytes32 key) external view returns (uint128 liquidity, uint256 innerFeeGrowth0X128, uint256 innerFeeGrowth1X128, uint128 fees0, uint128 fees1, uint256 veNftTokenId);
}

interface IRamsesV3PoolNoObs is IUniV3PoolNoObs {
    function _advancePeriod() external;
    function boostInfos(uint256 period) external view returns (uint128 totalBoostAmount, int128 totalVeNftAmount);
    function boostInfos(uint256 period, bytes32 key) external view returns (uint128 boostAmount, int128 veNftAmount, int256 secondsDebtX96, int256 boostedSecondsDebtX96);
    function boostedLiquidity() external view returns (uint128);
    function burn(uint256 index, int24 tickLower, int24 tickUpper, uint128 amount) external returns (uint256 amount0, uint256 amount1);
    function burn(uint256 index, int24 tickLower, int24 tickUpper, uint128 amount, uint256 veNftTokenId) external returns (uint256 amount0, uint256 amount1);
    function currentFee() external view returns (uint24);
    function lastPeriod() external view returns (uint256);
    function mint(address recipient, uint256 index, int24 tickLower, int24 tickUpper, uint128 amount, uint256 veNftTokenId, bytes calldata data) external returns (uint256 amount0, uint256 amount1);
    function nfpManager() external view returns (address);
    function periodCumulativesInside(uint32 period, int24 tickLower, int24 tickUpper) external view returns (uint160 secondsPerLiquidityInsideX128, uint160 secondsPerBoostedLiquidityInsideX128);
    function periods(uint256 period) external view returns (uint32 previousPeriod, int24 startTick, int24 lastTick, uint160 endSecondsPerLiquidityPeriodX128, uint160 endSecondsPerBoostedLiquidityPeriodX128, uint32 boostedInRange);
    function positionPeriodDebt(uint256 period, address owner, uint256 index, int24 tickLower, int24 tickUpper) external view returns (int256 secondsDebtX96, int256 boostedSecondsDebtX96);
    function positionPeriodSecondsInRange(uint256 period, address owner, uint256 index, int24 tickLower, int24 tickUpper) external view returns (uint256 periodSecondsInsideX96, uint256 periodBoostedSecondsInsideX96);
    function readStorage(bytes32[] calldata slots) external view returns (bytes32[] memory returnData);
    function setFee(uint24 _fee) external;
    function setFeeProtocol() external;
    function voter() external view returns (address);
    function votingEscrow() external view returns (address);
}

interface IRamsesV3PoolBase is IRamsesV3PoolNoObs, IRamsesObservable {}

interface IRamsesV3Pool is IRamsesV3PoolBase {
    function slot0() external view returns (
        uint160 sqrtPriceX96,
        int24 tick,
        uint16 observationIndex,
        uint16 observationCardinality,
        uint16 observationCardinalityNext,
        uint8 feeProtocol,
        bool unlocked
    );
    function veRam() external view returns (address);
}
