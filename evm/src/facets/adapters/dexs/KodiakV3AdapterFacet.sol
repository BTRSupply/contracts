// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IKodiakV3Pool} from "@interfaces/IKodiakV3Pool.sol";
import {UniV3AdapterFacet} from "@facets/adapters/dexs/UniV3AdapterFacet.sol";

contract KodiakV3AdapterFacet is UniV3AdapterFacet {
    function _getPoolSqrtPriceAndTick(
        address pool
    ) internal view override returns (uint160 sqrtPriceX96, int24 tick) {
        (sqrtPriceX96, tick, , , , , ) = IKodiakV3Pool(pool).slot0();
    }
} 