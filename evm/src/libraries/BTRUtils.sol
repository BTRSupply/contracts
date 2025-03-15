// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {BTRStorage as S} from "@libraries/BTRStorage.sol";
import {ALMVault, ErrorType, CoreStorage, DEX, Range, Restrictions, Registry} from "@/BTRTypes.sol";
import {BTRErrors as Errors} from "@libraries/BTREvents.sol";

library BTRUtils {
    /*═══════════════════════════════════════════════════════════════╗
    ║                             UTILS                              ║
    ╚═══════════════════════════════════════════════════════════════*/

    function getCoreStorageIfVaultExists(
        uint32 vaultId
    ) internal view returns (CoreStorage storage cs) {
        cs = S.core();
        if (vaultId >= cs.registry.vaultCount)
            revert Errors.NotFound(ErrorType.VAULT);
    }

    function getRestrictionsStorageIfVaultExists(
        uint32 vaultId
    ) internal view returns (Restrictions storage rs) {
        return getCoreStorageIfVaultExists(vaultId).restrictions;
    }

    function getVault(
        uint32 vaultId
    ) internal view returns (ALMVault storage vs) {
        vs = getCoreStorageIfVaultExists(vaultId).registry.vaults[vaultId];
        if (vs.id == 0) revert Errors.NotFound(ErrorType.VAULT);
    }

    function getRange(
        bytes32 rangeId
    ) internal view returns (Range storage rs) {
        rs = S.registry().ranges[rangeId];
        if (rs.id == bytes32(0)) revert Errors.NotFound(ErrorType.RANGE);
    }

    function getVaultCount() internal view returns (uint32) {
        return S.registry().vaultCount;
    }

    function getRangeCount() internal view returns (uint32) {
        return S.registry().rangeCount;
    }

    function isValidDEX(DEX dex) internal pure returns (bool) {
        return uint(dex) <= uint(DEX.STELLASWAP);
    }

    function toBytes32(address addr) internal pure returns (bytes32 result) {
        assembly {
            result := addr
        }
    }

    function toAddress(bytes32 b) internal pure returns (address addr) {
        assembly {
            addr := and(b, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
        }
    }

    function hashFast(address a, address b) internal pure returns (bytes32 c) {
        assembly {
            // load the 20-byte representations of the addresses
            let baseBytes := and(a, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            let quoteBytes := and(b, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)

            // shift the first address 12 bytes (96 bits) to the left
            // then combine with the second address
            c := or(shl(96, baseBytes), quoteBytes)
        }
    }
}
