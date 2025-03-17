// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {LibDiamond} from "@libraries/LibDiamond.sol";
import {LibAccessControl} from "@libraries/LibAccessControl.sol";
import {LibTreasury as T} from "@libraries/LibTreasury.sol";
import {ALMVault, PoolInfo, Range, Rebalance, AddressType, CoreStorage, ErrorType, VaultInitParams, DEX, Registry, FeeType} from "@/BTRTypes.sol";
import {BTRStorage as S} from "@libraries/BTRStorage.sol";
import {BTRErrors as Errors, BTREvents as Events} from "@libraries/BTREvents.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {LibMaths as M} from "@libraries/LibMaths.sol";
import {LibERC1155} from "@libraries/LibERC1155.sol";
import {BTRUtils} from "@libraries/BTRUtils.sol";
import {DEXAdapterFacet} from "@facets/abstract/DEXAdapterFacet.sol";
import {LibSwapper as SW} from "@libraries/LibSwapper.sol";

library LibALM {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    using M for uint256;
    using BTRUtils for uint32;
    using BTRUtils for bytes32;
    using LibERC1155 for uint32;
    using SW for address;

    uint256 private constant MAX_RANGES = 20;

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

        vs.token0 = IERC20(params.token0);
        vs.token1 = IERC20(params.token1);
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

    function _getDexAdapter(
        Registry storage registry,
        bytes32 poolId
    ) internal view returns (address) {
        DEX dex = registry.poolInfo[poolId].dex;
        return registry.dexAdapters[uint8(dex)];
    }

    function getDexAdapter(DEX dex) internal view returns (address) {
        return _getDexAdapter(S.registry(), dex);
    }

    function _getPoolDexAdapter(Registry storage registry, bytes32 poolId) internal view returns (address) {
        DEX dex = registry.poolInfo[poolId].dex;
        return registry.dexAdapters[uint8(dex)];
    }

    function getPoolDexAdapter(bytes32 poolId) internal view returns (address) {
        return _getPoolDexAdapter(S.registry(), poolId);
    }

    function _getRangeDexAdapter(Registry storage registry, bytes32 rangeId) internal view returns (address) {
        Range memory range = registry.ranges[rangeId];
        DEX dex = registry.poolInfo[range.poolId].dex;
        return _getDexAdapter(registry, dex);
    }

    function getRangeDexAdapter(bytes32 rangeId) internal view returns (address) {
        return _getRangeDexAdapter(S.registry(), rangeId);
    }

    function updateDexAdapter(DEX dex, address adapter) internal {
        // ensure that new dexs are sequentially added (if dex is not 0)
        uint8 dexIndex = uint8(dex);
        Registry storage registry = S.registry();
        if (
            dexIndex > 0 &&
            registry.dexAdapters[dexIndex - 1] != address(0)
        ) revert Errors.UnexpectedInput();
        registry.dexAdapters[dexIndex] = adapter;
    }

    function _getTotalBalances(
        ALMVault storage vs,
        Registry storage registry
    ) internal returns (uint256 balance0, uint256 balance1) {
        // NB: undeployed token balances are shared between all vaults, not part of this vault's accounting
        // balance0 = vs.token0.balanceOf(address(this)).subMax0(vs.pendingFees[vs.token0]);
        // balance1 = vs.token1.balanceOf(address(this)).subMax0(vs.pendingFees[vs.token1]);

        // Add tokens deployed in liquidity positions
        for (uint256 i = 0; i < vs.ranges.length; i++) {
            Range memory range = registry.ranges[vs.ranges[i]];
            // Ensure rangeId is set
            if (range.id == bytes32(0)) {
                // This should not be possible
                continue;
            }

            // Skip ranges with no liquidity
            if (range.liquidity == 0) continue;

            // Use delegatecall for read-only function with rangeId to access the same storage context
            bytes memory callData = abi.encodeWithSelector(
                DEXAdapterFacet.getAmountsForLiquidity.selector,
                range.id
            );

            // Execute delegatecall to preserve storage context
            (bool success, bytes memory returnData) = _getDexAdapter(
                registry,
                range.poolId
            ).delegatecall(callData);
            if (!success) revert Errors.DelegateCallFailed();

            // Decode return data
            (uint256 posAmount0, uint256 posAmount1) = abi.decode(
                returnData,
                (uint256, uint256)
            );

            balance0 += posAmount0;
            balance1 += posAmount1;
        }

        return (balance0, balance1);
    }

    function getTotalBalances(
        uint32 vaultId
    ) internal returns (uint256 balance0, uint256 balance1) {
        return _getTotalBalances(vaultId.getVault(), S.registry());
    }

    function _getWeights(
        ALMVault storage vs,
        Registry storage registry
    ) internal view returns (uint256[] memory weights0) {
        weights0 = new uint256[](vs.ranges.length);
        for (uint256 i = 0; i < vs.ranges.length; i++) {
            weights0[i] = registry.ranges[vs.ranges[i]].weightBps;
        }
    }

    function getWeights(
        uint32 vaultId
    ) internal view returns (uint256[] memory weights0) {
        return _getWeights(vaultId.getVault(), S.registry());
    }

    // in PRECISION_BP_BASIS
    function _getRangeRatio0(
        address adapterAddress,
        bytes32 rangeId
    ) internal returns (uint256 ratio0) {
        (bool success, bytes memory data) = adapterAddress.delegatecall(
            abi.encodeWithSelector(
                DEXAdapterFacet.getLiquidityRatio0.selector,
                rangeId
            )
        );
        if (!success) {
            revert Errors.DelegateCallFailed();
        }
        (ratio0) = abi.decode(data, (uint256));
    }

    // in PRECISION_BP_BASIS
    function _getRatios0(
        ALMVault storage vs,
        Registry storage registry
    ) internal returns (uint256[] memory ratios0) {
        ratios0 = new uint256[](vs.ranges.length);
        if (vs.ranges.length == 0) {
            revert Errors.NotFound(ErrorType.RANGE);
        }
        for (uint256 i = 0; i < vs.ranges.length;) {
            Range memory range = registry.ranges[vs.ranges[i]];
            address adapterAddress = _getPoolDexAdapter(registry, range.poolId);
            uint256 ratio0 = _getRangeRatio0(adapterAddress, range.id);
            ratios0[i] = ratio0;
            unchecked {
                i++;
            }
        }
    }

    // should return the current weights of token0 and token1 in the vault
    // to reflect the
    function getRatios0(
        uint32 vaultId
    ) internal returns (uint256[] memory ratios0) {
        return _getRatios0(vaultId.getVault(), S.registry());
    }

    // in PRECISION_BP_BASIS
    function _getRatio0(
        ALMVault storage vs,
        Registry storage registry,
        uint256 index
    ) internal returns (uint256 ratio0) {
        (uint256 amount0, uint256 amount1) = _getTotalBalances(vs, registry);
        return amount0.mulDivDown(M.PRECISION_BP_BASIS, amount0 + amount1);
    }

    // in PRECISION_BP_BASIS
    function _targetRatio0(
        ALMVault storage vs,
        Registry storage registry
    ) internal returns (uint256 targetPBp0) {
        uint256[] memory ratios0 = _getRatios0(vs, registry);
        uint256[] memory weights = _getWeights(vs, registry);
        unchecked {
            for (uint256 i = 0; i < vs.ranges.length; i++) {
                targetPBp0 += ratios0[i].mulDivDown(weights[i], M.BP_BASIS);
            }
        }
    }

    function targetRatio0(
        uint32 vaultId
    ) internal returns (uint256 targetPBp0) {
        return _targetRatio0(vaultId.getVault(), S.registry());
    }

    // in PRECISION_BP_BASIS
    function _targetRatio1(
        ALMVault storage vs,
        Registry storage registry
    ) internal returns (uint256 targetPBp1) {
        return M.PRECISION_BP_BASIS.subMax0(_targetRatio0(vs, registry));
    }

    function targetRatio1(
        uint32 vaultId
    ) internal returns (uint256 targetPBp1) {
        return _targetRatio1(vaultId.getVault(), S.registry());
    }

    /**
     * @notice Generic function to calculate token amounts for a given share amount
     * @param vs The vault storage reference
     * @param shares The share amount
     * @param feeType The type of fee to apply (NONE, ENTRY, EXIT)
     * @return amount0 The amount of token0
     * @return amount1 The amount of token1
     * @return fee0 The fee amount for token0
     * @return fee1 The fee amount for token1
     */
    function _sharesToAmounts(
        ALMVault storage vs,
        Registry storage registry,
        uint256 shares,
        FeeType feeType
    ) internal returns (uint256 amount0, uint256 amount1, uint256 fee0, uint256 fee1) {
        if (shares == 0)
            return (0, 0, 0, 0);
        if (vs.totalSupply == 0) {
            // For first deposit, use init amounts to determine share amount
            amount0 = vs.initAmount0.mulDivDown(shares, vs.initShares);
            amount1 = vs.initAmount1.mulDivDown(shares, vs.initShares);
        } else {
            (uint256 balance0, uint256 balance1) = _getTotalBalances(vs, registry);
            amount0 = balance0.mulDivUp(shares, vs.totalSupply);
            amount1 = balance1.mulDivUp(shares, vs.totalSupply);
        }
        if (feeType == FeeType.ENTRY && vs.fees.entry > 0) {
            fee0 = amount0.revBpUp(vs.fees.entry);
            fee1 = amount1.revBpUp(vs.fees.entry);
            amount0 += fee0; // more tokens for the same minted shares
            amount1 += fee1;
        } else if (feeType == FeeType.EXIT && vs.fees.exit > 0) {
            fee0 = amount0.bpUp(vs.fees.exit);
            fee1 = amount1.bpUp(vs.fees.exit);
            amount0 -= fee0; // less tokens out for the same burnt shares
            amount1 -= fee1;
        }
    }

    /**
     * @notice Generic function to calculate share amount for given token amounts
     * @param vs The vault storage reference
     * @param amount0 The amount of token0
     * @param amount1 The amount of token1
     * @param feeType The type of fee to apply (NONE, ENTRY, EXIT)
     * @return shares The equivalent share amount
     */
    function _amountsToShares(
        ALMVault storage vs,
        Registry storage registry,
        uint256 amount0,
        uint256 amount1,
        FeeType feeType
    ) internal returns (uint256 shares, uint256 fee0, uint256 fee1) {
        if (amount0 == 0 && amount1 == 0) {
            return (0, 0, 0);
        }

        (uint256 balance0, uint256 balance1) = _getTotalBalances(vs, registry);

        if (balance0.mulDivDown(M.PRECISION_BP_BASIS, balance0 + balance1)
            != amount0.mulDivDown(M.PRECISION_BP_BASIS, amount0 + amount1)) {
            revert Errors.UnexpectedInput(); // ratio breach
        }

        shares = uint256(amount0 + amount1).mulDivDown(vs.totalSupply, balance0 + balance1); // zero protection

        if (feeType == FeeType.ENTRY && vs.fees.entry > 0) {
            fee0 = amount0.bpUp(vs.fees.entry);
            fee1 = amount1.bpUp(vs.fees.entry);
            shares -= shares.bpUp(vs.fees.entry); // less shares minted for the same amount in
        } else if (feeType == FeeType.EXIT && vs.fees.exit > 0) {
            fee0 = amount0.revBpUp(vs.fees.exit);
            fee1 = amount1.revBpUp(vs.fees.exit);
            shares += shares.revBpUp(vs.fees.exit); // more shares burnt to get the same amount out
        }
    }

    function _burnAllRanges(
        ALMVault storage vs,
        Registry storage registry
    ) internal returns (uint256 totalAmount0, uint256 totalAmount1, uint256 totalLpFees0, uint256 totalLpFees1) {
        uint256 amount0; uint256 amount1; uint256 lpFees0; uint256 lpFees1;
        uint256 length = vs.ranges.length;
        unchecked {
            for (uint256 i = 0; i < length; i++) {
                (amount0, amount1, lpFees0, lpFees1) = _burnRange(vs, registry, 0); // index0 since we're swapping and popping
                totalAmount0 += amount0;
                totalAmount1 += amount1;
                totalLpFees0 += lpFees0;
                totalLpFees1 += lpFees1;
            }
        }
        return (totalAmount0, totalAmount1, totalLpFees0, totalLpFees1);
    }

    function _burnAllRanges(ALMVault storage vs, Rebalance memory rebalanceData) internal returns (uint256 totalAmount0, uint256 totalAmount1, uint256 totalLpFees0, uint256 totalLpFees1) {
        Registry storage registry = S.registry();
        uint256 burnLength = rebalanceData.ranges.length;
        uint256 amount0; uint256 amount1; uint256 lpFees0; uint256 lpFees1;
        
        for (uint256 i = 0; i < burnLength; ++i) {
            bytes32 rangeId = rebalanceData.ranges[i].id;
            // Find the index of the range in vs.ranges
            uint256 index;
            bool found = false;
            
            for (uint256 j = 0; j < vs.ranges.length; ++j) {
                if (vs.ranges[j] == rangeId) {
                    index = j;
                    found = true;
                    break;
                }
            }
            
            if (!found) continue; // Skip if range not found
            
            (amount0, amount1, lpFees0, lpFees1) = _burnRange(vs, registry, index);
            
            // Accumulate amounts and fees
            totalAmount0 += amount0;
            totalAmount1 += amount1;
            totalLpFees0 += lpFees0;
            totalLpFees1 += lpFees1;
        }

        return (totalAmount0, totalAmount1, totalLpFees0, totalLpFees1);
    }

    function _previewDeposit(
        ALMVault storage vs,
        Registry storage registry,
        uint256 mintShares
    ) internal returns (uint256 amount0, uint256 amount1, uint256 fee0, uint256 fee1) {
        return _sharesToAmounts(vs, registry, mintShares, FeeType.ENTRY);
    }

    function _previewDeposit(
        ALMVault storage vs,
        Registry storage registry,
        uint256 amount0,
        uint256 amount1
    ) internal returns (uint256 mintShares, uint256 fee0, uint256 fee1) {
        return _amountsToShares(vs, registry, amount0, amount1, FeeType.ENTRY);
    }

    function previewDeposit(
        uint32 vaultId,
        uint256 sharesMinted
    )
        internal
        returns (uint256 amount0, uint256 amount1, uint256 fee0, uint256 fee1)
    {
        return _previewDeposit(vaultId.getVault(), S.registry(), sharesMinted);
    }

    function previewDeposit(
        uint32 vaultId,
        uint256 amount0,
        uint256 amount1
    )
        internal
        returns (uint256 sharesAmount, uint256 fee0, uint256 fee1)
    {
        return _previewDeposit(vaultId.getVault(), S.registry(), amount0, amount1);
    }

    function _previewDeposit0For1(
        ALMVault storage vs,
        Registry storage registry,
        uint256 amount1
    ) internal returns (uint256 amount0, uint256 mintShares, uint256 fee0, uint256 fee1) {
        uint256 ratio0 = _targetRatio0(vs, registry);
        if (amount1 == 0 || vs.totalSupply == 0 || ratio0 == 0) {
            return (0, 0, 0, 0);
        }
        // cross product: amount0 = (ratio0 * amount1) / ratio1
        amount0 = ratio0.mulDivDown(amount1, M.PRECISION_BP_BASIS - ratio0);
        (mintShares, fee0, fee1) = _amountsToShares(vs, registry, amount0, amount1, FeeType.ENTRY);
    }

    function previewDeposit0For1(
        uint32 vaultId,
        uint256 amount1
    ) internal returns (uint256 amount0, uint256 mintShares, uint256 fee0, uint256 fee1) {
        return _previewDeposit0For1(vaultId.getVault(), S.registry(), amount1);
    }

    // in wei
    function _previewDeposit1For0(
        ALMVault storage vs,
        Registry storage registry,
        uint256 amount0
    ) internal returns (uint256 amount1, uint256 mintShares, uint256 fee0, uint256 fee1) {
        uint256 ratio1 = _targetRatio1(vs, registry);
        if (amount0 == 0 || vs.totalSupply == 0 || ratio1 == 0) {
            return (0, 0, 0, 0);
        }
        // cross product: amount1 = (ratio1 * amount0) / ratio0
        amount1 = ratio1.mulDivDown(amount0, M.PRECISION_BP_BASIS - ratio1);
        (mintShares, fee0, fee1) = _amountsToShares(vs, registry, amount0, amount1, FeeType.ENTRY);
    }

    function previewDeposit1For0(
        uint32 vaultId,
        uint256 amount0
    ) internal returns (uint256 amount1, uint256 mintShares, uint256 fee0, uint256 fee1) {
        return _previewDeposit1For0(vaultId.getVault(), S.registry(), amount0);
    }

    function _previewWithdraw(
        ALMVault storage vs,
        Registry storage registry,
        uint256 sharesBurnt
    ) internal returns (uint256 amount0, uint256 amount1, uint256 fee0, uint256 fee1) {
        return _sharesToAmounts(vs, registry, sharesBurnt, FeeType.EXIT);
    }

    function _previewWithdraw(
        ALMVault storage vs,
        Registry storage registry,
        uint256 amount0,
        uint256 amount1
    ) internal returns (uint256 sharesBurnt, uint256 fee0, uint256 fee1) {
        return _amountsToShares(vs, registry, amount0, amount1, FeeType.EXIT);
    }

    function _previewWithdraw0For1(
        ALMVault storage vs,
        Registry storage registry,
        uint256 amount1
    )
        internal
        returns (
            uint256 amount0,
            uint256 sharesBurnt,
            uint256 fee0,
            uint256 fee1
        )
    {
        uint256 ratio0 = _targetRatio0(vs, registry);
        if (amount1 == 0 || vs.totalSupply == 0 || ratio0 == 0) {
            return (0, 0, 0, 0);
        }
        // cross product: amount0 = (ratio0 * amount1) / ratio1
        amount0 = ratio0.mulDivDown(amount1, M.PRECISION_BP_BASIS - ratio0);
        (sharesBurnt, fee0, fee1) = _amountsToShares(vs, registry, amount0, amount1, FeeType.EXIT);
    }

    function previewWithdraw(
        uint32 vaultId,
        uint256 sharesAmount
    ) internal returns (uint256 amount0, uint256 amount1, uint256 fee0, uint256 fee1) {
        return _sharesToAmounts(vaultId.getVault(), S.registry(), sharesAmount, FeeType.EXIT);
    }

    function previewWithdraw(
        uint32 vaultId,
        uint256 amount0,
        uint256 amount1
    ) internal returns (uint256 sharesAmount, uint256 fee0, uint256 fee1) {
        return _amountsToShares(vaultId.getVault(), S.registry(), amount0, amount1, FeeType.EXIT);
    }

    function previewWithdraw0For1(
        uint32 vaultId,
        uint256 amount1
    )
        internal
        returns (
            uint256 amount0,
            uint256 sharesBurnt,
            uint256 fee0,
            uint256 fee1
        )
    {
        ALMVault storage vs = vaultId.getVault();
        return _previewWithdraw0For1(vs, S.registry(), amount1);
    }

    function _previewWithdraw1For0(
        ALMVault storage vs,
        Registry storage registry,
        uint256 amount0
    ) internal returns (uint256 amount1, uint256 sharesBurnt, uint256 fee0, uint256 fee1) {
        uint256 ratio1 = _targetRatio1(vs, registry);
        if (amount0 == 0 || vs.totalSupply == 0 || ratio1 == 0) {
            return (0, 0, 0, 0);
        }
        // cross product: amount1 = (ratio1 * amount0) / ratio0
        amount1 = ratio1.mulDivDown(amount0, M.PRECISION_BP_BASIS - ratio1);
        (sharesBurnt, fee0, fee1) = _amountsToShares(vs, registry, amount0, amount1, FeeType.EXIT);
    }

    function previewWithdraw1For0(
        uint32 vaultId,
        uint256 amount0
    )
        internal
        returns (
            uint256 amount1,
            uint256 sharesBurnt,
            uint256 fee0,
            uint256 fee1
        )
    {
        return _previewWithdraw1For0(vaultId.getVault(), S.registry(), amount0);
    }

    function _deposit(
        ALMVault storage vs,
        uint256 sharesMinted,
        address receiver
    ) internal returns (uint256 supply0, uint256 supply1, uint256 fee0, uint256 fee1) {
        if (sharesMinted == 0) revert Errors.ZeroValue();

        // Check that mint wouldn't exceed maxSupply
        if (vs.totalSupply + sharesMinted > vs.maxSupply) {
            revert Errors.Exceeds(vs.totalSupply + sharesMinted, vs.maxSupply);
        }

        // Preview how much of each token is needed and get fee info
        (supply0, supply1, fee0, fee1) = _sharesToAmounts(vs, S.registry(), sharesMinted, FeeType.ENTRY);

        // Execute deposit with calculated amounts
        _mintShares(vs, supply0, supply1, fee0, fee1, sharesMinted, receiver);

        return (supply0, supply1, fee0, fee1);
    }

    function _deposit(
        ALMVault storage vs,
        uint256 amount0,
        uint256 amount1,
        address receiver
    ) internal returns (uint256 mintedShares, uint256 fee0, uint256 fee1) {
        if (amount0 == 0 && amount1 == 0) revert Errors.ZeroValue();

        // Preview how many shares will be minted and fee info
        (mintedShares, fee0, fee1) = _amountsToShares(vs, S.registry(), amount0, amount1, FeeType.ENTRY);
        
        // Check that mint wouldn't exceed maxSupply
        if (vs.totalSupply + mintedShares > vs.maxSupply) {
            revert Errors.Exceeds(vs.totalSupply + mintedShares, vs.maxSupply);
        }

        // Execute deposit with the input amounts
        _mintShares(vs, amount0, amount1, fee0, fee1, mintedShares, receiver);

        return (mintedShares, fee0, fee1);
    }

    /**
     * @notice Common execution logic for deposits
     * @param vs The vault storage
     * @param amount0 The amount of token0 to deposit
     * @param amount1 The amount of token1 to deposit
     * @param fee0 The fee amount for token0
     * @param fee1 The fee amount for token1
     * @param sharesToMint The amount of shares to mint (after fee adjustments)
     * @param receiver The address to receive the shares
     */
    function _mintShares(
        ALMVault storage vs,
        uint256 amount0,
        uint256 amount1,
        uint256 fee0,
        uint256 fee1,
        uint256 sharesToMint,
        address receiver
    ) internal {
        // Transfer the exact amounts from user to contract
        vs.token0.safeTransferFrom(msg.sender, address(this), amount0);
        vs.token1.safeTransferFrom(msg.sender, address(this), amount1);

        // Calculate adjusted mint amount after fees
        uint256 adjustedMintAmount = sharesToMint;
        if (vs.fees.entry > 0) {
            // Add fees to pending fees
            vs.pendingFees[vs.token0] += fee0;
            vs.pendingFees[vs.token1] += fee1;

            // Adjust share amount if this is a share-based deposit (not amount-based)
            // For amount-based deposits the fee is already accounted for in mintedShares calculation
            (uint256 sharesWithoutFee, , ) = _amountsToShares(vs, S.registry(), amount0, amount1, FeeType.NONE);
            if (sharesToMint > sharesWithoutFee) {
                adjustedMintAmount = sharesToMint.subBpDown(vs.fees.entry);
            }
        }

        // Mint adjusted vault shares for the user
        vs.id.mint(receiver, adjustedMintAmount);

        emit Events.SharesMinted(receiver, adjustedMintAmount, amount0, amount1);
    }

    function deposit(
        uint32 vaultId,
        uint256 sharesMinted,
        address receiver
    ) internal returns (uint256 supply0, uint256 supply1, uint256 fee0, uint256 fee1) {
        ALMVault storage vs = vaultId.getVault();
        return _deposit(vs, sharesMinted, receiver);
    }

    function deposit(
        uint32 vaultId,
        uint256 amount0,
        uint256 amount1,
        address receiver
    ) internal returns (uint256 mintedShares, uint256 fee0, uint256 fee1) {
        ALMVault storage vs = vaultId.getVault();
        return _deposit(vs, amount0, amount1, receiver);
    }

    function _withdraw(
        ALMVault storage vs,
        Registry storage registry,
        uint256 sharesBurnt,
        address receiver
    ) internal returns (uint256 amount0, uint256 amount1, uint256 fee0, uint256 fee1) {
        // Validate withdrawal parameters
        _validateWithdrawal(vs, sharesBurnt);

        // Preview how much of each token to withdraw and get fee info
        (amount0, amount1, fee0, fee1) = _sharesToAmounts(vs, registry, sharesBurnt, FeeType.EXIT);

        // Execute withdrawal with calculated amounts
        _burnShares(
            vs, 
            registry, 
            amount0, 
            amount1, 
            fee0, 
            fee1, 
            sharesBurnt, 
            receiver, 
            false
        );
    }

    function _withdraw(
        ALMVault storage vs,
        Registry storage registry,
        uint256 amount0,
        uint256 amount1,
        address receiver
    ) internal returns (uint256 sharesAmount, uint256 fee0, uint256 fee1) {
        if (amount0 == 0 && amount1 == 0) revert Errors.ZeroValue();
        if (vs.totalSupply == 0) revert Errors.ZeroValue();

        // Preview how many shares to burn and fee info
        (sharesAmount, fee0, fee1) = _amountsToShares(vs, registry, amount0, amount1, FeeType.EXIT);
        
        // Validate the withdrawal
        if (vs.totalSupply < sharesAmount) revert Errors.Exceeds(vs.totalSupply, sharesAmount); // supply breach
        if (vs.id.balanceOf(msg.sender) < sharesAmount) revert Errors.BurnExceedsBalance(); // balance breach

        // Execute withdrawal with the input amounts
        _burnShares(
            vs, 
            registry, 
            amount0, 
            amount1, 
            fee0, 
            fee1, 
            sharesAmount, 
            receiver, 
            true
        );

        return (sharesAmount, fee0, fee1);
    }

    /**
     * @notice Validates basic withdrawal conditions
     * @param vs The vault storage
     * @param sharesBurnt The amount of shares to burn
     */
    function _validateWithdrawal(ALMVault storage vs, uint256 sharesBurnt) internal view {
        if (sharesBurnt == 0 || vs.totalSupply == 0) revert Errors.ZeroValue();
        if (vs.totalSupply < sharesBurnt) revert Errors.Exceeds(vs.totalSupply, sharesBurnt); // supply breach
        if (vs.id.balanceOf(msg.sender) < sharesBurnt) revert Errors.BurnExceedsBalance(); // balance breach
    }

    /**
     * @notice Common execution logic for withdrawals
     * @param vs The vault storage
     * @param registry The registry storage
     * @param amount0 The amount of token0 to withdraw
     * @param amount1 The amount of token1 to withdraw
     * @param fee0 The fee amount for token0
     * @param fee1 The fee amount for token1
     * @param sharesBurnt The amount of shares to burn
     * @param receiver The address to receive the tokens
     * @param isAmountBased Whether this is an amount-based withdrawal
     */
    function _burnShares(
        ALMVault storage vs,
        Registry storage registry,
        uint256 amount0,
        uint256 amount1,
        uint256 fee0,
        uint256 fee1,
        uint256 sharesBurnt,
        address receiver,
        bool isAmountBased
    ) internal {
        // Burn the users' vault shares
        vs.id.burn(msg.sender, sharesBurnt);

        if (vs.fees.exit > 0) {
            // Add exit fees to pending fees
            vs.pendingFees[vs.token0] += fee0;
            vs.pendingFees[vs.token1] += fee1;
        }

        // Burn underlying liquidity from ranges to free up tokens
        uint256 totalLpFees0;
        uint256 totalLpFees1;
        // TODO: partial burn to meet user requirements and not the whole vault
        (,,totalLpFees0, totalLpFees1) = _burnAllRanges(vs, S.registry());
        _accrueFees(vs, registry, totalLpFees0, totalLpFees1);

        // For amount-based withdrawals, adjust for fees
        uint256 transferAmount0 = isAmountBased ? (amount0 - fee0) : amount0;
        uint256 transferAmount1 = isAmountBased ? (amount1 - fee1) : amount1;

        // Transfer retrieved tokens to the receiver
        if (transferAmount0 + transferAmount1 > 0) {
            vs.token0.safeTransfer(receiver, transferAmount0);
            vs.token1.safeTransfer(receiver, transferAmount1);
        }

        emit Events.SharesBurnt(receiver, sharesBurnt, transferAmount0, transferAmount1);
    }

    function withdraw(
        uint32 vaultId,
        uint256 sharesBurnt,
        address receiver
    ) internal returns (uint256 amount0, uint256 amount1, uint256 fee0, uint256 fee1) {
        ALMVault storage vs = vaultId.getVault();
        return _withdraw(vs, S.registry(), sharesBurnt, receiver);
    }

    function withdraw(
        uint32 vaultId,
        uint256 amount0,
        uint256 amount1,
        address receiver
    ) internal returns (uint256 sharesAmount, uint256 fee0, uint256 fee1) {
        ALMVault storage vs = vaultId.getVault();
        return _withdraw(vs, S.registry(), amount0, amount1, receiver);
    }

    function _accruePerformanceFees(
        ALMVault storage vs,
        uint256 lpFees0,
        uint256 lpFees1
    ) internal returns (uint256 perfFee0, uint256 perfFee1) {
        if (vs.fees.perf > 0 && (lpFees0 + lpFees1 > 0)) {
            perfFee0 = lpFees0.bpUp(vs.fees.perf);
            perfFee1 = lpFees1.bpUp(vs.fees.perf);
            vs.accruedFees[vs.token0] += perfFee0;
            vs.accruedFees[vs.token1] += perfFee1;
            vs.timePoints.perfAccruedAt = uint64(block.timestamp);
        }
    }

    function _accrueManagementFees(
        ALMVault storage vs,
        Registry storage registry
    ) internal returns (uint256 mgmtFee0, uint256 mgmtFee1) {
        // Get current balances
        (uint256 balance0, uint256 balance1) = _getTotalBalances(
            vs,
            registry
        );

        // Calculate elapsed time since last fee accrual
        uint256 elapsed = block.timestamp - vs.timePoints.mgmtAccruedAt;
        if (elapsed == 0) return (0, 0);

        // Calculate pro-rated management fee for the elapsed period - round UP for protocol favor
        uint256 durationBps = uint256(elapsed).mulDivUp(
            M.PRECISION_BP_BASIS,
            M.SEC_PER_YEAR
        ); // in PRECISION_BP_BASIS

        // Apply management fee rate to token balances - round UP for protocol favor
        uint256 scaledRate = uint256(vs.fees.mgmt).mulDivUp(durationBps, M.BP_BASIS); // in PRECISION_BP_BASIS
        mgmtFee0 = balance0.mulDivUp(scaledRate, M.PRECISION_BP_BASIS); // back to wei
        mgmtFee1 = balance1.mulDivUp(scaledRate, M.PRECISION_BP_BASIS); // back to wei
        vs.accruedFees[vs.token0] += mgmtFee0;
        vs.accruedFees[vs.token1] += mgmtFee1;
        vs.timePoints.mgmtAccruedAt = uint64(block.timestamp);
    }

    function _accrueFees(
        ALMVault storage vs,
        Registry storage registry,
        uint256 lpFees0,
        uint256 lpFees1
    ) internal returns (uint256 perfFees0, uint256 perfFees1, uint256 mgmtFees0, uint256 mgmtFees1) {
        (perfFees0, perfFees1) = _accruePerformanceFees(vs, lpFees0, lpFees1);
        (mgmtFees0, mgmtFees1) = _accrueManagementFees(vs, registry);
    }

    function _collectFees(
        ALMVault storage vault,
        address collector
    ) internal returns (uint256 fees0, uint256 fees1) {
        // Get the pending fees for this vault
        fees0 = vault.pendingFees[vault.token0];
        fees1 = vault.pendingFees[vault.token1];

        // Reset pending fees
        vault.pendingFees[vault.token0] = 0;
        vault.pendingFees[vault.token1] = 0;

        // Update accrued fees for this vault
        vault.accruedFees[vault.token0] += fees0;
        vault.accruedFees[vault.token1] += fees1;

        // Transfer fees to the treasury
        if (fees0 + fees1 > 0) {
            vault.token0.safeTransfer(collector, fees0);
            vault.token1.safeTransfer(collector, fees1);
        }

        // Update last fee collection timestamp
        vault.timePoints.collectedAt = uint64(block.timestamp);
        emit Events.FeesCollected(vault.id, address(vault.token0), address(vault.token1), fees0, fees1);
    }

    function collectFees(
        uint32 vaultId
    ) internal returns (uint256 fees0, uint256 fees1) {
        return _collectFees(vaultId.getVault(), S.treasury().treasury);
    }

    function _processSwap(address router, bytes memory swapData) internal {
        // Execute swap through the router
        (bool success, ) = router.delegatecall(swapData);
        if (!success) revert Errors.SwapFailed();
    }

    function rebalance(
        uint32 vaultId,
        Rebalance memory rebalanceData
    ) internal returns (uint256 protocolFees0, uint256 protocolFees1) {
        ALMVault storage vs = vaultId.getVault();
        Registry storage registry = S.registry();

        // Ensure vault is not paused
        if (vs.paused) revert Errors.Paused(ErrorType.VAULT);

        return _rebalance(vs, registry, rebalanceData);
    }

    function _rebalance(
        ALMVault storage vs,
        Registry storage registry,
        Rebalance memory rebalanceData
    ) internal returns (uint256 protocolFees0, uint256 protocolFees1) {
        // Initialize tracking variables
        (uint256 totalAmount0, uint256 totalAmount1, uint256 totalLpFees0, uint256 totalLpFees1) = _burnAllRanges(vs, rebalanceData);
        _accrueFees(vs, registry, totalLpFees0, totalLpFees1);
        _processSwaps(rebalanceData); // swaps are processed before new ranges are minted
        _mintRanges(vs, rebalanceData);
        return (protocolFees0, protocolFees1);
    }

    function _burnRange(
        ALMVault storage vs,
        Registry storage registry,
        uint256 index
    ) internal returns (uint256 amount0, uint256 amount1, uint256 lpFees0, uint256 lpFees1) {
        Range memory range = registry.ranges[vs.ranges[index]];
        address adapterAddress = _getPoolDexAdapter(registry, range.poolId);
        if (range.liquidity > 0) {
            (bool success, bytes memory data) = adapterAddress.delegatecall(
                abi.encodeWithSelector(DEXAdapterFacet.burnRange.selector, range.id)
            );
            if (!success) revert Errors.DelegateCallFailed();
            // Extract withdrawn amounts and LP fees
            (amount0, amount1, lpFees0, lpFees1) = abi.decode(
                data,
                (uint256, uint256, uint256, uint256)
            );
        }
        delete registry.ranges[range.id];
        registry.rangeCount--;
        // swap and pop to save gas
        if (index < vs.ranges.length - 1) {
            vs.ranges[index] = vs.ranges[vs.ranges.length - 1];
        }
        vs.ranges.pop();
        return (amount0, amount1, lpFees0, lpFees1);
    }

    function _processSwaps(Rebalance memory rebalanceData) internal {
        // Process all swaps in the rebalance data
        uint256 swapLength = rebalanceData.swapRouters.length;
        unchecked {
            for (uint256 i = 0; i < swapLength; ++i) {
                _processSwap(rebalanceData.swapRouters[i], rebalanceData.swapData[i]);
            }
        }
    }

    function _processMints(
        ALMVault storage vs,
        Rebalance memory rebalanceData
    ) internal {
        // Process mints
        uint256 mintLength = rebalanceData.ranges.length;

        for (uint256 i = 0; i < mintLength; ++i) {
            _processMintRange(vs, rebalanceData.ranges[i]);
        }
    }

    function _processMintRange(
        ALMVault storage vs,
        Range memory range
    ) internal {
        // Ensure vaultId is set
        range.vaultId = vs.id;

        if (range.id == bytes32(0)) {
            // Generate a new rangeId based on vault, pool, and ticks
            range.id = keccak256(
                abi.encodePacked(
                    vs.id,
                    range.poolId,
                    range.lowerTick,
                    range.upperTick
                )
            );
        }
        
        bytes32 rangeId = range.id;
        Registry storage registry = S.registry();
        
        // Get the DEX adapter for this pool
        address adapterAddress = _getPoolDexAdapter(registry, range.poolId);

        // Store range in protocol-level mapping for future lookups
        registry.ranges[rangeId] = range;

        // Also add to backward-compatible array
        vs.ranges.push(rangeId);

        // Execute delegate call to mint liquidity
        (bool success, bytes memory data) = adapterAddress.delegatecall(
            abi.encodeWithSelector(DEXAdapterFacet.mintRange.selector, rangeId)
        );
        if (!success) revert Errors.DelegateCallFailed();

        // Update the range with the liquidity amount
        Range storage storedRange = registry.ranges[rangeId];
        (storedRange.liquidity, , ) = abi.decode(data, (uint128, uint256, uint256));
    }

    function _previewWithdraw(
        ALMVault storage vs,
        uint256 sharesBurnt
    ) internal returns (uint256 amount0, uint256 amount1, uint256 fee0, uint256 fee1) {
        return _sharesToAmounts(vs, S.registry(), sharesBurnt, FeeType.EXIT);
    }

    function _mintRanges(
        ALMVault storage vs,
        Rebalance memory rebalanceData
    ) internal {
        // Process mints
        uint256 mintLength = rebalanceData.ranges.length;

        for (uint256 i = 0; i < mintLength; ++i) {
            _processMintRange(vs, rebalanceData.ranges[i]);
        }
    }
}
