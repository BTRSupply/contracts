// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ALMVault, WithdrawProceeds, Range} from "@/BTRTypes.sol";
import {BTRErrors as Errors, BTREvents as Events} from "@libraries/BTREvents.sol";
import {BTRUtils} from "@libraries/BTRUtils.sol";
import {IVeloV3Pool} from "@interfaces/IVeloV3Pool.sol";
import {UniV3AdapterFacet} from "@dexs/UniV3AdapterFacet.sol";

/**
 * @title VeloV3AdapterFacet
 * @notice Facet for interacting with Velodrome V3 pools
 * @dev Implements V3-specific functionality for Velodrome V3
 */
contract VeloV3AdapterFacet is UniV3AdapterFacet {
    using SafeERC20 for IERC20;
    using BTRUtils for uint32;
    using BTRUtils for bytes32;

    /**
     * @inheritdoc UniV3AdapterFacet
     * @dev Implementation for Velodrome V3
     */
    function _getPoolSqrtPriceAndTick(
        address pool
    ) internal view virtual override returns (uint160 sqrtPriceX96, int24 tick) {
        (sqrtPriceX96, tick,,,,) = IVeloV3Pool(pool).slot0();
        return (sqrtPriceX96, tick);
    }
}
