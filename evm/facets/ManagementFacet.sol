// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibAccessControl} from "../libraries/LibAccessControl.sol";
import {LibManagement as M} from "../libraries/LibManagement.sol";
import {BTRStorage as S} from "../libraries/BTRStorage.sol";
import {BTRErrors as Errors, BTREvents as Events} from "../libraries/BTREvents.sol";
import {AccountStatus as AS, AddressType, ErrorType, Fees, ProtocolStorage, VaultStorage} from "../BTRTypes.sol";
import {PermissionedFacet} from "./abstract/PermissionedFacet.sol";
import {PausableFacet} from "./abstract/PausableFacet.sol";

contract ManagementFacet is PermissionedFacet, PausableFacet {

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
        return M.getVaultCount();
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                            TREASURY                            ║
    ╚═══════════════════════════════════════════════════════════════*/

    // protocol level fees
    function setFees(uint32 vaultId, Fees calldata fees) external onlyManager {
        M.setFees(vaultId, fees);
    }

    // protocol level fees
    function setFees(Fees calldata fees) external onlyManager {
        M.setFees(fees);
    }

    // vault level fees
    function getFees(uint32 vaultId) external view returns (Fees memory) {
        return M.getFees(vaultId);
    }

    // protocol level fees
    function getFees() external view returns (Fees memory) {
        return M.getFees();
    }

    // vault level fees
    function getAccruedFees(uint32 vaultId, IERC20Metadata token) external view returns (uint256) {
        return M.getAccruedFees(vaultId, token);
    }

    // protocol level fees
    function getAccruedFees(IERC20Metadata token) external view returns (uint256) {
        return M.getAccruedFees(token);
    }

    function getPendingFees(IERC20Metadata token) external view returns (uint256) {
        return M.getPendingFees(token);
    }

    function getPendingFees(uint32 vaultId, IERC20Metadata token) external view returns (uint256) {
        return M.getPendingFees(vaultId, token);
    }

    function setTreasury(address _treasury) external onlyAdmin {
        M.setTreasury(_treasury);
    }

    function getTreasury() external view returns (address) {
        return M.getTreasury();
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                       WHITELIST/BLACKLIST                      ║
    ╚═══════════════════════════════════════════════════════════════*/

    // Protocol level whitelist/blacklist functions
    function addToWhitelist(address[] calldata accounts, AddressType addressType) external onlyManager {
        M.addToWhitelistBatch(accounts, addressType);
    }

    function addToWhitelist(address account, AddressType addressType) external onlyManager {
        M.addToWhitelist(account, addressType);
    }

    function removeFromWhitelist(address[] calldata accounts) external onlyManager {
        M.removeFromWhitelistBatch(accounts);
    }

    function removeFromWhitelist(address account) external onlyManager {
        M.removeFromWhitelist(account);
    }

    function addToBlacklist(address[] calldata accounts, AddressType addressType) external onlyManager {
        M.addToBlacklistBatch(accounts, addressType);
    }

    function addToBlacklist(address account, AddressType addressType) external onlyManager {
        M.addToBlacklist(account, addressType);
    }

    function removeFromBlacklist(address target) external onlyManager {
        M.removeFromBlacklist(target);
    }

    function removeFromBlacklist(address[] calldata accounts) external onlyManager {
        M.removeFromBlacklistBatch(accounts);
    }

    function addToListBatch(uint32 vaultId, address[] calldata accounts, AS status) external onlyManager {
        M.addToListBatch(vaultId, accounts, status);
    }

    function addToListBatch(address[] calldata accounts, AS status) external onlyManager {
        M.addToListBatch(accounts, status);
    }

    function removeFromListBatch(address[] calldata accounts) external onlyManager {
        M.removeFromListBatch(accounts);
    }

    function removeFromListBatch(uint32 vaultId, address[] calldata accounts) external onlyManager {
        M.removeFromListBatch(vaultId, accounts);
    }

    // Vault level whitelist/blacklist functions
    function isWhitelisted(uint32 vaultId, address account) external view returns (bool) {
        return M.isWhitelisted(account, vaultId);
    }

    function isBlacklisted(uint32 vaultId, address account) external view returns (bool) {
        return M.isBlacklisted(account, vaultId);
    }

    // Protocol level whitelist/blacklist functions
    function isWhitelisted(address account) external view returns (bool) {
        return M.isWhitelisted(account);
    }

    function isBlacklisted(address target) external view returns (bool) {
        return M.isBlacklisted(target);
    }

    function getAccountStatus(address target) external view returns (AS) {
        return M.getAccountStatus(target);
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                         RESTRICTED MINT                        ║
    ╚═══════════════════════════════════════════════════════════════*/

    function setProtocolRestrictedMint(bool restricted) external onlyManager {
        M.setRestrictedMint(restricted);
    }

    function isProtocolRestrictedMint() external view returns (bool) {
        return M.isRestrictedMint(0);
    }

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
    ║                          VAULT FEES                            ║
    ╚═══════════════════════════════════════════════════════════════*/

    function setAccountStatus(uint32 vaultId, address account, AS status) external onlyManager {
        M.setAccountStatus(vaultId, account, status);
    }

    function setAccountStatus(address account, AS status) external onlyManager {
        M.setAccountStatus(account, status);
    }

    function setAccountStatus(address[] calldata accounts, AS status) external onlyManager {
        M.setAccountStatusBatch(accounts, status);
    }

    function setAccountStatus(uint32 vaultId, address[] calldata accounts, AS status) external onlyManager {
        M.setAccountStatusBatch(vaultId, accounts, status);
    }

    function addToWhitelist(uint32 vaultId, address account) external onlyManager {
        M.addToWhitelist(vaultId, account);
    }

    function addToWhitelist(address account) external onlyManager {
        M.addToWhitelist(account);
    }

    function addToWhitelistBatch(uint32 vaultId, address[] calldata accounts) external onlyManager {
        M.addToWhitelistBatch(vaultId, accounts);
    }

    function addToWhitelistBatch(address[] calldata accounts) external onlyManager {
        M.addToWhitelistBatch(accounts);
    }

    function addToBlacklist(uint32 vaultId, address account) external onlyManager {
        M.addToBlacklist(vaultId, account);
    }

    function addToBlacklist(address account) external onlyManager {
        M.addToBlacklist(account);
    }

    function addToBlacklistBatch(uint32 vaultId, address[] calldata accounts) external onlyManager {
        M.addToBlacklistBatch(vaultId, accounts);
    }

    function addToBlacklistBatch(address[] calldata accounts) external onlyManager {
        M.addToBlacklistBatch(accounts);
    }

    function getAccountStatus(uint32 vaultId, address account) external view returns (AS) {
        return M.getAccountStatus(vaultId, account);
    }
}
