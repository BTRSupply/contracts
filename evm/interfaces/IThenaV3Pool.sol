// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IAlgebraV3Pool} from "@interfaces/IAlgebraV3Pool.sol";

interface IThenaV3Pool is IAlgebraV3Pool {
    function globalState() external view returns (
        uint160 price,
        int24 tick,
        uint16 lastFee,
        uint16 timepointIndex,
        uint16 communityFeeToken0,
        uint16 communityFeeToken1,
        bool unlocked
    );
}
