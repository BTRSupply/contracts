// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IAlgebraV4Pool} from "@interfaces/IAlgebraV4Pool.sol";

interface ISwapXPool is IAlgebraV4Pool {
    function globalState() external view returns (
        uint160 price,
        int24 tick,
        uint16 lastFee,
        uint8 pluginConfig,
        uint16 communityFee,
        bool unlocked
    );
}
