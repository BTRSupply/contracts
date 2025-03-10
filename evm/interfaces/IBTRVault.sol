// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";
import { Range, Rebalance } from "../BTRTypes.sol";

/// @title IBTRVault interface for BTR LP vault
/// @notice Interface for smart contract managing liquidity providing strategy for a given token pair
/// using multiple Uniswap V3 LP positions on multiple fee tiers.
interface IBTRVault {
  function uniswapV3MintCallback(
    uint256 amount0Owed_,
    uint256 amount1Owed_,
    bytes calldata /*_data*/
  ) external;
  function mint(uint256 mintAmount_, address receiver_)
    external
    returns (uint256 amount0, uint256 amount1);
  function burn(uint256 burnAmount_, address receiver_)
    external
    returns (uint256 amount0, uint256 amount1);
  function rebalance(Rebalance calldata rebalanceParams_) external;
  function withdrawManagerBalance() external;

  // Storage getters
  function token0() external view returns (IERC20);
  function token1() external view returns (IERC20);
  function init0() external view returns (uint256);
  function init1() external view returns (uint256);
  function feeBps() external view returns (uint16);
  function managerBalance0() external view returns (uint256);
  function managerBalance1() external view returns (uint256);
  function manager() external view returns (address);
  function restrictedMint() external view returns (address);
  function factory() external view returns (address);
  function getRanges() external view returns (Range[] memory);
  function getPools() external view returns (address[] memory);
  function getRouters() external view returns (address[] memory);
}
