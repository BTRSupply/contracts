// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IUniV3Pool} from "./IUniV3Pool.sol";

interface IThrusterV3Pool is IUniV3Pool {
    function setGauge(address _gauge) external;
    function gauge() external view returns (address);
    function claimYieldAll(address _recipient, uint256 _amountWETH, uint256 _amountUSDB) external returns (uint256 amountWETH, uint256 amountUSDB, uint256 amountGas);
}
