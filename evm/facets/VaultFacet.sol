// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibAccessControl} from "../libraries/LibAccessControl.sol";
import {VaultStorage, Rebalance} from "../BTRTypes.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/utils/math/Math.sol";
import {IERC4626} from "@openzeppelin/interfaces/IERC4626.sol";
import {BTRStorage as S} from "../libraries/BTRStorage.sol";
import {BTRErrors as Errors, BTREvents as Events} from "../libraries/BTREvents.sol";
import {LibVaultMath} from "../libraries/LibVaultMath.sol";
import {ERC20Facet} from "./abstract/ERC20Facet.sol";
import {Maths} from "../libraries/Maths.sol";
import {PermissionedFacet} from "./abstract/PermissionedFacet.sol";
import {PausableFacet} from "./abstract/PausableFacet.sol";
import {NonReentrantFacet} from "./abstract/NonReentrantFacet.sol";

/// @title BTR Vault Facet
/// @dev BTR-specific functionality for vault management
contract VaultFacet is PermissionedFacet, PausableFacet, NonReentrantFacet {
  using SafeERC20 for IERC20;
  using Math for uint256;

  function initialize(
    string calldata _name,
    string calldata _symbol,
    address _asset,
    address _token1,
    uint256 _initialToken0Amount,
    uint256 _initialToken1Amount,
    uint16 _feeBps,
    uint256 _maxSupply
  ) external onlyAdmin {
    VaultStorage storage vs = S.vault();
    
    // Ensure vault is not already initialized
    if (address(vs.asset) != address(0)) {
      revert Errors.AlreadyInitialized();
    }

    // Set vault properties
    vs.name = _name;
    vs.symbol = _symbol;
    
    // Set tokens
    vs.asset = IERC20Metadata(_asset);
    
    // Initialize tokens array
    if (vs.tokens.length == 0) {
      vs.tokens = new IERC20Metadata[](2);
    }
    vs.tokens[0] = IERC20Metadata(_asset);  // Primary asset as tokens[0]
    vs.tokens[1] = IERC20Metadata(_token1); // Secondary token as tokens[1]
    vs.decimals = vs.tokens[0].decimals();
    
    // Set initial values
    vs.initialTokenAmounts = new uint256[](2);
    vs.initialTokenAmounts[0] = _initialToken0Amount;
    vs.initialTokenAmounts[1] = _initialToken1Amount;
    vs.initialShareAmount = _initialToken0Amount; // Set initial shares equal to initial token0 amount
    
    // Initialize manager token balances
    vs.managerTokenBalances = new uint256[](2);
    vs.managerTokenBalances[0] = 0; // Initialize manager token0 balance to 0
    vs.managerTokenBalances[1] = 0; // Initialize manager token1 balance to 0
    
    // Set fee
    if (_feeBps > Maths.BP_BASIS) {
      revert Errors.Exceeds(_feeBps, Maths.BP_BASIS);
    }
    vs.feeBps = _feeBps;
    
    // Set max supply
    vs.maxSupply = _maxSupply;
    
    // Initialize pause state (not paused by default)
    vs.paused = false;
    
    // Initialize global mint restriction (false by default)
    vs.restrictedMint = false;
    
    emit Events.LogSetInits(_initialToken0Amount, _initialToken1Amount);
  }

  function rebalance(Rebalance calldata _rebalance) external whenNotPaused onlyKeeper {
    // Rebalance implementation would go here
    // This would typically:
    // 1. Exit specified positions
    // 2. Create new positions with specified weights
    // 3. Optionally swap tokens to rebalance token holdings
    
    // For now, just emit the event
    emit Events.RebalanceExecuted(
      _rebalance,
      LibVaultMath.calculateTotalAssets(),
      LibVaultMath.calculateTotalToken1()
    );
  }

  // View functions

  function getMaxSupply() external view returns (uint256) {
    return S.vault().maxSupply;
  }

  function isRestrictedMint() external view returns (bool) {
    return S.vault().restrictedMint;
  }

  function isPoolAllowed(address pool) external view returns (bool) {
    return S.vault().whitelist[pool];
  }

  function isRouterAllowed(address router) external view returns (bool) {
    return S.vault().whitelist[router];
  }

  function getfeeBps() external view returns (uint16) {
    return S.vault().feeBps;
  }

  function getManagerBalances() external view returns (uint256 amount0, uint256 amount1) {
    VaultStorage storage vs = S.vault();
    return (vs.managerTokenBalances[0], vs.managerTokenBalances[1]);
  }

  function isRestrictedMinter(address minter) external view returns (bool) {
    return S.vault().restrictedMint[minter];
  }
}
