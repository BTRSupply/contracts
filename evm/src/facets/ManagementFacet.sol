// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {LibDiamond} from "@libraries/LibDiamond.sol";
import {LibAccessControl} from "@libraries/LibAccessControl.sol";
import {LibManagement as M} from "@libraries/LibManagement.sol";
import {BTRStorage as S} from "@libraries/BTRStorage.sol";
import {BTRErrors as Errors, BTREvents as Events} from "@libraries/BTREvents.sol";
import {AccountStatus as AS, AddressType, ErrorType, Fees, CoreStorage, ALMVault} from "@/BTRTypes.sol";
import {PermissionedFacet} from "@facets/abstract/PermissionedFacet.sol";
import {PausableFacet} from "@facets/abstract/PausableFacet.sol";
import {NonReentrantFacet} from "@facets/abstract/NonReentrantFacet.sol";

contract ManagementFacet is PermissionedFacet, PausableFacet, NonReentrantFacet {

    /*═══════════════════════════════════════════════════════════════╗
    ║                             PAUSE                              ║
    ╚═══════════════════════════════════════════════════════════════*/

    // protocol level pause
    function pause() external onlyManager {
        M.pause(0);
    }

    function unpause() external onlyManager {
        M.unpause(0);
    }

    // vault level pause
    function pause(uint32 vaultId) external onlyManager {
        M.pause(vaultId);
    }

    function unpause(uint32 vaultId) external onlyManager {
        M.unpause(vaultId);
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                           MANAGEMENT                           ║
    ╚═══════════════════════════════════════════════════════════════*/

    function getVersion() external view returns (uint8) {
        return M.getVersion();
    }

    function setVersion(uint8 version) external onlyAdmin {
        M.setVersion(version);
    }

    function setMaxSupply(uint32 vaultId, uint256 maxSupply) external onlyManager {
        M.setMaxSupply(vaultId, maxSupply);
    }

    function getMaxSupply(uint32 vaultId) external view returns (uint256) {
        return M.getMaxSupply(vaultId);
    }

    function getVaultCount() external view returns (uint32) {
        return S.registry().vaultCount;
    }

    function getRangeCount() external view returns (uint32) {
        return S.registry().rangeCount;
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                     WHITELISTED/BLACKLISTED                    ║
    ╚═══════════════════════════════════════════════════════════════*/

    function setAccountStatus(address account, AS status) external onlyManager {
        M.setAccountStatus(account, status);
    }

    function setAccountStatusBatch(address[] calldata accounts, AS status) external onlyManager {
        M.setAccountStatusBatch(accounts, status);
    }

    function getAccountStatus(address account) external view returns (AS) {
        return M.getAccountStatus(account);
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                       WHITELISTED/BLACKLISTED                  ║
    ╚═══════════════════════════════════════════════════════════════*/

    function addToWhitelist(address account) external onlyManager {
        M.addToWhitelist(account);
    }

    function removeFromList(address account) external onlyManager {
        M.removeFromList(account);
    }

    function addToBlacklist(address account) external onlyManager {
        M.addToBlacklist(account);
    }

    function addToListBatch(address[] calldata accounts, AS status) external onlyManager {
        M.addToListBatch(accounts, status);
    }

    function removeFromListBatch(address[] calldata accounts) external onlyManager {
        M.removeFromListBatch(accounts);
    }

    function isWhitelisted(address account) external view returns (bool) {
        return M.isWhitelisted(account);
    }

    function isBlacklisted(address account) external view returns (bool) {
        return M.isBlacklisted(account);
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                         RESTRICTED MINT                        ║
    ╚═══════════════════════════════════════════════════════════════*/

    function setRestrictedMint(uint32 vaultId, bool restricted) external onlyManager {
        M.setRestrictedMint(vaultId, restricted);
    }

    function isRestrictedMint(uint32 vaultId) external view returns (bool) {
        return M.isRestrictedMint(vaultId);
    }
    
    function isRestrictedMinter(uint32 vaultId, address minter) external view returns (bool) {
        return M.isRestrictedMinter(vaultId, minter);
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                            RANGES                              ║
    ╚═══════════════════════════════════════════════════════════════*/

    function setRangeWeights(uint32 vaultId, uint256[] memory weights) external onlyManager nonReentrant {
        M.setRangeWeights(vaultId, weights);
    }

    function zeroOutRangeWeights(uint32 vaultId) external onlyManager nonReentrant {
        M.zeroOutRangeWeights(vaultId);
    }
}
