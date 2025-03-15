// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {LibDiamond} from "@libraries/LibDiamond.sol";
import {LibAccessControl} from "@libraries/LibAccessControl.sol";
import {LibTreasury as T} from "@libraries/LibTreasury.sol";
import {ALMVault, PoolInfo, Range, Rebalance, AddressType, SwapPayload, CoreStorage, ErrorType, VaultInitParams, DEX, Registry, VaultInfo} from "@/BTRTypes.sol";
import {BTRStorage as S} from "@libraries/BTRStorage.sol";
import {BTRErrors as Errors, BTREvents as Events} from "@libraries/BTREvents.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {LibMaths as M} from "@libraries/LibMaths.sol";
import {LibERC1155} from "@libraries/LibERC1155.sol";
import {BTRUtils} from "@libraries/BTRUtils.sol";
import {DEXAdapter} from "@facets/abstract/DEXAdapter.sol";

library LibALM {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    using M for uint256;
    using BTRUtils for uint32;
    using BTRUtils for bytes32;

    uint256 private constant MAX_RANGES = 20;

    /**
     * @notice Enforce that an array has a positive length
     * @param length The length to validate
     */
    function checkRangesArrayLength(uint256 length) internal pure {
        if (length == 0) revert Errors.ZeroValue();
        if (length > MAX_RANGES) revert Errors.Exceeds(length, MAX_RANGES);
    }
    
    function createVault(
        VaultInitParams calldata params
    ) internal returns (uint32 vaultId) {
        if (params.token0 == address(0) || params.token1 == address(0))
            revert Errors.ZeroAddress();
        if (params.initAmount0 == 0 || params.initAmount1 == 0)
            revert Errors.ZeroValue(); // initial token amounts must be non-zero
        if (uint160(params.token0) >= uint160(params.token1))
            revert Errors.WrongOrder(ErrorType.TOKEN); // strict ordering in vault pair

        CoreStorage storage cs = S.core();

        vaultId = cs.registry.vaultCount + 1; // index 0 is reserved for protocol accounting
        ALMVault storage vs = cs.registry.vaults[vaultId];
        vs.id = vaultId;

        vs.name = params.name;
        vs.symbol = params.symbol;

        vs.token0 = params.token0;
        vs.token1 = params.token1;
        vs.decimals = 18; // Default to 18 decimals

        vs.initAmount0 = params.initAmount0;
        vs.initAmount1 = params.initAmount1;
        vs.initShares = params.initShares;
        vs.fees = cs.treasury.defaultFees;
        vs.maxSupply = type(uint256).max;
        vs.paused = false;
        vs.restrictedMint = true; // default to restricted mint to avoid liquidity drain/front-running

        // Set TWAP protection parameters - use defaults if not specified
        vs.lookback = cs.oracles.lookback;
        vs.maxDeviation = cs.oracles.maxDeviation;
        cs.registry.vaultCount++;

        emit Events.VaultCreated(vaultId, msg.sender, params);
        return vaultId;
    }

    function getDexAdapter(DEX dex) internal view returns (address) {
        return S.registry().dexAdapters[dex];
    }

    function getDexAdapter(bytes32 poolId) internal view returns (address) {
        Registry storage registry = S.registry();
        return registry.dexAdapters[registry.poolInfo[poolId].dex];
    }

    function updateDexAdapter(DEX dex, address adapter) internal {
        // ensure that new dexs are sequentially added (if dex is not 0)
        uint8 dexIndex = uint8(dex);
        Registry storage registry = S.registry();
        if (dexIndex > 0 && registry.dexAdapters[DEX(dexIndex - 1)] != address(0))
            revert Errors.UnexpectedInput();
        registry.dexAdapters[dex] = adapter;
    }

    // should return the current weights of token0 and token1 in the vault
    // to reflect the 
    function getRatios0(
        uint32 vaultId
    ) internal view returns (uint256[] memory ratios0) {      
        ALMVault storage vs = vaultId.getVault();
        if (vs.ranges.length == 0) {
            revert Errors.NotFound(ErrorType.RANGE);
        }
        ratios0 = new uint256[](vs.ranges.length);
        for (uint256 i = 0; i < vs.ranges.length;) {
            Range storage range = vs.ranges[i];
            address adapterAddress = getDexAdapter(range.poolId);
            uint256 ratio0 = _getRangeRatio0(adapterAddress, range.id);
            ratios0[i] = ratio0;
            unchecked {
                i++;
            }
        }
    }
    
    /**
     * @notice Calculate the token ratio for a range with standardized liquidity
     * @param adapterAddress The DEX adapter address
     * @param rangeId The range ID
     * @return ratio0 Amount of token0 for standardized liquidity
     */
    function _getRangeRatio0(
        address adapterAddress, 
        bytes32 rangeId
    ) internal view returns (uint256 ratio0) {
        (bool success, bytes memory data) = adapterAddress.staticcall(
            abi.encodeWithSelector(
                DEXAdapter.getLiquidityRatio0.selector,
                rangeId
            )
        );
        if (!success) {
            revert Errors.StaticCallFailed();
        }
        (ratio0) = abi.decode(data, (uint256));
    }

    function targetRatio0(
        uint32 vaultId
    ) internal view returns (uint256 targetPBp0) {
        ALMVault storage vs = vaultId.getVault();
        uint256[] memory ratios0 = getRatios0(vaultId);
        unchecked {
            for (uint256 i = 0; i < vs.ranges.length; i++) {
                // multiply effective ranges ratio by target weights
                targetPBp0 += ratios0[i].mulDivDown(vs.ranges[i].weightBps, M.BP_BASIS);
            }
        }
    }

    function targetRatio1(
        uint32 vaultId
    ) internal view returns (uint256 targetPBp1) {
        return M.PRECISION_BP_BASIS.subMax0(targetRatio0(vaultId));
    }

    function previewDeposit1For0(
        uint32 vaultId,
        uint256 amount0
    ) internal view returns (uint256 amount1) {
        return amount0.mulDivDown(targetRatio1(vaultId), M.PRECISION_BP_BASIS);
    }

    function previewDeposit0For1(
        uint32 vaultId,
        uint256 amount1
    ) internal view returns (uint256 amount0) {
        return amount1.mulDivDown(targetRatio0(vaultId), M.PRECISION_BP_BASIS);
    }

    /**
     * @notice Preview the token amounts required for minting a specific amount of shares
     * @param vaultId The vault ID
     * @param mintAmount The amount of shares to mint
     * @return amount0 The amount of token0 required
     * @return amount1 The amount of token1 required
     * @return fee0 The amount of token0 that will be taken as fee
     * @return fee1 The amount of token1 that will be taken as fee
     */
    function previewDeposit(
        uint32 vaultId,
        uint256 mintAmount
    ) internal view returns (uint256 amount0, uint256 amount1, uint256 fee0, uint256 fee1) {
        ALMVault storage vs = vaultId.getVault();
        
        if (vs.totalSupply == 0) {
            // For first deposit, use init amounts
            amount0 = vs.initAmount0.mulDivDown(mintAmount, vs.initShares);
            amount1 = vs.initAmount1.mulDivDown(mintAmount, vs.initShares);
        } else {
            // For subsequent deposits, calculate based on current token balance ratios
            (uint256 vaultBalance0, uint256 vaultBalance1) = getVaultTotalBalances(vaultId);
            amount0 = vaultBalance0.mulDivUp(mintAmount, vs.totalSupply);
            amount1 = vaultBalance1.mulDivUp(mintAmount, vs.totalSupply);
        }

        // Calculate fees if configured
        if (vs.fees.entry > 0) {
            fee0 = amount0.bpUp(vs.fees.entry);
            fee1 = amount1.bpUp(vs.fees.entry);
            
            // Adjust amounts UP to account for entry fee - total amount needed from user
            amount0 = amount0 + fee0;
            amount1 = amount1 + fee1;
        }
        
        return (amount0, amount1, fee0, fee1);
    }

    function deposit(
        uint32 vaultId,
        uint256 mintAmount,
        address receiver
    ) internal returns (uint256 supply0, uint256 supply1) {
        ALMVault storage vs = vaultId.getVault();

        if (mintAmount == 0) revert Errors.ZeroValue();

        // Check that mint wouldn't exceed maxSupply
        if (vs.totalSupply + mintAmount > vs.maxSupply) {
            revert Errors.Exceeds(vs.totalSupply + mintAmount, vs.maxSupply);
        }

        // Preview how much of each token is needed and get fee info
        uint256 fee0;
        uint256 fee1;
        (supply0, supply1, fee0, fee1) = previewDeposit(vaultId, mintAmount);

        // Transfer the exact amounts from user to contract
        IERC20(vs.token0).safeTransferFrom(msg.sender, address(this), supply0);
        IERC20(vs.token1).safeTransferFrom(msg.sender, address(this), supply1);
        
        // Calculate adjusted mint amount after fees
        uint256 adjustedMintAmount = mintAmount;
        if (vs.fees.entry > 0) {
            // Add fees to pending fees
            vs.pendingFees[IERC20(vs.token0)] += fee0;
            vs.pendingFees[IERC20(vs.token1)] += fee1;
            
            // Adjust mint amount down by entry fee percentage
            adjustedMintAmount = mintAmount.subBpDown(vs.fees.entry);
        }

        // Mint adjusted vault shares for the user
        LibERC1155.mint(vaultId, receiver, adjustedMintAmount);

        emit Events.Minted(receiver, adjustedMintAmount, supply0, supply1);
        return (supply0, supply1);
    }

    function withdraw(
        uint32 vaultId,
        uint256 burnAmount,
        address receiver
    ) internal returns (uint256 amount0, uint256 amount1) {
        ALMVault storage vs = vaultId.getVault();

        if (burnAmount == 0) revert Errors.ZeroValue();
        if (vs.totalSupply == 0) revert Errors.ZeroValue();

        // Preview how much of each token to withdraw and get fee info
        uint256 fee0;
        uint256 fee1;
        (amount0, amount1, fee0, fee1) = previewWithdraw(vaultId, burnAmount);

        // Burn the vault shares
        LibERC1155.burn(vaultId, msg.sender, burnAmount);

        // Apply exit fee if configured
        if (vs.fees.exit > 0) {
            // Add exit fees to pending fees
            vs.pendingFees[IERC20(vs.token0)] += fee0;
            vs.pendingFees[IERC20(vs.token1)] += fee1;
        }

        // Withdraw tokens from ranges
        _withdrawFromRanges(vaultId, burnAmount, amount0, amount1);

        // Transfer tokens to the receiver
        if (amount0 > 0) {
            IERC20(vs.token0).safeTransfer(receiver, amount0);
        }
        if (amount1 > 0) {
            IERC20(vs.token1).safeTransfer(receiver, amount1);
        }

        emit Events.Burnt(receiver, burnAmount, amount0, amount1);
        return (amount0, amount1);
    }
    
    /**
     * @notice Withdraw tokens from ranges proportionally
     * @param vaultId The vault ID
     * @param burnAmount The amount of shares being burned
     * @param targetAmount0 The target amount of token0 to withdraw
     * @param targetAmount1 The target amount of token1 to withdraw
     */
    function _withdrawFromRanges(
        uint32 vaultId,
        uint256 burnAmount, 
        uint256 targetAmount0, 
        uint256 targetAmount1
    ) internal {
        ALMVault storage vs = vaultId.getVault();
        
        // Calculate the withdrawal proportion
        uint256 proportion = burnAmount.mulDivUp(1e18, vs.totalSupply);
        
        // Withdraw proportionally from each range
        for (uint256 i = 0; i < vs.ranges.length; i++) {
            Range storage range = vs.ranges[i];
            
            // Skip ranges with no liquidity
            if (range.liquidity == 0) continue;
            
            // Calculate liquidity to withdraw from this range
            uint128 liquidityToWithdraw = uint128(uint256(range.liquidity).mulDivUp(proportion, 1e18));
            
            // Skip if no liquidity to withdraw
            if (liquidityToWithdraw == 0) continue;
            
            // Update range liquidity before withdrawal
            range.liquidity -= liquidityToWithdraw;
            
            // Create a temporary range with the withdrawal liquidity
            bytes32 tempRangeId = keccak256(abi.encodePacked("withdraw", range.id, liquidityToWithdraw));
            Range memory tempRange = Range({
                id: tempRangeId,
                vaultId: vaultId,
                poolId: range.poolId,
                positionId: range.positionId,
                weightBps: 0,
                liquidity: liquidityToWithdraw,
                lowerTick: range.lowerTick,
                upperTick: range.upperTick
            });
            
            // Store the temp range
            S.registry().ranges[tempRangeId] = tempRange;
            
            // Call the DEX adapter to withdraw the liquidity
            address adapterAddress = getDexAdapter(range.poolId);
            (bool success, bytes memory data) = adapterAddress.delegatecall(
                abi.encodeWithSelector(
                    DEXAdapter.withdraw.selector,
                    tempRangeId
                )
            );
            
            if (!success) {
                revert Errors.DelegateCallFailed();
            }
            
            // Clean up the temporary range
            delete S.registry().ranges[tempRangeId];
        }
    }

    function getVaultTotalBalances(
        uint32 vaultId
    ) internal view returns (uint256 balance0, uint256 balance1) {
        ALMVault storage vs = vaultId.getVault();

        // Get undeployed token balances (reserved for this vault)
        balance0 = 0; // vs.token0.balanceOf(address(this)).subMax0(vs.pending[0]);
        balance1 = 0; // vs.token1.balanceOf(address(this)).subMax0(vs.pending[1]);

        // Add tokens deployed in liquidity positions
        Range[] storage ranges = vs.ranges;
        for (uint256 i = 0; i < ranges.length; i++) {
            Range storage range = ranges[i];
            // Ensure rangeId is set
            if (range.id == bytes32(0)) {
                // This should not be possible
                continue;
            }

            // Skip ranges with no liquidity
            if (range.liquidity == 0) continue;
            
            // Use staticcall for read-only function with rangeId only
            bytes memory callData = abi.encodeWithSelector(
                DEXAdapter.getAmountsForLiquidity.selector,
                range.id
            );

            // Execute staticcall
            (bool success, bytes memory returnData) = getDexAdapter(range.poolId).staticcall(callData);
            if (!success) revert Errors.StaticCallFailed();
            
            // Decode return data
            (uint256 posAmount0, uint256 posAmount1) = abi.decode(returnData, (uint256, uint256));
            
            balance0 += posAmount0;
            balance1 += posAmount1;
        }
        
        return (balance0, balance1);
    }

    /**
     * @notice Calculate performance fees on LP fees
     * @param vaultId The vault ID
     * @param lpFees0 LP fees for token0
     * @param lpFees1 LP fees for token1
     * @return perfFee0 Performance fee for token0
     * @return perfFee1 Performance fee for token1
     */
    function getPerformanceFees(
        uint32 vaultId,
        uint256 lpFees0,
        uint256 lpFees1
    ) internal returns (uint256 perfFee0, uint256 perfFee1) {
        ALMVault storage vs = vaultId.getVault();
        
        if (vs.fees.perf > 0 && (lpFees0 > 0 || lpFees1 > 0)) {
            perfFee0 = lpFees0.mulDivUp(vs.fees.perf, M.BP_BASIS);
            
            perfFee1 = lpFees1.mulDivUp(vs.fees.perf, M.BP_BASIS);
            
            // Add performance fees to pending fees
            vs.pendingFees[IERC20(vs.token0)] += perfFee0;
            vs.pendingFees[IERC20(vs.token1)] += perfFee1;
        }
        
        return (perfFee0, perfFee1);
    }

    function getManagementFees(uint32 vaultId) internal returns (uint256 mgmtFee0, uint256 mgmtFee1) {
        ALMVault storage vs = vaultId.getVault();
        
        // Calculate time elapsed since last fee accrual - ensure no underflow
        uint256 elapsed = block.timestamp > vs.feeAccruedAt ? 
                          block.timestamp - vs.feeAccruedAt : 0;

        if (elapsed > 0 && vs.fees.mgmt > 0) {
            // Get current token balances (including deployed positions)
            (uint256 balance0, uint256 balance1) = getVaultTotalBalances(vaultId);
            
            // Calculate pro-rated management fee for the elapsed period - round UP for protocol favor
            uint256 durationBps = elapsed.mulDivUp(M.PRECISION_BP_BASIS, M.SEC_PER_YEAR); // in PRECISION_BP_BASIS

            // Apply management fee rate to token balances - round UP for protocol favor
            uint256 mgmtFeesBps = uint256(vs.fees.mgmt);
            uint256 scaledRate = mgmtFeesBps.mulDivUp(durationBps, M.BP_BASIS); // in PRECISION_BP_BASIS

            mgmtFee0 = balance0.mulDivUp(scaledRate, M.PRECISION_BP_BASIS); // back to wei
            mgmtFee1 = balance1.mulDivUp(scaledRate, M.PRECISION_BP_BASIS); // back to wei
            
            // Add management fees to pending fees
            vs.pendingFees[IERC20(vs.token0)] += mgmtFee0;
            vs.pendingFees[IERC20(vs.token1)] += mgmtFee1;
        }
        
        return (mgmtFee0, mgmtFee1);
    }

    function collectFees(uint32 vaultId) internal returns (uint256 fees0, uint256 fees1) {
        ALMVault storage vault = vaultId.getVault();

        // Get the pending fees for this vault
        fees0 = vault.pendingFees[IERC20(vault.token0)];
        fees1 = vault.pendingFees[IERC20(vault.token1)];

        // Reset pending fees
        vault.pendingFees[IERC20(vault.token0)] = 0;
        vault.pendingFees[IERC20(vault.token1)] = 0;

        // Update accrued fees for this vault
        vault.accruedFees[IERC20(vault.token0)] += fees0;
        vault.accruedFees[IERC20(vault.token1)] += fees1;

        // Transfer fees to the treasury
        address treasury = S.core().treasury.treasury;
        if (fees0 > 0) {
            IERC20(vault.token0).safeTransfer(treasury, fees0);
        }
        if (fees1 > 0) {
            IERC20(vault.token1).safeTransfer(treasury, fees1);
        }

        // Update last fee collection timestamp
        vault.feesCollectedAt = uint64(block.timestamp);
        emit Events.FeesCollected(vaultId, address(vault.token0), address(vault.token1), fees0, fees1);
        
        return (fees0, fees1);
    }

    /**
     * @notice Process a swap during rebalance
     * @param vaultId The vault ID
     * @param swap The swap payload containing router address and swap data
     */
    function processSwap(uint32 vaultId, SwapPayload memory swap) internal {
        // Validate vault before executing swap
        require(vaultId > 0, Errors.ZeroValue());
        
        // Execute swap through the router
        (bool success, ) = swap.router.call(swap.swapData);
        if (!success) revert Errors.SwapFailed();
    }

    /**
     * @notice Rebalance a vault by burning ranges, swapping tokens, and adding new ranges
     * @dev This function processes burns, swaps and mints in sequence
     * @param rebalance The rebalance data containing burns, swaps and mints
     * @return protocolFees0 The amount of protocol fees collected (token0)
     * @return protocolFees1 The amount of protocol fees collected (token1)
     */
    function rebalance(
        uint32 vaultId,
        Rebalance memory rebalance
    ) internal returns (uint256 protocolFees0, uint256 protocolFees1) {
        // Validate inputs
        checkRangesArrayLength(rebalance.burns.length);
        checkRangesArrayLength(rebalance.mints.length);
        ALMVault storage vs = vaultId.getVault();
        
        // Ensure vault is not paused
        if (vs.paused) revert Errors.Paused(ErrorType.VAULT);
        
        // Initialize tracking variables
        uint256 totalWithdrawn0 = 0;
        uint256 totalWithdrawn1 = 0;
        uint256 totalLpFees0 = 0;
        uint256 totalLpFees1 = 0;
        
        // Get operation lengths
        uint256 burnLength = rebalance.burns.length;
        uint256 swapLength = rebalance.swaps.length;
        uint256 mintLength = rebalance.mints.length;
        
        // Use a single loop to process corresponding operations
        uint256 maxOps = burnLength;
        if (swapLength > maxOps) maxOps = swapLength;
        if (mintLength > maxOps) maxOps = mintLength;
        
        for (uint256 i = 0; i < maxOps; ++i) {
            // 1. Process burn if index is valid
            if (i < burnLength) {
                Range memory burnRange = rebalance.burns[i];
                bytes32 rangeId = burnRange.id;
                
                Range storage range = rangeId.getRange();
                
                // Check if the range belongs to this vault
                if (range.vaultId != vaultId) {
                    revert Errors.Unauthorized(ErrorType.VAULT);
                }
                
                // Execute delegate call to withdraw liquidity
                address adapterAddress = getDexAdapter(range.poolId);
                (bool success, bytes memory data) = adapterAddress.delegatecall(
                    abi.encodeWithSelector(
                        DEXAdapter.withdraw.selector,
                        rangeId
                    )
                );
                if (!success) revert Errors.DelegateCallFailed();
                
                // Extract withdrawn amounts and LP fees
                (uint256 amount0, uint256 amount1, uint256 lpFees0, uint256 lpFees1) = 
                    abi.decode(data, (uint256, uint256, uint256, uint256));
                    
                // Accumulate withdrawn amounts and LP fees
                totalWithdrawn0 += amount0;
                totalWithdrawn1 += amount1;
                totalLpFees0 += lpFees0;
                totalLpFees1 += lpFees1;
                
                // Remove the range from the vault's range array
                bool found = false;
                uint256 indexToRemove;
                for (uint256 j = 0; j < vs.ranges.length; j++) {
                    if (vs.ranges[j].id == rangeId) {
                        found = true;
                        indexToRemove = j;
                        break;
                    }
                }
                
                // If found, use swap and pop pattern (more gas efficient)
                if (found && vs.ranges.length > 0) {
                    // If not the last element, swap with the last element
                    if (indexToRemove < vs.ranges.length - 1) {
                        vs.ranges[indexToRemove] = vs.ranges[vs.ranges.length - 1];
                    }
                    // Remove the last element
                    vs.ranges.pop();
                }
                
                // Delete the range from storage
                delete S.registry().ranges[rangeId];
            }
            
            // 2. Process swap if index is valid
            if (i < swapLength) {
                processSwap(vaultId, rebalance.swaps[i]);
            }
            
            // 3. Process mint if index is valid
            if (i < mintLength) {
                Range memory range = rebalance.mints[i];
                
                // Ensure vaultId is set
                range.vaultId = vaultId;
                
                // Get the DEX adapter for this pool
                address adapterAddress = getDexAdapter(range.poolId);
                
                // Generate or use existing rangeId
                bytes32 rangeId;
                if (range.id == bytes32(0)) {
                    // Generate a new rangeId based on vault, pool, and ticks
                    rangeId = keccak256(abi.encodePacked(
                        vaultId, 
                        range.poolId, 
                        range.lowerTick, 
                        range.upperTick
                    ));
                    range.id = rangeId;
                } else {
                    rangeId = range.id;
                }
                
                // Update position ID if needed - ensure it's stored as uint256 but generated as bytes32
                if (uint256(range.positionId) == 0) {
                    bytes32 newPositionId = keccak256(abi.encodePacked(
                        address(this),
                        range.lowerTick,
                        range.upperTick
                    ));
                    range.positionId = uint256(uint160(bytes20(newPositionId)));
                }
                
                // Execute delegate call to mint liquidity
                (bool success, bytes memory data) = adapterAddress.delegatecall(
                    abi.encodeWithSelector(
                        bytes4(keccak256("mint(bytes32)")),
                        rangeId
                    )
                );
                if (!success) revert Errors.DelegateCallFailed();
                
                // Update the range with the liquidity amount
                (range.liquidity, , ) = abi.decode(data, (uint128, uint256, uint256));
                
                // Store range in protocol-level mapping for future lookups
                S.registry().ranges[rangeId] = range;
                
                // Also add to backward-compatible array
                vs.ranges.push(range);
            }
        }
        
        return (totalLpFees0, totalLpFees1);
    }

    /**
     * @notice Generic function to calculate share amount for a given token amount
     * @param vaultId The vault ID
     * @param tokenAmount The token amount
     * @param isToken0 Whether the amount is for token0 (true) or token1 (false)
     * @param applyFees Whether to apply fees in the calculation
     * @return shareAmount The equivalent share amount
     */
    function _amountToShares(
        uint32 vaultId, 
        uint256 tokenAmount,
        bool isToken0,
        bool applyFees
    ) internal view returns (uint256 shareAmount) {
        ALMVault storage vs = vaultId.getVault();
        
        if (tokenAmount == 0 || vs.totalSupply == 0) {
            return 0;
        }
        
        (uint256 balance0, uint256 balance1) = getVaultTotalBalances(vaultId);
        
        // Get the correct balance based on token
        uint256 balance = isToken0 ? balance0 : balance1;
        
        // Account for exit fees if applicable and requested
        if (applyFees && vs.fees.exit > 0) {
            // Need to add fee percentage to get gross amount
            tokenAmount = tokenAmount.mulDivUp(M.BP_BASIS, M.BP_BASIS - vs.fees.exit);
        }
        
        // Calculate share amount
        shareAmount = tokenAmount.mulDivUp(vs.totalSupply, balance);
        
        return shareAmount;
    }
    
    /**
     * @notice Generic function to calculate token amounts for a given share amount
     * @param vaultId The vault ID
     * @param shareAmount The share amount
     * @param applyFees Whether to apply fees in the calculation
     * @return amount0 The amount of token0
     * @return amount1 The amount of token1
     * @return fee0 The fee amount for token0
     * @return fee1 The fee amount for token1
     */
    function _sharesToAmounts(
        uint32 vaultId,
        uint256 shareAmount,
        bool applyFees
    ) internal view returns (uint256 amount0, uint256 amount1, uint256 fee0, uint256 fee1) {
        ALMVault storage vs = vaultId.getVault();
        
        if (shareAmount == 0 || vs.totalSupply == 0) {
            return (0, 0, 0, 0);
        }
        
        // Calculate proportional token amounts
        (uint256 balance0, uint256 balance1) = getVaultTotalBalances(vaultId);
        amount0 = balance0.mulDivDown(shareAmount, vs.totalSupply);
        amount1 = balance1.mulDivDown(shareAmount, vs.totalSupply);
        
        // Calculate and apply exit fee if configured and requested
        if (applyFees && vs.fees.exit > 0) {
            fee0 = amount0.bpUp(vs.fees.exit);
            fee1 = amount1.bpUp(vs.fees.exit);
            
            // Subtract fees from withdrawal amounts
            amount0 = amount0 - fee0;
            amount1 = amount1 - fee1;
        }
        
        return (amount0, amount1, fee0, fee1);
    }

    /**
     * @notice Preview the token amounts to be received for burning a specific amount of shares
     * @param vaultId The vault ID
     * @param burnAmount The amount of shares to burn
     * @return amount0 The amount of token0 to be received
     * @return amount1 The amount of token1 to be received
     * @return fee0 The fee amount for token0
     * @return fee1 The fee amount for token1
     */
    function previewWithdraw(
        uint32 vaultId,
        uint256 burnAmount
    ) internal view returns (uint256 amount0, uint256 amount1, uint256 fee0, uint256 fee1) {
        return _sharesToAmounts(vaultId, burnAmount, true);
    }

    /**
     * @notice Preview how much token1 would be withdrawn for a given amount of token0
     * @param vaultId The vault ID
     * @param amount0 The amount of token0 to withdraw
     * @return amount1 The amount of token1 to be withdrawn
     * @return shareAmount The amount of shares that would be burned
     * @return fee0 The fee amount for token0
     * @return fee1 The fee amount for token1
     */
    function previewWithdraw0For1(
        uint32 vaultId,
        uint256 amount0
    ) internal view returns (uint256 amount1, uint256 shareAmount, uint256 fee0, uint256 fee1) {
        ALMVault storage vs = vaultId.getVault();
        
        if (amount0 == 0 || vs.totalSupply == 0) {
            return (0, 0, 0, 0);
        }
        
        // Calculate necessary share amount to withdraw this much token0
        shareAmount = _amountToShares(vaultId, amount0, true, true);
        
        // Calculate corresponding token amounts including fees
        uint256 totalAmount0;
        (totalAmount0, amount1, fee0, fee1) = _sharesToAmounts(vaultId, shareAmount, true);
        
        // Double-check that we're getting the requested amount0 (minus fees)
        if (totalAmount0 < amount0) {
            // Adjust share amount up slightly to ensure the user gets at least the requested amount
            shareAmount = shareAmount.mulDivUp(amount0, totalAmount0);
            (totalAmount0, amount1, fee0, fee1) = _sharesToAmounts(vaultId, shareAmount, true);
        }
        
        return (amount1, shareAmount, fee0, fee1);
    }
    
    /**
     * @notice Preview how much token0 would be withdrawn for a given amount of token1
     * @param vaultId The vault ID
     * @param amount1 The amount of token1 to withdraw
     * @return amount0 The amount of token0 to be withdrawn
     * @return shareAmount The amount of shares that would be burned
     * @return fee0 The fee amount for token0
     * @return fee1 The fee amount for token1
     */
    function previewWithdraw1For0(
        uint32 vaultId,
        uint256 amount1
    ) internal view returns (uint256 amount0, uint256 shareAmount, uint256 fee0, uint256 fee1) {
        ALMVault storage vs = vaultId.getVault();
        
        if (amount1 == 0 || vs.totalSupply == 0) {
            return (0, 0, 0, 0);
        }

        // Calculate necessary share amount to withdraw this much token1
        shareAmount = _amountToShares(vaultId, amount1, false, true);
        
        // Calculate corresponding token amounts including fees
        uint256 totalAmount1;
        (amount0, totalAmount1, fee0, fee1) = _sharesToAmounts(vaultId, shareAmount, true);
        
        // Double-check that we're getting the requested amount1 (minus fees)
        if (totalAmount1 < amount1) {
            // Adjust share amount up slightly to ensure the user gets at least the requested amount
            shareAmount = shareAmount.mulDivUp(amount1, totalAmount1);
            (amount0, totalAmount1, fee0, fee1) = _sharesToAmounts(vaultId, shareAmount, true);
        }
        
        return (amount0, shareAmount, fee0, fee1);
    }

    /**
     * @notice Get vault information for external view
     * @param vaultId The vault ID
     * @return info The vault information
     */
    function getVaultInfo(uint32 vaultId) internal view returns (VaultInfo memory info) {
        ALMVault storage vs = vaultId.getVault();
        
        info.id = vs.id;
        info.name = vs.name;
        info.symbol = vs.symbol;
        info.decimals = vs.decimals;
        info.totalSupply = vs.totalSupply;
        info.maxSupply = vs.maxSupply;
        
        info.token0 = vs.token0;
        info.token1 = vs.token1;
        
        // Copy ranges array
        info.ranges = new Range[](vs.ranges.length);
        for (uint256 i = 0; i < vs.ranges.length; i++) {
            info.ranges[i] = vs.ranges[i];
        }
        
        info.feesCollectedAt = vs.feesCollectedAt;
        info.feeAccruedAt = vs.feeAccruedAt;
        info.fees = vs.fees;
        info.initAmount0 = vs.initAmount0;
        info.initAmount1 = vs.initAmount1;
        info.initShares = vs.initShares;
        
        info.lookback = vs.lookback;
        info.maxDeviation = vs.maxDeviation;
        
        info.paused = vs.paused;
        info.restrictedMint = vs.restrictedMint;
        
        return info;
    }
}
