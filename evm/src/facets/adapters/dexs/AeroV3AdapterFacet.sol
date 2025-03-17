// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ALMVault, WithdrawProceeds, DEX} from "@/BTRTypes.sol";
import {BTRUtils} from "@libraries/BTRUtils.sol";
import {BTRErrors as Errors, BTREvents as Events} from "@libraries/BTREvents.sol";
import {VeloV3AdapterFacet} from "@dexs/VeloV3AdapterFacet.sol";
import {IAeroV3Pool} from "@interfaces/IAeroV3Pool.sol";

/**
 * @title AeroV3AdapterFacet
 * @notice Facet for interacting with Aerodrome V3 pools
 * @dev Extends VeloV3AdapterFacet as Aerodrome V3 is a fork of Velodrome V3 with the same interfaces
 */
contract AeroV3AdapterFacet is VeloV3AdapterFacet {
}
