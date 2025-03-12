// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {BTRErrors as Errors, BTREvents as Events} from "./BTREvents.sol";
import {BTRStorage as S} from "./BTRStorage.sol";
import {BTRUtils as Utils} from "./BTRUtils.sol";
import {LibAccessControl as AC} from "./LibAccessControl.sol";
import {LibPausable as P} from "./LibPausable.sol";
import {AccountStatus as AS, AddressType, ErrorType, Fees, ProtocolStorage, VaultStorage} from "../BTRTypes.sol";

library LibManagement {

    using Utils for uint32;

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
    ║                             PAUSE                              ║
    ╚═══════════════════════════════════════════════════════════════*/

    function pause(uint32 vaultId) internal {
        P.pause(vaultId);
    }

    function unpause(uint32 vaultId) internal {
        P.unpause(vaultId);
    }

    function isPaused(uint32 vaultId) internal view returns (bool) {
        return P.isPaused(vaultId);
    }

    function isPaused() internal view returns (bool) {
        return P.isPaused();
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                           MANAGEMENT                           ║
    ╚═══════════════════════════════════════════════════════════════*/

    function getVersion() internal view returns (uint8) {
        return S.protocol().version;
    }

    function setVersion(uint8 version) internal {
        S.protocol().version = version;
        emit Events.VersionUpdated(version);
    }

    function setMaxSupply(uint32 vaultId, uint256 maxSupply) internal {
        vaultId.getVaultStorage().maxSupply = maxSupply;
        emit Events.MaxSupplyUpdated(vaultId, maxSupply);
    }

    function getMaxSupply(uint32 vaultId) internal view returns (uint256) {
        return vaultId.getVaultStorage().maxSupply;
    }

    function isRestrictedMint(uint32 vaultId) internal view returns (bool) {
        return vaultId.getVaultStorage().restrictedMint;
    }

    function isRestrictedMinter(uint32 vaultId, address minter) internal view returns (bool) {
        ProtocolStorage storage ps = vaultId.getProtocolStorage();
        VaultStorage storage vs = ps.vaults[vaultId];

        // Check if address is blacklisted at either level
        if (getAccountStatus(0, minter) == AS.BLACKLIST || 
            getAccountStatus(vaultId, minter) == AS.BLACKLIST) {
            return true;
        }

        // If restricted mint is enabled, check whitelist
        if (ps.restrictedMint || vs.restrictedMint) {
            // If restricted mint is enabled, check if the address is NOT whitelisted
            return getAccountStatus(0, minter) != AS.WHITELIST && 
                   getAccountStatus(vaultId, minter) != AS.WHITELIST;
        }

        return false;
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                       ADDRESS STATUS                           ║
    ╚═══════════════════════════════════════════════════════════════*/

    function getAccountStatusMap(uint32 vaultId) internal view returns (mapping(address => AS) storage) {
        return vaultId == 0 ? S.protocol().accountStatus : vaultId.getVaultStorage().accountStatus;
    }

    function getAccountStatus(uint32 vaultId, address account) internal view returns (AS) {
        return getAccountStatusMap(vaultId)[account];
    }

    function setAccountStatus(uint32 vaultId, address account, AS status) internal {
        mapping(address => AS) storage sm = getAccountStatusMap(vaultId);
        AS prev = sm[account];
        sm[account] = status;
        emit Events.AccountStatusUpdated(account, vaultId, prev, status);
    }

    // Protocol level helpers
    function setAccountStatus(address account, AS status) internal {
        setAccountStatus(0, account, status);
    }

    function setAccountStatusBatch(uint32 vaultId, address[] memory accounts, AS status) internal {
        uint256 len = accounts.length;
        for (uint256 i = 0; i < len;) {
            setAccountStatus(vaultId, accounts[i], status);
            unchecked { ++i; }
        }
    }

    function setAccountStatusBatch(address[] memory accounts, AS status) internal {
        setAccountStatusBatch(0, accounts, status);
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                       WHITELIST/BLACKLIST                      ║
    ╚═══════════════════════════════════════════════════════════════*/

    function addToWhitelist(uint32 vaultId, address account) internal {
        setAccountStatus(vaultId, account, AS.WHITELIST);
    }

    function removeFromList(uint32 vaultId, address account) internal {
        setAccountStatus(vaultId, account, AS.NONE);
    }

    function addToBlacklist(uint32 vaultId, address account) internal {
        setAccountStatus(vaultId, account, AS.BLACKLIST);
    }

    function isWhitelisted(address account, uint32 vaultId) internal view returns (bool) {
        return getAccountStatus(vaultId, account) == AS.WHITELIST;
    }

    function isBlacklisted(address account, uint32 vaultId) internal view returns (bool) {
        return getAccountStatus(vaultId, account) == AS.BLACKLIST;
    }

    function isWhitelisted(address account) internal view returns (bool) {
        return isWhitelisted(account, 0);
    }

    function isBlacklisted(address account) internal view returns (bool) {
        return isBlacklisted(account, 0);
    }

    function addToWhitelist(address account) internal {
        addToWhitelist(0, account);
    }

    function addToBlacklist(address account) internal {
        addToBlacklist(0, account);
    }

    function removeFromList(address account) internal {
        removeFromList(0, account);
    }

    function addToListBatch(uint32 vaultId, address[] memory accounts, AS status) internal {
        for (uint256 i = 0; i < accounts.length; i++) {
            setAccountStatus(vaultId, accounts[i], status);
        }
    }

    function addToListBatch(address[] memory accounts, AS status) internal {
        addToListBatch(0, accounts, status);
    }

    function removeFromListBatch(uint32 vaultId, address[] memory accounts) internal {
        for (uint256 i = 0; i < accounts.length; i++) {
            setAccountStatus(vaultId, accounts[i], AS.NONE);
        }
    }

    function removeFromListBatch(address[] memory accounts) internal {
        removeFromListBatch(0, accounts);
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                         RESTRICTED MINT                        ║
    ╚═══════════════════════════════════════════════════════════════*/

    // vault level restricted mint
    function setRestrictedMint(uint32 vaultId, bool restricted) internal {
        if (vaultId == 0) {
            S.protocol().restrictedMint = restricted;
        } else {
            S.protocol().vaults[vaultId].restrictedMint = restricted;
        }
        if (restricted) {
            emit Events.MintRestricted(vaultId, msg.sender);
        } else {
            emit Events.MintUnrestricted(vaultId, msg.sender);
        }
    }

    // protocol level restricted mint
    function setRestrictedMint(bool restricted) internal {
        return setRestrictedMint(0, restricted);
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                            TREASURY                            ║
    ╚═══════════════════════════════════════════════════════════════*/

    function getTreasury() internal view returns (address) {
        return S.protocol().treasury;
    }

    function setTreasury(address treasury) internal {
        if (treasury == address(0)) revert Errors.ZeroAddress();
        ProtocolStorage storage ps = S.protocol();
        if (treasury == ps.treasury) revert Errors.AlreadyExists(ErrorType.TREASURY);

        // Revoke the previous treasury if it exists
        if (ps.treasury != address(0)) {
            AC.revokeRole(AC.TREASURY_ROLE, ps.treasury);
        }

        // Update treasury address
        AC.grantRole(AC.TREASURY_ROLE, treasury);
        ps.treasury = treasury;
        emit Events.TreasuryUpdated(treasury);
    }

    function setFees(uint32 vaultId, Fees memory fees) internal {
        // Validate fee ranges
        if (fees.entry > MAX_ENTRY_FEE_BPS) revert Errors.Exceeds(fees.entry, MAX_ENTRY_FEE_BPS);
        if (fees.exit > MAX_EXIT_FEE_BPS) revert Errors.Exceeds(fees.exit, MAX_EXIT_FEE_BPS);
        if (fees.mgmt > MAX_MGMT_FEE_BPS) revert Errors.Exceeds(fees.mgmt, MAX_MGMT_FEE_BPS);
        if (fees.perf > MAX_PERFORMANCE_FEE_BPS) revert Errors.Exceeds(fees.perf, MAX_PERFORMANCE_FEE_BPS);
        if (fees.flash > MAX_FLASH_FEE_BPS) revert Errors.Exceeds(fees.flash, MAX_FLASH_FEE_BPS);

        vaultId == 0 ? S.protocol().fees = fees : vaultId.getVaultStorage().fees = fees;
        emit Events.FeesUpdated(vaultId, fees.entry, fees.exit, fees.mgmt, fees.perf, fees.flash);
        emit Events.FeesUpdated(vaultId, fees.entry, fees.exit, fees.mgmt, fees.perf, fees.flash);
    }

    function setFees(Fees memory fees) internal {
        setFees(0, fees);
    }

    function getFees(uint32 vaultId) internal view returns (Fees memory) {
        return vaultId == 0 ? S.protocol().fees : vaultId.getVaultStorage().fees;
    }

    function getFees() internal view returns (Fees memory) {
        return getFees(0);
    }

    // vault level fees
    function getAccruedFees(uint32 vaultId, IERC20Metadata token) external view returns (uint256) {
        return vaultId == 0 ? S.protocol().accruedFees[token] : vaultId.getVaultStorage().accruedFees[token];
    }

    // protocol level fees
    function getAccruedFees(IERC20Metadata token) external view returns (uint256) {
        return S.protocol().accruedFees[token];
    }

    function getPendingFees(IERC20Metadata token) external view returns (uint256) {
        return S.protocol().pendingFees[token];
    }

    function getPendingFees(uint32 vaultId, IERC20Metadata token) external view returns (uint256) {
        return vaultId == 0 ? S.protocol().pendingFees[token] : vaultId.getVaultStorage().pendingFees[token];
    }
}
