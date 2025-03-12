// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibAccessControl} from "../libraries/LibAccessControl.sol";
import {VaultStorage, PoolInfo, Range, Rebalance, AddressType, SwapPayload, ProtocolStorage, ErrorType, VaultInitParams} from "../BTRTypes.sol";
import {BTRStorage as S} from "../libraries/BTRStorage.sol";
import {BTRErrors as Errors, BTREvents as Events} from "../libraries/BTREvents.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {SafeCast} from "@openzeppelin/utils/math/SafeCast.sol";
import {LibVaultMath} from "../libraries/LibVaultMath.sol";
import {Maths} from "../libraries/Maths.sol";
import {DEXTypes} from "../libraries/DEXTypes.sol";
import {ERC1155VaultsFacet} from "./ERC1155VaultsFacet.sol";

contract ALMFacet is ERC1155VaultsFacet {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    using Maths for uint256;

    uint256 private constant MAX_RANGES = 20;

    function createVault(
        VaultInitParams calldata params
    ) external onlyManager returns (uint32 vaultId) {
        if (params.token0 == address(0)) revert Errors.ZeroAddress();
        if (params.token1 == address(0)) revert Errors.ZeroAddress();
        if (params.token0 >= params.token1) revert Errors.WrongOrder(ErrorType.TOKEN);
        if (params.initialToken0Amount == 0 || params.initialToken1Amount == 0) revert Errors.ZeroValue();
        if (params.feeBps > Maths.BP_BASIS) revert Errors.Exceeds(params.feeBps, Maths.BP_BASIS);

        ProtocolStorage storage ps = S.protocol();
        
        vaultId = ps.vaultCount;
        
        VaultStorage storage vs = ps.vaults[vaultId];
        vs.id = vaultId;
        
        vs.name = params.name;
        vs.symbol = params.symbol;
        
        if (vs.tokens.length == 0) {
            vs.tokens = new IERC20Metadata[](2);
        }
        vs.tokens[0] = IERC20Metadata(params.token0);
        vs.tokens[1] = IERC20Metadata(params.token1);
        vs.asset = vs.tokens[0];
        vs.decimals = vs.tokens[0].decimals();
        
        vs.initialTokenAmounts = new uint256[](2);
        vs.initialTokenAmounts[0] = params.initialToken0Amount;
        vs.initialTokenAmounts[1] = params.initialToken1Amount;
        vs.initialShareAmount = params.initialToken0Amount;
        
        vs.managerTokenBalances = new uint256[](2);
        vs.managerTokenBalances[0] = 0;
        vs.managerTokenBalances[1] = 0;
        
        vs.feeBps = params.feeBps;
        
        vs.maxSupply = params.maxSupply;
        
        vs.paused = false;
        vs.restrictedMint = false;
        vs.reentrancyStatus = 0;
        
        // We don't handle fee tiers or pools at vault creation anymore
        
        ps.vaultCount++;
        
        emit Events.VaultCreated(vaultId, params.name, params.symbol);
        emit Events.LogSetInits(params.initialToken0Amount, params.initialToken1Amount);
        
        return vaultId;
    }

    function mint(
        uint32 vaultId,
        uint256 mintAmount,
        address receiver
    ) external vaultExists(vaultId) whenNotPaused(vaultId) nonReentrant returns (uint256 amount0, uint256 amount1) {
        VaultStorage storage vs = S.protocol().vaults[vaultId];
        
        if (vs.restrictedMint && !vs.whitelist[msg.sender]) revert Errors.Unauthorized(ErrorType.MINTER);
        if (mintAmount == 0) revert Errors.ZeroValue();
        
        (amount0, amount1) = LibVaultMath.calculateInitialMintAmounts(
            mintAmount, 
            vs.initialTokenAmounts[0], 
            vs.initialTokenAmounts[1]
        );
        
        vs.tokens[0].safeTransferFrom(msg.sender, address(this), amount0);
        vs.tokens[1].safeTransferFrom(msg.sender, address(this), amount1);
        
        _mint(vaultId, receiver, mintAmount);
        
        emit Events.MintCompleted(receiver, mintAmount, amount0, amount1);
        return (amount0, amount1);
    }

    function burn(
        uint32 vaultId,
        uint256 burnAmount,
        address receiver
    ) external vaultExists(vaultId) whenNotPaused(vaultId) nonReentrant returns (uint256 amount0, uint256 amount1) {
        VaultStorage storage vs = S.protocol().vaults[vaultId];
        
        if (burnAmount == 0) revert Errors.ZeroValue();
        if (vs.totalSupply == 0) revert Errors.ZeroValue();
        
        _burn(vaultId, msg.sender, burnAmount);
        
        amount0 = vs.tokens[0].balanceOf(address(this)) * burnAmount / vs.totalSupply;
        amount1 = vs.tokens[1].balanceOf(address(this)) * burnAmount / vs.totalSupply;
        
        if (amount0 > 0) {
            vs.tokens[0].safeTransfer(receiver, amount0);
        }
        
        if (amount1 > 0) {
            vs.tokens[1].safeTransfer(receiver, amount1);
        }
        
        emit Events.BurnCompleted(receiver, burnAmount, amount0, amount1);
        return (amount0, amount1);
    }

    function rebalance(
        uint32 vaultId, 
        Rebalance calldata rebalance
    ) external vaultExists(vaultId) onlyKeeper nonReentrant returns (bool) {
        VaultStorage storage vs = S.protocol().vaults[vaultId];
        
        if (rebalance.mints.length == 0) revert Errors.ZeroValue();
        if (rebalance.mints.length > MAX_RANGES) revert Errors.Exceeds(rebalance.mints.length, MAX_RANGES);
        
        for (uint256 i = 0; i < rebalance.mints.length; i++) {
            Range memory range = rebalance.mints[i];
            
            bytes32 poolId = range.poolId;
            if (vs.poolInfo[poolId].poolId == bytes32(0)) revert Errors.NotFound(ErrorType.POOL);
            
            if (range.lowerTick >= range.upperTick) revert Errors.InvalidRange(range.lowerTick, range.upperTick);
        }
        
        if (rebalance.burns.length > 0) {
        }
        
        if (rebalance.swaps.length > 0) {
        }
        
        for (uint256 i = 0; i < rebalance.mints.length; i++) {
        }
        
        emit Events.RebalanceExecuted(rebalance, 
            LibVaultMath.calculateTotalAssets(vaultId, address(this)),
            LibVaultMath.calculateTotalToken1(vaultId, address(this))
        );
        
        return true;
    }

    function getTokenBalances(uint32 vaultId) external view vaultExists(vaultId) returns (uint256 balance0, uint256 balance1) {
        VaultStorage storage vs = S.protocol().vaults[vaultId];
        
        balance0 = vs.tokens[0].balanceOf(address(this));
        balance1 = vs.tokens[1].balanceOf(address(this));
        
        return (balance0, balance1);
    }

    function getVaultInfo(uint32 vaultId) external view vaultExists(vaultId) returns (VaultStorage memory) {
        return S.protocol().vaults[vaultId];
    }
}
