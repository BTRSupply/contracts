// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IRamsesV3PoolNoObs} from "@interfaces/dexs/IRamsesV3Pool.sol";
import {IUniV3Observable} from "@interfaces/dexs/IUniV3Pool.sol";

interface IShadowV3Pool is IRamsesV3PoolNoObs, IUniV3Observable {
    function slot0() external view returns (uint160 sqrtPriceX96, int24 tick, uint16 observationIndex, uint16 observationCardinality, uint16 observationCardinalityNext, uint32 feeProtocol, bool unlocked);
}
