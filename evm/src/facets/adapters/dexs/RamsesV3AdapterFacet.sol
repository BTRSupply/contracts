// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IRamsesV3Pool} from "@interfaces/IRamsesV3Pool.sol";
import {UniV3AdapterFacet} from "@facets/adapters/dexs/UniV3AdapterFacet.sol";

contract RamsesV3AdapterFacet is UniV3AdapterFacet {
    function _getPoolSqrtPriceAndTick(
        address pool
    ) internal view override returns (uint160 sqrtPriceX96, int24 tick) {
        (sqrtPriceX96, tick, , , , , ) = IRamsesV3Pool(pool).slot0();
    }

    function _observe(
        address pool,
        uint32[] memory secondsAgos
    )
        internal
        view
        virtual
        returns (
            int56[] memory tickCumulatives,
            uint160[] memory intervalSecondsX128
        )
    {
        (tickCumulatives, intervalSecondsX128, ) = IRamsesV3Pool(pool).observe(secondsAgos);
    }

    function _getPosition(
        address pool,
        bytes32 positionId
    )
        internal
        view
        override
        returns (
            uint128 liquidity,
            uint128 fees0,
            uint128 fees1
        )
    {
        (liquidity, , , fees0, fees1, ) = IRamsesV3Pool(pool).positions(positionId);
    }

    function ramsesV2MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external {
        _mintCallback(amount0Owed, amount1Owed, data);
    }
}
