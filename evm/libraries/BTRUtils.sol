// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {BTRStorage as S} from "./BTRStorage.sol";
import {VaultStorage, ErrorType, ProtocolStorage} from "../BTRTypes.sol";
import {BTRErrors as Errors} from "./BTREvents.sol";

library BTRUtils {
    /*═══════════════════════════════════════════════════════════════╗
    ║                             UTILS                              ║
    ╚═══════════════════════════════════════════════════════════════*/

    function getProtocolStorage(uint32 vaultId) internal view returns (ProtocolStorage storage ps) {
        ps = S.protocol();
        if (vaultId >= ps.vaultCount) revert Errors.NotFound(ErrorType.VAULT);
    }

    function getVaultStorage(uint32 vaultId) internal view returns (VaultStorage storage vs) {
        ProtocolStorage storage ps = getProtocolStorage(vaultId);
        return ps.vaults[vaultId];
    }

    function getVaultCount() internal view returns (uint32) {
        return S.protocol().vaultCount;
    }
}
