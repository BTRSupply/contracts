// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BTRErrors as Errors, BTREvents as Events} from "@libraries/BTREvents.sol";
import {BTRStorage as S} from "@libraries/BTRStorage.sol";
import {BTRUtils} from "@libraries/BTRUtils.sol";
import {LibAccessControl as AC} from "@libraries/LibAccessControl.sol";
import {LibPausable as P} from "@libraries/LibPausable.sol";
import {LibMaths as M} from "@libraries/LibMaths.sol";
import {AccountStatus as AS, AddressType, ErrorType, Fees, CoreStorage, ALMVault, Oracles} from "@/BTRTypes.sol";

library LibManagement {

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
    uint32 internal constant MIN_TWAP_INTERVAL = 300; // 5 min
    uint32 internal constant MAX_TWAP_INTERVAL = 3600 * 24 * 7; // 7 days
    uint256 internal constant MAX_PRICE_DEVIATION = M.BP_BASIS / 3; // 33.33%
    uint256 internal constant MIN_PRICE_DEVIATION = 2; // 0.02%

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
        return S.core().version;
    }

    function setVersion(uint8 version) internal {
        S.core().version = version;
        emit Events.VersionUpdated(version);
    }

    function setMaxSupply(uint32 vaultId, uint256 maxSupply) internal {
        vaultId.getVault().maxSupply = maxSupply;
        emit Events.MaxSupplyUpdated(vaultId, maxSupply);
    }

    function getMaxSupply(uint32 vaultId) internal view returns (uint256) {
        return vaultId.getVault().maxSupply;
    }

    function isRestrictedMint(uint32 vaultId) internal view returns (bool) {
        return vaultId.getVault().restrictedMint;
    }

    function isRestrictedMinter(uint32 vaultId, address minter) internal view returns (bool) {
        AS status = getAccountStatus(minter);
        return (status == AS.BLACKLISTED) || (vaultId.getVault().restrictedMint && status != AS.WHITELISTED);
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                       ADDRESS STATUS                           ║
    ╚═══════════════════════════════════════════════════════════════*/

    function getAccountStatus(address account) internal view returns (AS) {
        return S.restrictions().accountStatus[account];
    }

    function setAccountStatus(address account, AS status) internal {
        mapping(address => AS) storage sm = S.restrictions().accountStatus;
        AS prev = sm[account];
        sm[account] = status;
        emit Events.AccountStatusUpdated(account, prev, status);
    }

    function setAccountStatusBatch(address[] memory accounts, AS status) internal {
        uint256 len = accounts.length;
        for (uint256 i = 0; i < len;) {
            setAccountStatus(accounts[i], status);
            unchecked { ++i; }
        }
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                       WHITELISTED/BLACKLISTED                  ║
    ╚═══════════════════════════════════════════════════════════════*/

    function addToWhitelist(address account) internal {
        setAccountStatus(account, AS.WHITELISTED);
    }

    function removeFromList(address account) internal {
        setAccountStatus(account, AS.NONE);
    }

    function addToBlacklist(address account) internal {
        setAccountStatus(account, AS.BLACKLISTED);
    }

    function isWhitelisted(address account) internal view returns (bool) {
        return getAccountStatus(account) == AS.WHITELISTED;
    }

    function isBlacklisted(address account) internal view returns (bool) {
        return getAccountStatus(account) == AS.BLACKLISTED;
    }

    function addToListBatch(address[] memory accounts, AS status) internal {
        for (uint256 i = 0; i < accounts.length;) {
            setAccountStatus(accounts[i], status);
            unchecked { ++i; }
        }
    }

    function removeFromListBatch(address[] memory accounts) internal {
        for (uint256 i = 0; i < accounts.length;) {
            setAccountStatus(accounts[i], AS.NONE);
            unchecked { ++i; }
        }
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                         RESTRICTED MINT                        ║
    ╚═══════════════════════════════════════════════════════════════*/

    // vault level restricted mint
    function setRestrictedMint(uint32 vaultId, bool restricted) internal {
        if (vaultId == 0) {
            revert Errors.InvalidParameter(); // restrictedMint is only at vault level
        }
        S.registry().vaults[vaultId].restrictedMint = restricted;
        
        if (restricted) {
            emit Events.MintRestricted(vaultId, msg.sender);
        } else {
            emit Events.MintUnrestricted(vaultId, msg.sender);
        }
    }

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

    // protocol level fees
    function getAccruedFees(IERC20 token) external view returns (uint256) {
        return getAccruedFees(0, token);
    }

    function getPendingFees(IERC20 token) external view returns (uint256) {
        return getPendingFees(0, token);
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                            RANGES                              ║
    ╚═══════════════════════════════════════════════════════════════*/

    function setRangeWeights(uint32 vaultId, uint256[] memory weights) internal {
        ALMVault storage vs = vaultId.getVault();
        
        if (weights.length != vs.ranges.length) {
            revert Errors.UnexpectedOutput();
        }

        uint256 totalWeight;
        for (uint256 i = 0; i < weights.length;) {
            totalWeight += weights[i];
            vs.ranges[i].weightBps = weights[i];
            unchecked { ++i; }
        }

        if (totalWeight >= M.BP_BASIS) {
            revert Errors.Exceeds(totalWeight, M.BP_BASIS - 1);
        }
    }

    function zeroOutRangeWeights(uint32 vaultId) internal {
        ALMVault storage vs = vaultId.getVault();
        uint256[] memory weights = new uint256[](vs.ranges.length);
        for (uint256 i = 0; i < weights.length;) {
            weights[i] = 0;
            unchecked { ++i; }
        }
        setRangeWeights(vaultId, weights);
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                            ORACLES                             ║
    ╚═══════════════════════════════════════════════════════════════*/

    function validatePriceProtection(uint32 lookback, uint256 maxDeviation) internal pure {
        if (lookback < MIN_TWAP_INTERVAL) revert Errors.Exceeds(lookback, MIN_TWAP_INTERVAL);
        if (lookback > MAX_TWAP_INTERVAL) revert Errors.Exceeds(lookback, MAX_TWAP_INTERVAL);
        if (maxDeviation < MIN_PRICE_DEVIATION) revert Errors.Exceeds(maxDeviation, MIN_PRICE_DEVIATION);
        if (maxDeviation > MAX_PRICE_DEVIATION) revert Errors.Exceeds(maxDeviation, MAX_PRICE_DEVIATION);
    }

    /**
     * @notice Set the default TWAP protection parameters at the protocol level
     * @param lookback Default TWAP interval in seconds for new vaults
     * @param maxDeviation Default maximum price deviation in basis points
     */
    function setDefaultPriceProtection(
        uint32 lookback,
        uint256 maxDeviation
    ) internal {
        validatePriceProtection(lookback, maxDeviation);
        Oracles storage os = S.oracles();
        os.lookback = lookback;
        os.maxDeviation = maxDeviation;
        emit Events.DefaultPriceProtectionUpdated(lookback, maxDeviation);
    }

    /**
     * @notice Set TWAP protection parameters for a specific vault
     * @param vaultId The vault ID to update
     * @param lookback TWAP interval in seconds
     * @param maxDeviation Maximum price deviation in basis points
     */
    function setVaultPriceProtection(
        uint32 vaultId,
        uint32 lookback,
        uint256 maxDeviation
    ) internal {
        validatePriceProtection(lookback, maxDeviation);
        ALMVault storage vs = vaultId.getVault();
        vs.lookback = lookback;
        vs.maxDeviation = maxDeviation;
        emit Events.VaultPriceProtectionUpdated(vaultId, lookback, maxDeviation);
    }
}
