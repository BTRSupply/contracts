// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {SafeCast} from "@openzeppelin/utils/math/SafeCast.sol";

import {LibDiamond} from "@libraries/LibDiamond.sol";
import {LibAccessControl} from "@libraries/LibAccessControl.sol";
import {VaultStorage, PoolInfo, Range, ErrorType} from "../../../BTRTypes.sol";
import {DEXTypes} from "@libraries/DEXTypes.sol";
import {BTRStorage as S} from "@libraries/BTRStorage.sol";
import {BTRErrors as Errors, BTREvents as Events} from "@libraries/BTREvents.sol";
import {IUniV3NFPManager} from "@interfaces/IUniV3NFPManager.sol";
import {IUniV3PoolFactory} from "@interfaces/IUniV3PoolFactory.sol";
import {IUniV3Pool} from "@interfaces/IUniV3Pool.sol";
import {FixedPoint96} from "@libraries/FixedPoint96.sol";
import {Maths} from "@libraries/Maths.sol";

// Structs for internal use
struct Withdraw {
    uint256 burn0;
    uint256 burn1;
    uint256 fee0;
    uint256 fee1;
}

struct VaultOperationContext {
    address self;
    IERC20 asset;
    IERC20 token1;
    IUniV3PoolFactory factory;
}

/// @title Uniswap Position Manager Facet
/// @notice Manages Uniswap V3 positions for BTR vault
/// @dev Implements position management functions from the original PositionManager library
contract UniV3Facet {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    using Maths for uint256;

    // Modifiers
    modifier onlyUniswap(bytes32 dexType) {
        if (dexType != DEXTypes.UNISWAP) revert Errors.NotFound(ErrorType.DEX);
        _;
    }

    modifier whenNotPaused() {
        if (S.protocol().paused) revert Errors.Paused();
        _;
    }

    /**
     * @notice Get liquidity for a given range position
     * @param pool The Uniswap V3 pool address
     * @param owner The position owner
     * @param lowerTick The lower tick of the position
     * @param upperTick The upper tick of the position
     * @return liquidity The liquidity amount
     */
    function getLiquidityByRange(
        address pool,
        address owner,
        int24 lowerTick,
        int24 upperTick
    ) public view returns (uint128 liquidity) {
        (liquidity, , , , ) = IUniV3Pool(pool).positions(
            getPositionId(owner, lowerTick, upperTick)
        );
    }

    /**
     * @notice Generate position ID for a given position
     * @param owner The position owner
     * @param lowerTick The lower tick of the position
     * @param upperTick The upper tick of the position
     * @return positionId The position ID
     */
    function getPositionId(
        address owner,
        int24 lowerTick,
        int24 upperTick
    ) public pure returns (bytes32 positionId) {
        return keccak256(abi.encodePacked(owner, lowerTick, upperTick));
    }

    /**
     * @notice Check if a range exists in the current ranges
     * @param range Range to check
     * @return exists Whether the range exists
     * @return index The index of the range if it exists
     */
    function rangeExists(Range memory range)
        public
        view
        onlyUniswap(range.dexType)
        returns (bool exists, uint256 index)
    {
        VaultStorage storage vs = S.protocol().vault;
        Range[] storage ranges = vs.ranges;
        
        for (uint256 i; i < ranges.length; i++) {
            exists = 
                range.lowerTick == ranges[i].lowerTick &&
                range.upperTick == ranges[i].upperTick &&
                range.poolId == ranges[i].poolId &&
                range.dexType == ranges[i].dexType;
                
            if (exists) {
                index = i;
                break;
            }
        }
    }

    /**
     * @notice Validate tick spacing for a range
     * @param poolAddress The Uniswap V3 pool address
     * @param range The range to validate
     * @return valid Whether the tick spacing is valid
     */
    function validateTickSpacing(
        address poolAddress,
        Range memory range
    ) public view onlyUniswap(range.dexType) returns (bool valid) {
        int24 spacing = IUniV3Pool(poolAddress).tickSpacing();
        return
            range.lowerTick < range.upperTick &&
            range.lowerTick % spacing == 0 &&
            range.upperTick % spacing == 0;
    }

    /**
     * @notice Withdraw liquidity from a position
     * @param poolAddress The Uniswap V3 pool address
     * @param lowerTick The lower tick of the position
     * @param upperTick The upper tick of the position
     * @param liquidity The liquidity amount to withdraw
     * @return result Withdrawal information (burn0, burn1, fee0, fee1)
     */
    function withdraw(
        address poolAddress,
        int24 lowerTick,
        int24 upperTick,
        uint128 liquidity
    ) public whenNotPaused returns (Withdraw memory result) {
        // Only keeper can call this function
        LibAccessControl.checkRole(LibAccessControl.KEEPER_ROLE);
        
        IUniV3Pool pool = IUniV3Pool(poolAddress);
        
        // First burn the liquidity
        (result.burn0, result.burn1) = pool.burn(
            lowerTick,
            upperTick,
            liquidity
        );

        // Then collect all fees
        (uint256 collect0, uint256 collect1) = pool.collect(
            address(this),  // Diamond contract address
            lowerTick,
            upperTick,
            type(uint128).max,
            type(uint128).max
        );

        result.fee0 = collect0 - result.burn0;
        result.fee1 = collect1 - result.burn1;
        
        // Apply fees to manager balance
        _applyFees(result.fee0, result.fee1);
        
        emit Events.PositionWithdrawn(poolAddress, lowerTick, upperTick, liquidity, result.burn0, result.burn1, result.fee0, result.fee1);
    }
    
    /**
     * @notice Mint liquidity to a position
     * @param poolAddress The Uniswap V3 pool address
     * @param lowerTick The lower tick of the position
     * @param upperTick The upper tick of the position
     * @param liquidity The liquidity amount to mint
     * @return amount0 Amount of token0 used
     * @return amount1 Amount of token1 used
     */
    function mint(
        address poolAddress,
        int24 lowerTick,
        int24 upperTick,
        uint128 liquidity
    ) public whenNotPaused returns (uint256 amount0, uint256 amount1) {
        // Only keeper can call this function
        LibAccessControl.checkRole(LibAccessControl.KEEPER_ROLE);
        
        IUniV3Pool pool = IUniV3Pool(poolAddress);
        
        // Mint the position
        (amount0, amount1) = pool.mint(
            address(this),  // Diamond contract address
            lowerTick,
            upperTick,
            liquidity,
            ""
        );
        
        emit Events.PositionMinted(poolAddress, lowerTick, upperTick, liquidity, amount0, amount1);
    }
    
    /**
     * @notice Callback function for Uniswap V3 mint
     * @param amount0Owed Amount of token0 owed
     * @param amount1Owed Amount of token1 owed
     * @param data Additional data
     */
    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external {
        VaultStorage storage vs = S.protocol().vault;
        
        // Verify caller is a whitelisted pool
        if (!vs.whitelist[msg.sender]) revert Errors.Unauthorized(ErrorType.POOL);
        
        // Transfer tokens to the pool
        if (amount0Owed > 0) {
            vs.asset.safeTransfer(msg.sender, amount0Owed);
        }
        if (amount1Owed > 0) {
            vs.tokens[1].safeTransfer(msg.sender, amount1Owed);
        }
    }
    
    /**
     * @notice Add a range to the vault's ranges
     * @param range The range to add
     */
    function addRange(Range memory range) external whenNotPaused {
        // Only keeper can call this function
        LibAccessControl.checkRole(LibAccessControl.KEEPER_ROLE);
        
        // Verify DEX type is Uniswap
        if (range.dexType != DEXTypes.UNISWAP) revert Errors.NotFound(ErrorType.DEX);
        
        // Check if range already exists
        (bool exists, ) = rangeExists(range);
        if (exists) revert Errors.AlreadyExists(ErrorType.RANGE);
        
        // Add range to storage
        VaultStorage storage vs = S.protocol().vault;
        vs.ranges.push(range);
        
        emit Events.RangeAdded(range.poolId, range.lowerTick, range.upperTick, range.dexType);
    }
    
    /**
     * @notice Remove a range from the vault's ranges
     * @param range The range to remove
     */
    function removeRange(Range memory range) external whenNotPaused {
        // Only keeper can call this function
        LibAccessControl.checkRole(LibAccessControl.KEEPER_ROLE);
        
        // Verify DEX type is Uniswap
        if (range.dexType != DEXTypes.UNISWAP) revert Errors.NotFound(ErrorType.DEX);
        
        // Check if range exists
        (bool exists, uint256 index) = rangeExists(range);
        if (!exists) revert Errors.NotFound(ErrorType.RANGE);
        
        // Remove range from storage
        VaultStorage storage vs = S.protocol().vault;
        uint256 lastIndex = vs.ranges.length - 1;
        
        if (index != lastIndex) {
            vs.ranges[index] = vs.ranges[lastIndex];
        }
        
        vs.ranges.pop();
        
        emit Events.RangeRemoved(range.poolId, range.lowerTick, range.upperTick, range.dexType);
    }
    
    /**
     * @notice Get all ranges for the vault
     * @return Array of ranges
     */
    function getRanges() external view returns (Range[] memory) {
        return S.protocol().vault.ranges;
    }
    
    /**
     * @notice Apply fees to manager balance
     * @param fee0 Amount of token0 fees
     * @param fee1 Amount of token1 fees
     */
    function _applyFees(uint256 fee0, uint256 fee1) internal {
        VaultStorage storage vs = S.protocol().vault;
        uint16 feeBps = vs.feeBps;
        
        vs.managerTokenBalances[0] += fee0.bp(feeBps);
        vs.managerTokenBalances[1] += fee1.bp(feeBps);
    }
} 