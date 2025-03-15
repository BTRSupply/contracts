// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {BTRStorage as S} from "@libraries/BTRStorage.sol";
import {BTRUtils} from "@libraries/BTRUtils.sol";
import {ALMVault, ErrorType, Restrictions} from "@/BTRTypes.sol";
import {BTRErrors as Errors, BTREvents as Events} from "@libraries/BTREvents.sol";

library LibPausable {

    using BTRUtils for uint32;

    /*═══════════════════════════════════════════════════════════════╗
    ║                             PAUSE                              ║
    ╚═══════════════════════════════════════════════════════════════*/

    function pause(uint32 vaultId) internal {
        if (vaultId == 0) {
            Restrictions storage rs = S.restrictions();
            if (rs.paused) revert Errors.Paused(ErrorType.PROTOCOL);
            rs.paused = true;
        } else {
            ALMVault storage vs = vaultId.getVault();
            if (vs.paused) revert Errors.Paused(ErrorType.VAULT);
            vs.paused = true;
        }
        emit Events.Paused(vaultId, msg.sender);
    }

    function unpause(uint32 vaultId) internal {
        if (vaultId == 0) {
            Restrictions storage rs = S.restrictions();
            if (!rs.paused) revert Errors.NotPaused(ErrorType.PROTOCOL);
            rs.paused = false;
        } else {
            ALMVault storage vs = vaultId.getVault();
            if (!vs.paused) revert Errors.NotPaused(ErrorType.VAULT);
            vs.paused = false;
        }
        emit Events.Unpaused(vaultId, msg.sender);
    }

    function isPaused(uint32 vaultId) internal view returns (bool) {
        if (vaultId == 0) {
            return S.restrictions().paused;
        } else {
            return vaultId.getVault().paused;
        }
    }

    // protocol level pause
    function isPaused() internal view returns (bool) {
        return isPaused(0);
    }
}
