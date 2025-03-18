// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// is IUniV3PoolDeployer
interface IUniV3PoolFactory {
    function createPool(address tokenA, address tokenB, uint24 fee) external returns (address pool);
    function enableFeeAmount(uint24 fee, int24 tickSpacing) external;
    function feeAmountTickSpacing(uint24) external view returns (int24);
    function getPool(address, address, uint24) external view returns (address);
    function owner() external view returns (address);
    function parameters() external view returns (address factory, address token0, address token1, uint24 fee, int24 tickSpacing);
    function setOwner(address _owner) external;
}
