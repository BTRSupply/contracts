// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {ALMVault, Range, WithdrawProceeds, ErrorType, DEX} from "@/BTRTypes.sol";
import {BTRErrors as Errors, BTREvents as Events} from "@libraries/BTREvents.sol";
import {BTRUtils} from "@libraries/BTRUtils.sol";
import {IUniV3Pool} from "@interfaces/IUniV3Pool.sol";
import {IUniV3NFPManager} from "@interfaces/IUniV3NFPManager.sol";
import {V3AdapterFacet} from "@facets/abstract/V3AdapterFacet.sol";
import {LibDEXMaths} from "@libraries/LibDEXMaths.sol";

/**
 * @title UniV3AdapterFacet
 * @notice Facet for interacting with Uniswap V3 pools
 * @dev Implements V3-specific functionality for Uniswap V3
 */
contract UniV3AdapterFacet is V3AdapterFacet {
    using SafeERC20 for IERC20;
    using BTRUtils for uint32;
    using BTRUtils for bytes32;
    using LibDEXMaths for int24;
    using LibDEXMaths for uint160;

    /**
     * @notice Callback function for Uniswap V3 minting
     * @param amount0Owed Amount of token0 to pay
     * @param amount1Owed Amount of token1 to pay
     * @param data Callback data containing pool and minimum amounts
     */
    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external {
        _mintCallback(amount0Owed, amount1Owed, data);
    }
}
