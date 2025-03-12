// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {BTRStorage as S} from "../../libraries/BTRStorage.sol";
import {BTRErrors as Errors} from "../../libraries/BTREvents.sol";
import {BTRUtils as Utils} from "../../libraries/BTRUtils.sol";
import {LibPausable as P} from "../../libraries/LibPausable.sol";
import {ErrorType} from "../../BTRTypes.sol";

abstract contract PausableFacet {

    modifier whenNotPaused() {
        if (P.isPaused()) revert Errors.Paused(ErrorType.PROTOCOL);
        _;
    }

    /// @dev Throws if the contract is not paused
    modifier whenPaused() {
        if (!P.isPaused()) revert Errors.NotPaused(ErrorType.PROTOCOL);
        _;
    }

    /// @dev Throws if the specified vault is not paused
    modifier whenVaultNotPaused(uint32 vaultId) {
        if (P.isPaused(vaultId) || P.isPaused()) revert Errors.Paused(ErrorType.VAULT);
        _;
    }

    /// @dev Throws if the specified vault is paused
    modifier whenVaultPaused(uint32 vaultId) {
        if (!P.isPaused(vaultId) && !P.isPaused()) revert Errors.NotPaused(ErrorType.VAULT);
        _;
    }

    function isPaused() external view returns (bool) {
        return P.isPaused();
    }

    function isPaused(uint32 vaultId) external view returns (bool) {
        return P.isPaused(vaultId);
    }
}
