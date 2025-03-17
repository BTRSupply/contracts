// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ISwapXPool} from "@interfaces/ISwapXPool.sol";
import {AlgebraV4AdapterFacet} from "@facets/adapters/dexs/AlgebraV4AdapterFacet.sol";

contract SwapXAdapterFacet is AlgebraV4AdapterFacet {
    function _getPoolSqrtPriceAndTick(address pool) internal view override returns (uint160 sqrtPriceX96, int24 tick) {
        (sqrtPriceX96, tick, , , , ) = ISwapXPool(pool).globalState();
    }
}
