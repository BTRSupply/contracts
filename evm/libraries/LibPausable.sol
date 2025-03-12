// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {BTRStorage as S} from "./BTRStorage.sol";
import {BTRUtils as Utils} from "./BTRUtils.sol";
import {VaultStorage, ErrorType, ProtocolStorage} from "../BTRTypes.sol";
import {BTRErrors as Errors, BTREvents as Events} from "./BTREvents.sol";

library LibPausable {

    using Utils for uint32;

    /*═══════════════════════════════════════════════════════════════╗
    ║                             PAUSE                              ║
    ╚═══════════════════════════════════════════════════════════════*/

    function pause(uint32 vaultId) internal {
        if (vaultId == 0) {
            ProtocolStorage storage ps = vaultId.getProtocolStorage();
            if (ps.paused) revert Errors.Paused(ErrorType.PROTOCOL);
            ps.paused = true;
        } else {
            VaultStorage storage vs = vaultId.getVaultStorage();
            if (vs.paused) revert Errors.Paused(ErrorType.VAULT);
            vs.paused = true;
        }
        emit Events.Paused(vaultId, msg.sender);
    }

    function unpause(uint32 vaultId) internal {
        if (vaultId == 0) {
            ProtocolStorage storage ps = vaultId.getProtocolStorage();
            if (!ps.paused) revert Errors.NotPaused(ErrorType.PROTOCOL);
            ps.paused = false;
        } else {
            VaultStorage storage vs = vaultId.getVaultStorage();
            if (!vs.paused) revert Errors.NotPaused(ErrorType.VAULT);
            vs.paused = false;
        }
        emit Events.Unpaused(vaultId, msg.sender);
    }

    function isPaused(uint32 vaultId) internal view returns (bool) {
        ProtocolStorage storage ps = vaultId.getProtocolStorage();
        return vaultId == 0 ? ps.paused : ps.vaults[vaultId].paused;
    }

    // protocol level pause
    function isPaused() internal view returns (bool) {
        return isPaused(0);
    }
}
