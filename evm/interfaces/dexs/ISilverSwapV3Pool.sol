// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IAlgebraV3PoolBase} from "@interfaces/IAlgebraV3Pool.sol";

interface ISilverSwapV3Pool is IAlgebraV3PoolBase {
    function globalState()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 lastFee,
            uint8 pluginConfig,
            uint16 communityFee,
            bool unlocked
        );
}
