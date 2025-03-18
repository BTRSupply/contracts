// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {IAlgebraV3PoolBase} from "./IAlgebraV3Pool.sol";

interface ILynexV3Pool is IAlgebraV3PoolBase {
    function globalState()
        external
        view
        returns (
            uint160 price,
            int24 tick,
            uint16 fee,
            uint16 timepointIndex,
            uint16 communityFeeToken0,
            uint16 communityFeeToken1,
            bool unlocked
        );
}
