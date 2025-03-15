// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IUniV3PoolBase} from "@interfaces/IUniV3Pool.sol";

interface IVeloV3Pool is IUniV3PoolBase {
  function burn(int24 tickLower, int24 tickUpper, uint128 amount, address owner) external returns (uint256 amount0, uint256 amount1);
  function collect(address recipient, int24 tickLower, int24 tickUpper, uint128 amount0Requested, uint128 amount1Requested, address owner) external returns (uint128 amount0, uint128 amount1);
  function collectFees() external returns (uint128 amount0, uint128 amount1);
  function factory() external view returns (address);
  function factoryRegistry() external view returns (address);
  function gauge() external view returns (address);
  function gaugeFees() external view returns (uint128 token0, uint128 token1);
  function getRewardGrowthInside(int24 tickLower, int24 tickUpper, uint256 _rewardGrowthGlobalX128) external view returns (uint256 rewardGrowthInside);
  function initialize(address _factory, address _token0, address _token1, int24 _tickSpacing, address _factoryRegistry, uint160 _sqrtPriceX96) external;
  function lastUpdated() external view returns (uint32);
  function nft() external view returns (address);
  function periodFinish() external view returns (uint256);
  function rewardGrowthGlobalX128() external view returns (uint256);
  function rewardRate() external view returns (uint256);
  function rewardReserve() external view returns (uint256);
  function rollover() external view returns (uint256);
  function setGaugeAndPositionManager(address _gauge, address _nft) external;
  function slot0() external view returns (
    uint160 sqrtPriceX96,
    int24 tick,
    uint16 observationIndex,
    uint16 observationCardinality,
    uint16 observationCardinalityNext,
    bool unlocked);
  function stake(int128 stakedLiquidityDelta, int24 tickLower, int24 tickUpper, bool positionUpdate) external;
  function stakedLiquidity() external view returns (uint128);
  function syncReward(uint256 _rewardRate, uint256 _rewardReserve, uint256 _periodFinish) external;
  function unstakedFee() external view returns (uint24);
  function updateRewardsGrowthGlobal() external;
}
