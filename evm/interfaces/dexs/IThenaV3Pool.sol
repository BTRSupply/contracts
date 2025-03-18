// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IAlgebraV3Pool} from "@interfaces/dexs/IAlgebraV3Pool.sol";

interface IThenaV3Pool is IAlgebraV3Pool {
    function globalState() external view override returns (
        uint160 price,
        int24 tick,
        uint16 fee,
        uint16 timepointIndex,
        uint8 communityFeeToken0,
        uint8 communityFeeToken1,
        bool unlocked
    );
}
