// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {LibAccessControl} from "./LibAccessControl.sol";
import {BTRStorage as S} from "./BTRStorage.sol";
import {VaultStorage, AddressType} from "../BTRTypes.sol";
import {BTRErrors as Errors, BTREvents as Events} from "./BTREvents.sol";

/// @title LibManageable
/// @notice Library for vault management functionality
/// @dev Shared logic for management functions including pause control
library LibManageable {
    // Fee constants
    uint16 internal constant MIN_FEE_BPS = 0;
    uint16 internal constant MAX_FEE_BPS = 5000; // 50%
    uint16 internal constant MAX_FLASH_FEE_BPS = 5000; // 50%
    uint16 internal constant MAX_PERFORMANCE_FEE_BPS = 5000; // 50%
    uint16 internal constant MAX_ENTRY_FEE_BPS = 5000; // 50%
    uint16 internal constant MAX_EXIT_FEE_BPS = 5000; // 50%
    uint16 internal constant MAX_MGMT_FEE_BPS = 5000; // 50%

    /*═══════════════════════════════════════════════════════════════╗
    ║                             PAUSE                              ║
    ╚═══════════════════════════════════════════════════════════════*/

    /// @notice Check if the protocol is paused
    /// @return Whether the protocol is paused
    function isPaused() internal view returns (bool) {
        return S.protocol().paused;
    }

    /// @notice Pause the protocol - internal implementation
    function pause() internal {
        if (S.protocol().paused) {
            revert Errors.Paused();
        }
        
        S.protocol().paused = true;
        
        emit Events.ProtocolPaused(msg.sender);
    }

    /// @notice Unpause the protocol - internal implementation
    function unpause() internal {
        if (!S.protocol().paused) {
            revert Errors.NotPaused();
        }
        
        S.protocol().paused = false;
        
        emit Events.ProtocolUnpaused(msg.sender);
    }

    /// @notice Check if the protocol is paused
    /// @return Whether the protocol is paused
    function whenNotPaused() internal view {
        if (S.protocol().paused) revert Errors.Paused();
    }

    /// @notice Check if the protocol is not paused
    /// @return Whether the protocol is not paused
    function whenPaused() internal view {
        if (!S.protocol().paused) revert Errors.NotPaused();
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                           MANAGEMENT                           ║
    ╚═══════════════════════════════════════════════════════════════*/

    /// @notice Set protocol level fees - internal implementation
    /// @param fees New fee configuration
    function setProtocolFees(Fees memory fees) internal {
        // Validate fee ranges
        if (fees.entry > MAX_ENTRY_FEE_BPS) revert Errors.Exceeds(fees.entry, MAX_ENTRY_FEE_BPS);
        if (fees.exit > MAX_EXIT_FEE_BPS) revert Errors.Exceeds(fees.exit, MAX_EXIT_FEE_BPS);
        if (fees.mgmt > MAX_MGMT_FEE_BPS) revert Errors.Exceeds(fees.mgmt, MAX_MGMT_FEE_BPS);
        if (fees.perf > MAX_PERFORMANCE_FEE_BPS) revert Errors.Exceeds(fees.perf, MAX_PERFORMANCE_FEE_BPS);
        if (fees.flash > MAX_FLASH_FEE_BPS) revert Errors.Exceeds(fees.flash, MAX_FLASH_FEE_BPS);
        
        S.protocol().fees = fees;
        emit Events.ProtocolFeesUpdated(fees.entry, fees.exit, fees.mgmt, fees.perf, fees.flash);
    }

    /// @notice Set vault level fees - internal implementation
    /// @param vaultId ID of the vault
    /// @param fees New fee configuration
    function setVaultFees(uint32 vaultId, Fees memory fees) internal {
        // Validate fee ranges
        if (fees.entry > MAX_ENTRY_FEE_BPS) revert Errors.Exceeds(fees.entry, MAX_ENTRY_FEE_BPS);
        if (fees.exit > MAX_EXIT_FEE_BPS) revert Errors.Exceeds(fees.exit, MAX_EXIT_FEE_BPS);
        if (fees.mgmt > MAX_MGMT_FEE_BPS) revert Errors.Exceeds(fees.mgmt, MAX_MGMT_FEE_BPS);
        if (fees.perf > MAX_PERFORMANCE_FEE_BPS) revert Errors.Exceeds(fees.perf, MAX_PERFORMANCE_FEE_BPS);
        if (fees.flash > MAX_FLASH_FEE_BPS) revert Errors.Exceeds(fees.flash, MAX_FLASH_FEE_BPS);
        
        VaultStorage storage vs = S.protocol().vaults[vaultId];
        vs.fees = fees;
        emit Events.VaultFeesUpdated(vaultId, fees.entry, fees.exit, fees.mgmt, fees.perf, fees.flash);
    }

    /// @notice Get protocol level fees
    /// @return Current fee configuration
    function getProtocolFees() internal view returns (Fees memory) {
        return S.protocol().fees;
    }

    /// @notice Get vault level fees
    /// @param vaultId ID of the vault
    /// @return Current fee configuration
    function getVaultFees(uint32 vaultId) internal view returns (Fees memory) {
        return S.protocol().vaults[vaultId].fees;
    }

    /// @notice Set restricted mint status for an address - internal implementation
    /// @param minter Address to set restriction for
    /// @param restricted Whether the address is restricted
    function setRestrictedMint(address minter, bool restricted) internal {
        if (minter == address(0)) {
            revert Errors.ZeroAddress();
        }
        
        S.protocol().restrictedMint[minter] = restricted;
        
        emit Events.MintRestricted(minter);
        emit Events.restrictedMintUpdated(restricted);
    }

    /// @notice Set maximum supply - internal implementation
    /// @param maxSupply Maximum tokens that can be minted (0 = unlimited)
    function setMaxSupply(uint256 maxSupply) internal {
        S.protocol().maxSupply = maxSupply;
        emit Events.MaxSupplyUpdated(maxSupply);
    }

    /// @notice Get the maximum mint capacity
    /// @return The maximum tokens that can be minted
    function getMaxSupply() internal view returns (uint256) {
        return S.protocol().maxSupply;
    }

    /// @notice Check if global mint restriction is active
    /// @return Whether global mint restriction is active
    function isRestrictedMint() internal view returns (bool) {
        return S.protocol().restrictedMint;
    }

    /// @notice Check if an address is restricted from minting
    /// @param minter The address to check
    /// @return Whether the address is restricted
    function isRestrictedMinter(address minter) internal view returns (bool) {
        return S.protocol().whitelist[minter];
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                          WHITELIST                           ║
    ╚═══════════════════════════════════════════════════════════════*/

    /// @notice Add addresses to the vault's whitelist
    /// @param vaultId ID of the vault
    /// @param accounts Addresses to add to whitelist
    function addToWhitelist(uint32 vaultId, address[] calldata accounts) internal {
        VaultStorage storage vs = S.protocol().vaults[vaultId];
        
        for (uint256 i = 0; i < accounts.length; i++) {
            vs.whitelist[accounts[i]] = AddressType.USER;
        }
        
        emit Events.WhitelistUpdated(vaultId, accounts, true);
    }

    /// @notice Remove addresses from the vault's whitelist
    /// @param vaultId ID of the vault
    /// @param accounts Addresses to remove from whitelist
    function removeFromWhitelist(uint32 vaultId, address[] calldata accounts) internal {
        VaultStorage storage vs = S.protocol().vaults[vaultId];
        
        for (uint256 i = 0; i < accounts.length; i++) {
            vs.whitelist[accounts[i]] = AddressType.NONE;
        }
        
        emit Events.WhitelistUpdated(vaultId, accounts, false);
    }

    /// @notice Set restricted mint status for a vault
    /// @param vaultId ID of the vault
    /// @param restricted Whether minting should be restricted to whitelisted addresses
    function setVaultRestrictedMint(uint32 vaultId, bool restricted) internal {
        VaultStorage storage vs = S.protocol().vaults[vaultId];
        vs.restrictedMint = restricted;
        emit Events.RestrictedMintUpdated(vaultId, restricted);
    }

    /// @notice Check if an account is whitelisted for a vault
    /// @param vaultId ID of the vault
    /// @param account Address to check
    /// @return Whether the account is whitelisted
    function isWhitelisted(uint32 vaultId, address account) internal view returns (bool) {
        return S.protocol().vaults[vaultId].whitelist[account] != AddressType.NONE;
    }
} 