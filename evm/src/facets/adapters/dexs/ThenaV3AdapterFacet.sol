// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IThenaV3Pool} from "@interfaces/IThenaV3Pool.sol";
import {AlgebraV3AdapterFacet} from "@facets/adapters/dexs/AlgebraV3AdapterFacet.sol";

contract ThenaV3AdapterFacet is AlgebraV3AdapterFacet {
    function _getPoolSqrtPriceAndTick(address pool) internal view override returns (uint160 sqrtPriceX96, int24 tick) {
        (sqrtPriceX96, tick,,,,,) = IThenaV3Pool(pool).globalState();
    }
}
