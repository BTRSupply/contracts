// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BTRErrors as Errors, BTREvents as Events} from "@libraries/BTREvents.sol";
import {BTRStorage as S} from "@libraries/BTRStorage.sol";
import {BTRUtils} from "@libraries/BTRUtils.sol";
import {LibAccessControl as AC} from "@libraries/LibAccessControl.sol";
import {LibPausable as P} from "@libraries/LibPausable.sol";
import {LibMaths as M} from "@libraries/LibMaths.sol";
import {LibTreasury as T} from "@libraries/LibTreasury.sol";
import {AccountStatus as AS, AddressType, ErrorType, Fees, CoreStorage, ALMVault, Oracles, Range, Registry} from "@/BTRTypes.sol";
import {LibBitMask} from "@libraries/LibBitMask.sol";

library LibManagement {

    using BTRUtils for uint32;
    using LibBitMask for uint256;

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

    // Restriction bit positions
    uint8 internal constant RESTRICT_SWAP_CALLER_BIT = 0;
    uint8 internal constant RESTRICT_SWAP_ROUTER_BIT = 1;
    uint8 internal constant RESTRICT_SWAP_INPUT_BIT = 2;
    uint8 internal constant RESTRICT_SWAP_OUTPUT_BIT = 3;
    uint8 internal constant RESTRICT_BRIDGE_INPUT_BIT = 4;
    uint8 internal constant RESTRICT_BRIDGE_OUTPUT_BIT = 5;
    uint8 internal constant RESTRICT_BRIDGE_ROUTER_BIT = 6;
    uint8 internal constant APPROVE_MAX_BIT = 7;
    uint8 internal constant AUTO_REVOKE_BIT = 8;

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
        return T.getTreasury();
    }
    
    function setTreasury(address treasury) internal {
        T.setTreasury(treasury);
    }
    
    // Forward fee-related functions to LibTreasury
    function validateFees(Fees memory fees) internal pure {
        T.validateFees(fees);
    }

    function setFees(uint32 vaultId, Fees memory fees) internal {
        T.setFees(vaultId, fees);
    }

    function setFees(Fees memory fees) internal {
        T.setFees(fees);
    }

    function getFees(uint32 vaultId) internal view returns (Fees memory) {
        return T.getFees(vaultId);
    }

    function getFees() internal view returns (Fees memory) {
        return T.getFees();
    }

    // vault level fees
    function getAccruedFees(uint32 vaultId, IERC20 token) internal view returns (uint256) {
        return T.getAccruedFees(vaultId, token);
    }

    function getPendingFees(uint32 vaultId, IERC20 token) internal view returns (uint256) {
        return T.getPendingFees(vaultId, token);
    }

    // protocol level fees
    function getAccruedFees(IERC20 token) external view returns (uint256) {
        return T.getAccruedFees(token);
    }

    function getPendingFees(IERC20 token) external view returns (uint256) {
        return T.getPendingFees(token);
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                            RANGES                              ║
    ╚═══════════════════════════════════════════════════════════════*/

    function setRangeWeights(uint32 vaultId, uint256[] memory weights) internal {
        ALMVault storage vs = vaultId.getVault();
        
        if (weights.length != vs.ranges.length) {
            revert Errors.UnexpectedOutput();
        }

        Registry storage rs = S.registry();

        uint256 totalWeight;
        for (uint256 i = 0; i < weights.length;) {
            totalWeight += weights[i];
            Range storage range = rs.ranges[vs.ranges[i]];
            range.weightBps = weights[i];
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

    /*═══════════════════════════════════════════════════════════════╗
    ║                        RESTRICTION MANAGEMENT                  ║
    ╚═══════════════════════════════════════════════════════════════*/

    function getRestrictions() internal view returns (uint256) {
        return S.restrictions().restrictionMask;
    }

    function setRestriction(uint8 _bit, bool _value) internal {
        uint256 restrictions = S.restrictions().restrictionMask;
        S.restrictions().restrictionMask = _value 
            ? restrictions.setBit(_bit)
            : restrictions.resetBit(_bit);
        emit Events.RestrictionUpdated(_bit, _value);
    }

    function setSwapCallerRestriction(bool _value) internal {
        setRestriction(RESTRICT_SWAP_CALLER_BIT, _value);
    }

    function setSwapRouterRestriction(bool _value) internal {
        setRestriction(RESTRICT_SWAP_ROUTER_BIT, _value);
    }

    function setSwapInputRestriction(bool _value) internal {
        setRestriction(RESTRICT_SWAP_INPUT_BIT, _value);
    }

    function setSwapOutputRestriction(bool _value) internal {
        setRestriction(RESTRICT_SWAP_OUTPUT_BIT, _value);
    }

    function setBridgeInputRestriction(bool _value) internal {
        setRestriction(RESTRICT_BRIDGE_INPUT_BIT, _value);
    }

    function setBridgeOutputRestriction(bool _value) internal {
        setRestriction(RESTRICT_BRIDGE_OUTPUT_BIT, _value);
    }

    function setBridgeRouterRestriction(bool _value) internal {
        setRestriction(RESTRICT_BRIDGE_ROUTER_BIT, _value);
    }

    function setApproveMax(bool _value) internal {
        setRestriction(APPROVE_MAX_BIT, _value);
    }

    function setAutoRevoke(bool _value) internal {
        setRestriction(AUTO_REVOKE_BIT, _value);
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                        RESTRICTION CHECKS                      ║
    ╚═══════════════════════════════════════════════════════════════*/

    function isRestricted(uint8 _bit, address _address) internal view returns (bool) {
        return getRestrictions().getBit(_bit) && !isWhitelisted(_address);
    }

    function isSwapCallerRestricted(address _caller) internal view returns (bool) {
        return isRestricted(RESTRICT_SWAP_CALLER_BIT, _caller);
    }

    function isSwapRouterRestricted(address _router) internal view returns (bool) {
        return isRestricted(RESTRICT_SWAP_ROUTER_BIT, _router);
    }

    function isSwapInputRestricted(address _input) internal view returns (bool) {
        return isRestricted(RESTRICT_SWAP_INPUT_BIT, _input);
    }

    function isSwapOutputRestricted(address _output) internal view returns (bool) {
        return isRestricted(RESTRICT_SWAP_OUTPUT_BIT, _output);
    }

    function isBridgeInputRestricted(address _input) internal view returns (bool) {
        return isRestricted(RESTRICT_BRIDGE_INPUT_BIT, _input);
    }

    function isBridgeOutputRestricted(address _output) internal view returns (bool) {
        return isRestricted(RESTRICT_BRIDGE_OUTPUT_BIT, _output);
    }

    function isBridgeRouterRestricted(address _router) internal view returns (bool) {
        return isRestricted(RESTRICT_BRIDGE_ROUTER_BIT, _router);
    }

    function isApproveMax() internal view returns (bool) {
        return getRestrictions().getBit(APPROVE_MAX_BIT);
    }

    function isAutoRevoke() internal view returns (bool) {
        return getRestrictions().getBit(AUTO_REVOKE_BIT);
    }

    function initializeRestrictions(
        bool _restrictSwapCaller,
        bool _restrictSwapRouter,
        bool _approveMax,
        bool _autoRevoke
    ) internal {
        uint256 restrictions = 0;
        if (_restrictSwapCaller) restrictions = restrictions.setBit(RESTRICT_SWAP_CALLER_BIT);
        if (_restrictSwapRouter) restrictions = restrictions.setBit(RESTRICT_SWAP_ROUTER_BIT);
        if (_approveMax) restrictions = restrictions.setBit(APPROVE_MAX_BIT);
        if (_autoRevoke) restrictions = restrictions.setBit(AUTO_REVOKE_BIT);
        S.restrictions().restrictionMask = restrictions;
        
        // Emit single initialization event
        emit Events.RestrictionsInitialized(_restrictSwapCaller, _restrictSwapRouter, _approveMax, _autoRevoke);
    }
}
