// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@/BTRTypes.sol";
import {IDiamondCut} from "@interfaces/IDiamondCut.sol";

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
  error UnexpectedInput();
  error UnexpectedOutput();
  error SwapFailed();
  error RouterError();
  error DelegateCallFailed();
  error StaticCallFailed();
  error CallRestricted();
  error SlippageTooHigh();
  error StalePrice();

  // ERC20/ERC1155 errors - keeping these as they are standard
  error TransferExceedsBalance();
  error InsufficientAllowance();
  error BurnExceedsBalance();
}

library BTREvents {
  // Events

  // Diamond specific events
  event DiamondCut(IDiamondCut.FacetCut[] _diamondCut, address _init, bytes _calldata);
  event FunctionAdded(address indexed facetAddress, bytes4 selector);
  event FunctionReplaced(address indexed oldFacetAddress, address indexed newFacetAddress, bytes4 selector);
  event FunctionRemoved(address indexed facetAddress, bytes4 selector);
  event FacetAdded(address indexed facetAddress);
  event FacetRemoved(address indexed facetAddress);
  event InitializationFailed(address indexed initContract, bytes reason);

  // Core operation events
  event VaultCreated(uint32 indexed vaultId, address indexed creator, VaultInitParams params);
  event SharesMinted(address indexed receiver, uint256 mintAmount, uint256 amount0, uint256 amount1);
  event SharesBurnt(address indexed receiver, uint256 burnAmount, uint256 amount0, uint256 amount1);
  event PositionsBurned(address indexed user, uint256 amount0, uint256 amount1);
  event RebalanceExecuted(Rebalance rebalanceParams, uint256 balance0After, uint256 balance1After);
  event EmergencyWithdrawal(address token, uint256 amount, address owner);
  event Paused(uint32 indexed scope, address indexed by);
  event Unpaused(uint32 indexed scope, address indexed by);
  event FeesUpdated(uint32 indexed scope, uint16 entry, uint16 exit, uint16 mgmt, uint16 perf, uint16 flash);
  event FeesCollected(uint32 indexed scope, address indexed token0, address indexed token1, uint256 fee0, uint256 fee1);
  event FeesAccrued(uint32 indexed vaultId, address indexed token0, address indexed token1, uint256 fee0, uint256 fee1);

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
  event RangeMinted(bytes32 indexed rangeId, uint128 liquidity, uint256 amount0, uint256 amount1);
  event RangeBurnt(bytes32 indexed rangeId, uint128 liquidity, uint256 burn0, uint256 burn1, uint256 fee0, uint256 fee1);
  event RangeAdded(bytes32 indexed poolId, int24 lowerTick, int24 upperTick, DEX dex);
  event RangeRemoved(bytes32 indexed poolId, int24 lowerTick, int24 upperTick, DEX dex);

  // Protocol management events
  event VersionUpdated(uint8 version);
  event TreasuryUpdated(address indexed treasury);
  event PoolInfoAdded(bytes32 indexed poolId, DEX dex, address token0, address token1);
  event PoolInfoRemoved(bytes32 indexed poolId);
  event AccountStatusUpdated(
    address indexed account,
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
  event RescueRequested(address indexed receiver, uint64 timestamp, TokenType tokenType, bytes32[] tokens);
  event RescueExecuted(address indexed token, address indexed receiver, uint256 amount, TokenType tokenType);
  event RescueCancelled(address indexed receiver, TokenType tokenType, bytes32[] tokens);
  event TokenRescued(address indexed token, uint256 indexed tokenId, address indexed receiver);
  event RescueFailed(address indexed token, uint256 indexed tokenId, string reason);

  // Swapper events
  event Swapped(address indexed user, address indexed assetIn, address indexed assetOut, uint256 amountIn, uint256 amountOut);
  event SwapperInitialized(bool restrictSwapCaller, bool restrictSwapRouter, bool approveMax, bool autoRevoke);
  
  // Restriction management events
  event RestrictionUpdated(uint8 indexed restrictionType, bool enabled);
  event RestrictionsInitialized(bool restrictSwapCaller, bool restrictSwapRouter, bool approveMax, bool autoRevoke);
  
  // TWAP protection events
  event DefaultPriceProtectionUpdated(uint32 lookback, uint256 maxDeviation);
  event VaultPriceProtectionUpdated(uint32 indexed vaultId, uint32 lookback, uint256 maxDeviation);
}
