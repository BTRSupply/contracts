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
  error NotFound(ErrorType _type);
  error Unauthorized(ErrorType _type);
  error AlreadyExists(ErrorType _type);
  error Insufficient(uint256 actual, uint256 minimum);
  error Exceeds(uint256 actual, uint256 maximum);
  error OutOfRange(uint256 actual, uint256 minimum, uint256 maximum);
  error AlreadyInitialized();
  error Failed(ErrorType _type);
  error Paused(ErrorType _type);
  error NotPaused(ErrorType _type);
  error Locked();
  error Expired(ErrorType _type);
  error NotZero(uint256 value);
  error WrongOrder(ErrorType _type);
  error InitializationFailed();
  
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
  event RebalanceExecuted(Rebalance rebalanceParams, uint256 balance0After, uint256 balance1After);
  event EmergencyWithdrawal(address token, uint256 amount, address owner);
  event Paused(uint32 indexed scope, address indexed by);
  event Unpaused(uint32 indexed scope, address indexed by);
  event FeesUpdated(uint32 indexed scope, uint16 entry, uint16 exit, uint16 mgmt, uint16 perf, uint16 flash);
  event FeesCollected(uint256 fee0, uint256 fee1);

  // Additional vault events
  event MaxSupplyUpdated(uint32 indexed vaultId, uint256 newCapacity);
  event MintRestricted(uint32 indexed vaultId, address by);
  event MintUnrestricted(uint32 indexed vaultId, address by);
  event PoolInfoAdded(address indexed pool, uint24 feeTier);
  event PoolInfoRemoved(address indexed pool);
  event RouterAdded(address indexed router);
  event RouterRemoved(address indexed router);
  event FeeTierStatusUpdated(uint24 feeTier, bool allowed);
  event BlacklistUpdated(address indexed target);
  
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

  // Protocol management events
  event VersionUpdated(uint8 version);
  event TreasuryUpdated(address indexed treasury);
  event PoolInfoAdded(bytes32 indexed poolId, bytes32 dexType, address token0, address token1);
  event PoolInfoRemoved(bytes32 indexed poolId);
  event AccountStatusUpdated(
    address indexed account,
    uint32 indexed vaultId,
    AccountStatus prev,
    AccountStatus status
  );

  // Access control events
  event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
  event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
  event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
  event RoleAcceptanceCreated(bytes32 indexed role, address indexed account, address indexed sender);
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
  event TimelockConfigUpdated(uint256 grantDelay, uint256 acceptWindow);
  
  // Rescue events
  event RescueConfigUpdated(uint64 timelock, uint64 validity);
  event RescueRequested(address indexed receiver, uint8 tokenType, bytes32[] tokens);
  event RescueExecuted(address indexed receiver, uint8 tokenType, bytes32[] tokens, uint256 count);
  event RescueCancelled(address indexed receiver, uint8 tokenType, bytes32[] tokens);

  // Swapper events
  event Swapped(address indexed user, address indexed assetIn, address indexed assetOut, uint256 amountIn, uint256 amountOut);
  event SwapRestrictionUpdated(uint8 indexed restrictionType, bool enabled);
}
