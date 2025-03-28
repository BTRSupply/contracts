// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ALMVault, WithdrawProceeds, Range, ErrorType} from "@/BTRTypes.sol";
import {BTRErrors as Errors, BTREvents as Events} from "@libraries/BTREvents.sol";
import {BTRUtils} from "@libraries/BTRUtils.sol";
import {IAlgebraV4Pool} from "@interfaces/dexs/IAlgebraV4Pool.sol";
import {V3AdapterFacet} from "@facets/abstract/V3AdapterFacet.sol";
import {LibDEXMaths} from "@libraries/LibDEXMaths.sol";

contract AlgebraV4AdapterFacet is V3AdapterFacet {
    using SafeERC20 for IERC20;
    using BTRUtils for uint32;
    using BTRUtils for bytes32;

    function _getPoolSqrtPriceAndTick(
        address pool
    ) internal view virtual override returns (uint160 sqrtPriceX96, int24 tick) {
        (sqrtPriceX96, tick, , , , , ) = IAlgebraV4Pool(pool).safelyGetStateOfAMM();
    }

    function _observe(
        address /* pool */,
        uint32[] memory /* secondsAgos */
    )
        internal
        pure
        override
        returns (
            int56[] memory /* tickCumulatives */,
            uint160[] memory /* intervalSecondsX128 */
        )
    {
        // V4 doesn't have getTimepoints at the pool level
        // TODO: Implement this
        revert Errors.NotFound(ErrorType.FUNCTION);
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
        // Handle return types from positions - liquidity is uint256, need to cast to uint128
        (uint256 liquidity256, , , uint128 f0, uint128 f1) = IAlgebraV4Pool(pool).positions(
            positionId
        );
        // Safe cast from uint256 to uint128, assumption: liquidity fits in uint128
        liquidity = uint128(liquidity256);
        fees0 = f0;
        fees1 = f1;
    }

    function _mintPosition(
        address pool,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) internal virtual override returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1, ) = IAlgebraV4Pool(pool).mint(
            address(this), // leftoverRecipient
            address(this), // recipient
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
        // Burn position to release tokens, V4 has additional data parameter
        (amount0, amount1) = IAlgebraV4Pool(pool).burn(
            tickLower,
            tickUpper,
            liquidity,
            abi.encode(pool) // Additional data parameter in V4
        );
    }

    // V4 uses the same callback but may need to be implemented differently
    function algebraMintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external {
        _mintCallback(amount0Owed, amount1Owed, data);
    }
}
