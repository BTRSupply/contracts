// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ALMVault, WithdrawProceeds, Range, ErrorType} from "@/BTRTypes.sol";
import {BTRErrors as Errors, BTREvents as Events} from "@libraries/BTREvents.sol";
import {BTRUtils} from "@libraries/BTRUtils.sol";
import {IAlgebraV3Pool} from "@interfaces/IAlgebraV3Pool.sol";
import {V3AdapterFacet} from "@facets/abstract/V3AdapterFacet.sol";
import {LibDEXMaths} from "@libraries/LibDEXMaths.sol";

contract AlgebraV3AdapterFacet is V3AdapterFacet {
    using SafeERC20 for IERC20;
    using BTRUtils for uint32;
    using BTRUtils for bytes32;

    function _getPoolSqrtPriceAndTick(
        address pool
    ) internal view override returns (uint160 sqrtPriceX96, int24 tick) {
        (sqrtPriceX96, tick, , , , , ) = IAlgebraV3Pool(pool).globalState();
    }

    function _observe(
        address pool,
        uint32[] memory secondsAgos
    )
        internal
        view
        override
        returns (
            int56[] memory tickCumulatives,
            uint160[] memory intervalSecondsX128
        )
    {
        (tickCumulatives, intervalSecondsX128, , ) = IAlgebraV3Pool(pool)
            .getTimepoints(secondsAgos);
        return (tickCumulatives, intervalSecondsX128);
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
        (liquidity, , , , fees0, fees1) = IAlgebraV3Pool(pool).positions(
            positionId
        );
    }

    function _mintPosition(
        address pool,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) internal virtual override returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = IAlgebraV3Pool(pool).mint(
            address(this),
            address(this),
            tickLower,
            tickUpper,
            liquidity,
            abi.encode(pool)
        );
    }

    function _burnPosition(
        address pool,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) internal virtual override returns (uint256 amount0, uint256 amount1) {
        // Burn position to release tokens
        (amount0, amount1) = IAlgebraV3Pool(pool).burn(
            tickLower,
            tickUpper,
            liquidity
        );
    }

    function algebraMintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external {
        _mintCallback(amount0Owed, amount1Owed, data);
    }
}
