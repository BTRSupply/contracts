// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IUniV3PoolBase} from "@interfaces/dexs/IUniV3Pool.sol";

interface ICakeV3Pool is IUniV3PoolBase {
    function lmPool() external view returns (address);
    function setFeeProtocol(uint32 feeProtocol0, uint32 feeProtocol1) external;
    function setLmPool(address _lmPool) external;
    function slot0() external view returns (uint160 sqrtPriceX96, int24 tick, uint16 observationIndex, uint16 observationCardinality, uint16 observationCardinalityNext, uint32 feeProtocol, bool unlocked);
}
