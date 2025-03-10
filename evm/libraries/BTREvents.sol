// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../BTRTypes.sol";

/**
 * @title BTREvents
 * @notice Library for BTR error messages and events
 * @dev Centralizes all error codes and events for BTR contracts
 */
library BTRErrors {
  // Common consolidated errors
  error ZeroValue();
  error ZeroAddress();
  error InvalidParameter();
  error NotFound(ErrorType identifier);
  error Unauthorized(ErrorType identifier);
  error AlreadyExists(ErrorType identifier);
  error Insufficient(uint256 actual, uint256 minimum);
  error Exceeds(uint256 actual, uint256 maximum);
  error OutOfRange(uint256 actual, uint256 minimum, uint256 maximum);
  error AlreadyInitialized();
  error Failed(ErrorType operation);
  error Paused();
  error NotPaused();
  error Locked();
  error Expired(ErrorType type_);
  error NotZero(uint256 value);
  error WrongOrder(ErrorType type_);
  error InitializationFailed();
  
  // Diamond specific errors from BTRDiamond.sol
  error ZeroOwnerAddress();
  error ZeroDiamondCutAddress();
  error FunctionNotFound();
  error EthNotAccepted();

  // Math errors from Maths.sol
  error ValueOutOfCastRange();
  
  // ERC20 errors - keeping these as they are standard
  error TransferExceedsBalance();
  error InsufficientAllowance();
  error BurnExceedsBalance();
  
  // Swapper specific error that doesn't fit the consolidated patterns
  error UnexpectedOutput();
}

library BTREvents {
  // Events

  // Core operation events
  event MintCompleted(address indexed receiver, uint256 mintAmount, uint256 amount0, uint256 amount1);
  event BurnCompleted(address indexed receiver, uint256 burnAmount, uint256 amount0, uint256 amount1);
  event PositionsBurned(address indexed user, uint256 amount0, uint256 amount1);
  event FeesCollected(uint256 fee0, uint256 fee1);
  event RebalanceExecuted(Rebalance rebalanceParams, uint256 balance0After, uint256 balance1After);
  event EmergencyWithdrawal(address token, uint256 amount, address owner);

  // Manager events
  event LogWithdrawManagerBalance(uint256 amount0, uint256 amount1);
  
  // Configuration events
  event LogSetInits(uint256 init0, uint256 init1);
  event FeesSet(uint16 feeBps);
  event CollectedFees(uint256 fee0, uint256 fee1);
  
  // Additional vault events
  event VaultPaused(address indexed manager);
  event VaultUnpaused(address indexed manager);
  event MaxSupplyUpdated(uint256 newCapacity);
  event restrictedMintUpdated(bool restricted);
  event PoolAdded(address indexed pool, uint24 feeTier);
  event PoolRemoved(address indexed pool);
  event RouterAdded(address indexed router);
  event RouterRemoved(address indexed router);
  event FeeTierStatusUpdated(uint24 feeTier, bool allowed);
  event BlacklistUpdated(address indexed target, uint8 AddressType);
  
  // ERC20 events
  event Transfer(address indexed from, address indexed to, uint256 amount);
  event Approval(address indexed owner, address indexed spender, uint256 amount);
  
  // ERC4626 events
  event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
  event Withdraw(address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares);

  // Position management events
  event PositionMinted(address indexed pool, int24 lowerTick, int24 upperTick, uint128 liquidity, uint256 amount0, uint256 amount1);
  event PositionWithdrawn(address indexed pool, int24 lowerTick, int24 upperTick, uint128 liquidity, uint256 burn0, uint256 burn1, uint256 fee0, uint256 fee1);
  event RangeAdded(bytes32 indexed poolId, int24 lowerTick, int24 upperTick, bytes32 dexType);
  event RangeRemoved(bytes32 indexed poolId, int24 lowerTick, int24 upperTick, bytes32 dexType);
  
  // DEX management events
  event DEXAdded(bytes32 indexed dexType);
  event DEXRemoved(bytes32 indexed dexType);
  event PoolInfoAdded(bytes32 indexed poolId, bytes32 dexType, address token0, address token1, uint24 fee);
  
  // Access control events
  event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
  event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
  event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
  event RoleAcceptanceCreated(bytes32 indexed role, address indexed account, address indexed sender);
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
  event TimelockConfigUpdated(uint256 grantDelay, uint256 acceptWindow);
  
  // Rescuable events
  event RescueConfigUpdated(uint64 timelock, uint64 validity);
  event RescueRequested(address indexed token, address indexed receiver, uint64 timestamp);
  event RescueExecuted(address indexed token, address indexed receiver, uint256 amount);
  event RescueCancelled(address indexed token, address indexed requester);

  // Swapper events
  event Swapped(address indexed user, address indexed assetIn, address indexed assetOut, uint256 amountIn, uint256 amountOut);
  event AddressWhitelisted(address indexed account);
  event AddressRemovedFromWhitelist(address indexed account);
  event SwapRestrictionUpdated(uint8 indexed restrictionType, bool enabled);
}
