// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ICakeV3Pool} from "@interfaces/dexs/ICakeV3Pool.sol";
import {UniV3AdapterFacet} from "@facets/adapters/dexs/UniV3AdapterFacet.sol";

contract CakeV3AdapterFacet is UniV3AdapterFacet {
    function _getPoolSqrtPriceAndTick(
        address pool
    ) internal view override returns (uint160 sqrtPriceX96, int24 tick) {
        (sqrtPriceX96, tick, , , , , ) = ICakeV3Pool(pool).slot0();
    }
}
