// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IUniV3Pool} from "@interfaces/dexs/IUniV3Pool.sol";

interface IKyoV3Pool is IUniV3Pool {
    function stake(int24 tickLower, int24 tickUpper, uint128 amount) external;
    function unstake(int24 tickLower, int24 tickUpper, uint128 amount) external;
}
