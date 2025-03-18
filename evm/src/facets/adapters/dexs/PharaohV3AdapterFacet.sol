// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IPharaohV3Pool} from "@interfaces/dexs/IPharaohV3Pool.sol";
import {RamsesV3AdapterFacet} from "@facets/adapters/dexs/RamsesV3AdapterFacet.sol";

contract PharaohV3AdapterFacet is RamsesV3AdapterFacet {
    function _getPoolSqrtPriceAndTick(
        address pool
    ) internal view virtual override returns (uint160 sqrtPriceX96, int24 tick) {
        (sqrtPriceX96, tick, , , , , ) = IPharaohV3Pool(pool).slot0();
    }
}
