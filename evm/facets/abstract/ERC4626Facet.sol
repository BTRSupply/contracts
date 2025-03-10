// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IERC4626} from "@openzeppelin/interfaces/IERC4626.sol";
import {BTRStorage as S} from "../../libraries/BTRStorage.sol";
import {VaultStorage} from "../../BTRTypes.sol";
import {LibVaultMath} from "../../libraries/LibVaultMath.sol";
import {Maths} from "../../libraries/Maths.sol";
import {BTRErrors as Errors, BTREvents as Events} from "../../libraries/BTREvents.sol";
import {ERC20Facet} from "./ERC20Facet.sol";
import {PausableFacet} from "./PausableFacet.sol";
import {NonReentrantFacet} from "./NonReentrantFacet.sol";

/// @dev ERC4626 vault implementation inheriting from ERC20Facet to avoid redundant functions
abstract contract ERC4626Facet is ERC20Facet, PausableFacet, NonReentrantFacet, IERC4626 {
    using SafeERC20 for IERC20;
    
    function asset() external view virtual override returns (address) {
        return address(S.vault().asset);
    }
    
    function totalAssets() public view virtual override returns (uint256) {
        return LibVaultMath.calculateTotalAssets();
    }
    
    function convertToShares(uint256 assets) public view virtual override returns (uint256) {
        return LibVaultMath.convertToShares(assets, Maths.Rounding.DOWN);
    }
    
    function convertToAssets(uint256 shares) public view virtual override returns (uint256) {
        return LibVaultMath.convertToAssets(shares, Maths.Rounding.DOWN);
    }
    
    function maxDeposit(address) external view virtual override returns (uint256) {
        VaultStorage storage vs = S.vault();
        
        if (vs.paused) {
            return 0;
        }
        
        if (vs.maxSupply == 0) {
            return type(uint256).max;
        }
        
        uint256 remainingShares = vs.maxSupply - vs.totalSupply;
        return LibVaultMath.convertToAssets(remainingShares, Maths.Rounding.DOWN);
    }
    
    function previewDeposit(uint256 assets) external view virtual override returns (uint256) {
        return convertToShares(assets);
    }
    
    function deposit(uint256 assets, address receiver) external virtual override whenNotPaused nonReentrant returns (uint256);
    
    function maxMint(address) external view virtual override returns (uint256) {
        VaultStorage storage vs = S.vault();
        
        if (vs.paused) {
            return 0;
        }
        
        if (vs.maxSupply == 0) {
            return type(uint256).max;
        }
        
        return vs.maxSupply - vs.totalSupply;
    }
    
    function previewMint(uint256 shares) external view virtual override returns (uint256) {
        return LibVaultMath.convertToAssets(shares, Maths.Rounding.UP);
    }
    
    function mint(uint256 shares, address receiver) external virtual override whenNotPaused nonReentrant returns (uint256);
    
    function maxWithdraw(address owner) external view virtual override returns (uint256) {
        if (S.vault().paused) {
            return 0;
        }
        
        return convertToAssets(S.vault().balances[owner]);
    }
    
    function previewWithdraw(uint256 assets) external view virtual override returns (uint256) {
        return LibVaultMath.convertToShares(assets, Maths.Rounding.UP);
    }
    
    function withdraw(uint256 assets, address receiver, address owner) external virtual override whenNotPaused nonReentrant returns (uint256);

    function maxRedeem(address owner) external view virtual override returns (uint256) {
        if (S.vault().paused) {
            return 0;
        }
        
        return S.vault().balances[owner];
    }
    
    function previewRedeem(uint256 shares) external view virtual override returns (uint256) {
        return LibVaultMath.convertToAssets(shares, Maths.Rounding.DOWN);
    }
    
    function redeem(uint256 shares, address receiver, address owner) external virtual override whenNotPaused nonReentrant returns (uint256);
} 