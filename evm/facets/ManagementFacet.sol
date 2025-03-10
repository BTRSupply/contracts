// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibAccessControl} from "../libraries/LibAccessControl.sol";
import {LibManageable} from "../libraries/LibManageable.sol";
import "../BTRTypes.sol";
import {BTRStorage as S} from "../libraries/BTRStorage.sol";
import {BTRErrors as Errors, BTREvents as Events} from "../libraries/BTREvents.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {ProtocolStorage} from "../BTRTypes.sol";
import {PermissionedFacet} from "./abstract/PermissionedFacet.sol";

contract ManagementFacet is PermissionedFacet {
    /*═══════════════════════════════════════════════════════════════╗
    ║                             PAUSE                              ║
    ╚═══════════════════════════════════════════════════════════════*/

    function isPaused() external view returns (bool) {
        return LibManageable.isPaused();
    }

    function pause() external onlyManager {
        LibManageable.pause();
    }

    function unpause() external onlyManager {
        LibManageable.unpause();
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                         CONFIGURATION                          ║
    ╚═══════════════════════════════════════════════════════════════*/

    function setfeeBps(uint16 feeBps) external onlyManager {
        LibManageable.setfeeBps(feeBps);
    }

    function setRestrictedMint(address minter, bool restricted) external onlyAdmin {
        LibManageable.setRestrictedMint(minter, restricted);
    }

    function setMaxSupply(uint256 maxSupply) external onlyManager {
        LibManageable.setMaxSupply(maxSupply);
    }

    function setAddressType(address target, AddressType addressType) external onlyManager {
        if (target == address(0)) {
            revert Errors.ZeroAddress();
        }
        
        ProtocolStorage storage ms = S.management();
        ms.blacklist[target] = addressType;
        
        emit Events.BlacklistUpdated(target, uint8(addressType));
    }

    function setBlacklist(address target, uint8 addressType) external onlyManager {
        // Replace require statement with custom error
        if (addressType > uint8(AddressType.ROUTER)) {
            revert Errors.InvalidAddressType(addressType);
        }
        
        if (target == address(0)) {
            revert Errors.ZeroAddress();
        }

        ProtocolStorage storage ms = S.management();
        ms.blacklist[target] = AddressType(addressType);
        
        emit Events.BlacklistUpdated(target, addressType);
    }

    /// @notice Set the treasury address and grant treasury role
    /// @param _treasury New treasury address
    function setTreasury(address _treasury) external onlyAdmin {
        if (_treasury == address(0)) {
            revert Errors.InvalidTreasuryAddress();
        }
        
        ProtocolStorage storage ms = S.management();
        ms.treasury = _treasury;
        
        // Grant treasury role to the address
        LibAccessControl.grantRole(LibAccessControl.TREASURY_ROLE, _treasury);
        
        emit Events.TreasuryUpdated(_treasury);
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                             VIEWS                              ║
    ╚═══════════════════════════════════════════════════════════════*/

    function isBlacklisted(address target) external view returns (bool) {
        return S.management().blacklist[target] != AddressType.NONE;
    }

    function getAddressType(address target) external view returns (uint8) {
        return uint8(S.management().blacklist[target]);
    }

    function getAddressTypeEnum(address target) external view returns (AddressType) {
        return S.management().blacklist[target];
    }

    function getMaxSupply() external view returns (uint256) {
        return LibManageable.getMaxSupply();
    }

    function isRestrictedMint() external view returns (bool) {
        return LibManageable.isRestrictedMint();
    }
    
    function isRestrictedMinter(address minter) external view returns (bool) {
        return LibManageable.isRestrictedMinter(minter);
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                        VAULT MANAGEMENT                         ║
    ╚═══════════════════════════════════════════════════════════════*/

    /// @notice Check if an account is whitelisted for a vault
    /// @param vaultId ID of the vault
    /// @param account Address to check
    /// @return True if the account is whitelisted
    function isVaultWhitelisted(uint32 vaultId, address account) external view returns (bool) {
        if (vaultId >= S.protocol().vaultCount) revert Errors.NotFound(ErrorType.VAULT);
        return LibManageable.isWhitelisted(vaultId, account);
    }

    /// @notice Add addresses to whitelist for a vault
    /// @param vaultId ID of the vault
    /// @param accounts Addresses to add to whitelist
    function addToVaultWhitelist(uint32 vaultId, address[] calldata accounts) external onlyManager {
        if (vaultId >= S.protocol().vaultCount) revert Errors.NotFound(ErrorType.VAULT);
        LibManageable.addToWhitelist(vaultId, accounts);
    }

    /// @notice Remove addresses from whitelist for a vault
    /// @param vaultId ID of the vault
    /// @param accounts Addresses to remove from whitelist
    function removeFromVaultWhitelist(uint32 vaultId, address[] calldata accounts) external onlyManager {
        if (vaultId >= S.protocol().vaultCount) revert Errors.NotFound(ErrorType.VAULT);
        LibManageable.removeFromWhitelist(vaultId, accounts);
    }

    /// @notice Set restricted mint status for a vault
    /// @param vaultId ID of the vault
    /// @param restricted Whether minting should be restricted to whitelisted addresses
    function setVaultRestrictedMint(uint32 vaultId, bool restricted) external onlyManager {
        if (vaultId >= S.protocol().vaultCount) revert Errors.NotFound(ErrorType.VAULT);
        LibManageable.setVaultRestrictedMint(vaultId, restricted);
    }

    /// @notice Set fee for a vault
    /// @param vaultId ID of the vault
    /// @param feeBps Fee in basis points (1/100 of a percent)
    function setVaultFee(uint32 vaultId, uint16 feeBps) external onlyManager {
        if (vaultId >= S.protocol().vaultCount) revert Errors.NotFound(ErrorType.VAULT);
        if (feeBps > 10000) revert Errors.Exceeds(feeBps, 10000);
        
        VaultStorage storage vs = S.protocol().vaults[vaultId];
        vs.feeBps = feeBps;
        emit Events.FeeUpdated(vaultId, feeBps);
    }

    /// @notice Get current vault count
    /// @return Count of vaults created
    function getVaultCount() external view returns (uint32) {
        return S.protocol().vaultCount;
    }

    /// @notice Pause a specific vault
    /// @param vaultId ID of the vault to pause
    function pauseVault(uint32 vaultId) external onlyManager {
        if (vaultId >= S.protocol().vaultCount) revert Errors.NotFound(ErrorType.VAULT);
        VaultStorage storage vs = S.protocol().vaults[vaultId];
        vs.paused = true;
        emit Events.VaultPaused(vaultId);
    }

    /// @notice Unpause a specific vault
    /// @param vaultId ID of the vault to unpause
    function unpauseVault(uint32 vaultId) external onlyManager {
        if (vaultId >= S.protocol().vaultCount) revert Errors.NotFound(ErrorType.VAULT);
        VaultStorage storage vs = S.protocol().vaults[vaultId];
        vs.paused = false;
        emit Events.VaultUnpaused(vaultId);
    }
}