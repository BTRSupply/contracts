// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {BTRStorage as S} from "@libraries/BTRStorage.sol";
import {BTRUtils} from "@libraries/BTRUtils.sol";
import {BTRErrors as Errors} from "@libraries/BTREvents.sol";
import {ErrorType, AccountStatus as AS} from "@/BTRTypes.sol";

abstract contract RestrictedFacet {

    using BTRUtils for uint32;

    function checkNotBlacklisted(address account) internal view {
        if (S.restrictions().accountStatus[account] == AS.BLACKLISTED) revert Errors.Unauthorized(ErrorType.ADDRESS);
    }

    function checkWhitelisted(address account) internal view {
        if (S.restrictions().accountStatus[account] != AS.WHITELISTED) revert Errors.Unauthorized(ErrorType.ADDRESS);
    }

    function checkUnlisted(uint32 /* vaultId */, address account) internal view {
        if (S.restrictions().accountStatus[account] != AS.NONE) revert Errors.Unauthorized(ErrorType.ADDRESS);
    }

    function checkUnrestrictedMinter(uint32 vaultId, address account) internal view {
        vaultId.getVault().restrictedMint ? checkWhitelisted(account) : checkNotBlacklisted(account);
    }

    modifier onlyNotBlacklisted(uint32 vaultId, address account) {
        checkNotBlacklisted(account);
        _;
    }

    modifier onlyWhitelisted(uint32 vaultId, address account) {
        checkWhitelisted(account);
        _;
    }

    modifier onlyUnlisted(uint32 vaultId, address account) {
        checkUnlisted(vaultId, account);
        _;
    }
    
    modifier onlyUnrestrictedMinter(uint32 vaultId, address account) {
        checkUnrestrictedMinter(vaultId, account);
        _;
    }
}
