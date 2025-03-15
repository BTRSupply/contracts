// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LibDEXMaths} from "@libraries/LibDEXMaths.sol";

/**
 * @title DEXAdapter
 * @notice Base contract for DEX-specific adapters
 * @dev Implements common functionality for interacting with various DEX pools
 */
abstract contract DEXAdapterFacet {
    using LibDEXMaths for uint160;
    using LibDEXMaths for int24;

    /// @notice Struct to hold pool state information
    struct PoolState {
        uint160 sqrtPriceX96;
        int24 tick;
        uint16 observationCardinality;
        uint16 observationCardinalityNext;
        uint8 feeProtocol;
        bool unlocked;
    }

    /// @notice Struct to hold position information
    struct PositionInfo {
        uint128 liquidity;
        uint256 innerFeeGrowth0X128;
        uint256 innerFeeGrowth1X128;
        uint128 fees0;
        uint128 fees1;
    }

    /// @notice Struct for minting parameters
    struct MintParams {
        address pool;
        address recipient;
        int24 tickLower;
        int24 upperTick;
        uint128 amount;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    /// @notice Struct for burning parameters
    struct BurnParams {
        address pool;
        int24 tickLower;
        int24 upperTick;
        uint128 amount;
    }

    /// @notice Struct for collecting fees parameters
    struct CollectParams {
        address pool;
        address recipient;
        int24 tickLower;
        int24 upperTick;
        uint128 amount0Requested;
        uint128 amount1Requested;
    }

    /// @notice Struct for swap parameters
    struct SwapParams {
        address pool;
        address recipient;
        bool zeroForOne;
        uint256 amountSpecified;
        uint160 sqrtPriceLimitX96;
        bytes data;
    }

    /**
     * @notice Get the current state of a pool
     * @param pool Address of the pool
     * @return state Current pool state
     */
    function getPoolState(address pool) external view virtual returns (PoolState memory state);

    /**
     * @notice Get information about a specific position
     * @param pool Address of the pool
     * @param owner Owner of the position
     * @param tickLower Lower tick of the position
     * @param upperTick Upper tick of the position
     * @return position Position information
     */
    function getPositionInfo(
        address pool,
        address owner,
        int24 tickLower,
        int24 upperTick
    ) external view virtual returns (PositionInfo memory position);

    /**
     * @notice Add liquidity to a pool
     * @param params Minting parameters
     * @return amount0 Amount of token0 added
     * @return amount1 Amount of token1 added
     */
    function mint(MintParams calldata params) 
        external 
        virtual 
        returns (uint256 amount0, uint256 amount1);

    /**
     * @notice Remove liquidity from a pool
     * @param params Burning parameters
     * @return amount0 Amount of token0 removed
     * @return amount1 Amount of token1 removed
     */
    function burn(BurnParams calldata params)
        external
        virtual
        returns (uint256 amount0, uint256 amount1);

    /**
     * @notice Collect accumulated fees
     * @param params Collection parameters
     * @return amount0 Amount of token0 collected
     * @return amount1 Amount of token1 collected
     */
    function collect(CollectParams calldata params)
        external
        virtual
        returns (uint256 amount0, uint256 amount1);

    /**
     * @notice Execute a swap
     * @param params Swap parameters
     * @return amount0 Amount of token0 swapped
     * @return amount1 Amount of token1 swapped
     */
    function swap(SwapParams calldata params)
        external
        virtual
        returns (uint256 amount0, uint256 amount1);

    /**
     * @notice Check if a tick spacing is valid for this DEX
     * @param tickSpacing The tick spacing to validate
     * @return valid Whether the tick spacing is valid
     */
    function isValidTickSpacing(int24 tickSpacing) external view virtual returns (bool valid);

    /**
     * @notice Get the fee tier for a pool
     * @param pool Address of the pool
     * @return feeTier The pool's fee tier
     */
    function getFeeTier(address pool) external view virtual returns (uint24 feeTier);

    /**
     * @notice Calculate amounts of tokens for given liquidity
     * @param pool Address of the pool
     * @param tickLower Lower tick
     * @param upperTick Upper tick
     * @param liquidity Amount of liquidity
     * @return amount0 Amount of token0
     * @return amount1 Amount of token1
     */
    function getTokenAmounts(
        address pool,
        int24 tickLower,
        int24 upperTick,
        uint128 liquidity
    ) external view virtual returns (uint256 amount0, uint256 amount1);

    /**
     * @notice Get the protocol fees accumulated in a pool
     * @param pool Address of the pool
     * @return token0Fees Protocol fees in token0
     * @return token1Fees Protocol fees in token1
     */
    function getProtocolFees(address pool) 
        external 
        view 
        virtual 
        returns (uint128 token0Fees, uint128 token1Fees);

    /**
     * @notice Get the tokens in a pool
     * @param pool Address of the pool
     * @return token0 Address of token0
     * @return token1 Address of token1
     */
    function getPoolTokens(address pool)
        external
        view
        virtual
        returns (address token0, address token1);
} 