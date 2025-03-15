// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {BTRErrors as Errors, BTREvents as Events} from "@libraries/BTREvents.sol";
import {BTRStorage as S} from "@libraries/BTRStorage.sol";
import {LibAccessControl as AC} from "@libraries/LibAccessControl.sol";
import {ErrorType, Fees, CoreStorage} from "@/BTRTypes.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LibALM} from "@libraries/LibALM.sol";
import {BTRUtils} from "@libraries/BTRUtils.sol";

library LibTreasury {

    using LibALM for uint32;
    using BTRUtils for uint32;

    /*═══════════════════════════════════════════════════════════════╗
    ║                           CONSTANTS                            ║
    ╚═══════════════════════════════════════════════════════════════*/

    uint16 internal constant MIN_FEE_BPS = 0;
    uint16 internal constant MAX_FEE_BPS = 5000; // 50%
    uint16 internal constant MAX_FLASH_FEE_BPS = 5000; // 50%
    uint16 internal constant MAX_PERFORMANCE_FEE_BPS = 5000; // 50%
    uint16 internal constant MAX_ENTRY_FEE_BPS = 5000; // 50%
    uint16 internal constant MAX_EXIT_FEE_BPS = 5000; // 50%
    uint16 internal constant MAX_MGMT_FEE_BPS = 5000; // 50%

    /*═══════════════════════════════════════════════════════════════╗
    ║                            TREASURY                            ║
    ╚═══════════════════════════════════════════════════════════════*/

    function getTreasury() internal view returns (address) {
        return S.core().treasury.treasury;
    }

    function setTreasury(address treasury) internal {
        if (treasury == address(0)) revert Errors.ZeroAddress();
        CoreStorage storage cs = S.core();
        if (treasury == cs.treasury.treasury) revert Errors.AlreadyExists(ErrorType.ADDRESS);

        // Revoke the previous treasury if it exists
        if (cs.treasury.treasury != address(0)) {
            AC.revokeRole(AC.TREASURY_ROLE, cs.treasury.treasury);
        }

        // Update treasury address
        AC.grantRole(AC.TREASURY_ROLE, treasury);
        cs.treasury.treasury = treasury;
        emit Events.TreasuryUpdated(treasury);
    }

    function validateFees(Fees memory fees) internal pure {
        if (fees.entry > MAX_ENTRY_FEE_BPS) revert Errors.Exceeds(fees.entry, MAX_ENTRY_FEE_BPS);
        if (fees.exit > MAX_EXIT_FEE_BPS) revert Errors.Exceeds(fees.exit, MAX_EXIT_FEE_BPS);
        if (fees.mgmt > MAX_MGMT_FEE_BPS) revert Errors.Exceeds(fees.mgmt, MAX_MGMT_FEE_BPS);
        if (fees.perf > MAX_PERFORMANCE_FEE_BPS) revert Errors.Exceeds(fees.perf, MAX_PERFORMANCE_FEE_BPS);
        if (fees.flash > MAX_FLASH_FEE_BPS) revert Errors.Exceeds(fees.flash, MAX_FLASH_FEE_BPS);
    }

    function setFees(uint32 vaultId, Fees memory fees) internal {
        validateFees(fees);
        vaultId.getVault().fees = fees;
        emit Events.FeesUpdated(vaultId, fees.entry, fees.exit, fees.mgmt, fees.perf, fees.flash);
    }

    function setFees(Fees memory fees) internal {
        setFees(0, fees);
    }

    function setDefaultFees(Fees memory fees) internal {
        validateFees(fees);
        S.core().treasury.defaultFees = fees;
        emit Events.FeesUpdated(0, fees.entry, fees.exit, fees.mgmt, fees.perf, fees.flash);
    }

    function getFees(uint32 vaultId) internal view returns (Fees memory) {
        return vaultId == 0 ? S.core().treasury.defaultFees : vaultId.getVault().fees;
    }

    function getFees() internal view returns (Fees memory) {
        return getFees(0);
    }

    // vault level fees
    function getAccruedFees(uint32 vaultId, IERC20 token) internal view returns (uint256) {
        return vaultId.getVault().accruedFees[token];
    }

    function getPendingFees(uint32 vaultId, IERC20 token) internal view returns (uint256) {
        return vaultId.getVault().pendingFees[token];
    }

    function collectFees(uint32 vaultId) internal {
        vaultId.collectFees();
    }

    function collectAllFees() internal {
        for (uint32 vaultId = 0; vaultId < S.registry().vaultCount;) {
            vaultId.collectFees();
            unchecked { ++vaultId; }
        }
    }

    // protocol level fees
    function getAccruedFees(IERC20 token) internal view returns (uint256) {
        return getAccruedFees(0, token); // Use vault ID 0 for protocol-level fees
    }

    // protocol level fees
    function getPendingFees(IERC20 token) internal view returns (uint256) {
        return getPendingFees(0, token); // Use vault ID 0 for protocol-level fees
    }
}
